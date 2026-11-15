"""Crea o actualiza el usuario administrador a partir de las variables ADMIN_* del .env."""
import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from werkzeug.security import generate_password_hash

RAIZ = Path(__file__).resolve().parent.parent
load_dotenv(RAIZ / ".env")


def _hashear(password: str) -> str:
    # Equivale a seguridad.hashear (Fase 2): pbkdf2:sha256
    return generate_password_hash(password, method="pbkdf2:sha256")


def crear_admin() -> None:
    datos = {
        "nombre": os.environ["ADMIN_NOMBRE"],
        "apellido": os.environ["ADMIN_APELLIDO"],
        "cedula": os.environ["ADMIN_CEDULA"],
        "telefono": os.environ["ADMIN_TELEFONO"],
        "correo": os.environ["ADMIN_CORREO"].strip().lower(),
        "hash": _hashear(os.environ["ADMIN_PASSWORD"]),
    }
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        conn.execute(
            """INSERT INTO usuarios (nombre, apellido, cedula, telefono, correo, password_hash, rol, activo)
               VALUES (%(nombre)s, %(apellido)s, %(cedula)s, %(telefono)s, %(correo)s, %(hash)s, 'admin', TRUE)
               ON CONFLICT (correo) DO UPDATE
               SET nombre = EXCLUDED.nombre, apellido = EXCLUDED.apellido, telefono = EXCLUDED.telefono,
                   password_hash = EXCLUDED.password_hash, rol = 'admin', activo = TRUE""",
            datos,
        )
    print(f"Administrador listo: {datos['correo']}")


if __name__ == "__main__":
    crear_admin()
