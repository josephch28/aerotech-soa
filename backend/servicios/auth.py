"""Servicio 2 – Autenticación (/api/auth)."""
from flask import Blueprint, g, jsonify, request

from db import serializar, transaccion
from errores import ErrorApi, ErrorValidacion
from seguridad import generar_token, token_requerido, verificar

bp = Blueprint("auth", __name__, url_prefix="/api/auth")


@bp.post("/login")
def login():
    datos = request.get_json(silent=True) or {}
    correo = str(datos.get("correo") or "").strip().lower()
    password = datos.get("password")
    errores = {}
    if not correo:
        errores["correo"] = "Correo inválido"
    if not password:
        errores["password"] = "La contraseña es obligatoria"
    if errores:
        raise ErrorValidacion(errores)
    with transaccion() as cur:
        cur.execute("SELECT * FROM usuarios WHERE correo=%s", (correo,))
        u = cur.fetchone()
        if not u or not verificar(password, u["password_hash"]):
            raise ErrorApi("Credenciales incorrectas", 401)
        if not u["activo"]:
            raise ErrorApi("Cuenta desactivada. Contacte al administrador", 403)
        token, exp = generar_token(cur, u)
    return jsonify(serializar({
        "mensaje": "Inicio de sesión exitoso", "token": token, "expira": exp,
        "usuario": {"id": u["id"], "nombre": u["nombre"], "apellido": u["apellido"],
                    "correo": u["correo"], "rol": u["rol"]}}))


@bp.post("/logout")
@token_requerido
def logout():
    with transaccion() as cur:
        cur.execute("UPDATE tokens SET estado='revocado' WHERE token=%s", (g.token,))
    return jsonify({"mensaje": "Sesión cerrada"})
