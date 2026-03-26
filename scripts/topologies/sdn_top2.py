#!/usr/bin/env python3
"""
sdn_top2.py — Multi-Controller SDN Topology
============================================
Project : Study, Design, and Implementation of an SDN Architecture
Authors : Abderrahmane Aroussi & Amin Mriroud
Supervisor : Pr. Tarek AIT BAHA
Institution : ESTG — DUT Réseaux Informatiques & Sécurité (RIS)
Year : 2025-2026

Topology Description
--------------------
  • 6 Open vSwitch switches  (s1 – s6)
  • 12 hosts                 (h1 – h12), 2 hosts per switch
  • 3 OpenDaylight controllers running in Docker containers
    - ODL-1  →  172.17.0.1:6633  (manages s1, s2)
    - ODL-2  →  172.17.0.1:6634  (manages s3, s4)
    - ODL-3  →  172.17.0.1:6635  (manages s5, s6)
  • Full inter-switch mesh for end-to-end connectivity

Usage
-----
  sudo python3 sdn_top2.py

Prerequisites
-------------
  • Three ODL Docker containers running (start_odl_controllers.sh)
  • Mininet 2.3.0 installed
  • Open vSwitch installed and running
"""

from mininet.net import Mininet
from mininet.node import RemoteController, OVSKernelSwitch
from mininet.link import TCLink
from mininet.cli import CLI
from mininet.log import setLogLevel, info


# ──────────────────────────────────────────────
# Controller definitions
# Docker bridge IP is 172.17.0.1 by default.
# Each ODL container is mapped to a distinct port.
# ──────────────────────────────────────────────
DOCKER_BRIDGE_IP = '172.17.0.1'

CONTROLLERS = [
    {'name': 'odl1', 'ip': DOCKER_BRIDGE_IP, 'port': 6633},
    {'name': 'odl2', 'ip': DOCKER_BRIDGE_IP, 'port': 6634},
    {'name': 'odl3', 'ip': DOCKER_BRIDGE_IP, 'port': 6635},
]

# Switch → Controller assignment
# odl1 manages s1, s2
# odl2 manages s3, s4
# odl3 manages s5, s6
SWITCH_CONTROLLER_MAP = {
    's1': 'odl1',
    's2': 'odl1',
    's3': 'odl2',
    's4': 'odl2',
    's5': 'odl3',
    's6': 'odl3',
}


def build_network():
    """
    Build and start the 6-switch / 12-host / 3-controller topology.
    Returns the Mininet network object.
    """
    net = Mininet(
        switch=OVSKernelSwitch,
        link=TCLink,
        controller=None,        # Controllers added manually below
        autoSetMacs=True,       # Assign deterministic MACs (00:00:00:00:00:XX)
        autoStaticArp=False,    # Let the SDN controller handle ARP learning
    )

    # ── Add remote controllers ────────────────────────────────────────────
    info('*** Adding OpenDaylight remote controllers\n')
    controllers = {}
    for c in CONTROLLERS:
        ctrl = net.addController(
            c['name'],
            controller=RemoteController,
            ip=c['ip'],
            port=c['port'],
        )
        controllers[c['name']] = ctrl
        info(f'    {c["name"]} → {c["ip"]}:{c["port"]}\n')

    # ── Add switches ──────────────────────────────────────────────────────
    info('*** Adding switches\n')
    switches = {}
    for i in range(1, 7):
        sw_name = f's{i}'
        sw = net.addSwitch(sw_name, protocols='OpenFlow13')
        switches[sw_name] = sw
        info(f'    {sw_name} (assigned to {SWITCH_CONTROLLER_MAP[sw_name]})\n')

    # ── Add hosts (2 per switch) ──────────────────────────────────────────
    info('*** Adding hosts\n')
    hosts = {}
    host_index = 1
    for i in range(1, 7):
        sw_name = f's{i}'
        for _ in range(2):
            h_name = f'h{host_index}'
            ip_addr = f'10.0.0.{host_index}/24'
            host = net.addHost(h_name, ip=ip_addr)
            net.addLink(host, switches[sw_name])
            hosts[h_name] = host
            info(f'    {h_name} ({ip_addr}) → {sw_name}\n')
            host_index += 1

    # ── Inter-switch links (linear chain: s1–s2–s3–s4–s5–s6) ─────────────
    # This guarantees a connected topology. Extend to a mesh if needed.
    info('*** Adding inter-switch links\n')
    inter_switch_links = [
        ('s1', 's2'),
        ('s2', 's3'),
        ('s3', 's4'),
        ('s4', 's5'),
        ('s5', 's6'),
        # Optional cross-links for redundancy (uncomment to enable):
        # ('s1', 's4'),
        # ('s2', 's5'),
        # ('s3', 's6'),
    ]
    for sw_a, sw_b in inter_switch_links:
        net.addLink(switches[sw_a], switches[sw_b])
        info(f'    {sw_a} ↔ {sw_b}\n')

    # ── Start the network ─────────────────────────────────────────────────
    info('*** Starting network\n')
    net.build()

    # Start each controller
    for ctrl in controllers.values():
        ctrl.start()

    # Start each switch and connect it to its designated controller
    info('*** Connecting switches to designated controllers\n')
    for sw_name, sw in switches.items():
        assigned_ctrl_name = SWITCH_CONTROLLER_MAP[sw_name]
        assigned_ctrl = controllers[assigned_ctrl_name]
        sw.start([assigned_ctrl])
        info(f'    {sw_name} → {assigned_ctrl_name}\n')

    return net


def run():
    setLogLevel('info')

    info('\n')
    info('╔══════════════════════════════════════════════════════════════╗\n')
    info('║       SDN Multi-Controller Topology — ESTG PFE 2025-2026    ║\n')
    info('║  6 Switches · 12 Hosts · 3 OpenDaylight Controllers         ║\n')
    info('╚══════════════════════════════════════════════════════════════╝\n')
    info('\n')

    net = build_network()

    info('\n*** Network is ready.\n')
    info('*** Tip: run "pingall" to validate full connectivity (expect 0% loss).\n')
    info('*** Tip: run "h6 iperf -s &" then "h1 iperf -c 10.0.0.6" for throughput.\n\n')

    CLI(net)

    info('*** Stopping network\n')
    net.stop()


if __name__ == '__main__':
    run()
