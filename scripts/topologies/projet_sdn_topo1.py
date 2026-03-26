#!/usr/bin/env python3
"""
projet_sdn.py — Dual-Switch Custom Topology
============================================
Project    : Study, Design, and Implementation of an SDN Architecture
Authors    : Abderrahmane Aroussi & Amin Mriroud
Supervisor : Pr. Tarek AIT BAHA
Institution: ESTG — DUT Réseaux Informatiques & Sécurité (RIS)
Year       : 2025-2026

Topology Description
--------------------
  • 2 Open vSwitch switches  (s1, s2)
  • 4 hosts                  (h1, h2 on s1 — h3, h4 on s2)
  • 1 OpenDaylight controller (remote, default 127.0.0.1:6633)
  • Inter-switch link        : 100 Mbps bandwidth, 2 ms delay

                ┌──────────────────────────────────┐
                │   OpenDaylight Controller (odl1)  │
                │         127.0.0.1:6633            │
                └───────────┬──────────────┬────────┘
                            │ OpenFlow 1.3 │
               ┌────────────▼──┐        ┌──▼────────────┐
               │   Switch s1   │────────│   Switch s2   │
               │               │100Mbps │               │
               │               │  2ms   │               │
               └──┬─────────┬──┘        └──┬─────────┬──┘
                  │         │              │         │
                 h1        h2             h3        h4
             10.0.0.1  10.0.0.2      10.0.0.3  10.0.0.4

Usage
-----
  # With this script (recommended):
  sudo mn --custom projet_sdn.py --topo projet_sdn \\
          --controller=remote,ip=127.0.0.1,port=6633 \\
          --switch ovsk,protocols=OpenFlow13

  # Or run directly:
  sudo python3 projet_sdn.py

Expected Results
----------------
  pingall (1st run) : ~50% packet loss  — OpenFlow learning phase
  pingall (2nd run) :   0% packet loss  — flows installed by ODL
  iPerf h1 → h2    : ~640 Mbit/s       — intra-switch (1 hop)
  iPerf h1 → h4    : ~585 Mbit/s       — inter-switch (2 hops)
"""

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import RemoteController, OVSKernelSwitch
from mininet.link import TCLink
from mininet.cli import CLI
from mininet.log import setLogLevel, info


# ──────────────────────────────────────────────
# Topology class (used with --custom flag)
# ──────────────────────────────────────────────

class DualSwitchTopo(Topo):
    """
    Two-switch, four-host topology with a 100 Mbps / 2 ms inter-switch link.
    Registered under the name 'projet_sdn' for use with --custom --topo.
    """

    def build(self):
        # ── Switches ──────────────────────────────────────────────────────
        s1 = self.addSwitch('s1', protocols='OpenFlow13')
        s2 = self.addSwitch('s2', protocols='OpenFlow13')

        # ── Hosts ─────────────────────────────────────────────────────────
        h1 = self.addHost('h1', ip='10.0.0.1/24', mac='00:00:00:00:00:01')
        h2 = self.addHost('h2', ip='10.0.0.2/24', mac='00:00:00:00:00:02')
        h3 = self.addHost('h3', ip='10.0.0.3/24', mac='00:00:00:00:00:03')
        h4 = self.addHost('h4', ip='10.0.0.4/24', mac='00:00:00:00:00:04')

        # ── Host–Switch links (1 Gbps, no artificial delay) ───────────────
        self.addLink(h1, s1)
        self.addLink(h2, s1)
        self.addLink(h3, s2)
        self.addLink(h4, s2)

        # ── Inter-switch link (100 Mbps, 2 ms — matches report config) ────
        self.addLink(
            s1, s2,
            bw=100,       # Mbps  — matches Figure 3.5 in report
            delay='2ms',  # RTT   — introduces measurable hop overhead
            loss=0,
            use_htb=True,
        )


# Register the topology so Mininet can find it via --topo=projet_sdn
topos = {'projet_sdn': DualSwitchTopo}


# ──────────────────────────────────────────────
# Standalone entry point (direct execution)
# ──────────────────────────────────────────────

def run():
    setLogLevel('info')

    info('\n')
    info('╔══════════════════════════════════════════════════════════════╗\n')
    info('║         SDN Dual-Switch Topology — ESTG PFE 2025-2026       ║\n')
    info('║    2 Switches · 4 Hosts · 1 OpenDaylight Controller         ║\n')
    info('╚══════════════════════════════════════════════════════════════╝\n')
    info('\n')

    topo = DualSwitchTopo()

    net = Mininet(
        topo=topo,
        switch=OVSKernelSwitch,
        link=TCLink,
        controller=None,
        autoSetMacs=False,   # MACs defined explicitly in build()
        autoStaticArp=False, # Let ODL handle ARP — preserves learning phase
    )

    # Add remote ODL controller
    odl1 = net.addController(
        'odl1',
        controller=RemoteController,
        ip='127.0.0.1',
        port=6633,
    )

    net.build()
    odl1.start()

    # Start each switch connected to odl1
    for sw in net.switches:
        sw.start([odl1])

    info('\n*** Network started.\n')
    info('*** Tip: run "pingall" twice — observe 50%% → 0%% packet loss.\n')
    info('*** Tip: run "h4 iperf -s &" then "h1 iperf -c 10.0.0.4"\n\n')

    CLI(net)
    net.stop()


if __name__ == '__main__':
    run()
