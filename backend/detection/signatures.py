"""
signatures.py
=============
Lightweight rule-based (signature) detection engine. Operates directly on
raw packet metadata as it arrives — independent of the ML flow pipeline —
so it can catch fast, obvious attacks (port scans, SYN floods, known-bad
IPs) with near-zero latency, before a full flow even completes.

This is intentionally simple/explainable: for a final-year viva you should
be able to explain every rule in one sentence, which is the whole point of
signature-based detection versus the ML side.
"""

import time
from collections import defaultdict, deque

import config


class SignatureEngine:
    def __init__(self):
        # src_ip -> deque[(timestamp, dst_port)]
        self._port_touches = defaultdict(deque)
        # src_ip -> deque[timestamp] of SYN packets
        self._syn_times = defaultdict(deque)

    def inspect(self, pkt_meta: dict) -> list[dict]:
        """
        pkt_meta expected keys: src_ip, dst_ip, src_port, dst_port, protocol,
        flags (set of TCP flag chars, e.g. {'S','A'}), timestamp
        Returns a list of alert dicts (may be empty).
        """
        alerts = []
        now = pkt_meta["timestamp"]
        src_ip = pkt_meta["src_ip"]

        # --- Rule 1: known malicious IP ---
        if src_ip in config.KNOWN_MALICIOUS_IPS:
            alerts.append({
                "detection_type": "signature",
                "rule_or_label": "Known Malicious IP",
                "severity": "critical",
                "confidence": None,
                "description": f"Traffic from blocklisted IP {src_ip}",
            })

        # --- Rule 2: port scan (many distinct dst ports from one src IP) ---
        if pkt_meta.get("dst_port") is not None:
            dq = self._port_touches[src_ip]
            dq.append((now, pkt_meta["dst_port"]))
            while dq and now - dq[0][0] > 10.0:  # 10s window
                dq.popleft()
            distinct_ports = {p for _, p in dq}
            if len(distinct_ports) >= config.PORT_SCAN_UNIQUE_PORT_THRESHOLD:
                alerts.append({
                    "detection_type": "signature",
                    "rule_or_label": "Port Scan",
                    "severity": "warning",
                    "confidence": None,
                    "description": f"{src_ip} touched {len(distinct_ports)} distinct ports in 10s",
                })
                dq.clear()  # avoid re-alerting every packet

        # --- Rule 3: SYN flood (many SYNs, no completed handshake) ---
        if "S" in pkt_meta.get("flags", set()) and "A" not in pkt_meta.get("flags", set()):
            dq = self._syn_times[src_ip]
            dq.append(now)
            while dq and now - dq[0] > 5.0:  # 5s window
                dq.popleft()
            if len(dq) >= config.SYN_FLOOD_PACKET_THRESHOLD:
                alerts.append({
                    "detection_type": "signature",
                    "rule_or_label": "SYN Flood",
                    "severity": "critical",
                    "confidence": None,
                    "description": f"{src_ip} sent {len(dq)} SYNs in 5s (possible DoS)",
                })
                dq.clear()

        for a in alerts:
            a["source_ip"] = pkt_meta["src_ip"]
            a["destination_ip"] = pkt_meta["dst_ip"]
            a["source_port"] = pkt_meta.get("src_port")
            a["destination_port"] = pkt_meta.get("dst_port")
            a["protocol"] = pkt_meta.get("protocol")

        return alerts
