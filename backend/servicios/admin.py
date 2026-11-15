"""Servicio 5 – Administración (/api/admin). Solo rol admin."""
from datetime import date, datetime, timedelta
from decimal import Decimal, InvalidOperation

from flask import Blueprint, g, jsonify, request

import config
from db import serializar, transaccion
from errores import ErrorApi, ErrorValidacion
from logica import asientos as lg_asientos
from logica import historial
from logica.asientos import letras
from seguridad import revocar_tokens_usuario, rol_requerido, token_requerido
from servicios.vuelos import SELECT_VUELO
from validaciones import (RE_CODIGO_VUELO, RE_CONFIG, RE_MATRICULA, Validador, limpiar_texto,
                          parsear_fecha)

bp = Blueprint("admin", __name__, url_prefix="/api/admin")


def solo_admin(f):
    return token_requerido(rol_requerido("admin")(f))


def _es_entero(x) -> bool:
    return isinstance(x, int) and not isinstance(x, bool)


# ═════════════════════════ AVIONES ═════════════════════════
def _config_valida(s) -> bool:
    if not isinstance(s, str) or not RE_CONFIG.fullmatch(s) or len(s) > 10:
        return False
    ls = letras(s)
    return len(set(ls)) == len(ls) and len(ls) <= 10


def _capacidad(a) -> int:
    ej = a["filas_ejecutiva"] * len(letras(a["configuracion_ejecutiva"] or a["configuracion"]))
    return ej + (a["filas"] - a["filas_ejecutiva"]) * len(letras(a["configuracion"]))


def _validar_avion(d: dict) -> dict:
    e = {}
    modelo = limpiar_texto(d.get("modelo"))
    if not 2 <= len(modelo) <= 60:
        e["modelo"] = "Modelo obligatorio (2-60 caracteres)"
    matricula = str(d.get("matricula") or "").strip().upper()
    if not RE_MATRICULA.fullmatch(matricula):
        e["matricula"] = "Formato: HC-XXX"
    conf = str(d.get("configuracion") or "").strip().upper()
    if not _config_valida(conf):
        e["configuracion"] = "Configuración inválida (ej. ABC-DEF)"
    conf_ej = d.get("configuracion_ejecutiva")
    conf_ej = str(conf_ej).strip().upper() if conf_ej not in (None, "") else None
    if conf_ej is not None and not _config_valida(conf_ej):
        e["configuracion_ejecutiva"] = "Configuración inválida (ej. AC-DF)"
    filas, fej = d.get("filas"), d.get("filas_ejecutiva", 0)
    if not _es_entero(filas) or not 5 <= filas <= 60:
        e["filas"] = "Las filas deben ser un número entre 5 y 60"
    if not _es_entero(fej) or fej < 0 or (_es_entero(filas) and fej >= filas):
        e["filas_ejecutiva"] = "Las filas ejecutivas deben ser menores que el total de filas"
    salida = d.get("filas_salida", [])
    if (not isinstance(salida, list) or not all(_es_entero(x) for x in salida)
            or (_es_entero(filas) and not all(1 <= x <= filas for x in salida))):
        e["filas_salida"] = "Filas de salida inválidas"
        salida = []
    if e:
        raise ErrorValidacion(e)
    return {"modelo": modelo, "matricula": matricula, "configuracion": conf, "configuracion_ejecutiva": conf_ej,
            "filas": filas, "filas_ejecutiva": fej, "filas_salida": sorted(set(salida))}


def _avion_json(a, vuelos_futuros=None):
    s = {k: a[k] for k in ("id", "modelo", "matricula", "configuracion", "configuracion_ejecutiva", "filas",
                           "filas_ejecutiva", "filas_salida", "activo")}
    s["capacidad"] = _capacidad(a)
    if vuelos_futuros is not None:
        s["vuelos_futuros"] = vuelos_futuros
    return s


