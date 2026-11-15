"""Servicio 4 – Reservas (/api/reservas)."""
import re
import secrets
import xml.etree.ElementTree as ET
from datetime import date, datetime, timedelta
from decimal import Decimal

from flask import Blueprint, Response, g, jsonify, request

import config
from db import serializar, transaccion
from errores import ErrorApi, ErrorValidacion
from logica import asientos as lg_asientos
from logica import historial
from logica.precios import calcular
from seguridad import token_requerido
from servicios.vuelos import SELECT_VUELO
from validaciones import RE_PASAPORTE, Validador, parsear_fecha, validar_cedula, validar_telefono, validar_correo

bp = Blueprint("reservas", __name__, url_prefix="/api/reservas")

ALFABETO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
RE_ASIENTO = re.compile(r"^\d{1,2}[A-K]$")


# ───────────────────────── utilidades ─────────────────────────
def _edad(nacimiento: date, a_fecha: date) -> int:
    return a_fecha.year - nacimiento.year - ((a_fecha.month, a_fecha.day) < (nacimiento.month, nacimiento.day))


def _salida(vuelo) -> datetime:
    return datetime.combine(vuelo["fecha"], vuelo["hora_salida"], tzinfo=config.ZONA)


def _dentro_de_plazo(vuelo, horas: int) -> bool:
    return _salida(vuelo) >= config.ahora() + timedelta(hours=horas)


def _codigo_reserva(cur) -> str:
    while True:
        codigo = "".join(secrets.choice(ALFABETO) for _ in range(6))
        cur.execute("SELECT 1 FROM reservas WHERE codigo_reserva=%s", (codigo,))
        if not cur.fetchone():
            return codigo


def _parsear_body(datos, usuario) -> tuple[dict, list[dict]]:
    """Valida la estructura y los formatos. Devuelve (contacto, pasajeros) normalizados."""
    datos = datos if isinstance(datos, dict) else {}
    errores: dict[str, str] = {}

    contacto_in = datos.get("contacto") if isinstance(datos.get("contacto"), dict) else {}
    vc = Validador({"telefono": contacto_in.get("telefono", usuario["telefono"]),
                    "correo": contacto_in.get("correo", usuario["correo"])}, prefijo="contacto.")
    vc.telefono("telefono")
    vc.correo("correo")
    errores.update(vc.errores)

    lista = datos.get("pasajeros")
    pasajeros = []
    if not isinstance(lista, list) or not (1 <= len(lista) <= 9):
        errores["pasajeros"] = "Debe incluir de 1 a 9 pasajeros"
        lista = []
    for i, p in enumerate(lista):
        p = p if isinstance(p, dict) else {}
        v = Validador(p, prefijo=f"pasajeros[{i}].")
        v.regex("asiento", RE_ASIENTO, "Código de asiento inválido (ej. 12A)", mayusculas=True)
        v.texto("nombres")
        v.texto("apellidos")
        tipo = str(p.get("tipo_documento") or "").strip().lower()
        if tipo == "cedula":
            v.cedula("numero_documento")
        elif tipo == "pasaporte":
            v.pasaporte("numero_documento")
        else:
            v._err("tipo_documento", "Tipo de documento inválido (cedula o pasaporte)")
            v._err("numero_documento", "Número de documento inválido")
        v.fecha("fecha_nacimiento")
        errores.update(v.errores)
        if "fecha_nacimiento" in v.limpio and v.limpio["fecha_nacimiento"] > config.ahora().date():
            errores[f"pasajeros[{i}].fecha_nacimiento"] = "La fecha de nacimiento no puede ser futura"
        v.limpio["tipo_documento"] = tipo
        pasajeros.append(v.limpio)

    if not errores:
        vistos_a, vistos_d = {}, {}
        for i, p in enumerate(pasajeros):
            if p["asiento"] in vistos_a:
                errores[f"pasajeros[{i}].asiento"] = "Asiento repetido en la reserva"
            vistos_a[p["asiento"]] = i
            if p["numero_documento"] in vistos_d:
                errores[f"pasajeros[{i}].numero_documento"] = "Documento repetido en la reserva"
            vistos_d[p["numero_documento"]] = i
    if errores:
        raise ErrorValidacion(errores)
    return vc.limpio, pasajeros


