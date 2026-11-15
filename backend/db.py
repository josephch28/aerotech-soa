"""Acceso a PostgreSQL (psycopg 3)."""
from contextlib import contextmanager
from datetime import date, datetime, time
from decimal import Decimal

import psycopg
from psycopg.rows import dict_row

import config


def get_conn():
    return psycopg.connect(config.DATABASE_URL, row_factory=dict_row)


@contextmanager
def transaccion():
    """Entrega un cursor; hace commit al salir bien y rollback ante cualquier excepción."""
    conn = get_conn()
    try:
        with conn.cursor() as cur:
            yield cur
        conn.commit()
    except BaseException:
        conn.rollback()
        raise
    finally:
        conn.close()


def serializar(obj):
    """Convierte tipos de BD a tipos JSON (Decimal→float, fechas→ISO)."""
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, datetime):
        return obj.isoformat()
    if isinstance(obj, (date, time)):
        return obj.isoformat(timespec="minutes") if isinstance(obj, time) else obj.isoformat()
    if isinstance(obj, dict):
        return {k: serializar(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [serializar(v) for v in obj]
    return obj