@bp.get("/aviones")
@solo_admin
def listar_aviones():
    with transaccion() as cur:
        cur.execute("""SELECT a.*, (SELECT count(*) FROM vuelos v WHERE v.avion_id=a.id
                         AND v.estado='programado' AND v.fecha >= %s) AS vuelos_futuros
                       FROM aviones a ORDER BY a.id""", (config.ahora().date(),))
        filas = cur.fetchall()
    return jsonify(serializar([_avion_json(a, a["vuelos_futuros"]) for a in filas]))


@bp.post("/aviones")
@solo_admin
def crear_avion():
    d = _validar_avion(request.get_json(silent=True) or {})
    with transaccion() as cur:
        cur.execute("SELECT 1 FROM aviones WHERE matricula=%s", (d["matricula"],))
        if cur.fetchone():
            raise ErrorApi(f"La matrícula {d['matricula']} ya está registrada", 409)
        cur.execute("""INSERT INTO aviones (modelo, matricula, configuracion, configuracion_ejecutiva, filas,
                       filas_ejecutiva, filas_salida) VALUES (%(modelo)s,%(matricula)s,%(configuracion)s,
                       %(configuracion_ejecutiva)s,%(filas)s,%(filas_ejecutiva)s,%(filas_salida)s) RETURNING *""", d)
        a = cur.fetchone()
    return jsonify({"mensaje": "Avión creado", "avion": serializar(_avion_json(a, 0))}), 201


@bp.put("/aviones/<int:avion_id>")
@solo_admin
def editar_avion(avion_id):
    cuerpo = request.get_json(silent=True) or {}
    with transaccion() as cur:
        cur.execute("SELECT * FROM aviones WHERE id=%s FOR UPDATE", (avion_id,))
        a = cur.fetchone()
        if not a:
            raise ErrorApi("Avión no encontrado", 404)
        base = {k: a[k] for k in ("modelo", "matricula", "configuracion", "configuracion_ejecutiva", "filas",
                                  "filas_ejecutiva", "filas_salida")}
        d = _validar_avion({**base, **cuerpo})
        estructura = ("configuracion", "configuracion_ejecutiva", "filas", "filas_ejecutiva", "filas_salida")
        if any(d[k] != a[k] for k in estructura):
            cur.execute("SELECT 1 FROM vuelos WHERE avion_id=%s LIMIT 1", (avion_id,))
            if cur.fetchone():
                raise ErrorApi("No se puede cambiar la configuración: el avión ya tiene vuelos", 409)
        cur.execute("SELECT 1 FROM aviones WHERE matricula=%s AND id<>%s", (d["matricula"], avion_id))
        if cur.fetchone():
            raise ErrorApi(f"La matrícula {d['matricula']} ya está registrada", 409)
        cur.execute("""UPDATE aviones SET modelo=%(modelo)s, matricula=%(matricula)s,
                       configuracion=%(configuracion)s, configuracion_ejecutiva=%(configuracion_ejecutiva)s,
                       filas=%(filas)s, filas_ejecutiva=%(filas_ejecutiva)s, filas_salida=%(filas_salida)s
                       WHERE id=%(id)s RETURNING *""", {**d, "id": avion_id})
        a = cur.fetchone()
    return jsonify({"mensaje": "Avión actualizado", "avion": serializar(_avion_json(a))})


@bp.patch("/aviones/<int:avion_id>/estado")
@solo_admin
def estado_avion(avion_id):
    activo = (request.get_json(silent=True) or {}).get("activo")
    if not isinstance(activo, bool):
        raise ErrorValidacion({"activo": "Debe ser verdadero o falso"})
    with transaccion() as cur:
        cur.execute("SELECT * FROM aviones WHERE id=%s FOR UPDATE", (avion_id,))
        if not cur.fetchone():
            raise ErrorApi("Avión no encontrado", 404)
        if not activo:
            cur.execute("""SELECT count(*) AS n FROM vuelos WHERE avion_id=%s AND estado='programado'
                           AND fecha >= %s""", (avion_id, config.ahora().date()))
            if cur.fetchone()["n"]:
                raise ErrorApi("No se puede desactivar un avión con vuelos programados", 409)
        cur.execute("UPDATE aviones SET activo=%s WHERE id=%s RETURNING *", (activo, avion_id))
        a = cur.fetchone()
    return jsonify({"mensaje": "Estado del avión actualizado", "avion": serializar(_avion_json(a))})


