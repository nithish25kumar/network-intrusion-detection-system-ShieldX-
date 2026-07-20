import os
import joblib

ARTIFACT_DIR = os.path.join(os.path.dirname(__file__), "artifacts")
SRC = os.path.join(ARTIFACT_DIR, "ids_model.pkl")

print(f"Loading {SRC} ...")
size_before = os.path.getsize(SRC) / (1024 * 1024)
clf = joblib.load(SRC)

print("Re-saving with compression ...")
joblib.dump(clf, SRC, compress=3)

size_after = os.path.getsize(SRC) / (1024 * 1024)
print(f"Size before: {size_before:.1f} MB")
print(f"Size after:  {size_after:.1f} MB")