def _preparar(cur, vuelo, pasajeros, reserva_id=None):
    """Reglas que dependen del vuelo. Devuelve (asientos_en_orden, precios, subtotal, iva, total)."""
    codigos = [p["asiento"] for p in pasajeros]
    mapa = lg_asientos.obtener_asientos(cur, vuelo["id"], codigos)  # 400 si no existen
    lista = [mapa[c] for c in codigos]

    errores, adultos = {}, 0
    for i, (p, a) in enumerate(zip(pasajeros, lista)):
        edad = _edad(p["fecha_nacimiento"], vuelo["fecha"])
        if edad < 2:
            errores[f"pasajeros[{i}].fecha_nacimiento"] = "Los menores de 2 años no ocupan asiento"
        elif edad > 110:
            errores[f"pasajeros[{i}].fecha_nacimiento"] = "Edad inválida (máximo 110 años)"
        elif a["salida_emergencia"] and edad < 15:
            errores[f"pasajeros[{i}].asiento"] = (
                "Los asientos de salida de emergencia requieren pasajeros mayores de 15 años")
        if edad >= 18:
            adultos += 1
    if errores:
        raise ErrorValidacion(errores)
    if adultos == 0:
        raise ErrorApi("Debe viajar al menos un adulto", 400, campos={"pasajeros": "Debe viajar al menos un adulto"})

    cur.execute("""SELECT DISTINCT p.numero_documento FROM pasajeros p JOIN reservas r ON r.id=p.reserva_id
                   WHERE r.vuelo_id=%s AND r.estado='confirmada' AND p.numero_documento = ANY(%s)
                     AND r.id <> %s""", (vuelo["id"], [p["numero_documento"] for p in pasajeros], reserva_id or 0))
    dup = [r["numero_documento"] for r in cur.fetchall()]
    if dup:
        raise ErrorApi(f"El pasajero con documento {dup[0]} ya tiene reserva en este vuelo", 409,
                       extra={"documentos_duplicados": dup})

    precios, subtotal, iva, total = calcular(lista, vuelo)
    return lista, precios, subtotal, iva, total


def _insertar_pasajeros(cur, reserva_id, pasajeros, lista, precios):
    for p, a, precio in zip(pasajeros, lista, precios):
        cur.execute("""INSERT INTO pasajeros (reserva_id, asiento_id, nombres, apellidos, tipo_documento,
                                              numero_documento, fecha_nacimiento, precio)
                       VALUES (%s,%s,%s,%s,%s,%s,%s,%s)""",
                    (reserva_id, a["id"], p["nombres"], p["apellidos"], p["tipo_documento"],
                     p["numero_documento"], p["fecha_nacimiento"], precio))


def _estado_actual(cur, reserva_id) -> dict:
    cur.execute("""SELECT a.codigo FROM pasajeros p JOIN asientos a ON a.id=p.asiento_id
                   WHERE p.reserva_id=%s ORDER BY p.id""", (reserva_id,))
    return [r["codigo"] for r in cur.fetchall()]


def _bloquear_reserva(cur, reserva_id):
    """Orden de bloqueo global: primero el vuelo, luego la reserva (evita interbloqueos)."""
    cur.execute("SELECT vuelo_id FROM reservas WHERE id=%s", (reserva_id,))
    fila = cur.fetchone()
    if not fila:
        raise ErrorApi("Reserva no encontrada", 404)
    vuelo = lg_asientos.bloquear_vuelo(cur, fila["vuelo_id"])
    cur.execute("SELECT * FROM reservas WHERE id=%s FOR UPDATE", (reserva_id,))
    return cur.fetchone(), vuelo


def _cargar_visible(cur, reserva_id):
    """Reserva visible para el usuario actual (propia o cualquiera si es admin); si no, 404."""
    cur.execute("SELECT * FROM reservas WHERE id=%s", (reserva_id,))
    r = cur.fetchone()
    if not r or (g.rol != "admin" and r["usuario_id"] != g.usuario_id):
        raise ErrorApi("Reserva no encontrada", 404)
    return r


