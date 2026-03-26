#!/usr/bin/env bash
# =============================================================================
#  run_iperf.sh
#  Automated TCP throughput benchmarking for both SDN topologies.
# =============================================================================
#  Project    : Study, Design, and Implementation of an SDN Architecture
#  Authors    : Abderrahmane Aroussi & Amin Mriroud
#  Supervisor : Pr. Tarek AIT BAHA
#  Institution: ESTG — DUT Réseaux Informatiques & Sécurité (RIS)
#  Year       : 2025-2026
#
#  What this script does
#  ---------------------
#  Runs a series of iPerf TCP throughput tests that replicate the exact
#  measurements reported in the PFE (Chapter 3, Section 3.2):
#
#  Dual-switch topology:
#    Test A — h1 → h2  (intra-switch, same s1)   → expected ~640 Mbit/s
#    Test B — h1 → h4  (inter-switch, s1 → s2)   → expected ~585 Mbit/s
#
#  Multi-controller topology:
#    Test C — h1 → h6  (cross-controller, s1→s3) → expected ~9.81 Gbits/s
#
#  Usage
#  -----
#    # Dual-switch topology:
#    sudo bash run_iperf.sh --topo dual
#
#    # Multi-controller topology:
#    sudo bash run_iperf.sh --topo multi
#
#    # Default (dual):
#    sudo bash run_iperf.sh
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_result(){ echo -e "${CYAN}[RESULT]${NC} $*"; }

# ── Parse arguments ───────────────────────────────────────────────────────────
TOPO="${1:---topo}"
MODE="${2:-dual}"
[[ "$TOPO" != "--topo" ]] && MODE="$TOPO"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPO_DIR="${SCRIPT_DIR}/../topologies"
RESULTS_DIR="${SCRIPT_DIR}/../../results"
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
RESULT_FILE="${RESULTS_DIR}/iperf_${MODE}_${TIMESTAMP}.txt"

# ── Topology-specific configuration ──────────────────────────────────────────
case "$MODE" in
    dual)
        TOPO_SCRIPT="${TOPO_DIR}/projet_sdn.py"
        TOPO_NAME="projet_sdn"
        CONTROLLER_PORT=6633
        DESCRIPTION="Dual-Switch / 4-Host — Single ODL Controller"

        # iPerf test pairs: "server_host server_ip client_host label"
        IPERF_TESTS=(
            "h2|10.0.0.2|h1|Intra-switch (h1→h2, same s1) — expected ~640 Mbit/s"
            "h4|10.0.0.4|h1|Inter-switch (h1→h4, s1→s2)  — expected ~585 Mbit/s"
        )
        ;;
    multi)
        TOPO_SCRIPT="${TOPO_DIR}/sdn_top2.py"
        TOPO_NAME="direct"
        CONTROLLER_PORT=6633
        DESCRIPTION="6-Switch / 12-Host — 3 ODL Controllers"

        IPERF_TESTS=(
            "h6|10.0.0.6|h1|Cross-controller (h1→h6, s1→s3) — expected ~9.81 Gbits/s"
            "h2|10.0.0.2|h1|Intra-switch     (h1→h2, same s1)"
            "h12|10.0.0.12|h1|Full traversal  (h1→h12, s1→s6)"
        )
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Unknown topology: '$MODE'. Use: dual | multi"
        exit 1
        ;;
esac

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         Automated iPerf Throughput Test — SDN PFE 2025-2026 ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
log_info "Topology : ${DESCRIPTION}"
log_info "Results  : ${RESULT_FILE}"
echo ""

# ── Check prerequisites ───────────────────────────────────────────────────────
log_step "Checking prerequisites..."

for tool in mn iperf; do
    if ! command -v "$tool" &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} '$tool' not found."
        [[ "$tool" == "iperf" ]] && echo "  Install with: sudo apt install iperf"
        exit 1
    fi
done

if ! nc -z 127.0.0.1 "$CONTROLLER_PORT" 2>/dev/null; then
    log_warn "ODL controller not detected on port ${CONTROLLER_PORT}."
    read -rp "Continue anyway? [y/N] " confirm
    [[ "${confirm,,}" != "y" ]] && exit 1
