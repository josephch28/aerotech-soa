"""Configuración cargada desde .env."""
import os
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from zoneinfo import ZoneInfo

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent / ".env")

DATABASE_URL: str = os.environ.get("DATABASE_URL", "")
JWT_SECRET: str = os.environ.get("JWT_SECRET", "")
JWT_HORAS_EXPIRACION: int = int(os.environ.get("JWT_HORAS_EXPIRACION", 8))
IVA: Decimal = Decimal(os.environ.get("IVA", "0.15"))
ZONA = ZoneInfo(os.environ.get("ZONA_HORARIA", "America/Guayaquil"))
HORAS_LIMITE_RESERVA: int = int(os.environ.get("HORAS_LIMITE_RESERVA", 1))
HORAS_LIMITE_CAMBIOS: int = int(os.environ.get("HORAS_LIMITE_CAMBIOS", 3))


def ahora() -> datetime:
    return datetime.now(ZONA)
