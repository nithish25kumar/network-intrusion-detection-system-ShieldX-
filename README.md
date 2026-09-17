# 🛡️ ShieldX – ML-Powered Network Intrusion Detection System

**ShieldX** is a real-time Network Intrusion Detection System (IDS) with a **Flutter** mobile dashboard and a **FastAPI + Machine Learning** backend. It captures and classifies network traffic on the fly, flagging malicious activity — DDoS, port scans, brute force, web attacks, and more — and streams live alerts straight to your phone.

Built as a final-year project, ShieldX combines a trained **Random Forest classifier** (on the real-world **CICIDS2017** dataset, 2.8M+ labeled network flows) with a lightweight signature engine, wrapped in a clean, modern monitoring UI.

---

🧑‍💻 Developed By

**Nithish Kumar K**
Final Year Project — Network Security / Machine Learning
📧 [your email here]
🔗 [your LinkedIn here]

---

## 🚀 Features

* 🤖 **ML-based flow classification** — Random Forest trained on CICIDS2017, detecting 9+ attack categories (DDoS, PortScan, Brute Force, Web Attacks, Botnet, Infiltration, Heartbleed, and more)
* 📡 **Two monitoring modes** — live packet capture (via Scapy) or CSV replay for repeatable demos
* ⚡ **Real-time alerts** — pushed to the app instantly over WebSocket as traffic is classified
* 📊 **Live stats dashboard** — total alerts, critical/warning counts, model status, at a glance
* 🔍 **Alert history & filtering** — browse past detections, filter by severity
* 🔐 **JWT-based authentication** — secured API access
* 🚦 **Signature-based rules** — catches obvious patterns (port scans, SYN floods) alongside the ML model
* 📈 **Full evaluation pipeline** — precision/recall/F1, confusion matrices, and feature importance included

## 🔧 Tech Stack

**Frontend**
* **Flutter** — cross-platform mobile dashboard
* **Provider** — state management
* **fl_chart** — live stats visualization
* **web_socket_channel** — real-time alert streaming

**Backend**
* **FastAPI** — REST API + WebSocket server
* **Scapy** — live packet capture
* **SQLAlchemy + SQLite** — alert persistence
* **python-jose / passlib** — JWT auth

**Machine Learning**
* **scikit-learn** (Random Forest Classifier)
* **pandas / numpy** — data preprocessing
* Trained on **CICIDS2017** (Canadian Institute for Cybersecurity, UNB)

---

## 🏁 Getting Started

Full setup instructions — including backend setup, training the ML model on CICIDS2017, and running the Flutter app on an Android emulator — are in [`SHIELDX_SETUP_GUIDE.md`](./SHIELDX_SETUP_GUIDE.md).

Quick version:
```bash
# Backend
cd backend
python3.12 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Frontend
flutter pub get
flutter run
```

**Default login:** `admin` / `changeme123`

---

## ⚠️ Known Limitations

* Live packet capture requires root access and a real network interface — use **replay mode** when demoing on an emulator
* Rare attack classes (e.g. Heartbleed, Infiltration) have very few training samples in CICIDS2017, which limits per-class recall despite high overall accuracy
* Single hardcoded demo account — not intended for production use as-is