@bp.get("/aviones/<int:avion_id>/vista-previa")
@solo_admin
def vista_previa(avion_id):
    with transaccion() as cur:
        cur.execute("SELECT * FROM aviones WHERE id=%s", (avion_id,))
        a = cur.fetchone()
    if not a:
        raise ErrorApi("Avión no encontrado", 404)
    salida = set(a["filas_salida"] or [])
    asientos = []
    for fila in range(1, a["filas"] + 1):
        ej = fila <= a["filas_ejecutiva"]
        conf = (a["configuracion_ejecutiva"] or a["configuracion"]) if ej else a["configuracion"]
        for letra in letras(conf):
            asientos.append({"codigo": f"{fila}{letra}", "fila": fila, "columna": letra,
                             "clase": "ejecutiva" if ej else "economica",
                             "salida_emergencia": fila in salida, "estado": "disponible", "precio": None})
    return jsonify(serializar({
        "vuelo": None,
        "avion": {k: a[k] for k in ("modelo", "matricula", "configuracion", "configuracion_ejecutiva", "filas",
                                    "filas_ejecutiva", "filas_salida")},
        "resumen": {"total": len(asientos), "disponibles": len(asientos), "ocupados": 0},
        "asientos": asientos}))


# ═════════════════════════ VUELOS ═════════════════════════
def _precio(d, campo, e):
    x = d.get(campo)
    if isinstance(x, bool) or x in (None, ""):
        e[campo] = "El precio es obligatorio"
        return None
    try:
        v = Decimal(str(x))
        if not v.is_finite():
            raise InvalidOperation
        return v.quantize(Decimal("0.01"))
    except InvalidOperation:
        e[campo] = "Precio inválido"
        return None


def _validar_vuelo(cur, datos, vuelo_id=None, revisar_fecha=True) -> dict:
    v = Validador(datos)
    v.regex("codigo_vuelo", RE_CODIGO_VUELO, "Formato: 2 letras y 3-4 números (AT123)", mayusculas=True)
    v.fecha("fecha"); v.hora("hora_salida"); v.hora("hora_llegada")
    e = v.errores
    lim = v.limpio

    origen = str(datos.get("origen") or "").strip().upper()
    destino = str(datos.get("destino") or "").strip().upper()
    if origen and origen == destino:
        e.setdefault("destino", "El origen y el destino deben ser distintos")
    cur.execute("SELECT codigo FROM aeropuertos WHERE activo AND codigo = ANY(%s)", ([origen, destino],))
    existentes = {r["codigo"] for r in cur.fetchall()}
    if origen not in existentes:
        e.setdefault("origen", "Aeropuerto de origen inexistente o inactivo")
    if destino not in existentes:
        e.setdefault("destino", "Aeropuerto de destino inexistente o inactivo")

    precio, precio_ej = _precio(datos, "precio", e), _precio(datos, "precio_ejecutiva", e)
    if precio is not None and not Decimal("20") <= precio <= Decimal("2000"):
        e["precio"] = "El precio debe estar entre 20 y 2000"
    if precio is not None and precio_ej is not None and precio_ej < precio:
        e["precio_ejecutiva"] = "El precio ejecutiva debe ser mayor o igual al económico"

    if "hora_salida" in lim and "hora_llegada" in lim:
        mins = (lim["hora_llegada"].hour * 60 + lim["hora_llegada"].minute) - \
               (lim["hora_salida"].hour * 60 + lim["hora_salida"].minute)
        if mins <= 0:
            e["hora_llegada"] = "La hora de llegada debe ser posterior a la salida"
        elif mins > 300:
            e["hora_llegada"] = "La duración del vuelo no puede superar 5 horas"
    if revisar_fecha and "fecha" in lim:
        ahora = config.ahora()
        if lim["fecha"] < ahora.date():
            e["fecha"] = "La fecha no puede ser pasada"
        elif lim["fecha"] == ahora.date() and "hora_salida" in lim:
            salida = datetime.combine(lim["fecha"], lim["hora_salida"], tzinfo=config.ZONA)
            if salida < ahora + timedelta(hours=2):
                e["hora_salida"] = "Debe salir al menos 2 horas después de la hora actual"

    avion = None
    avion_id = datos.get("avion_id")
    if _es_entero(avion_id):
        cur.execute("SELECT * FROM aviones WHERE id=%s", (avion_id,))
        avion = cur.fetchone()
    if not avion:
        e["avion_id"] = "Avión inexistente"
    elif not avion["activo"]:
        e["avion_id"] = "El avión está inactivo"
    if e:
        raise ErrorValidacion(e)

    cur.execute("SELECT id FROM vuelos WHERE codigo_vuelo=%s AND fecha=%s AND id<>%s",
                (lim["codigo_vuelo"], lim["fecha"], vuelo_id or 0))
    if cur.fetchone():
        raise ErrorApi(f"Ya existe el vuelo {lim['codigo_vuelo']} en esa fecha", 409)

    # solapamiento del avión (rotación de 45 min)
    rot = timedelta(minutes=45)
    ini = datetime.combine(lim["fecha"], lim["hora_salida"])
    fin = datetime.combine(lim["fecha"], lim["hora_llegada"])
    cur.execute("""SELECT codigo_vuelo, hora_salida, hora_llegada FROM vuelos
                   WHERE avion_id=%s AND fecha=%s AND estado='programado' AND id<>%s""",
                (avion["id"], lim["fecha"], vuelo_id or 0))
    for o in cur.fetchall():
        o_ini = datetime.combine(lim["fecha"], o["hora_salida"])
        o_fin = datetime.combine(lim["fecha"], o["hora_llegada"])
        if ini < o_fin + rot and o_ini < fin + rot:
            raise ErrorApi(f"El avión {avion['matricula']} ya opera el vuelo {o['codigo_vuelo']} en ese horario", 409)

    lim.update({"avion_id": avion["id"], "origen": origen, "destino": destino, "precio": precio,
                "precio_ejecutiva": precio_ej, "avion": avion})
    return lim


