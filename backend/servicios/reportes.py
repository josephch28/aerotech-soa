"""Servicio 6 – Reportes (/api/reportes). Solo rol admin."""
from datetime import timedelta

from flask import Blueprint, jsonify

import config
from db import serializar, transaccion
from seguridad import rol_requerido, token_requerido

bp = Blueprint("reportes", __name__, url_prefix="/api/reportes")

OCUPACION = """(SELECT count(*) FILTER (WHERE a.estado='ocupado') * 100.0 / NULLIF(count(*), 0)
                FROM asientos a WHERE a.vuelo_id=v.id)"""


@bp.get("/dashboard")
@token_requerido
@rol_requerido("admin")
def dashboard():
    hoy = config.ahora().date()
    with transaccion() as cur:
        cur.execute(f"""SELECT
            (SELECT count(*) FROM vuelos WHERE estado='programado' AND fecha >= %s) AS vuelos_programados,
            (SELECT count(*) FROM reservas WHERE estado='confirmada') AS reservas_confirmadas,
            (SELECT count(*) FROM pasajeros p JOIN reservas r ON r.id=p.reserva_id
               WHERE r.estado='confirmada') AS pasajeros,
            (SELECT COALESCE(sum(total), 0) FROM reservas WHERE estado='confirmada') AS ingresos,
            (SELECT COALESCE(avg({OCUPACION}), 0) FROM vuelos v
               WHERE v.estado='programado' AND v.fecha >= %s) AS ocupacion_promedio,
            (SELECT count(*) FROM usuarios WHERE rol='cliente') AS usuarios_clientes""", (hoy, hoy))
        ind = cur.fetchone()
        ind["ocupacion_promedio"] = round(float(ind["ocupacion_promedio"]), 1)

        cur.execute(f"""SELECT v.codigo_vuelo, v.fecha, v.origen || '-' || v.destino AS ruta,
                               ROUND(COALESCE({OCUPACION}, 0), 1) AS ocupacion
                        FROM vuelos v WHERE v.estado='programado' AND v.fecha >= %s
                        ORDER BY v.fecha, v.hora_salida LIMIT 10""", (hoy,))
        ocupacion = cur.fetchall()

        cur.execute("""SELECT (fecha_reserva AT TIME ZONE %s)::date AS fecha, count(*) AS reservas,
                              COALESCE(sum(total), 0) AS ingresos
                       FROM reservas WHERE estado='confirmada' AND (fecha_reserva AT TIME ZONE %s)::date >= %s
                       GROUP BY 1 ORDER BY 1""", (config.ZONA.key, config.ZONA.key, hoy - timedelta(days=13)))
        por_dia = cur.fetchall()

        cur.execute("""SELECT v.origen || '-' || v.destino AS ruta, count(p.id) AS pasajeros,
                              COALESCE(sum(p.precio), 0) AS ingresos
                       FROM pasajeros p JOIN reservas r ON r.id=p.reserva_id JOIN vuelos v ON v.id=r.vuelo_id
                       WHERE r.estado='confirmada' GROUP BY 1 ORDER BY pasajeros DESC, ingresos DESC LIMIT 5""")
        rutas = cur.fetchall()
    return jsonify(serializar({"indicadores": ind, "ocupacion_por_vuelo": ocupacion,
                               "reservas_por_dia": por_dia, "rutas_top": rutas}))
