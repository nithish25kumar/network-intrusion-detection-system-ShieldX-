"""
train_model.py
================
Trains the hybrid ML-based anomaly detector for the Network IDS project
using the CICIDS2017 dataset.

USAGE:
    1. Drop all CICIDS2017 CSV files into ml_training/data/
       (Monday-WorkingHours.pcap_ISCX.csv, Tuesday-...csv,
        Wednesday-workingHours.pcap_ISCX.csv,
        Thursday-WorkingHours-Morning-WebAttacks.pcap_ISCX.csv,
        Thursday-WorkingHours-Afternoon-Infilteration.pcap_ISCX.csv,
        Friday-WorkingHours-Morning.pcap_ISCX.csv,
        Friday-WorkingHours-Afternoon-PortScan.pcap_ISCX.csv,
        Friday-WorkingHours-Afternoon-DDos.pcap_ISCX.csv)
    2. pip install -r requirements.txt
    3. python train_model.py

OUTPUT (written to ml_training/artifacts/):
    - ids_model.pkl        -> trained RandomForestClassifier
    - label_encoder.pkl    -> maps class index -> attack label string
    - scaler.pkl           -> StandardScaler fitted on training features
    - feature_columns.json -> ordered list of feature names the model expects
    - metrics_report.txt   -> accuracy / precision / recall / F1 / confusion matrix
    - feature_importance.png

These four artifacts (model, encoder, scaler, feature list) are exactly what
backend/detection/ml_detector.py loads at runtime, so once training finishes,
copy the whole artifacts/ folder into backend/models/.
"""

import os
import glob
import json
import warnings

import numpy as np
import pandas as pd
import joblib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    accuracy_score,
    f1_score,
)

warnings.filterwarnings("ignore")

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
ARTIFACT_DIR = os.path.join(os.path.dirname(__file__), "artifacts")
os.makedirs(ARTIFACT_DIR, exist_ok=True)

# Cap rows per file while developing/debugging on a laptop. Set to None for
# the full dataset once your pipeline works end-to-end (expect ~2.8M rows
# total across all 8 CICIDS2017 files, which is fine for RandomForest but
# slow to iterate on).
SAMPLE_ROWS_PER_FILE = None  # e.g. 150_000 for a quick dev run

RANDOM_STATE = 42


def load_all_csvs() -> pd.DataFrame:
    csv_paths = sorted(glob.glob(os.path.join(DATA_DIR, "*.csv")))
    if not csv_paths:
        raise FileNotFoundError(
            f"No CSV files found in {DATA_DIR}. Drop the CICIDS2017 CSVs there first."
        )

    frames = []
    for path in csv_paths:
        print(f"Loading {os.path.basename(path)} ...")
        df = pd.read_csv(path, low_memory=False, encoding="latin1")
        # CICIDS2017 CSVs have a leading space in most column names
        df.columns = df.columns.str.strip()
        if SAMPLE_ROWS_PER_FILE:
            df = df.sample(min(len(df), SAMPLE_ROWS_PER_FILE), random_state=RANDOM_STATE)
        frames.append(df)
        print(f"  -> {len(df):,} rows")

    full = pd.concat(frames, ignore_index=True)
    print(f"\nTotal combined rows: {len(full):,}")
    return full


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    # Standardize label column name
    if "Label" not in df.columns:
        raise KeyError("Expected a 'Label' column in the CICIDS2017 CSVs.")

    # Drop columns that are identifiers / not useful as ML features
    drop_cols = [c for c in ["Flow ID", "Source IP", "Src IP", "Destination IP",
                              "Dst IP", "Timestamp", "SimillarHTTP", "Unnamed: 0"]
                 if c in df.columns]
    df = df.drop(columns=drop_cols)

    # Replace inf/-inf with NaN, then drop rows with NaN (CICIDS2017 has some
    # divide-by-zero artifacts in flow-rate columns)
    df = df.replace([np.inf, -np.inf], np.nan)
    before = len(df)
    df = df.dropna()
    print(f"Dropped {before - len(df):,} rows containing inf/NaN")

    # Normalize label text, e.g. "Web Attack ï¿½ Brute Force" -> "Web Attack - Brute Force"
    df["Label"] = df["Label"].str.strip()
    df["Label"] = df["Label"].str.replace("ï¿½", "-", regex=False)
    df["Label"] = df["Label"].str.replace(r"\s*-\s*", " - ", regex=True)
    return df


