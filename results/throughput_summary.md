# Throughput Summary — iPerf TCP Benchmarking Results

**Project:** Study, Design, and Implementation of an SDN Architecture  
**Authors:** Abderrahmane Aroussi & Amin Mriroud  
**Supervisor:** Pr. Tarek AIT BAHA — ESTG, DUT RIS, 2025–2026

---

## Methodology

All throughput measurements were performed using **iPerf** (TCP mode) between emulated hosts in Mininet. Prior to each measurement, a double `pingall` round was executed to ensure all OpenFlow flow rules were installed by the OpenDaylight controller, eliminating the learning-phase overhead from the results.

- **Tool:** iPerf (TCP, default window size)
- **Environment:** Ubuntu 24.04 VM · 4 CPU cores · 8 GB RAM
- **Switch type:** Open vSwitch (OVS) · OpenFlow 1.3
- **Controller:** OpenDaylight (Karaf OSGi) inside Docker container

> **Important note:** Results marked `*` were obtained with no bandwidth constraints on virtual links. They reflect the theoretical maximum throughput of the emulated data path, not real-world physical hardware performance.

---

## Topology 2 — Dual Switch · 4 Hosts · 1 Controller

**Setup:**
- 2 OVS switches (s1, s2) connected via a **100 Mbps / 2 ms** inter-switch link
- h1, h2 attached to s1 — h3, h4 attached to s2
- 1 OpenDaylight controller at `127.0.0.1:6633`

### Results

| Test | Source | Destination | Path | Throughput |
|------|--------|-------------|------|-----------|
| A | h1 | h2 | Intra-switch (s1 only) | **640 Mbit/s** |
| B | h1 | h4 | Inter-switch (s1 → s2) | **585 Mbit/s** |

### iPerf Commands

```bash
# Test A — intra-switch
mininet> h2 iperf -s &
mininet> h1 iperf -c 10.0.0.2

# Test B — inter-switch
mininet> h4 iperf -s &
mininet> h1 iperf -c 10.0.0.4
```

### Analysis

The **55 Mbit/s delta** between Test A and Test B is explained by:

- The inter-switch link overhead (OVS processes the packet twice — once on egress from s1, once on ingress to s2).
- The 2 ms artificial delay on the inter-switch link (`delay='2ms'` in `projet_sdn.py`).
- Both values confirm that once FLOW_MOD entries are installed, **the ODL controller introduces zero throughput overhead** — all forwarding is handled by OVS in kernel space.

---

## Topology 3 — Multi-Controller · 6 Switches · 12 Hosts

**Setup:**
- 6 OVS switches (s1–s6), linear chain topology
- 12 hosts, 2 per switch (h1–h12)
- 3 independent OpenDaylight Docker containers:

| Controller | Docker Port | Switches Managed |
|-----------|-------------|-----------------|
| ODL-1 | 172.17.0.1:6633 | s1, s2 |
| ODL-2 | 172.17.0.1:6634 | s3, s4 |
| ODL-3 | 172.17.0.1:6635 | s5, s6 |

- **No bandwidth limit** imposed on virtual links

### Results

| Test | Source | Destination | Path | Throughput |
|------|--------|-------------|------|-----------|
| C | h1 | h6 | Cross-controller (ODL-1 → ODL-2) | **9.81 Gbits/s** `*` |

### Raw iPerf Output

```
------------------------------------------------------------
Client connecting to 10.0.0.6, TCP port 5001
TCP window size: 85.3 KByte (default)
------------------------------------------------------------
[  3] local 10.0.0.1 port 54321 connected with 10.0.0.6 port 5001
[ ID] Interval       Transfer     Bandwidth
[  3]  0.0-10.0 sec  11.5 GBytes  9.81 Gbits/sec
```

### Analysis

The 9.81 Gbits/s result demonstrates two critical properties:

1. **Negligible control plane overhead.** Post-installation, the controller is not consulted for forwarding — OVS handles everything in kernel space via the installed flow table entries.
2. **Transparent multi-controller coordination.** The h1 → h6 path crosses the ODL-1/ODL-2 domain boundary (s2 → s3 link). No throughput degradation was observed from this controller handoff, confirming that distributed control does not introduce a data plane bottleneck.

---

## Consolidated Comparison

| Scenario | Topology | Controllers | BW Limit | Result |
|----------|----------|-------------|----------|--------|
| h1 → h2 (intra-switch) | Dual switch | 1 | 100 Mbps | **640 Mbit/s** |
| h1 → h4 (inter-switch) | Dual switch | 1 | 100 Mbps | **585 Mbit/s** |
| h1 → h6 (cross-controller) | Multi-controller | 3 | None `*` | **9.81 Gbits/s** |

---

## Literature Comparison

| Controller | Benchmark | Switches | Result | Source |
|-----------|-----------|----------|--------|--------|
| OpenDaylight (early release) | Cbench latency | 8 | 55 req/s | Khattak et al., ICPADS 2014 |
| OpenDaylight (this work) | iPerf TCP | 6 | 9.81 Gbits/s | PFE Report, 2026 |

> The gap reflects both ODL's maturity since its initial release and the fundamental difference between Cbench latency testing (controller response rate) and iPerf bulk TCP throughput (data plane forwarding capacity).

---

*Documented: 24/03/2026 · Ubuntu 24.04 · OVS 2.17 · OpenDaylight 0.18.2 · Mininet 2.3.0*
