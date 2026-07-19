"""
sniffer.py
==========
Live packet capture using Scapy. Requires elevated privileges to run
(root on Linux/macOS, or Npcap + admin on Windows).

Each packet is normalized into a small dict and handed to a callback —
the callback (wired up in main.py) forwards it to both the SignatureEngine
(immediate per-packet checks) and the FlowAggregator (for later ML
inference once a flow is idle/complete).
"""

import time

from scapy.all import sniff, IP, TCP, UDP

import config


def _extract_flags(tcp_layer) -> set:
    flag_str = str(tcp_layer.flags)  # e.g. "SA", "S", "PA"
    return set(flag_str)


def _packet_to_meta(pkt) -> dict | None:
    if IP not in pkt:
        return None

    ip_layer = pkt[IP]
    meta = {
        "timestamp": time.time(),
        "src_ip": ip_layer.src,
        "dst_ip": ip_layer.dst,
        "length": len(pkt),
        "src_port": None,
        "dst_port": None,
        "protocol": "OTHER",
        "flags": set(),
    }

    if TCP in pkt:
        tcp = pkt[TCP]
        meta["src_port"] = int(tcp.sport)
        meta["dst_port"] = int(tcp.dport)
        meta["protocol"] = "TCP"
        meta["flags"] = _extract_flags(tcp)
    elif UDP in pkt:
        udp = pkt[UDP]
        meta["src_port"] = int(udp.sport)
        meta["dst_port"] = int(udp.dport)
        meta["protocol"] = "UDP"

    return meta


class LiveSniffer:
    """
    Wraps scapy.sniff in a stoppable background-friendly loop.
    Usage:
        sniffer = LiveSniffer(on_packet=my_callback)
        sniffer.start()   # blocking — run in a thread
        sniffer.stop()
    """

    def __init__(self, on_packet, interface: str = None):
        self.on_packet = on_packet
        self.interface = interface or config.CAPTURE_INTERFACE
        self._stop_flag = False

    def _handle(self, pkt):
        meta = _packet_to_meta(pkt)
        if meta:
            self.on_packet(meta)

    def _should_stop(self, pkt):
        return self._stop_flag

    def start(self):
        self._stop_flag = False
        sniff(
            iface=self.interface,
            prn=self._handle,
            store=False,
            stop_filter=self._should_stop,
        )

    def stop(self):
        self._stop_flag = True
