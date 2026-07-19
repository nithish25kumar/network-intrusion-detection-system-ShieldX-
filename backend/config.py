import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(BASE_DIR, "models")
DB_PATH = os.path.join(BASE_DIR, "db", "ids.db")
DATABASE_URL = f"sqlite:///{DB_PATH}"

# JWT auth
SECRET_KEY = os.environ.get("IDS_SECRET_KEY", "dev-secret-change-me-before-deploying")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 12

# Demo credentials (final-year project scope — swap for a real user table
# with hashed passwords if you want to go further)
DEMO_USERNAME = "admin"
DEMO_PASSWORD_HASH = None  # set at runtime in auth.py using passlib

# Network interface for live capture (Scapy). None = ask scapy to pick default.
CAPTURE_INTERFACE = os.environ.get("IDS_INTERFACE", None)

# Sliding time window (seconds) used to aggregate raw packets into
# "flow" feature vectors before they're passed to the ML model.
FLOW_WINDOW_SECONDS = 2.0

# Simple signature engine thresholds
PORT_SCAN_UNIQUE_PORT_THRESHOLD = 15   # distinct dst ports from one src IP within window
SYN_FLOOD_PACKET_THRESHOLD = 100       # SYN packets from one src IP within window
KNOWN_MALICIOUS_IPS = set()            # populate with a threat-intel feed if you want
