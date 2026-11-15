"""Servicio 3 – Vuelos (consulta pública, aeropuertos y mapa de asientos)."""
from datetime import timedelta

from flask import Blueprint, jsonify, request

import config
from db import serializar, transaccion
from errores import ErrorApi, ErrorValidacion
from validaciones import parsear_fecha

bp = Blueprint("vuelos", __name__, url_prefix="/api")

SELECT_VUELO = """
SELECT v.id, v.codigo_vuelo, v.origen, v.destino, ao.ciudad AS ciudad_origen, ad.ciudad AS ciudad_destino,
       v.fecha, v.hora_salida, v.hora_llegada,
       (EXTRACT(EPOCH FROM (v.hora_llegada - v.hora_salida)) / 60)::int AS duracion_minutos,
       v.precio, v.precio_ejecutiva, v.asientos_disponibles, v.estado,
       av.modelo AS modelo_avion, av.matricula
FROM vuelos v
JOIN aeropuertos ao ON ao.codigo = v.origen
JOIN aeropuertos ad ON ad.codigo = v.destino
JOIN aviones av ON av.id = v.avion_id
"""


@bp.get("/aeropuertos")
def aeropuertos():
    with transaccion() as cur:
        cur.execute("SELECT codigo, ciudad, nombre FROM aeropuertos WHERE activo ORDER BY ciudad")
        filas = cur.fetchall()
    return jsonify(serializar(filas))


@bp.get("/vuelos")
def listar():
    q = request.args
    errores, filtros, params = {}, [], []
    for campo in ("origen", "destino"):
        val = (q.get(campo) or "").strip().upper()
        if val:
            if len(val) != 3 or not val.isalpha():
                errores[campo] = "Código de aeropuerto inválido (3 letras)"
            else:
                filtros.append(f"v.{campo} = %s")
                params.append(val)
    if q.get("fecha"):
        f = parsear_fecha(q["fecha"])
        if f:
            filtros.append("v.fecha = %s")
            params.append(f)
        else:
            errores["fecha"] = "Formato de fecha/hora inválido"
    pasajeros = 1
    if q.get("pasajeros"):
        if q["pasajeros"].isdigit() and 1 <= int(q["pasajeros"]) <= 9:
            pasajeros = int(q["pasajeros"])
        else:
            errores["pasajeros"] = "Debe ser un número entre 1 y 9"
    if errores:
        raise ErrorValidacion(errores)
    limite = (config.ahora() + timedelta(hours=config.HORAS_LIMITE_RESERVA)).replace(tzinfo=None)
    sql = (SELECT_VUELO + " WHERE v.estado='programado' AND (v.fecha + v.hora_salida) > %s "
           "AND v.asientos_disponibles >= %s " + "".join(f" AND {f}" for f in filtros) +
           " ORDER BY v.fecha, v.hora_salida")
    with transaccion() as cur:
        cur.execute(sql, [limite, pasajeros, *params])
        vuelos = cur.fetchall()
    return jsonify(serializar({"total": len(vuelos), "vuelos": vuelos}))


@bp.get("/vuelos/<int:vuelo_id>")
def detalle(vuelo_id):
    with transaccion() as cur:
        cur.execute(SELECT_VUELO + " WHERE v.id=%s", (vuelo_id,))
        v = cur.fetchone()
    if not v:
        raise ErrorApi("Vuelo no encontrado", 404)
    return jsonify(serializar(v))


@bp.get("/vuelos/<int:vuelo_id>/asientos")
def mapa_asientos(vuelo_id):
    with transaccion() as cur:
        cur.execute("""SELECT v.id, v.codigo_vuelo, v.origen, v.destino, v.fecha, v.hora_salida,
                              v.precio, v.precio_ejecutiva, av.modelo, av.matricula, av.configuracion,
                              av.configuracion_ejecutiva, av.filas, av.filas_ejecutiva, av.filas_salida
                       FROM vuelos v JOIN aviones av ON av.id=v.avion_id WHERE v.id=%s""", (vuelo_id,))
        r = cur.fetchone()
        if not r:
            raise ErrorApi("Vuelo no encontrado", 404)
        cur.execute("""SELECT codigo, fila, columna, clase, salida_emergencia, estado FROM asientos
                       WHERE vuelo_id=%s ORDER BY fila, columna""", (vuelo_id,))
        asientos = cur.fetchall()
    for a in asientos:
        a["precio"] = r["precio_ejecutiva"] if a["clase"] == "ejecutiva" else r["precio"]
    libres = sum(1 for a in asientos if a["estado"] == "disponible")
    return jsonify(serializar({
        "vuelo": {k: r[k] for k in ("id", "codigo_vuelo", "origen", "destino", "fecha", "hora_salida",
                                    "precio", "precio_ejecutiva")},
        "avion": {"modelo": r["modelo"], "matricula": r["matricula"], "configuracion": r["configuracion"],
                  "configuracion_ejecutiva": r["configuracion_ejecutiva"], "filas": r["filas"],
                  "filas_ejecutiva": r["filas_ejecutiva"], "filas_salida": r["filas_salida"]},
        "resumen": {"total": len(asientos), "disponibles": libres, "ocupados": len(asientos) - libres},
        "asientos": asientos}))
