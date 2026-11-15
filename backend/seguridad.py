"""Hash de contraseñas, JWT y decoradores de autorización."""
import secrets
from datetime import datetime, timedelta, timezone
from functools import wraps

import jwt
from flask import g, request
from werkzeug.security import check_password_hash, generate_password_hash

import config
from db import transaccion
from errores import ErrorApi


def hashear(password: str) -> str:
    return generate_password_hash(password, method="pbkdf2:sha256")


def verificar(password: str, hash_guardado: str) -> bool:
    return check_password_hash(hash_guardado, password)


def generar_token(cur, usuario: dict):
    """Crea el JWT, lo guarda en `tokens` y devuelve (token, expiracion)."""
    exp = datetime.now(timezone.utc) + timedelta(hours=config.JWT_HORAS_EXPIRACION)
    token = jwt.encode(
        {"sub": str(usuario["id"]), "nombre": usuario["nombre"], "rol": usuario["rol"],
         "jti": secrets.token_hex(8), "exp": exp},
        config.JWT_SECRET, algorithm="HS256")
    cur.execute("INSERT INTO tokens (usuario_id, token, expiracion) VALUES (%s,%s,%s)",
                (usuario["id"], token, exp))
    return token, exp


def revocar_tokens_usuario(cur, usuario_id, excepto=None):
    if excepto:
        cur.execute("UPDATE tokens SET estado='revocado' WHERE usuario_id=%s AND token<>%s AND estado='activo'",
                    (usuario_id, excepto))
    else:
        cur.execute("UPDATE tokens SET estado='revocado' WHERE usuario_id=%s AND estado='activo'",
                    (usuario_id,))


def token_requerido(f):
    @wraps(f)
    def envoltura(*args, **kwargs):
        cab = request.headers.get("Authorization", "")
        if not cab.startswith("Bearer ") or len(cab) < 8:
            raise ErrorApi("Token requerido", 401)
        token = cab[7:].strip()
        try:
            jwt.decode(token, config.JWT_SECRET, algorithms=["HS256"])
        except jwt.ExpiredSignatureError:
            raise ErrorApi("Token expirado", 401)
        except jwt.InvalidTokenError:
            raise ErrorApi("Token inválido", 401)
        with transaccion() as cur:
            cur.execute(
                """SELECT u.id, u.rol, u.activo FROM tokens t JOIN usuarios u ON u.id=t.usuario_id
                   WHERE t.token=%s AND t.estado='activo' AND t.expiracion > NOW()""", (token,))
            fila = cur.fetchone()
        if not fila:
            raise ErrorApi("Sesión cerrada o token revocado", 401)
        if not fila["activo"]:
            raise ErrorApi("Cuenta desactivada. Contacte al administrador", 403)
        g.usuario_id, g.rol, g.token = fila["id"], fila["rol"], token
        return f(*args, **kwargs)
    return envoltura


def rol_requerido(*roles):
    def decorador(f):
        @wraps(f)
        def envoltura(*args, **kwargs):
            if g.get("rol") not in roles:
                raise ErrorApi("No tiene permisos para esta operación", 403)
            return f(*args, **kwargs)
        return envoltura
    return decorador
