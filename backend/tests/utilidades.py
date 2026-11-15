"""Utilidades de prueba: cédulas válidas, datos aleatorios y constructores de cuerpos."""
import random
import re
import string
from datetime import date, timedelta


def validar_cedula(c: str) -> bool:
    if not re.fullmatch(r"\d{10}", c or ""):
        return False
    provincia, tercero = int(c[:2]), int(c[2])
    if not (1 <= provincia <= 24 or provincia == 30) or tercero >= 6:
        return False
    suma = 0
    for i, coef in enumerate([2, 1, 2, 1, 2, 1, 2, 1, 2]):
        p = int(c[i]) * coef
        suma += p - 9 if p > 9 else p
    return (10 - suma % 10) % 10 == int(c[9])


def generar_cedula_valida() -> str:
    """Genera una cédula ecuatoriana aleatoria que cumple el módulo 10."""
    provincia = random.randint(1, 24)
    base = f"{provincia:02d}{random.randint(0, 5)}{random.randint(0, 999999):06d}"
    suma = 0
    for i, coef in enumerate([2, 1, 2, 1, 2, 1, 2, 1, 2]):
        p = int(base[i]) * coef
        suma += p - 9 if p > 9 else p
    return base + str((10 - suma % 10) % 10)


def correo_aleatorio() -> str:
    sufijo = "".join(random.choices(string.ascii_lowercase + string.digits, k=10))
    return f"test_{sufijo}@correo.com"


def matricula_aleatoria() -> str:
    return "HC-" + "".join(random.choices(string.ascii_uppercase + string.digits, k=4))


def codigo_vuelo_aleatorio() -> str:
    return "".join(random.choices(string.ascii_uppercase, k=2)) + str(random.randint(1000, 9999))


def fecha_nacimiento(edad: int, fecha_vuelo: str | None = None) -> str:
    """Fecha de nacimiento tal que la persona tenga exactamente `edad` años en `fecha_vuelo`."""
    ref = date.fromisoformat(fecha_vuelo) if fecha_vuelo else date(2027, 6, 15)
    cumple = date(ref.year - edad, ref.month, min(ref.day, 28))
    return (cumple - timedelta(days=30)).isoformat()


def pasajero(asiento: str, edad: int = 30, fecha_vuelo: str | None = None, tipo: str = "cedula",
             documento: str | None = None) -> dict:
    if documento is None:
        documento = generar_cedula_valida() if tipo == "cedula" else "AB" + str(random.randint(100000, 999999))
    return {"asiento": asiento, "nombres": "Pasajero", "apellidos": "Prueba", "tipo_documento": tipo,
            "numero_documento": documento, "fecha_nacimiento": fecha_nacimiento(edad, fecha_vuelo)}


def cuerpo_reserva(vuelo: dict, pasajeros: list[dict], con_vuelo: bool = True) -> dict:
    cuerpo = {"pasajeros": pasajeros}
    if con_vuelo:
        cuerpo["vuelo_id"] = vuelo["id"]
    return cuerpo
