"""Siembra de datos de AeroTech.

Pasos: 1) aeropuertos, 2) aviones, 5) admin, 3) vuelos (con `crear_vuelo`, genera asientos),
4) usuario demo y reservas demo (~30 % de ocupación en varios vuelos).

Uso (desde backend/): python -m scripts.sembrar --reset
"""
import argparse
import os
import random
from pathlib import Path

import psycopg
from dotenv import load_dotenv

from scripts.aplicar_esquema import aplicar_esquema
from scripts.crear_admin import crear_admin

RAIZ = Path(__file__).resolve().parent.parent
load_dotenv(RAIZ / ".env")

AEROPUERTOS = [
    ("UIO", "Quito", "Aeropuerto Internacional Mariscal Sucre"),
    ("GYE", "Guayaquil", "Aeropuerto Internacional José Joaquín de Olmedo"),
    ("CUE", "Cuenca", "Aeropuerto Mariscal Lamar"),
    ("MEC", "Manta", "Aeropuerto Internacional Eloy Alfaro"),
    ("LOH", "Loja", "Aeropuerto Ciudad de Catamayo"),
    ("GPS", "Baltra - Galápagos", "Aeropuerto Seymour"),
    ("ESM", "Esmeraldas", "Aeropuerto Carlos Concha Torres"),
    ("OCC", "Coca", "Aeropuerto Francisco de Orellana"),
]

# modelo, matricula, configuracion, config. ejecutiva, filas, filas ejecutiva, filas salida
AVIONES = [
    ("Airbus A320", "HC-ATA", "ABC-DEF", "AC-DF", 30, 3, [12, 13]),
    ("Embraer E190", "HC-ATB", "AC-DF", "A-DF", 24, 2, [11]),
    ("ATR 72-600", "HC-ATC", "AC-DF", None, 18, 0, [1, 18]),
]

# codigo, matrícula del avión, origen, destino, fecha, salida, llegada, precio
VUELOS = [
    ("AT101", "HC-ATA", "UIO", "GYE", "2026-12-21", "09:45", "10:40", 89),
    ("AT102", "HC-ATB", "UIO", "CUE", "2026-12-21", "12:20", "13:15", 99),
    ("AT103", "HC-ATA", "UIO", "MEC", "2026-12-21", "14:50", "15:40", 79),
    ("AT201", "HC-ATC", "UIO", "GPS", "2026-12-21", "07:00", "09:30", 150),  # ATR: pruebas de llenado
    ("AT104", "HC-ATA", "GYE", "UIO", "2026-12-21", "12:00", "12:55", 89),
    ("AT105", "HC-ATB", "CUE", "UIO", "2026-12-21", "15:00", "15:55", 99),
    ("AT106", "HC-ATA", "UIO", "GYE", "2026-12-22", "09:45", "10:40", 89),
    ("AT107", "HC-ATB", "UIO", "LOH", "2026-12-22", "08:00", "09:05", 95),
    ("AT108", "HC-ATC", "GYE", "GPS", "2026-12-22", "08:30", "11:00", 140),
    ("AT109", "HC-ATA", "GYE", "CUE", "2026-12-23", "10:00", "10:45", 70),
    ("AT110", "HC-ATB", "UIO", "OCC", "2026-12-23", "07:30", "08:15", 85),
    ("AT111", "HC-ATC", "UIO", "ESM", "2026-12-23", "13:00", "13:50", 75),
    ("AT112", "HC-ATA", "UIO", "GYE", "2026-12-28", "09:45", "10:40", 99),
    ("AT113", "HC-ATB", "UIO", "CUE", "2026-12-28", "12:20", "13:15", 109),
    ("AT114", "HC-ATA", "UIO", "MEC", "2027-01-05", "14:50", "15:40", 85),
    ("AT115", "HC-ATC", "UIO", "GPS", "2027-01-05", "07:00", "09:30", 160),
    ("AT116", "HC-ATB", "GYE", "LOH", "2027-01-10", "11:00", "11:50", 80),
]


