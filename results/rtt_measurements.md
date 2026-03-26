# RTT Measurements — Latency Analysis

**Project:** Study, Design, and Implementation of an SDN Architecture  
**Authors:** Abderrahmane Aroussi & Amin Mriroud  
**Supervisor:** Pr. Tarek AIT BAHA — ESTG, DUT RIS, 2025–2026

---

## Methodology

Latency was measured using the `ping` utility between host pairs across both topologies. Each test used **3 ICMP echo requests** (`ping -c 3`). RTT values (min/avg/max) are reported in milliseconds.

All measurements were taken **after flow rules were installed** (post-learning phase) to reflect steady-state SDN forwarding performance, not initial controller reaction time.

- **Tool:** `ping` (ICMP echo request/reply)
- **Packets per test:** 3
- **Environment:** Ubuntu 24.04 VM · 4 CPU cores · 8 GB RAM
- **Switch type:** Open vSwitch (OVS) · OpenFlow 1.3

---

## Topology 2 — Dual Switch · 4 Hosts · 1 Controller

**Topology script:** `scripts/topologies/projet_sdn.py`  
**Inter-switch link:** 100 Mbps · **2 ms artificial delay**

### Learning Phase — pingall Round 1

| Result | Value |
|--------|-------|
| Packets sent | 6 |
| Packets received | 3 |
| **Packet loss** | **50%** |
| Cause | PACKET_IN flood — flow rules not yet installed |

### Steady State — pingall Round 2

| Result | Value |
|--------|-------|
| Packets sent | 6 |
| Packets received | 6 |
| **Packet loss** | **0%** |
| Cause | All FLOW_MOD entries installed by ODL |

### Targeted RTT Tests (Steady State)

| Test | Source | Destination | Path | Min RTT | Avg RTT | Max RTT |
|------|--------|-------------|------|---------|---------|---------|
| 1 | h1 | h2 | Intra-switch (s1) | 0.08 ms | 0.12 ms | 0.19 ms |
| 2 | h1 | h4 | Inter-switch (s1 → s2) | 4.11 ms | 4.23 ms | 4.38 ms |

> **Note:** The significantly higher RTT for the inter-switch path (Test 2) is expected and by design — the Mininet topology script applies a `delay='2ms'` parameter to the inter-switch link, producing a ~4 ms round-trip time (2 ms each way).

### Ping Commands Used

```bash
# Test 1 — intra-switch
mininet> h1 ping -c 3 h2

# Test 2 — inter-switch
mininet> h1 ping -c 3 h4
```

---

## Topology 3 — Multi-Controller · 6 Switches · 12 Hosts

**Topology script:** `scripts/topologies/sdn_top2.py`  
**Inter-switch links:** No artificial delay · No bandwidth limit

### Full Connectivity Test — pingall

| Result | Value |
|--------|-------|
| Host pairs tested | 132 (12 × 11) |
| Packets received | 132 |
| **Packet loss** | **0%** |
| Controllers active | 3 (ODL-1, ODL-2, ODL-3) |

### Targeted RTT Tests — Three Representative Paths

These three tests were selected to characterise three distinct forwarding scenarios:

| Test | Source | Destination | Path Description | Hops | Min RTT | Max RTT |
|------|--------|-------------|-----------------|------|---------|---------|
| A | h1 | h2 | Same switch (s1) — ODL-1 domain | 1 | 0.075 ms | 0.151 ms |
| B | h1 | h6 | Different switches (s1 → s3) — ODL-1 → ODL-2 boundary | 3 | 0.067 ms | 0.276 ms |
| C | h1 | h12 | Full traversal (s1 → s6) — crosses all 3 controllers | 6 | 0.080 ms | 0.185 ms |

### Ping Commands Used

```bash
# Test A — same switch
mininet> h1 ping -c 3 h2

# Test B — cross-controller boundary
mininet> h1 ping -c 3 h6

# Test C — full network traversal
mininet> h1 ping -c 3 h12
```

### Raw Ping Output (Representative)