def _detalle(cur, r) -> dict:
    cur.execute(SELECT_VUELO + " WHERE v.id=%s", (r["vuelo_id"],))
    vuelo = cur.fetchone()
    cur.execute("""SELECT p.nombres, p.apellidos, p.tipo_documento, p.numero_documento, p.fecha_nacimiento,
                          a.codigo AS asiento, a.clase, a.salida_emergencia, p.precio
                   FROM pasajeros p JOIN asientos a ON a.id=p.asiento_id
                   WHERE p.reserva_id=%s ORDER BY a.fila, a.columna""", (r["id"],))
    pasajeros = cur.fetchall()
    for p in pasajeros:
        p["edad"] = _edad(p["fecha_nacimiento"], vuelo["fecha"])
    confirmada = r["estado"] == "confirmada" and vuelo["estado"] == "programado"
    en_plazo = _dentro_de_plazo(vuelo, config.HORAS_LIMITE_CAMBIOS)
    es_admin = g.rol == "admin"
    return serializar({
        "id": r["id"], "codigo_reserva": r["codigo_reserva"], "estado": r["estado"],
        "cantidad_asientos": r["cantidad_asientos"], "subtotal": r["subtotal"], "iva": r["iva"],
        "total": r["total"], "contacto": {"telefono": r["telefono_contacto"], "correo": r["correo_contacto"]},
        "motivo_cancelacion": r["motivo_cancelacion"], "fecha_reserva": r["fecha_reserva"],
        "fecha_modificacion": r["fecha_modificacion"], "usuario_id": r["usuario_id"],
        "vuelo": vuelo, "pasajeros": pasajeros,
        "puede_editar": bool(confirmada and en_plazo and not es_admin and r["usuario_id"] == g.usuario_id),
        "puede_cancelar": bool(r["estado"] == "confirmada" and (es_admin or en_plazo)),
    })


def _resumen_reserva(cur, reserva_id) -> dict:
    cur.execute("SELECT * FROM reservas WHERE id=%s", (reserva_id,))
    r = cur.fetchone()
    return serializar({"id": r["id"], "codigo_reserva": r["codigo_reserva"],
                       "cantidad_asientos": r["cantidad_asientos"],
                       "asientos": _estado_actual(cur, reserva_id), "subtotal": r["subtotal"],
                       "iva": r["iva"], "total": r["total"], "estado": r["estado"]})


# ───────────────────────── endpoints ─────────────────────────
def crear_reserva(cur, usuario: dict, datos) -> int:
    """Lógica de creación reutilizable (también la usa scripts/sembrar.py). Devuelve el id."""
    contacto, pasajeros = _parsear_body(datos, usuario)
    vuelo_id = datos.get("vuelo_id")
    if not isinstance(vuelo_id, int) or isinstance(vuelo_id, bool):
        raise ErrorValidacion({"vuelo_id": "El vuelo es obligatorio"})
    vuelo = lg_asientos.bloquear_vuelo(cur, vuelo_id)
    if vuelo["estado"] != "programado":
        raise ErrorApi("El vuelo está cancelado", 409)
    if not _dentro_de_plazo(vuelo, config.HORAS_LIMITE_RESERVA):
        raise ErrorApi(f"Fuera de plazo: no se puede reservar con menos de {config.HORAS_LIMITE_RESERVA} h "
                       "de anticipación", 409)
    lista, precios, subtotal, iva, total = _preparar(cur, vuelo, pasajeros)
    cur.execute("""INSERT INTO reservas (codigo_reserva, usuario_id, vuelo_id, cantidad_asientos, subtotal, iva,
                                         total, telefono_contacto, correo_contacto)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id""",
                (_codigo_reserva(cur), usuario["id"], vuelo_id, len(pasajeros), subtotal, iva, total,
                 contacto["telefono"], contacto["correo"]))
    reserva_id = cur.fetchone()["id"]
    codigos = [p["asiento"] for p in pasajeros]
    lg_asientos.ocupar(cur, vuelo_id, reserva_id, codigos)
    _insertar_pasajeros(cur, reserva_id, pasajeros, lista, precios)
    lg_asientos.recontar(cur, vuelo_id)
    historial.registrar(cur, reserva_id, usuario["id"], "creada", {"asientos": codigos, "total": total})
    return reserva_id


def _usuario_actual(cur) -> dict:
    cur.execute("SELECT id, nombre, apellido, telefono, correo FROM usuarios WHERE id=%s", (g.usuario_id,))
    return cur.fetchone()


@bp.post("/")
@token_requerido
def crear():
    datos = request.get_json(silent=True)
    with transaccion() as cur:
        reserva_id = crear_reserva(cur, _usuario_actual(cur), datos)
        resumen = _resumen_reserva(cur, reserva_id)
    return jsonify({"mensaje": "Reserva creada", "reserva": resumen}), 201