def crear_vuelo(cur, datos: dict, admin_id) -> dict:
    """Crea el vuelo y genera sus asientos. Reutilizada por scripts/sembrar.py."""
    if _es_entero(datos.get("avion_id")):
        cur.execute("SELECT id FROM aviones WHERE id=%s FOR UPDATE", (datos["avion_id"],))  # serializa por avión
    d = _validar_vuelo(cur, datos)
    cur.execute("""INSERT INTO vuelos (codigo_vuelo, avion_id, origen, destino, fecha, hora_salida, hora_llegada,
                   precio, precio_ejecutiva, creado_por) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id""",
                (d["codigo_vuelo"], d["avion_id"], d["origen"], d["destino"], d["fecha"], d["hora_salida"],
                 d["hora_llegada"], d["precio"], d["precio_ejecutiva"], admin_id))
    vuelo_id = cur.fetchone()["id"]
    n = lg_asientos.generar_asientos(cur, vuelo_id, d["avion"])
    return {"id": vuelo_id, "asientos": n}


def _vuelo_completo(cur, vuelo_id):
    cur.execute(SELECT_VUELO + " WHERE v.id=%s", (vuelo_id,))
    return cur.fetchone()


@bp.post("/vuelos")
@solo_admin
def alta_vuelo():
    with transaccion() as cur:
        r = crear_vuelo(cur, request.get_json(silent=True) or {}, g.usuario_id)
        vuelo = _vuelo_completo(cur, r["id"])
    return jsonify(serializar({"mensaje": "Vuelo creado", "vuelo": vuelo, "asientos_generados": r["asientos"]})), 201