**Test A — h1 → h2 (same switch, s1):**
```
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=0.151 ms
64 bytes from 10.0.0.2: icmp_seq=2 ttl=64 time=0.075 ms
64 bytes from 10.0.0.2: icmp_seq=3 ttl=64 time=0.098 ms
--- 10.0.0.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss
rtt min/avg/max/mdev = 0.075/0.108/0.151/0.032 ms
```

**Test B — h1 → h6 (s1 → s3, ODL-1 → ODL-2):**
```
PING 10.0.0.6 (10.0.0.6) 56(84) bytes of data.
64 bytes from 10.0.0.6: icmp_seq=1 ttl=64 time=0.276 ms
64 bytes from 10.0.0.6: icmp_seq=2 ttl=64 time=0.067 ms
64 bytes from 10.0.0.6: icmp_seq=3 ttl=64 time=0.091 ms
--- 10.0.0.6 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss
rtt min/avg/max/mdev = 0.067/0.145/0.276/0.091 ms
```

**Test C — h1 → h12 (s1 → s6, full traversal):**
```
PING 10.0.0.12 (10.0.0.12) 56(84) bytes of data.
64 bytes from 10.0.0.12: icmp_seq=1 ttl=64 time=0.185 ms
64 bytes from 10.0.0.12: icmp_seq=2 ttl=64 time=0.080 ms
64 bytes from 10.0.0.12: icmp_seq=3 ttl=64 time=0.094 ms
--- 10.0.0.12 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss
rtt min/avg/max/mdev = 0.080/0.120/0.185/0.045 ms
```

---

## Analysis

### Key Observations

**1. Sub-millisecond forwarding across the entire multi-controller topology.**  
All RTT measurements remain below 0.3 ms — even for the full 6-hop path (h1 → h12) crossing all three ODL controller domains. This confirms that the control plane overhead is **absent from the data plane** once flow rules are installed.

**2. No latency penalty at controller domain boundaries.**  
Test B (h1 → h6, crossing ODL-1 → ODL-2) shows a max RTT of 0.276 ms, comparable to the intra-domain Test A (0.151 ms). The inter-controller boundary introduces no measurable additional latency in steady state.

**3. The 2 ms delay in Topology 2 is intentional and instructive.**  
The `delay='2ms'` parameter in `projet_sdn.py` was deliberately chosen to make the hop overhead observable and to model a more realistic WAN-like inter-switch link. It explains the ~4 ms RTT for inter-switch paths in that topology.

**4. First-packet latency vs. steady-state latency.**  
The 50% packet loss during the first `pingall` round is not a latency measurement — it is a binary loss event caused by the SDN learning phase. Once ODL installs FLOW_MOD entries (typically within 100–300 ms of the first PACKET_IN), all subsequent packets experience the sub-millisecond RTTs shown above.

### Interpretation Table

| Observation | Explanation |
|-------------|-------------|
| RTT < 0.3 ms in all steady-state tests | OVS forwards in kernel space — no userspace overhead |
| No RTT increase at controller boundaries | FLOW_MOD rules installed per-switch, controller not in forwarding path |
| Higher RTT variance in Test B (0.067–0.276 ms) | First packet in sequence may have caught a residual flow miss |
| 4+ ms RTT in Topology 2 inter-switch | Intentional `delay='2ms'` on inter-switch link |

---

## Consolidated RTT Summary

| Topology | Test | Path | Min | Avg | Max | Loss |
|----------|------|------|-----|-----|-----|------|
| Dual switch | h1→h2 | Intra-switch | 0.08 ms | 0.12 ms | 0.19 ms | 0% |
| Dual switch | h1→h4 | Inter-switch | 4.11 ms | 4.23 ms | 4.38 ms | 0% |
| Multi-controller | h1→h2 | Same switch | 0.075 ms | 0.108 ms | 0.151 ms | 0% |
| Multi-controller | h1→h6 | Cross-controller | 0.067 ms | 0.145 ms | 0.276 ms | 0% |
| Multi-controller | h1→h12 | Full traversal | 0.080 ms | 0.120 ms | 0.185 ms | 0% |

---

*Documented: 24/03/2026 · Ubuntu 24.04 · OVS 2.17 · OpenDaylight 0.18.2 · Mininet 2.3.0*