@bp.get("/")
@token_requerido
def mis_reservas():
    estado = request.args.get("estado")
    if estado and estado not in ("confirmada", "cancelada"):
        raise ErrorValidacion({"estado": "Estado inválido (confirmada o cancelada)"})
    with transaccion() as cur:
        sql = "SELECT * FROM reservas WHERE usuario_id=%s" + (" AND estado=%s" if estado else "")
        cur.execute(sql + " ORDER BY fecha_reserva DESC", (g.usuario_id, estado) if estado else (g.usuario_id,))
        salida = []
        for r in cur.fetchall():
            cur.execute(SELECT_VUELO + " WHERE v.id=%s", (r["vuelo_id"],))
            salida.append(serializar({
                "id": r["id"], "codigo_reserva": r["codigo_reserva"], "estado": r["estado"],
                "cantidad_asientos": r["cantidad_asientos"], "total": r["total"],
                "fecha_reserva": r["fecha_reserva"], "vuelo": cur.fetchone(),
                "asientos": _estado_actual(cur, r["id"])}))
    return jsonify({"total": len(salida), "reservas": salida})


@bp.get("/<int:reserva_id>")
@token_requerido
def detalle(reserva_id):
    with transaccion() as cur:
        return jsonify(_detalle(cur, _cargar_visible(cur, reserva_id)))


@bp.put("/<int:reserva_id>")
@token_requerido
def editar(reserva_id):
    datos = request.get_json(silent=True)
    with transaccion() as cur:
        cur.execute("SELECT usuario_id FROM reservas WHERE id=%s", (reserva_id,))
        dueno = cur.fetchone()
        if not dueno or (g.rol != "admin" and dueno["usuario_id"] != g.usuario_id):
            raise ErrorApi("Reserva no encontrada", 404)
        if g.rol == "admin":
            raise ErrorApi("No tiene permisos para esta operación", 403)
        usuario = _usuario_actual(cur)
        contacto, pasajeros = _parsear_body(datos, usuario)
        r, vuelo = _bloquear_reserva(cur, reserva_id)
        if r["estado"] != "confirmada":
            raise ErrorApi("La reserva está cancelada y no puede modificarse", 409)
        if vuelo["estado"] != "programado" or not _dentro_de_plazo(vuelo, config.HORAS_LIMITE_CAMBIOS):
            raise ErrorApi(f"Fuera de plazo: solo se puede modificar hasta {config.HORAS_LIMITE_CAMBIOS} h "
                           "antes de la salida", 409)
        antes = {"asientos": _estado_actual(cur, reserva_id), "total": r["total"]}

        lg_asientos.liberar_de_reserva(cur, reserva_id)
        cur.execute("DELETE FROM pasajeros WHERE reserva_id=%s", (reserva_id,))
        lista, precios, subtotal, iva, total = _preparar(cur, vuelo, pasajeros, reserva_id)
        codigos = [p["asiento"] for p in pasajeros]
        lg_asientos.ocupar(cur, vuelo["id"], reserva_id, codigos)  # 409 => rollback total
        _insertar_pasajeros(cur, reserva_id, pasajeros, lista, precios)
        cur.execute("""UPDATE reservas SET cantidad_asientos=%s, subtotal=%s, iva=%s, total=%s,
                       telefono_contacto=%s, correo_contacto=%s, fecha_modificacion=NOW() WHERE id=%s""",
                    (len(pasajeros), subtotal, iva, total, contacto["telefono"], contacto["correo"], reserva_id))
        lg_asientos.recontar(cur, vuelo["id"])
        historial.registrar(cur, reserva_id, g.usuario_id, "modificada",
                            {"antes": antes, "despues": {"asientos": codigos, "total": total}})
        resumen = _resumen_reserva(cur, reserva_id)
        diferencia = round(float(total - Decimal(r["total"])), 2)
    return jsonify({"mensaje": "Reserva actualizada", "reserva": resumen, "diferencia": diferencia})


