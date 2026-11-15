"""Servicio 1 – Usuarios (/api/usuarios)."""
from flask import Blueprint, g, jsonify, request

from db import serializar, transaccion
from errores import ErrorApi, ErrorValidacion
from seguridad import hashear, revocar_tokens_usuario, token_requerido, verificar
from validaciones import Validador, validar_password

bp = Blueprint("usuarios", __name__, url_prefix="/api/usuarios")

CAMPOS_PUBLICOS = "id, nombre, apellido, cedula, telefono, correo, rol, activo, fecha_registro"


@bp.post("/registro")
def registro():
    v = Validador(request.get_json(silent=True))
    v.texto("nombre"); v.texto("apellido"); v.cedula("cedula"); v.telefono("telefono")
    v.correo("correo"); v.password("password")
    d = v.verificar()
    with transaccion() as cur:
        cur.execute("SELECT 1 FROM usuarios WHERE correo=%s", (d["correo"],))
        if cur.fetchone():
            raise ErrorApi("El correo ya está registrado", 409)
        cur.execute("SELECT 1 FROM usuarios WHERE cedula=%s", (d["cedula"],))
        if cur.fetchone():
            raise ErrorApi("La cédula ya está registrada", 409)
        cur.execute(
            f"""INSERT INTO usuarios (nombre, apellido, cedula, telefono, correo, password_hash, rol)
                VALUES (%s,%s,%s,%s,%s,%s,'cliente') RETURNING {CAMPOS_PUBLICOS}""",
            (d["nombre"], d["apellido"], d["cedula"], d["telefono"], d["correo"], hashear(d["password"])))
        usuario = cur.fetchone()
    return jsonify({"mensaje": "Usuario registrado", "usuario": serializar(usuario)}), 201


@bp.get("/perfil")
@token_requerido
def perfil():
    with transaccion() as cur:
        cur.execute(f"SELECT {CAMPOS_PUBLICOS} FROM usuarios WHERE id=%s", (g.usuario_id,))
        u = cur.fetchone()
        cur.execute("""SELECT count(*) AS total,
                              count(*) FILTER (WHERE estado='confirmada') AS activas
                       FROM reservas WHERE usuario_id=%s""", (g.usuario_id,))
        r = cur.fetchone()
    u["total_reservas"] = r["total"]
    u["reservas_activas"] = r["activas"]
    return jsonify(serializar(u))


@bp.put("/perfil")
@token_requerido
def editar_perfil():
    v = Validador(request.get_json(silent=True))
    v.texto("nombre"); v.texto("apellido"); v.telefono("telefono")
    d = v.verificar()
    with transaccion() as cur:
        cur.execute(f"""UPDATE usuarios SET nombre=%s, apellido=%s, telefono=%s WHERE id=%s
                        RETURNING {CAMPOS_PUBLICOS}""",
                    (d["nombre"], d["apellido"], d["telefono"], g.usuario_id))
        u = cur.fetchone()
    return jsonify({"mensaje": "Perfil actualizado", "usuario": serializar(u)})


@bp.put("/password")
@token_requerido
def cambiar_password():
    datos = request.get_json(silent=True) or {}
    actual, nueva = datos.get("password_actual"), datos.get("password_nueva")
    errores = {}
    if not actual:
        errores["password_actual"] = "La contraseña actual es obligatoria"
    if not validar_password(nueva):
        errores["password_nueva"] = "Mínimo 8 caracteres con letras y números"
    if errores:
        raise ErrorValidacion(errores)
    with transaccion() as cur:
        cur.execute("SELECT password_hash FROM usuarios WHERE id=%s", (g.usuario_id,))
        if not verificar(actual, cur.fetchone()["password_hash"]):
            raise ErrorValidacion({"password_actual": "La contraseña actual es incorrecta"})
        cur.execute("UPDATE usuarios SET password_hash=%s WHERE id=%s", (hashear(nueva), g.usuario_id))
        revocar_tokens_usuario(cur, g.usuario_id, excepto=g.token)
    return jsonify({"mensaje": "Contraseña actualizada"})
