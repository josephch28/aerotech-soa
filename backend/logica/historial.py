"""Auditoría de reservas."""
from psycopg.types.json import Jsonb

from db import serializar


def registrar(cur, reserva_id, usuario_id, accion, detalle: dict):
    cur.execute("""INSERT INTO historial_reservas (reserva_id, usuario_id, accion, detalle)
                   VALUES (%s,%s,%s,%s)""", (reserva_id, usuario_id, accion, Jsonb(serializar(detalle))))