def build_datasets(df: pd.DataFrame):
    y_raw = df["Label"]
    X = df.drop(columns=["Label"])

    # Keep only numeric feature columns (a handful of CICIDS2017 columns can
    # be read in as object dtype due to stray strings)
    X = X.select_dtypes(include=[np.number])

    feature_columns = list(X.columns)

    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(y_raw)

    print(f"\nClasses found ({len(label_encoder.classes_)}):")
    for i, cls in enumerate(label_encoder.classes_):
        count = int((y == i).sum())
        print(f"  [{i}] {cls}: {count:,}")

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=RANDOM_STATE, stratify=y
    )

    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    return X_train_scaled, X_test_scaled, y_train, y_test, scaler, label_encoder, feature_columns


def train(X_train, y_train):
    print("\nTraining RandomForestClassifier ...")
    clf = RandomForestClassifier(
        n_estimators=200,
        max_depth=25,
        min_samples_split=4,
        class_weight="balanced_subsample",  # CICIDS2017 is heavily imbalanced (mostly BENIGN)
        n_jobs=-1,
        random_state=RANDOM_STATE,
        verbose=1,
    )
    clf.fit(X_train, y_train)
    return clf


def evaluate(clf, X_test, y_test, label_encoder, feature_columns):
    y_pred = clf.predict(X_test)

    acc = accuracy_score(y_test, y_pred)
    f1_macro = f1_score(y_test, y_pred, average="macro")
    f1_weighted = f1_score(y_test, y_pred, average="weighted")

    report = classification_report(
        y_test, y_pred, target_names=label_encoder.classes_, zero_division=0
    )
    cm = confusion_matrix(y_test, y_pred)

    report_path = os.path.join(ARTIFACT_DIR, "metrics_report.txt")
    with open(report_path, "w") as f:
        f.write(f"Accuracy: {acc:.4f}\n")
        f.write(f"F1 (macro): {f1_macro:.4f}\n")
        f.write(f"F1 (weighted): {f1_weighted:.4f}\n\n")
        f.write("Classification report:\n")
        f.write(report)
        f.write("\n\nConfusion matrix (rows=true, cols=predicted):\n")
        f.write(np.array2string(cm))

    print(f"\nAccuracy: {acc:.4f}  |  F1 macro: {f1_macro:.4f}  |  F1 weighted: {f1_weighted:.4f}")
    print(f"Full report written to {report_path}")

    # Feature importance plot -> great for the "results" chapter of your report
    importances = clf.feature_importances_
    order = np.argsort(importances)[::-1][:20]
    plt.figure(figsize=(10, 8))
    plt.barh(
        [feature_columns[i] for i in order][::-1],
        importances[order][::-1],
    )
    plt.title("Top 20 Feature Importances (Random Forest)")
    plt.tight_layout()
    plt.savefig(os.path.join(ARTIFACT_DIR, "feature_importance.png"), dpi=150)
    print("Feature importance plot saved.")


def main():
    df = load_all_csvs()
    df = clean_dataframe(df)
    X_train, X_test, y_train, y_test, scaler, label_encoder, feature_columns = build_datasets(df)

    clf = train(X_train, y_train)
    evaluate(clf, X_test, y_test, label_encoder, feature_columns)

    joblib.dump(clf, os.path.join(ARTIFACT_DIR, "ids_model.pkl"))
    joblib.dump(scaler, os.path.join(ARTIFACT_DIR, "scaler.pkl"))
    joblib.dump(label_encoder, os.path.join(ARTIFACT_DIR, "label_encoder.pkl"))
    with open(os.path.join(ARTIFACT_DIR, "feature_columns.json"), "w") as f:
        json.dump(feature_columns, f, indent=2)

    print(f"\nAll artifacts saved to {ARTIFACT_DIR}")
    print("Copy this whole folder's contents into backend/models/ to use it in the live IDS.")


if __name__ == "__main__":
    main()