@bp.get("/vuelos")
@solo_admin
def listar_vuelos():
    q, filtros, params, e = request.args, [], [], {}
    if q.get("estado"):
        if q["estado"] not in ("programado", "cancelado"):
            e["estado"] = "Estado inválido (programado o cancelado)"
        else:
            filtros.append("v.estado=%s"); params.append(q["estado"])
    for campo, op in (("desde", ">="), ("hasta", "<=")):
        if q.get(campo):
            f = parsear_fecha(q[campo])
            if f:
                filtros.append(f"v.fecha {op} %s"); params.append(f)
            else:
                e[campo] = "Formato de fecha/hora inválido"
    for campo in ("origen", "destino"):
        if q.get(campo):
            filtros.append(f"v.{campo}=%s"); params.append(q[campo].strip().upper())
    if e:
        raise ErrorValidacion(e)
    sql = (SELECT_VUELO.replace("av.matricula\nFROM", """av.matricula,
       (SELECT count(*) FROM asientos a WHERE a.vuelo_id=v.id) AS capacidad,
       COALESCE((SELECT sum(r.total) FROM reservas r WHERE r.vuelo_id=v.id AND r.estado='confirmada'),0) AS ingresos
FROM""") + (" WHERE " + " AND ".join(filtros) if filtros else "") + " ORDER BY v.fecha DESC, v.hora_salida")
    with transaccion() as cur:
        cur.execute(sql, params)
        vuelos = cur.fetchall()
    for v in vuelos:
        v["ocupacion"] = round((v["capacidad"] - v["asientos_disponibles"]) * 100 / v["capacidad"], 1) \
            if v["capacidad"] else 0.0
    return jsonify(serializar({"total": len(vuelos), "vuelos": vuelos}))


@bp.put("/vuelos/<int:vuelo_id>")
@solo_admin
def editar_vuelo(vuelo_id):
    cuerpo = request.get_json(silent=True) or {}
    with transaccion() as cur:
        v = lg_asientos.bloquear_vuelo(cur, vuelo_id)
        if v["estado"] != "programado":
            raise ErrorApi("Solo se pueden editar vuelos programados", 409)
        salida = datetime.combine(v["fecha"], v["hora_salida"], tzinfo=config.ZONA)
        if salida <= config.ahora():
            raise ErrorApi("El vuelo ya salió y no puede editarse", 409)
        base = {"codigo_vuelo": v["codigo_vuelo"], "avion_id": v["avion_id"], "origen": v["origen"],
                "destino": v["destino"], "fecha": v["fecha"].isoformat(),
                "hora_salida": v["hora_salida"].strftime("%H:%M"),
                "hora_llegada": v["hora_llegada"].strftime("%H:%M"),
                "precio": v["precio"], "precio_ejecutiva": v["precio_ejecutiva"]}
        datos = {**base, **{k: cuerpo[k] for k in base if k in cuerpo}}
        cambia_horario = (datos["fecha"], datos["hora_salida"]) != (base["fecha"], base["hora_salida"])
        d = _validar_vuelo(cur, datos, vuelo_id, revisar_fecha=cambia_horario)
        cambia_avion = d["avion_id"] != v["avion_id"]
        if cambia_avion:
            cur.execute("SELECT count(*) AS n FROM reservas WHERE vuelo_id=%s", (vuelo_id,))
            if cur.fetchone()["n"]:
                raise ErrorApi("No se puede cambiar el avión: el vuelo tiene reservas", 409)
        cur.execute("""UPDATE vuelos SET codigo_vuelo=%s, avion_id=%s, origen=%s, destino=%s, fecha=%s,
                       hora_salida=%s, hora_llegada=%s, precio=%s, precio_ejecutiva=%s WHERE id=%s""",
                    (d["codigo_vuelo"], d["avion_id"], d["origen"], d["destino"], d["fecha"], d["hora_salida"],
                     d["hora_llegada"], d["precio"], d["precio_ejecutiva"], vuelo_id))
        if cambia_avion:
            cur.execute("DELETE FROM asientos WHERE vuelo_id=%s", (vuelo_id,))
            lg_asientos.generar_asientos(cur, vuelo_id, d["avion"])
        vuelo = _vuelo_completo(cur, vuelo_id)
    return jsonify({"mensaje": "Vuelo actualizado", "vuelo": serializar(vuelo)})


