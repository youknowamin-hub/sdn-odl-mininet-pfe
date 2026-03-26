<div align="center">

<img src="assets/banner.png" alt="SDN Architecture Banner" width="100%"/>

# Study, Design, and Implementation of an SDN Architecture
### *Decoupling the Control Plane from the Data Plane using OpenDaylight, Mininet, and Docker*

[![OpenDaylight](https://img.shields.io/badge/Controller-OpenDaylight-blue?style=flat-square&logo=linux)](https://www.opendaylight.org/)
[![Mininet](https://img.shields.io/badge/Emulator-Mininet_2.3.0-green?style=flat-square)](http://mininet.org/)
[![Docker](https://img.shields.io/badge/Platform-Docker-2496ED?style=flat-square&logo=docker)](https://www.docker.com/)
[![OpenFlow](https://img.shields.io/badge/Protocol-OpenFlow_1.3-orange?style=flat-square)](https://www.opennetworking.org/)
[![Python](https://img.shields.io/badge/Scripting-Python_3-yellow?style=flat-square&logo=python)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square)](LICENSE)

> **Final Year Project (PFE) — Réseaux Informatiques et Sécurité (RIS)**  
> École Supérieure de Technologie de Guelmim (ESTG) — Academic Year 2025–2026

</div>

---

## Table of Contents

1. [Executive Summary](#-executive-summary)
2. [Key Technical Achievements](#-key-technical-achievements)
3. [Architecture Overview](#-architecture-overview)
4. [Technology Stack](#-technology-stack)
5. [Repository Structure](#-repository-structure)
6. [Environment Prerequisites](#-environment-prerequisites)
7. [Step-by-Step Setup Guide](#-step-by-step-setup-guide)
   - [Phase 1 — Deploy OpenDaylight via Docker](#phase-1--deploy-opendaylight-via-docker)
   - [Phase 2 — Launch Single-Switch Topology](#phase-2--launch-single-switch-topology)
   - [Phase 3 — Launch Dual-Switch Custom Topology](#phase-3--launch-dual-switch-custom-topology)
   - [Phase 4 — Multi-Controller Scalability Experiment](#phase-4--multi-controller-scalability-experiment)
8. [Experimental Results](#-experimental-results)
9. [OpenFlow Protocol Analysis](#-openflow-protocol-analysis)
10. [Challenges & Solutions](#-challenges--solutions)
11. [Future Perspectives](#-future-perspectives)
12. [References](#-references)
13. [Credits & Acknowledgements](#-credits--acknowledgements)

---

## 📋 Executive Summary

Traditional computer networks embed both the **Control Plane** and the **Data Plane** within each physical device. Routers and switches make autonomous forwarding decisions through distributed protocols (OSPF, BGP, STP), rendering network evolution and large-scale management increasingly complex and error-prone.

This project addresses this limitation by designing, deploying, and benchmarking a **Software-Defined Networking (SDN)** architecture — a paradigm that fundamentally decouples the control plane from the data plane. All network intelligence is centralized within a programmable software controller (**OpenDaylight**), while forwarding elements (**Open vSwitch**) remain stateless and are governed by flow rules delivered via the **OpenFlow 1.3** southbound protocol.

The practical implementation leverages **Mininet 2.3.0** for network topology emulation and **Docker** for reproducible, containerized controller deployment. The project progressively scales from a single-switch topology to a **distributed 3-controller, 6-switch, 12-host** architecture, validating both correctness and performance at each stage.

This repository serves as both a technical portfolio and a scientific reference — a reproducible, documented foundation for future researchers and engineers exploring programmable networking.

---

## 🏆 Key Technical Achievements

| Achievement | Detail |
|---|---|
| **Full SDN Stack Deployment** | OpenDaylight controller deployed inside Docker; OVS switches managed via OpenFlow 1.3 |
| **Progressive Topology Scaling** | Single switch → Dual switch → 6-switch / 12-host multi-controller topology |
| **Distributed Control Plane** | 3 independent OpenDaylight instances coordinating on ports 6633 / 6634 / 6635 |
| **Zero Packet Loss** | 0% drop across all 132 host pairs (pingall) in the multi-controller experiment |
| **9.81 Gbits/s Throughput** | Peak TCP throughput measured via iPerf3 in the unconstrained multi-controller topology |
| **640 / 585 Mbit/s** | Intra-switch vs. inter-switch throughput confirming expected SDN forwarding behavior |
| **OpenFlow Learning Phase** | Documented 50% → 0% packet loss transition as PACKET\_IN / FLOW\_MOD cycle completes |
| **Wireshark Protocol Analysis** | Captured and decoded HELLO, FEATURES\_REQUEST, PACKET\_IN, FLOW\_MOD, MULTIPART\_REQUEST |
| **Flow Table Inspection** | Verified reactive MAC-learning rules, flooding entries, and catch-all drop rules via `dpctl` |

---

## 🏗 Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                   APPLICATION PLANE                       │
│   Traffic Engineering  │  Load Balancing  │  Security     │
│             Northbound REST APIs (RESTCONF)               │
└───────────────────────┬──────────────────────────────────┘
                        │
┌───────────────────────▼──────────────────────────────────┐
│                    CONTROL PLANE                          │
│                                                           │
│   ┌──────────┐     ┌──────────┐     ┌──────────┐        │
│   │  ODL-1   │     │  ODL-2   │     │  ODL-3   │        │
│   │ :6633    │     │ :6634    │     │ :6635    │        │
│   └────┬─────┘     └────┬─────┘     └────┬─────┘        │
│        │ Southbound OpenFlow 1.3          │              │
└────────┼──────────────────────────────────┼──────────────┘
         │                                  │
┌────────▼──────────────────────────────────▼──────────────┐
│                     DATA PLANE                            │
│                                                           │
│  ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌────┐        │
│  │ s1 │──│ s2 │──│ s3 │──│ s4 │──│ s5 │──│ s6 │        │
│  └──┬─┘  └──┬─┘  └──┬─┘  └──┬─┘  └──┬─┘  └──┬─┘        │
│   h1,h2  h3,h4  h5,h6  h7,h8  h9,h10 h11,h12            │
└──────────────────────────────────────────────────────────┘
```

**Multi-Controller Experiment:** 6 Open vSwitch instances, 12 hosts (2 per switch), 3 independent OpenDaylight Docker containers — each managing 2 switches via OpenFlow 1.3.

---

## 🛠 Technology Stack

| Component | Tool / Version | Role |
|---|---|---|
| **SDN Controller** | OpenDaylight (Karaf OSGi) | Centralized Control Plane — flow rule management via RESTCONF |
| **Network Emulator** | Mininet 2.3.0 | Virtual topology creation using Linux network namespaces |
| **Containerization** | Docker | Reproducible, isolated ODL controller deployment |
| **Southbound Protocol** | OpenFlow 1.3 | Controller ↔ Switch communication protocol |
| **Data Plane** | Open vSwitch (OVS) | Programmable virtual switches executing flow table rules |
| **Performance Testing** | iPerf3 | TCP throughput benchmarking between emulated hosts |
| **Protocol Analysis** | Wireshark | OpenFlow message capture and dissection |
| **Scripting** | Python 3 | Custom Mininet topology definition scripts |
| **Host OS** | Ubuntu 24.04 LTS | Base virtual machine (4 CPU cores, 8 GB RAM) |
| **ODL Features** | `odl-restconf`, `odl-l2switch-switch` | RESTCONF API exposure + Layer 2 reactive switching |

---

## 📁 Repository Structure

```
sdn-odl-mininet-pfe/
│
├── README.md                        # This document
├── LICENSE
│
├── scripts/                         # All executable scripts
│   ├── topologies/
│   │   ├── projet_sdn.py            # Dual-switch 4-host topology (Topology 2)
│   │   └── sdn_top2.py              # 6-switch 12-host 3-controller topology
│   ├── docker/
│   │   └── start_odl_controllers.sh # Launch 3 ODL Docker containers
│   └── tests/
│       ├── run_pingall.sh           # Automate connectivity tests
│       └── run_iperf.sh             # Automate throughput benchmarking
│
├── docs/                            # Academic documentation
│   ├── PFE_Report_SDN_G15_RIS.pdf  # Full final year project report
│   ├── PFE_Presentation_SDN_G15.pdf # Defense presentation slides
│   └── improvement_plan.pdf         # Post-defense improvement roadmap
│
├── assets/                          # Figures, diagrams, screenshots
│   ├── architecture_diagram.png
│   ├── topology_single_switch.png
│   ├── topology_dual_switch.png
│   ├── topology_multi_controller.png
│   ├── wireshark_openflow.png
│   ├── iperf_results/
│   │   ├── iperf_intra_640mbps.png
│   │   ├── iperf_inter_585mbps.png
│   │   └── iperf_multicontroller_9.81gbps.png
│   └── connectivity_tests/
│       ├── pingall_learning_phase.png
│       └── pingall_full_connectivity.png
│
├── results/                         # Raw experimental data
│   ├── throughput_summary.md
│   ├── flow_table_dumps.txt
│   └── rtt_measurements.md
│
└── references/                      # Bibliography and related papers
    └── bibliography.md
```

---

## 💻 Environment Prerequisites

Before replicating this environment, ensure the following:

- **Host OS:** Ubuntu 22.04 or 24.04 LTS (VM or native)
- **RAM:** Minimum 8 GB
- **CPU:** 4 cores recommended
- **Docker:** v24.0+ installed ([official guide](https://docs.docker.com/engine/install/ubuntu/))
- **Mininet:** v2.3.0 installed
- **Python:** 3.10+
- **Network:** Docker bridge interface available (`172.17.0.1` default)

**Install Mininet:**
```bash
sudo apt update && sudo apt install -y mininet openvswitch-switch
```

**Verify Open vSwitch:**
```bash
sudo ovs-vsctl show
```

---

## 🚀 Step-by-Step Setup Guide

### Phase 1 — Deploy OpenDaylight via Docker

> This phase deploys the OpenDaylight SDN controller in an isolated Docker container and activates the required features.

**Step 1.1 — Pull the OpenDaylight Docker image:**
```bash
docker pull opendaylight/odl:0.18.2
```

**Step 1.2 — Launch the container in interactive mode:**
```bash
docker run -itd \
  --name odl1 \
  -p 6633:6633 \
  -p 8181:8181 \
  -p 8101:8101 \
  opendaylight/odl:0.18.2
```

> **Note:** The `-itd` flag is critical. Running without `-it` causes the Karaf shell initialization to fail with the error `String index out of range: 0`. This was a documented challenge in this project.

**Step 1.3 — Attach to the Karaf console:**
```bash
docker exec -it odl1 /opt/opendaylight/bin/client
```

**Step 1.4 — Install required features inside the Karaf CLI:**
```
opendaylight-user@root> feature:install odl-restconf
opendaylight-user@root> feature:install odl-l2switch-switch
```

**Step 1.5 — Verify the controller is listening on OpenFlow port:**
```bash
ss -tlnp | grep 6633
# Expected: LISTEN on 0.0.0.0:6633
```

---

### Phase 2 — Launch Single-Switch Topology

> Tests basic controller connectivity and the OpenFlow learning phase.

```bash
sudo mn \
  --controller=remote,ip=127.0.0.1,port=6633 \
  --topo=single,3 \
  --switch ovsk,protocols=OpenFlow13
```

**Inside the Mininet CLI — run connectivity tests:**
```
mininet> pingall
# Expected first run: ~50% packet loss (learning phase)

mininet> pingall
# Expected second run: 0% packet loss (flows installed)
```

**Inspect installed flow tables:**
```
mininet> sh ovs-ofctl dump-flows s1 -O OpenFlow13
```

---

### Phase 3 — Launch Dual-Switch Custom Topology

> Evaluates inter-switch routing and iPerf throughput across two hops.

Use the provided custom topology script:
```bash
sudo mn \
  --custom scripts/topologies/projet_sdn.py \
  --topo projet_sdn \
  --controller=remote,ip=127.0.0.1,port=6633 \
  --switch ovsk,protocols=OpenFlow13
```

**Run iPerf throughput tests:**
```
mininet> h4 iperf -s &
mininet> h1 iperf -c 10.0.0.4
# Expected: ~585 Mbit/s (inter-switch, 2 hops)

mininet> h2 iperf -s &
mininet> h1 iperf -c 10.0.0.2
# Expected: ~640 Mbit/s (intra-switch, 1 hop)
```

---

### Phase 4 — Multi-Controller Scalability Experiment

> Deploys 3 independent OpenDaylight instances and a 6-switch / 12-host topology to validate distributed control plane scalability.

**Step 4.1 — Launch 3 ODL containers on distinct ports:**
```bash
# Controller 1
docker run -itd --name odl1 -p 6633:6633 -p 8181:8181 opendaylight/odl:0.18.2

# Controller 2
docker run -itd --name odl2 -p 6634:6633 -p 8182:8181 opendaylight/odl:0.18.2

# Controller 3
docker run -itd --name odl3 -p 6635:6633 -p 8183:8181 opendaylight/odl:0.18.2
```

**Step 4.2 — Install features on each controller (repeat for odl2, odl3):**
```bash
docker exec -it odl1 /opt/opendaylight/bin/client \
  -u karaf "feature:install odl-restconf odl-l2switch-switch"
```

**Step 4.3 — Launch the multi-controller topology:**
```bash
sudo python3 scripts/topologies/sdn_top2.py
```

> The `sdn_top2.py` script creates 6 switches and 12 hosts, assigning switches s1–s2 to ODL-1 (172.17.0.1:6633), s3–s4 to ODL-2 (172.17.0.1:6634), and s5–s6 to ODL-3 (172.17.0.1:6635).

**Step 4.4 — Validate full connectivity:**
```
mininet> pingall
# Expected: 0% dropped (132/132 received)
```

**Step 4.5 — Measure peak throughput:**
```
mininet> h6 iperf -s &
mininet> h1 iperf -c 10.0.0.6
# Expected: 9.81 Gbits/sec
```

---

## 📊 Experimental Results

### Connectivity Tests

| Test | Topology | Packet Loss |
|---|---|---|
| 1st `pingall` | Single switch (3 hosts) | **50%** — learning phase |
| 2nd `pingall` | Single switch (3 hosts) | **0%** — flows installed |
| `pingall` | Dual switch (4 hosts) | **0%** — full connectivity |
| `pingall` | 3-controller / 6-switch / 12-host | **0%** — 132/132 received |

### Throughput Performance (iPerf3 / TCP)

| Scenario | Topology | Throughput |
|---|---|---|
| h1 → h2 (same switch) | Dual-switch | **640 Mbit/s** |
| h1 → h4 (different switch) | Dual-switch | **585 Mbit/s** |
| h1 → h6 (multi-controller) | 6-switch / 3-ODL | **9.81 Gbits/s** |

> The 640 → 585 Mbit/s delta confirms the expected inter-switch processing overhead. The 9.81 Gbits/s figure is obtained without bandwidth constraints on virtual links, reflecting the theoretical maximum throughput of the emulated data path.

### RTT Measurements (Multi-Controller Topology)

| Path | Min RTT | Max RTT |
|---|---|---|
| h1 → h2 (same switch) | 0.075 ms | 0.151 ms |
| h1 → h6 (different switch) | 0.067 ms | 0.276 ms |
| h1 → h12 (full traversal) | 0.080 ms | 0.185 ms |

---

## 🔬 OpenFlow Protocol Analysis

Wireshark captures confirm the standard OpenFlow 1.3 message lifecycle:

| Message Type | Direction | Meaning |
|---|---|---|
| `OFPT_HELLO` | Controller ↔ Switch | Protocol handshake and version negotiation |
| `OFPT_FEATURES_REQUEST` | Controller → Switch | Controller queries switch capabilities and datapath ID |
| `OFPT_PACKET_IN` | Switch → Controller | Unknown flow — switch escalates first packet to controller |
| `OFPT_FLOW_MOD` | Controller → Switch | Controller installs a reactive flow entry in the switch table |
| `OFPT_MULTIPART_REQUEST` | Controller → Switch | Controller requests flow statistics and counters |

**Sample flow entry extracted via `dpctl dump-flows` (switch s1):**

```
dl_src=00:00:00:00:00:01, dl_dst=00:00:00:00:00:02
  → action: output:s1-eth2 | priority=10 | n_packets=41

dl_src=00:00:00:00:00:02, dl_dst=00:00:00:00:00:01
  → action: output:s1-eth1 | priority=10 | n_packets=2

in_port=s1-eth1 (unknown destination)
  → action: output:s1-eth2, CONTROLLER | priority=2

* (catch-all)
  → action: drop | priority=0
```

---

## ⚠ Challenges & Solutions

| Challenge | Root Cause | Solution Applied |
|---|---|---|
| **Karaf startup failure** — `String index out of range: 0` | ODL container launched without interactive TTY | Relaunched with `docker run -itd` flag; manually installed features via Karaf CLI |
| **MiniEdit import error** — `StrictVersion not found` | `distutils` removed from Python 3 in Ubuntu 24.04 | Abandoned MiniEdit; used custom Python topology scripts via CLI — all experiments completed successfully |
| **Initial 50% packet loss** | Expected SDN behavior — PACKET\_IN flood during controller learning phase | Documented as expected behavior; confirmed 0% loss after FLOW\_MOD cycle completion |
| **Multi-controller port conflicts** | Three ODL instances share the default 6633 port | Mapped each container to distinct host ports (6633 / 6634 / 6635); custom Python script assigned switches to corresponding controllers |

---

## 🔭 Future Perspectives

This project establishes a foundational SDN prototype. The following research directions represent natural extensions:

### 1. Quantitative Controller Benchmarking
Deploy **Cbench** to evaluate OpenDaylight's throughput and latency under stress conditions (varying number of switches and flow request rates). Compare against Floodlight, ONOS, and Ryu using standardized metrics.

### 2. East-West Protocol Implementation
Implement controller-to-controller state synchronization using East-West protocols (e.g., **BGP-LS**, **HyperFlow**). This is critical for true multi-domain SDN consistency, especially in multi-controller deployments where flow state must be shared across controller boundaries.

### 3. SDN-Based Security Functions
Given the RIS specialization, this is the most strategically relevant extension:
- **DDoS mitigation** via reactive flow blocking at the controller level
- **Distributed firewall** using northbound REST API rule injection
- **Network slicing** to enforce security zones
- **SIEM integration** for event correlation with SDN topology data

### 4. Advanced QoS Measurements
Instrument the topology with **D-ITG** to measure latency distribution, jitter, and loss rate under heterogeneous traffic loads (UDP bursts, VoIP simulations, bulk transfers).

### 5. Failure Scenario Simulation
Simulate link and switch failures and observe controller convergence behavior: time to reroute, flow reconvergence latency, and topology update propagation.

### 6. Kubernetes + SDN Integration
Combine SDN network policies with **Kubernetes** container orchestration to enforce microsegmentation and programmable network policies for microservices architectures.

### 7. Physical Hardware Validation
Migrate from emulated (Mininet) to physical **OpenFlow-capable switches** (e.g., HP ProCurve, Pica8) to validate results under real hardware constraints.

---

## 📚 References

1. N. McKeown et al., "OpenFlow: enabling innovation in campus networks," *ACM SIGCOMM CCR*, vol. 38, no. 2, pp. 69–74, 2008.
2. Open Networking Foundation, "SDN Definition." [Online]. https://www.opennetworking.org/sdn-definition/
3. D. Kreutz et al., "Software-Defined Networking: A Comprehensive Survey," *Proc. IEEE*, vol. 103, no. 1, pp. 14–76, 2015.
4. OpenDaylight Project. [Online]. https://www.opendaylight.org/
5. Mininet Team. [Online]. http://mininet.org/
6. Z. K. Khattak, M. Awais, and A. Iqbal, "Performance Evaluation of OpenDaylight SDN Controller," *Proc. ICPADS*, 2014.
7. T. Li, J. Chen, and H. Fu, "Application Scenarios based on SDN: An Overview," *J. Phys.: Conf. Ser.*, vol. 1187, 2019.
8. T. Hu et al., "Multi-controller Based SDN: A Survey," *IEEE Access*, vol. 6, pp. 15980–15996, 2018.

---

## 👥 Credits & Acknowledgements

<div align="center">

| Role | Name |
|---|---|
| **Developer & Researcher** | [Abderrahmane Aroussi](https://abderrahmane-aroussi.me) — [@Abderrahmane-Aroussi](https://github.com/Abderrahmane-Aroussi) |
| **Developer & Researcher** | Amin Mriroud |
| **Project Supervisor** | Pr. Tarek AIT BAHA — École Supérieure de Technologie de Guelmim |
| **Jury Member** | Pr. Amine Bouaouda — ESTG |

</div>

**Special Thanks:**  
We extend particular gratitude to **Pr. Amine Bouaouda** for his course on Virtualization and Cloud Computing, which provided the essential foundation in Docker containerization applied throughout this project. We also thank **Pr. Tarek AIT BAHA** for suggesting this advanced topic and for his guidance in navigating an emerging technology absent from our curriculum.

---

<div align="center">

> *"We chose to learn what was not taught — and built a working SDN prototype from scratch."*  
> — Abderrahmane Aroussi & Amin Mriroud, 2026

**École Supérieure de Technologie de Guelmim (ESTG) — DUT Réseaux Informatiques et Sécurité**  
Academic Year 2025–2026

</div>
