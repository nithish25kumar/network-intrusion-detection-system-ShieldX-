"""
replay.py
=========
Demo/testing mode: replays rows from a CICIDS2017 CSV file as if they were
live flows, feeding them straight into the ML detector (bypassing the raw
Scapy -> FlowAggregator path, since these rows are already flow-level
features). This is the most reliable way to demo attack detection —
capturing on a real quiet network won't show DDoS/PortScan traffic unless
you actively generate it with hping3/nmap in a lab.

Usage: python -m capture.replay --file data/Friday-WorkingHours-Afternoon-DDos.pcap_ISCX.csv --speed 20
"""

import argparse
import json
import time

import pandas as pd

from detection.ml_detector import MLDetector
from detection.engine import DetectionEngine


def replay_csv(path: str, speed: float = 10.0, limit: int = None, engine: DetectionEngine = None):
    """
    speed: rows replayed per second (simulated). Higher = faster demo.
    engine: pass the app's shared DetectionEngine (with on_alert wired to the
            websocket broadcaster) when called from main.py. If omitted (e.g.
            running this file standalone for a quick sanity check), a local
            engine is created and alerts are just printed, not broadcast.
    """
    df = pd.read_csv(path, low_memory=False, encoding="latin1")
    df.columns = df.columns.str.strip()
    if limit:
        df = df.head(limit)

    if engine is None:
        engine = DetectionEngine()
    if not engine.ml.ready:
        print("WARNING: ML model artifacts not found in backend/models/. "
              "Only label-based ground truth will be printed, no live predictions.")

    delay = 1.0 / speed if speed > 0 else 0

    for _, row in df.iterrows():
        features = row.to_dict()
        true_label = features.pop("Label", "UNKNOWN")

        meta = {
            "src_ip": features.get("Source IP", "10.0.0.1"),
            "dst_ip": features.get("Destination IP", "10.0.0.2"),
            "src_port": features.get("Source Port"),
            "dst_port": features.get("Destination Port"),
            "protocol": "TCP",
        }
        result = engine.process_flow_features(features, meta)
        if result:
            print(f"[true={true_label}] -> predicted={result['rule_or_label']} "
                  f"(confidence={result.get('confidence')}, severity={result['severity']})")

        if delay:
            time.sleep(delay)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", required=True, help="Path to a CICIDS2017 CSV")
    parser.add_argument("--speed", type=float, default=10.0, help="Rows per second")
    parser.add_argument("--limit", type=int, default=None, help="Max rows to replay")
    args = parser.parse_args()
    replay_csv(args.file, speed=args.speed, limit=args.limit)