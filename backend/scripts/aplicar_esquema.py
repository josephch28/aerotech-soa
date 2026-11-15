"""Ejecuta sql/schema.sql contra la base de datos (reinicia las tablas)."""
import os
from pathlib import Path

import psycopg
from dotenv import load_dotenv

RAIZ = Path(__file__).resolve().parent.parent
load_dotenv(RAIZ / ".env")


def aplicar_esquema() -> None:
    sql = (RAIZ / "sql" / "schema.sql").read_text(encoding="utf-8")
    with psycopg.connect(os.environ["DATABASE_URL"], autocommit=True) as conn:
        conn.execute(sql)
    print("Esquema aplicado: 9 tablas creadas.")


if __name__ == "__main__":
    aplicar_esquema()
