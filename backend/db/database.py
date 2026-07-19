import datetime
import os
import sys

from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime
from sqlalchemy.orm import declarative_base, sessionmaker

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

os.makedirs(os.path.dirname(config.DB_PATH), exist_ok=True)

engine = create_engine(config.DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)
    source_ip = Column(String, index=True)
    destination_ip = Column(String)
    source_port = Column(Integer, nullable=True)
    destination_port = Column(Integer, nullable=True)
    protocol = Column(String, nullable=True)

    detection_type = Column(String)   # "signature" | "anomaly"
    rule_or_label = Column(String)    # e.g. "Port Scan" or ML predicted class
    severity = Column(String)         # "info" | "warning" | "critical"
    confidence = Column(Float, nullable=True)  # ML probability, null for signature hits
    description = Column(String, nullable=True)


class TrafficStat(Base):
    __tablename__ = "traffic_stats"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, index=True)
    packets_per_sec = Column(Float)
    bytes_per_sec = Column(Float)
    active_flows = Column(Integer)


def init_db():
    Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