@bp.put("/<int:reserva_id>/cancelar")
@token_requerido
def cancelar(reserva_id):
    datos = request.get_json(silent=True)
    datos = datos if isinstance(datos, dict) else {}
    with transaccion() as cur:
        _cargar_visible(cur, reserva_id)  # 404 si no es visible
        r, vuelo = _bloquear_reserva(cur, reserva_id)
        if r["estado"] != "confirmada":
            raise ErrorApi("La reserva ya está cancelada", 409)
        if g.rol == "admin":
            motivo = str(datos.get("motivo") or "").strip()
            if len(motivo) < 5 or len(motivo) > 200:
                raise ErrorValidacion({"motivo": "El motivo es obligatorio (5 a 200 caracteres)"})
        else:
            if not _dentro_de_plazo(vuelo, config.HORAS_LIMITE_CAMBIOS):
                raise ErrorApi(f"Fuera de plazo: solo se puede cancelar hasta {config.HORAS_LIMITE_CAMBIOS} h "
                               "antes de la salida", 409)
            motivo = "Cancelada por el cliente"
        antes = _estado_actual(cur, reserva_id)
        lg_asientos.liberar_de_reserva(cur, reserva_id)
        cur.execute("UPDATE reservas SET estado='cancelada', motivo_cancelacion=%s, fecha_modificacion=NOW() "
                    "WHERE id=%s", (motivo, reserva_id))
        lg_asientos.recontar(cur, vuelo["id"])
        historial.registrar(cur, reserva_id, g.usuario_id, "cancelada", {"motivo": motivo, "asientos": antes})
    return jsonify({"mensaje": "Reserva cancelada", "motivo": motivo})


@bp.get("/<int:reserva_id>/historial")
@token_requerido
def ver_historial(reserva_id):
    with transaccion() as cur:
        _cargar_visible(cur, reserva_id)
        cur.execute("""SELECT h.accion, h.fecha, h.detalle, u.nombre || ' ' || u.apellido AS usuario
                       FROM historial_reservas h LEFT JOIN usuarios u ON u.id=h.usuario_id
                       WHERE h.reserva_id=%s ORDER BY h.id""", (reserva_id,))
        eventos = cur.fetchall()
    return jsonify(serializar({"total": len(eventos), "eventos": eventos}))


@bp.get("/<int:reserva_id>/factura")
@token_requerido
def factura(reserva_id):
    with transaccion() as cur:
        r = _cargar_visible(cur, reserva_id)
        d = _detalle(cur, r)
        cur.execute("SELECT nombre, apellido, cedula, correo FROM usuarios WHERE id=%s", (r["usuario_id"],))
        u = cur.fetchone()
        cur.execute(f"SELECT (SELECT ciudad FROM aeropuertos WHERE codigo=%s) AS o, "
                    f"(SELECT ciudad FROM aeropuertos WHERE codigo=%s) AS d",
                    (d["vuelo"]["origen"], d["vuelo"]["destino"]))
    v = d["vuelo"]

    def sub(padre, nombre, texto=None, **attrs):
        e = ET.SubElement(padre, nombre, {k: str(x) for k, x in attrs.items()})
        if texto is not None:
            e.text = str(texto)
        return e

    raiz = ET.Element("factura")
    sub(raiz, "numero", f"P001-{r['id']:06d}")
    sub(raiz, "codigo_reserva", r["codigo_reserva"])
    sub(raiz, "fecha_emision", r["fecha_reserva"].astimezone(config.ZONA).date().isoformat())
    c = sub(raiz, "cliente")
    sub(c, "nombre", f"{u['nombre']} {u['apellido']}"); sub(c, "cedula", u["cedula"]); sub(c, "correo", u["correo"])
    ve = sub(raiz, "vuelo")
    sub(ve, "codigo", v["codigo_vuelo"])
    sub(ve, "origen", f"{v['ciudad_origen']} ({v['origen']})")
    sub(ve, "destino", f"{v['ciudad_destino']} ({v['destino']})")
    sub(ve, "fecha", v["fecha"]); sub(ve, "hora_salida", v["hora_salida"]); sub(ve, "avion", v["modelo_avion"])
    ps = sub(raiz, "pasajeros")
    for p in d["pasajeros"]:
        pe = sub(ps, "pasajero")
        sub(pe, "nombre", f"{p['nombres']} {p['apellidos']}")
        sub(pe, "documento", p["numero_documento"], tipo=p["tipo_documento"])
        sub(pe, "asiento", p["asiento"]); sub(pe, "clase", p["clase"]); sub(pe, "precio", f"{p['precio']:.2f}")
    sub(raiz, "subtotal", f"{d['subtotal']:.2f}")
    sub(raiz, "iva", f"{d['iva']:.2f}", porcentaje=int(config.IVA * 100))
    sub(raiz, "total", f"{d['total']:.2f}")
    sub(raiz, "estado", r["estado"])
    ET.indent(raiz)
    cuerpo = ET.tostring(raiz, encoding="UTF-8", xml_declaration=True)
    return Response(cuerpo, content_type="application/xml; charset=utf-8")