def sembrar_base(conn) -> None:
    for codigo, ciudad, nombre in AEROPUERTOS:
        conn.execute("""INSERT INTO aeropuertos (codigo, ciudad, nombre) VALUES (%s,%s,%s)
                        ON CONFLICT (codigo) DO NOTHING""", (codigo, ciudad, nombre))
    for modelo, mat, conf, conf_ej, filas, filas_ej, salida in AVIONES:
        conn.execute("""INSERT INTO aviones (modelo, matricula, configuracion, configuracion_ejecutiva,
                                             filas, filas_ejecutiva, filas_salida)
                        VALUES (%s,%s,%s,%s,%s,%s,%s) ON CONFLICT (matricula) DO NOTHING""",
                     (modelo, mat, conf, conf_ej, filas, filas_ej, salida))
    print(f"Sembrados {len(AEROPUERTOS)} aeropuertos y {len(AVIONES)} aviones.")


def sembrar_vuelos() -> list[int]:
    from db import transaccion
    from servicios.admin import crear_vuelo
    ids = []
    with transaccion() as cur:
        cur.execute("SELECT id FROM usuarios WHERE rol='admin' ORDER BY id LIMIT 1")
        admin_id = cur.fetchone()["id"]
        cur.execute("SELECT id, matricula FROM aviones")
        aviones = {a["matricula"]: a["id"] for a in cur.fetchall()}
        for cod, mat, o, d, fecha, sal, lle, precio in VUELOS:
            ej = precio + 100 if mat != "HC-ATC" else precio   # el ATR no tiene clase ejecutiva
            r = crear_vuelo(cur, {"codigo_vuelo": cod, "avion_id": aviones[mat], "origen": o, "destino": d,
                                  "fecha": fecha, "hora_salida": sal, "hora_llegada": lle,
                                  "precio": precio, "precio_ejecutiva": ej}, admin_id)
            ids.append(r["id"])
    print(f"Creados {len(ids)} vuelos con sus asientos.")
    return ids


def sembrar_reservas_demo(vuelo_ids: list[int]) -> None:
    from db import transaccion
    from scripts.crear_admin import _hashear
    from servicios.reservas import crear_reserva
    from tests.utilidades import generar_cedula_valida

    azar = random.Random(2026)
    correo, password = os.environ["DEMO_CORREO"].strip().lower(), os.environ["DEMO_PASSWORD"]
    with transaccion() as cur:
        cur.execute("""INSERT INTO usuarios (nombre, apellido, cedula, telefono, correo, password_hash, rol)
                       VALUES ('Cliente','Demo',%s,'0988888888',%s,%s,'cliente')
                       ON CONFLICT (correo) DO UPDATE SET password_hash=EXCLUDED.password_hash
                       RETURNING id, nombre, apellido, telefono, correo""",
                    (generar_cedula_valida(), correo, _hashear(password)))
        demo = cur.fetchone()

    total = 0
    for vid in vuelo_ids[:10]:   # los 10 primeros vuelos quedan ~30 % ocupados
        with transaccion() as cur:
            cur.execute("SELECT codigo FROM asientos WHERE vuelo_id=%s ORDER BY id", (vid,))
            codigos = [r["codigo"] for r in cur.fetchall()]
        azar.shuffle(codigos)
        pendientes = codigos[: int(len(codigos) * 0.30)]
        usados = set()
        while pendientes:
            n = min(azar.randint(1, 4), len(pendientes))
            grupo, pendientes = pendientes[:n], pendientes[n:]
            pasajeros = []
            for a in grupo:
                doc = generar_cedula_valida()
                while doc in usados:
                    doc = generar_cedula_valida()
                usados.add(doc)
                pasajeros.append({"asiento": a, "nombres": azar.choice(["Luis", "María", "Carlos", "Ana", "José", "Lucía"]),
                                  "apellidos": azar.choice(["Torres", "Vega", "Ríos", "Mora", "Paredes", "Salazar"]),
                                  "tipo_documento": "cedula", "numero_documento": doc,
                                  "fecha_nacimiento": f"{azar.randint(1955, 2000)}-{azar.randint(1, 12):02d}-{azar.randint(1, 28):02d}"})
            with transaccion() as cur:
                crear_reserva(cur, demo, {"vuelo_id": vid, "pasajeros": pasajeros})
            total += 1
    print(f"Usuario demo listo ({correo}) y {total} reservas demo creadas.")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--reset", action="store_true", help="Ejecuta schema.sql antes de sembrar")
    args = ap.parse_args()
    if args.reset:
        aplicar_esquema()
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        sembrar_base(conn)
    crear_admin()                      # paso 5 (antes de los vuelos: se necesita creado_por)
    ids = sembrar_vuelos()             # paso 3
    sembrar_reservas_demo(ids)         # paso 4


if __name__ == "__main__":
    main()
