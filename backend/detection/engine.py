"""
engine.py
=========
Ties together SignatureEngine (per-packet rules) and MLDetector (per-flow
classification) into one place, persists alerts to the DB, and notifies
any registered callback (main.py wires this to the WebSocket broadcaster).
"""

import datetime
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from detection.signatures import SignatureEngine
from detection.ml_detector import MLDetector
from db.database import SessionLocal, Alert


SEVERITY_BY_ATTACK_TYPE = {
    # Coarse severity mapping — tune based on what matters for your report
    "DDoS": "critical",
    "DoS Hulk": "critical",
    "DoS GoldenEye": "critical",
    "DoS slowloris": "critical",
    "DoS Slowhttptest": "critical",
    "PortScan": "warning",
    "Bot": "critical",
    "Infiltration": "critical",
    "Heartbleed": "critical",
    "Web Attack - Brute Force": "warning",
    "Web Attack - XSS": "warning",
    "Web Attack - Sql Injection": "critical",
    "FTP-Patator": "warning",
    "SSH-Patator": "warning",
}


class DetectionEngine:
    def __init__(self, on_alert=None):
        self.signatures = SignatureEngine()
        self.ml = MLDetector()
        self.on_alert = on_alert  # callable(alert_dict) -> None, e.g. websocket broadcast

    # ---------- Per-packet path (live capture) ----------
    def process_packet(self, pkt_meta: dict):
        alerts = self.signatures.inspect(pkt_meta)
        for alert in alerts:
            self._emit(alert)

    # ---------- Per-flow path (ML, from aggregator or CSV replay) ----------
    def process_flow_features(self, flow_features: dict, meta: dict):
        prediction = self.ml.predict(flow_features)
        if prediction is None:
            return None

        label, confidence, is_attack = prediction
        if not is_attack:
            return {
                "detection_type": "anomaly",
                "rule_or_label": label,
                "severity": "info",
                "confidence": confidence,
                "source_ip": meta.get("src_ip"),
                "destination_ip": meta.get("dst_ip"),
                "source_port": meta.get("src_port"),
                "destination_port": meta.get("dst_port"),
                "protocol": meta.get("protocol"),
                "description": "Benign flow",
            }

        alert = {
            "detection_type": "anomaly",
            "rule_or_label": label,
            "severity": SEVERITY_BY_ATTACK_TYPE.get(label, "warning"),
            "confidence": confidence,
            "source_ip": meta.get("src_ip"),
            "destination_ip": meta.get("dst_ip"),
            "source_port": meta.get("src_port"),
            "destination_port": meta.get("dst_port"),
            "protocol": meta.get("protocol"),
            "description": f"ML model classified flow as {label} ({confidence:.1%} confidence)",
        }
        self._emit(alert)
        return alert

    # ---------- persistence + broadcast ----------
    def _emit(self, alert: dict):
        db = SessionLocal()
        try:
            record = Alert(
                timestamp=datetime.datetime.utcnow(),
                source_ip=alert.get("source_ip"),
                destination_ip=alert.get("destination_ip"),
                source_port=alert.get("source_port"),
                destination_port=alert.get("destination_port"),
                protocol=alert.get("protocol"),
                detection_type=alert.get("detection_type"),
                rule_or_label=alert.get("rule_or_label"),
                severity=alert.get("severity"),
                confidence=alert.get("confidence"),
                description=alert.get("description"),
            )
            db.add(record)
            db.commit()
            db.refresh(record)
            alert["id"] = record.id
            alert["timestamp"] = record.timestamp.isoformat() + "Z"
        finally:
            db.close()

        if self.on_alert:
            self.on_alert(alert)
