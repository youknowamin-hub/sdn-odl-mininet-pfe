#!/usr/bin/env bash
# =============================================================================
#  start_odl_controllers.sh
#  Launch 3 OpenDaylight SDN controllers in isolated Docker containers.
# =============================================================================
#  Project    : Study, Design, and Implementation of an SDN Architecture
#  Authors    : Abderrahmane Aroussi & Amin Mriroud
#  Supervisor : Pr. Tarek AIT BAHA
#  Institution: ESTG — DUT Réseaux Informatiques & Sécurité (RIS)
#  Year       : 2025-2026
#
#  Controller mapping:
#    ODL-1 → host port 6633  (manages s1, s2)
#    ODL-2 → host port 6634  (manages s3, s4)
#    ODL-3 → host port 6635  (manages s5, s6)
#
#  Usage:
#    chmod +x start_odl_controllers.sh
#    ./start_odl_controllers.sh
#
#  To stop and remove all containers:
#    ./start_odl_controllers.sh --stop
# =============================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
ODL_IMAGE="opendaylight/odl:0.18.2"
FEATURES="odl-restconf odl-l2switch-switch"

declare -A CONTROLLERS=(
    ["odl1"]="6633:8181:8101"
    ["odl2"]="6634:8182:8102"
    ["odl3"]="6635:8183:8103"
)
# Format: OpenFlow_port:RESTCONF_port:Karaf_SSH_port

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colour

# ── Helper functions ──────────────────────────────────────────────────────────

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║       OpenDaylight Multi-Controller Bootstrap Script         ║"
    echo "║       ESTG PFE 2025-2026 — SDN Architecture                 ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()    { echo -e "${BLUE}[STEP]${NC}  $*"; }

container_exists() { docker ps -a --format '{{.Names}}' | grep -q "^${1}$"; }
container_running() { docker ps --format '{{.Names}}' | grep -q "^${1}$"; }

# ── Stop mode ─────────────────────────────────────────────────────────────────
stop_all() {
    echo ""
    log_warn "Stopping and removing all ODL controller containers..."
    for name in "${!CONTROLLERS[@]}"; do
        if container_exists "$name"; then
            docker rm -f "$name" && log_info "Removed: $name"
        else
            log_warn "$name not found — skipping."
        fi
    done
    echo ""
    log_info "All ODL containers removed."
    exit 0
}

[[ "${1:-}" == "--stop" ]] && stop_all

# ── Main deployment ───────────────────────────────────────────────────────────

print_banner

# Step 1: Check Docker is running
log_step "Checking Docker daemon..."
if ! docker info &>/dev/null; then
    log_error "Docker is not running. Please start Docker and retry."
    exit 1
fi
log_info "Docker is running."

# Step 2: Pull ODL image if not present
log_step "Checking ODL image: ${ODL_IMAGE}"
if ! docker image inspect "${ODL_IMAGE}" &>/dev/null; then
    log_warn "Image not found locally. Pulling from Docker Hub..."
    docker pull "${ODL_IMAGE}"
else
    log_info "Image already present — skipping pull."
fi

# Step 3: Launch containers
echo ""
log_step "Launching OpenDaylight controller containers..."
echo ""

for name in odl1 odl2 odl3; do
    IFS=':' read -r of_port restconf_port karaf_port <<< "${CONTROLLERS[$name]}"

    if container_running "$name"; then
        log_warn "${name} is already running — skipping."
        continue
    fi

    if container_exists "$name"; then
        log_warn "${name} container exists but is stopped. Removing stale container..."
        docker rm -f "$name"
    fi

    log_info "Starting ${name}  (OpenFlow: ${of_port} | RESTCONF: ${restconf_port} | Karaf SSH: ${karaf_port})"

    docker run -itd \
        --name "${name}" \
        -p "${of_port}:6633" \
        -p "${restconf_port}:8181" \
        -p "${karaf_port}:8101" \
        "${ODL_IMAGE}" \
        > /dev/null

    log_info "${name} container started."
done

# Step 4: Wait for Karaf to initialise
echo ""
log_step "Waiting for Karaf shell to initialise (45 seconds)..."
echo -n "    "
for i in $(seq 1 45); do
    sleep 1
    echo -n "."
    [[ $((i % 10)) -eq 0 ]] && echo -n " ${i}s "
done
echo ""

# Step 5: Install required features in each container
echo ""
log_step "Installing ODL features: ${FEATURES}"
echo ""

for name in odl1 odl2 odl3; do
    if ! container_running "$name"; then
        log_error "${name} is not running — cannot install features."
        continue
    fi

    log_info "Installing features on ${name}..."

    docker exec -i "${name}" \
        /opt/opendaylight/bin/client \
        -u karaf \
        "feature:install ${FEATURES}" 2>/dev/null \
    && log_info "${name} — features installed successfully." \
    || log_warn "${name} — feature install command returned non-zero. Verify manually."

done

# Step 6: Verify all containers are running
echo ""
log_step "Verification — running containers:"
echo ""
printf "  %-10s %-20s %-20s %-20s\n" "NAME" "OpenFlow Port" "RESTCONF Port" "Status"
printf "  %-10s %-20s %-20s %-20s\n" "────────" "──────────────" "─────────────" "──────"

for name in odl1 odl2 odl3; do
    IFS=':' read -r of_port restconf_port karaf_port <<< "${CONTROLLERS[$name]}"
    if container_running "$name"; then
        status="${GREEN}RUNNING${NC}"
    else
        status="${RED}NOT RUNNING${NC}"
    fi
    printf "  %-10s %-20s %-20s " "$name" "0.0.0.0:${of_port}" "0.0.0.0:${restconf_port}"
    echo -e "${status}"
done

# Step 7: Print next steps
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  All controllers are ready. Next step:${NC}"
echo ""
echo "  sudo python3 scripts/topologies/sdn_top2.py"
echo ""
echo "  Inside Mininet CLI:"
echo "    mininet> pingall                         # Expect 0% loss"
echo "    mininet> h6 iperf -s &"
echo "    mininet> h1 iperf -c 10.0.0.6           # Expect ~9.81 Gbits/s"
echo ""
echo "  RESTCONF API (ODL-1):"
echo "    http://localhost:8181/restconf/operational/network-topology:network-topology"
echo "    Default credentials: admin / admin"
echo ""
echo "  To stop all containers:"
echo "    ./start_odl_controllers.sh --stop"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""