fi

log_info "Prerequisites OK."
echo ""

# ── Build iPerf Mininet command sequence ─────────────────────────────────────
# Strategy:
#   1. Run pingall twice to prime the flow tables (eliminates learning phase
#      overhead from throughput numbers — matches report methodology).
#   2. For each test pair: start iPerf server on server_host, run iPerf
#      client on client_host, kill server, wait between tests.

build_mininet_commands() {
    echo "py print('\n[PRIMING] Running 2x pingall to install all flow rules...')"
    echo "pingall"
    echo "py import time; time.sleep(2)"
    echo "pingall"
    echo "py import time; time.sleep(2)"
    echo ""

    local test_num=1
    for test in "${IPERF_TESTS[@]}"; do
        IFS='|' read -r server_host server_ip client_host label <<< "$test"
        echo "py print(f'\n[TEST ${test_num}] ${label}')"
        echo "${server_host} iperf -s -t 15 &"
        echo "py import time; time.sleep(1)"
        echo "${client_host} iperf -c ${server_ip} -t 10 -i 2"
        echo "py import time; time.sleep(2)"
        echo "${server_host} kill %1"
        echo "py import time; time.sleep(1)"
        echo ""
        ((test_num++))
    done

    echo "py print('\n[DONE] All iPerf tests complete.')"
    echo "exit"
}

# ── Write header to results file ──────────────────────────────────────────────
{
    echo "═══════════════════════════════════════════════════════════════"
    echo "  iPerf Throughput Report — $(date)"
    echo "  Topology: ${DESCRIPTION}"
    echo "  Tests:"
    for test in "${IPERF_TESTS[@]}"; do
        IFS='|' read -r _ _ _ label <<< "$test"
        echo "    • ${label}"
    done
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
} | tee "$RESULT_FILE"

# ── Run Mininet ───────────────────────────────────────────────────────────────
log_step "Launching Mininet and running iPerf tests..."
echo "(This will take approximately $((${#IPERF_TESTS[@]} * 15 + 30)) seconds)"
echo ""

COMMANDS=$(build_mininet_commands)

if [[ "$MODE" == "multi" ]]; then
    echo "$COMMANDS" | sudo python3 "$TOPO_SCRIPT" 2>&1 | tee -a "$RESULT_FILE"
else
    echo "$COMMANDS" | sudo mn \
        --custom "$TOPO_SCRIPT" \
        --topo "$TOPO_NAME" \
        --controller=remote,ip=127.0.0.1,port="$CONTROLLER_PORT" \
        --switch ovsk,protocols=OpenFlow13 \
        --link tc \
        2>&1 | tee -a "$RESULT_FILE"
fi

# ── Parse and display summary ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log_result "Throughput Summary"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Extract iPerf summary lines (look for Mbits/sec or Gbits/sec in results)
echo "  Extracted iPerf results:"
grep -E "(Mbits/sec|Gbits/sec)" "$RESULT_FILE" \
    | grep -v "^--" \
    | awk '{print "  " $0}' \
    || log_warn "Could not auto-parse results — check ${RESULT_FILE} manually."

echo ""

# ── Reference table (from PFE report) ────────────────────────────────────────
echo -e "${CYAN}  Reference values from PFE report (Chapter 3):${NC}"
echo "  ┌─────────────────────────────────────────┬────────────────┐"
echo "  │ Scenario                                │ Throughput     │"
echo "  ├─────────────────────────────────────────┼────────────────┤"
echo "  │ h1→h2  intra-switch (dual topology)     │  ~640 Mbit/s   │"
echo "  │ h1→h4  inter-switch (dual topology)     │  ~585 Mbit/s   │"
echo "  │ h1→h6  multi-controller (no BW limit)   │  ~9.81 Gbits/s │"
echo "  └─────────────────────────────────────────┴────────────────┘"
echo ""
log_info "Full results saved to: ${RESULT_FILE}"
echo ""