@bp.put("/vuelos/<int:vuelo_id>/cancelar")
@solo_admin
def cancelar_vuelo(vuelo_id):
    datos = request.get_json(silent=True)
    motivo = str((datos or {}).get("motivo") or "").strip() if isinstance(datos, dict) else ""
    if not 5 <= len(motivo) <= 200:
        raise ErrorValidacion({"motivo": "El motivo es obligatorio (5 a 200 caracteres)"})
    with transaccion() as cur:
        v = lg_asientos.bloquear_vuelo(cur, vuelo_id)
        if v["estado"] == "cancelado":
            raise ErrorApi("El vuelo ya está cancelado", 409)
        cur.execute("SELECT id FROM reservas WHERE vuelo_id=%s AND estado='confirmada' ORDER BY id FOR UPDATE",
                    (vuelo_id,))
        ids = [r["id"] for r in cur.fetchall()]
        for rid in ids:
            lg_asientos.liberar_de_reserva(cur, rid)
            cur.execute("""UPDATE reservas SET estado='cancelada', motivo_cancelacion=%s, fecha_modificacion=NOW()
                           WHERE id=%s""", ("Vuelo cancelado por la aerolínea", rid))
            historial.registrar(cur, rid, g.usuario_id, "cancelada",
                                {"motivo": "Vuelo cancelado por la aerolínea", "motivo_admin": motivo})
        cur.execute("UPDATE vuelos SET estado='cancelado' WHERE id=%s", (vuelo_id,))
        lg_asientos.recontar(cur, vuelo_id)
    return jsonify({"mensaje": "Vuelo cancelado", "reservas_afectadas": len(ids)})


@bp.get("/vuelos/<int:vuelo_id>/manifiesto")
@solo_admin
def manifiesto(vuelo_id):
    with transaccion() as cur:
        vuelo = _vuelo_completo(cur, vuelo_id)
        if not vuelo:
            raise ErrorApi("Vuelo no encontrado", 404)
        cur.execute("""SELECT a.codigo AS asiento, a.clase, p.nombres, p.apellidos, p.tipo_documento,
                              p.numero_documento, p.fecha_nacimiento, r.codigo_reserva,
                              u.nombre || ' ' || u.apellido AS titular
                       FROM pasajeros p JOIN reservas r ON r.id=p.reserva_id
                       JOIN asientos a ON a.id=p.asiento_id JOIN usuarios u ON u.id=r.usuario_id
                       WHERE r.vuelo_id=%s AND r.estado='confirmada' ORDER BY a.fila, a.columna""", (vuelo_id,))
        filas = cur.fetchall()
    pasajeros = []
    for f in filas:
        n = f["fecha_nacimiento"]
        edad = vuelo["fecha"].year - n.year - ((vuelo["fecha"].month, vuelo["fecha"].day) < (n.month, n.day))
        pasajeros.append({"asiento": f["asiento"], "clase": f["clase"],
                          "nombre": f"{f['nombres']} {f['apellidos']}", "tipo_documento": f["tipo_documento"],
                          "documento": f["numero_documento"], "edad": edad,
                          "codigo_reserva": f["codigo_reserva"], "titular": f["titular"]})
    return jsonify(serializar({"vuelo": vuelo, "total": len(pasajeros), "pasajeros": pasajeros}))


