#!/usr/bin/env bash
# =============================================================================
#  run_pingall.sh
#  Automated connectivity test for both SDN topologies.
# =============================================================================
#  Project    : Study, Design, and Implementation of an SDN Architecture
#  Authors    : Abderrahmane Aroussi & Amin Mriroud
#  Supervisor : Pr. Tarek AIT BAHA
#  Institution: ESTG — DUT Réseaux Informatiques & Sécurité (RIS)
#  Year       : 2025-2026
#
#  What this script does
#  ---------------------
#  Runs TWO consecutive pingall rounds to demonstrate the OpenFlow
#  learning phase behaviour documented in the PFE report:
#
#    Round 1 — ~50% packet loss  (PACKET_IN flood, flows not yet installed)
#    Round 2 —   0% packet loss  (FLOW_MOD installed, all paths known)
#
#  Then runs targeted ping tests between specific host pairs to measure RTT.
#
#  Usage
#  -----
#    # Dual-switch topology (Topology 2):
#    sudo bash run_pingall.sh --topo dual
#
#    # Multi-controller topology (Topology 3):
#    sudo bash run_pingall.sh --topo multi
#
#    # Default (dual) if no flag given:
#    sudo bash run_pingall.sh
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

# Support both: --topo dual   OR   just: dual
if [[ "$TOPO" != "--topo" ]]; then
    MODE="$TOPO"
fi

# ── Resolve topology script and controller port ───────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOPO_DIR="${SCRIPT_DIR}/../topologies"
RESULTS_DIR="${SCRIPT_DIR}/../../results"
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
RESULT_FILE="${RESULTS_DIR}/pingall_${MODE}_${TIMESTAMP}.txt"

case "$MODE" in
    dual)
        TOPO_SCRIPT="${TOPO_DIR}/projet_sdn.py"
        TOPO_NAME="projet_sdn"
        CONTROLLER_PORT=6633
        DESCRIPTION="Dual-Switch / 4-Host — Single ODL Controller"
        ;;
    multi)
        TOPO_SCRIPT="${TOPO_DIR}/sdn_top2.py"
        TOPO_NAME="direct"   # sdn_top2.py has its own main()
        CONTROLLER_PORT=6633
        DESCRIPTION="6-Switch / 12-Host — 3 ODL Controllers"
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Unknown topology: '$MODE'. Use: dual | multi"
        exit 1
        ;;
esac

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           Automated Pingall Test — SDN PFE 2025-2026        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
log_info "Topology   : ${DESCRIPTION}"
log_info "Script     : ${TOPO_SCRIPT}"
log_info "Results    : ${RESULT_FILE}"
echo ""

# ── Check prerequisites ───────────────────────────────────────────────────────
log_step "Checking prerequisites..."

if ! command -v mn &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} Mininet not found. Install with: sudo apt install mininet"
    exit 1
fi

if ! command -v ovs-vsctl &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} Open vSwitch not found."
    exit 1
fi

# Check ODL controller is reachable on expected port
if ! nc -z 127.0.0.1 "$CONTROLLER_PORT" 2>/dev/null; then
    log_warn "ODL controller not detected on port ${CONTROLLER_PORT}."
    log_warn "Make sure start_odl_controllers.sh has been run first."
    read -rp "Continue anyway? [y/N] " confirm
    [[ "${confirm,,}" != "y" ]] && exit 1
fi

log_info "Prerequisites OK."
echo ""

# ── Mininet commands to run inside the session ────────────────────────────────
# These are piped into Mininet's stdin for automated execution.
MININET_COMMANDS=$(cat <<'EOF'
py print("\n[TEST 1] Round 1 pingall — expect ~50% loss (learning phase)")
pingall
py print("\n[TEST 2] Waiting 3 seconds for flows to stabilise...")
py import time; time.sleep(3)
py print("\n[TEST 3] Round 2 pingall — expect 0% loss (flows installed)")
pingall
py print("\n[TEST 4] Targeted RTT tests")
h1 ping -c 3 h2
h1 ping -c 3 h3
py print("\n[TEST 5] Flow table inspection on s1")
sh ovs-ofctl dump-flows s1 -O OpenFlow13
py print("\n[TEST 6] Flow table inspection on s2")
sh ovs-ofctl dump-flows s2 -O OpenFlow13
py print("\n[DONE] All connectivity tests complete. Exiting.")
exit
EOF
)

# ── Run Mininet ───────────────────────────────────────────────────────────────
log_step "Launching Mininet and running tests..."
echo "═══════════════════════════════════════════════════════════════" | tee "$RESULT_FILE"
echo "  Pingall Test Report — $(date)"                                | tee -a "$RESULT_FILE"
echo "  Topology: ${DESCRIPTION}"                                     | tee -a "$RESULT_FILE"
echo "═══════════════════════════════════════════════════════════════" | tee -a "$RESULT_FILE"
echo ""

if [[ "$MODE" == "multi" ]]; then
    # Multi-controller: topology has its own main(), pipe commands into CLI
    echo "$MININET_COMMANDS" | sudo python3 "$TOPO_SCRIPT" 2>&1 | tee -a "$RESULT_FILE"
else
    # Dual-switch: use mn --custom flag
    echo "$MININET_COMMANDS" | sudo mn \
        --custom "$TOPO_SCRIPT" \
        --topo "$TOPO_NAME" \
        --controller=remote,ip=127.0.0.1,port="$CONTROLLER_PORT" \
        --switch ovsk,protocols=OpenFlow13 \
        --link tc \
        2>&1 | tee -a "$RESULT_FILE"
fi

# ── Parse and summarise results ───────────────────────────────────────────────
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
log_result "Test Summary"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

# Extract packet loss lines from results file
ROUND1=$(grep -A1 "Round 1" "$RESULT_FILE" | grep "Results:" | head -1 || echo "Not captured")
ROUND2=$(grep -A1 "Round 2" "$RESULT_FILE" | grep "Results:" | head -1 || echo "Not captured")

echo ""
log_result "Round 1 (learning phase) : ${ROUND1}"
log_result "Round 2 (flows installed): ${ROUND2}"
echo ""
log_info "Full results saved to: ${RESULT_FILE}"
echo ""
