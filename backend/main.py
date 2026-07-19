"""
main.py
=======
Entry point for the Network IDS backend.

Run with:
    uvicorn main:app --reload --host 0.0.0.0 --port 8000

Live packet capture (--mode live in /api/monitor/start) requires root:
    sudo -E $(which uvicorn) main:app --host 0.0.0.0 --port 8000
"""

import asyncio
import threading
import time
from typing import Optional

from fastapi import FastAPI, Depends, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from sqlalchemy import desc

import auth
import config
from db.database import init_db, get_db, Alert
from api.websocket_manager import manager
from detection.engine import DetectionEngine
from capture.sniffer import LiveSniffer
from capture.flow_aggregator import FlowAggregator
from capture.replay import replay_csv

app = FastAPI(title="Network IDS API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten this before any real deployment
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

init_db()

engine = DetectionEngine(on_alert=lambda alert: manager.broadcast({"type": "alert", "data": alert}))
aggregator = FlowAggregator()

_monitor_thread: Optional[threading.Thread] = None
_monitor_stop_flag = threading.Event()
_monitor_mode = {"active": False, "mode": None}


@app.on_event("startup")
async def on_startup():
    manager.bind_loop(asyncio.get_event_loop())


# ---------------- Auth ----------------

@app.post("/api/auth/login")
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    if not auth.authenticate_user(form_data.username, form_data.password):
        raise HTTPException(status_code=401, detail="Incorrect username or password")
    token = auth.create_access_token(form_data.username)
    return {"access_token": token, "token_type": "bearer"}


# ---------------- Alerts ----------------

@app.get("/api/alerts")
def get_alerts(
    limit: int = 100,
    severity: Optional[str] = None,
    db: Session = Depends(get_db),
    user: str = Depends(auth.get_current_user),
):
    query = db.query(Alert).order_by(desc(Alert.timestamp))
    if severity:
        query = query.filter(Alert.severity == severity)
    rows = query.limit(limit).all()
    return [
        {
            "id": r.id,
            "timestamp": r.timestamp.isoformat() + "Z",
            "source_ip": r.source_ip,
            "destination_ip": r.destination_ip,
            "source_port": r.source_port,
            "destination_port": r.destination_port,
            "protocol": r.protocol,
            "detection_type": r.detection_type,
            "rule_or_label": r.rule_or_label,
            "severity": r.severity,
            "confidence": r.confidence,
            "description": r.description,
        }
        for r in rows
    ]


@app.get("/api/stats")
def get_stats(db: Session = Depends(get_db), user: str = Depends(auth.get_current_user)):
    total = db.query(Alert).count()
    critical = db.query(Alert).filter(Alert.severity == "critical").count()
    warning = db.query(Alert).filter(Alert.severity == "warning").count()
    return {
        "total_alerts": total,
        "critical": critical,
        "warning": warning,
        "monitoring_active": _monitor_mode["active"],
        "monitoring_mode": _monitor_mode["mode"],
        "ml_model_loaded": engine.ml.ready,
    }


# ---------------- Monitoring control ----------------

def _packet_callback(pkt_meta: dict):
    engine.process_packet(pkt_meta)
    aggregator.add_packet(pkt_meta)


def _live_capture_loop(interface: Optional[str]):
    sniffer = LiveSniffer(on_packet=_packet_callback, interface=interface)

    def flow_flusher():
        while not _monitor_stop_flag.is_set():
            time.sleep(config.FLOW_WINDOW_SECONDS)
            for flow in aggregator.flush_expired():
                meta = flow.pop("_meta")
                engine.process_flow_features(flow, meta)

    flusher_thread = threading.Thread(target=flow_flusher, daemon=True)
    flusher_thread.start()
    sniffer.start()  # blocks until sniffer.stop() is called


def _run_and_reset_on_exit(target, args):
    """
    Runs a monitoring target (live capture or replay) in the background
    thread and guarantees _monitor_mode['active'] is reset to False when it
    finishes or crashes — so a dead thread never leaves the API stuck
    reporting "Monitoring already active".
    """
    try:
        target(*args)
    except Exception as e:
        print(f"[monitor] background thread stopped with error: {e}")
    finally:
        _monitor_mode["active"] = False


@app.post("/api/monitor/start")
def start_monitor(mode: str = "live", csv_path: Optional[str] = None, speed: float = 15.0,
                   user: str = Depends(auth.get_current_user)):
    global _monitor_thread
    if _monitor_mode["active"]:
        raise HTTPException(status_code=400, detail="Monitoring already active")

    _monitor_stop_flag.clear()
    _monitor_mode["active"] = True
    _monitor_mode["mode"] = mode

    if mode == "live":
        _monitor_thread = threading.Thread(
            target=_run_and_reset_on_exit,
            args=(_live_capture_loop, (config.CAPTURE_INTERFACE,)),
            daemon=True,
        )
    elif mode == "replay":
        if not csv_path:
            raise HTTPException(status_code=400, detail="csv_path required for replay mode")
        _monitor_thread = threading.Thread(
            target=_run_and_reset_on_exit,
            args=(replay_csv, (csv_path, speed, None, engine)),
            daemon=True,
        )
    else:
        raise HTTPException(status_code=400, detail="mode must be 'live' or 'replay'")

    _monitor_thread.start()
    return {"status": "started", "mode": mode}


@app.post("/api/monitor/stop")
def stop_monitor(user: str = Depends(auth.get_current_user)):
    _monitor_stop_flag.set()
    _monitor_mode["active"] = False
    return {"status": "stopped"}


# ---------------- WebSocket ----------------

@app.websocket("/ws/alerts")
async def websocket_alerts(ws: WebSocket):
    await manager.connect(ws)
    try:
        while True:
            await ws.receive_text()  # keep-alive; client doesn't need to send anything meaningful
    except WebSocketDisconnect:
        manager.disconnect(ws)


@app.get("/api/health")
def health():
    return {"status": "ok", "ml_model_loaded": engine.ml.ready}