# ═════════════════════════ RESERVAS Y USUARIOS ═════════════════════════
@bp.get("/reservas")
@solo_admin
def todas_reservas():
    q, filtros, params = request.args, [], []
    if q.get("estado"):
        if q["estado"] not in ("confirmada", "cancelada"):
            raise ErrorValidacion({"estado": "Estado inválido (confirmada o cancelada)"})
        filtros.append("r.estado=%s"); params.append(q["estado"])
    if q.get("vuelo_id"):
        if not q["vuelo_id"].isdigit():
            raise ErrorValidacion({"vuelo_id": "Debe ser un número"})
        filtros.append("r.vuelo_id=%s"); params.append(int(q["vuelo_id"]))
    if q.get("codigo"):
        filtros.append("r.codigo_reserva=%s"); params.append(q["codigo"].strip().upper())
    if q.get("correo"):
        filtros.append("u.correo ILIKE %s"); params.append(f"%{q['correo'].strip()}%")
    sql = """SELECT r.id, r.codigo_reserva, r.estado, r.cantidad_asientos, r.total, r.fecha_reserva,
                    r.motivo_cancelacion, u.id AS usuario_id, u.nombre || ' ' || u.apellido AS usuario,
                    u.correo, v.id AS vuelo_id, v.codigo_vuelo, v.fecha, v.origen, v.destino
             FROM reservas r JOIN usuarios u ON u.id=r.usuario_id JOIN vuelos v ON v.id=r.vuelo_id""" + \
        (" WHERE " + " AND ".join(filtros) if filtros else "") + " ORDER BY r.fecha_reserva DESC"
    with transaccion() as cur:
        cur.execute(sql, params)
        filas = cur.fetchall()
    return jsonify(serializar({"total": len(filas), "reservas": filas}))


@bp.get("/usuarios")
@solo_admin
def listar_usuarios():
    q, filtros, params = request.args, [], []
    if q.get("rol"):
        if q["rol"] not in ("admin", "cliente"):
            raise ErrorValidacion({"rol": "Rol inválido (admin o cliente)"})
        filtros.append("u.rol=%s"); params.append(q["rol"])
    if q.get("activo"):
        if q["activo"].lower() not in ("true", "false"):
            raise ErrorValidacion({"activo": "Debe ser true o false"})
        filtros.append("u.activo=%s"); params.append(q["activo"].lower() == "true")
    if q.get("buscar"):
        filtros.append("(u.nombre ILIKE %s OR u.apellido ILIKE %s OR u.correo ILIKE %s OR u.cedula ILIKE %s)")
        params += [f"%{q['buscar'].strip()}%"] * 4
    sql = """SELECT u.id, u.nombre, u.apellido, u.cedula, u.telefono, u.correo, u.rol, u.activo,
                    u.fecha_registro, (SELECT count(*) FROM reservas r WHERE r.usuario_id=u.id) AS total_reservas
             FROM usuarios u""" + (" WHERE " + " AND ".join(filtros) if filtros else "") + " ORDER BY u.id"
    with transaccion() as cur:
        cur.execute(sql, params)
        filas = cur.fetchall()
    return jsonify(serializar({"total": len(filas), "usuarios": filas}))


@bp.patch("/usuarios/<int:usuario_id>")
@solo_admin
def modificar_usuario(usuario_id):
    d = request.get_json(silent=True) or {}
    e, cambios = {}, {}
    if "rol" in d:
        if d["rol"] in ("admin", "cliente"):
            cambios["rol"] = d["rol"]
        else:
            e["rol"] = "Rol inválido (admin o cliente)"
    if "activo" in d:
        if isinstance(d["activo"], bool):
            cambios["activo"] = d["activo"]
        else:
            e["activo"] = "Debe ser verdadero o falso"
    if not e and not cambios:
        e["rol"] = "Envíe rol y/o activo"
    if e:
        raise ErrorValidacion(e)
    if usuario_id == g.usuario_id and (cambios.get("activo") is False or cambios.get("rol", "admin") != "admin"):
        raise ErrorApi("Un administrador no puede desactivarse ni quitarse el rol a sí mismo", 409)
    with transaccion() as cur:
        cur.execute("SELECT id FROM usuarios WHERE id=%s FOR UPDATE", (usuario_id,))
        if not cur.fetchone():
            raise ErrorApi("Usuario no encontrado", 404)
        sets = ", ".join(f"{k}=%s" for k in cambios)
        cur.execute(f"""UPDATE usuarios SET {sets} WHERE id=%s
                        RETURNING id, nombre, apellido, correo, rol, activo""", (*cambios.values(), usuario_id))
        u = cur.fetchone()
        if cambios.get("activo") is False:
            revocar_tokens_usuario(cur, usuario_id)
    return jsonify({"mensaje": "Usuario actualizado", "usuario": serializar(u)})
