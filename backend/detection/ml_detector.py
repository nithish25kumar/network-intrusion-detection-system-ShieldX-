"""
ml_detector.py
===============
Loads the artifacts produced by ml_training/train_model.py and runs
inference on flow feature dicts produced by capture/flow_aggregator.py.

Since the live aggregator only computes a subset of the 78 CICIDS2017
features, missing columns are zero-filled at inference time. This is a
reasonable approximation for a student project — document it as a known
limitation in your report rather than pretending it's not there.
"""

import json
import os

import joblib
import numpy as np

import config


class MLDetector:
    def __init__(self, models_dir: str = None):
        models_dir = models_dir or config.MODELS_DIR
        model_path = os.path.join(models_dir, "ids_model.pkl")
        scaler_path = os.path.join(models_dir, "scaler.pkl")
        encoder_path = os.path.join(models_dir, "label_encoder.pkl")
        columns_path = os.path.join(models_dir, "feature_columns.json")

        missing = [p for p in [model_path, scaler_path, encoder_path, columns_path] if not os.path.exists(p)]
        if missing:
            self.ready = False
            self._missing = missing
            return

        self.model = joblib.load(model_path)
        self.scaler = joblib.load(scaler_path)
        self.label_encoder = joblib.load(encoder_path)
        with open(columns_path) as f:
            self.feature_columns = json.load(f)
        self.ready = True

        # Whatever class label string means "no attack" in your training data
        self.benign_labels = {"BENIGN", "Benign", "benign"}

    def predict(self, flow_features: dict):
        """
        flow_features: dict produced by FlowAggregator._compute_features
        (may contain a "_meta" key which is ignored here).
        Returns (label: str, confidence: float, is_attack: bool) or None if
        the model isn't loaded yet.
        """
        if not self.ready:
            return None

        row = []
        for col in self.feature_columns:
            row.append(flow_features.get(col, 0.0))
        X = np.array(row, dtype=float).reshape(1, -1)
        X_scaled = self.scaler.transform(X)

        proba = self.model.predict_proba(X_scaled)[0]
        pred_idx = int(np.argmax(proba))
        label = self.label_encoder.inverse_transform([pred_idx])[0]
        confidence = float(proba[pred_idx])
        is_attack = label not in self.benign_labels

        return label, confidence, is_attack
