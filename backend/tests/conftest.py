"""Fixtures de pytest. Las pruebas usan HTTP real contra API_URL (por defecto http://localhost:5000)."""
import os
import random
import sys
from pathlib import Path

import pytest
import requests
from dotenv import load_dotenv

sys.path.insert(0, str(Path(__file__).resolve().parent))
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

from utilidades import (codigo_vuelo_aleatorio, correo_aleatorio, generar_cedula_valida,  # noqa: E402
                        matricula_aleatoria)

API_URL = os.getenv("API_URL", "http://localhost:5000").rstrip("/")


class Sesion:
    """Cliente HTTP mínimo con token opcional."""

    def __init__(self, token=None, datos=None):
        self.token = token
        self.datos = datos or {}

    def _cab(self):
        return {"Authorization": f"Bearer {self.token}"} if self.token else {}

    def _pedir(self, metodo, ruta, **kw):
        return requests.request(metodo, API_URL + ruta, headers=self._cab(), timeout=60, **kw)

    def get(self, ruta, **kw): return self._pedir("GET", ruta, **kw)
    def post(self, ruta, **kw): return self._pedir("POST", ruta, **kw)
    def put(self, ruta, **kw): return self._pedir("PUT", ruta, **kw)
    def patch(self, ruta, **kw): return self._pedir("PATCH", ruta, **kw)


@pytest.fixture(scope="session")
def api():
    return Sesion()


@pytest.fixture(scope="session")
def admin():
    r = requests.post(API_URL + "/api/auth/login", timeout=60,
                      json={"correo": os.environ["ADMIN_CORREO"], "password": os.environ["ADMIN_PASSWORD"]})
    assert r.status_code == 200, f"No se pudo iniciar sesión como admin: {r.text}"
    return Sesion(r.json()["token"], r.json()["usuario"])


def _registrar_cliente() -> Sesion:
    datos = {"nombre": "Usuario", "apellido": "Prueba", "cedula": generar_cedula_valida(),
             "telefono": "09" + str(random.randint(10000000, 99999999)), "correo": correo_aleatorio(),
             "password": "Clave" + str(random.randint(1000, 9999))}
    r = requests.post(API_URL + "/api/usuarios/registro", json=datos, timeout=60)
    assert r.status_code == 201, r.text
    datos["id"] = r.json()["usuario"]["id"]
    r = requests.post(API_URL + "/api/auth/login", json={"correo": datos["correo"], "password": datos["password"]},
                      timeout=60)
    assert r.status_code == 200, r.text
    return Sesion(r.json()["token"], datos)


@pytest.fixture
def nuevo_cliente():
    """Fábrica: cada llamada registra y autentica un cliente distinto."""
    return _registrar_cliente


@pytest.fixture
def cliente():
    return _registrar_cliente()


@pytest.fixture
def otro_cliente():
    return _registrar_cliente()


@pytest.fixture
def fabrica_vuelos(admin):
    """Fábrica de vuelos de prueba. Al terminar, cancela los que creó (los deja fuera de las búsquedas)."""
    creados = []

    def crear(avion_id, **cambios):
        fijo = any(k in cambios for k in ("fecha", "hora_salida"))
        for _ in range(30):
            hora = random.randint(6, 18)
            datos = {"codigo_vuelo": codigo_vuelo_aleatorio(), "avion_id": avion_id, "origen": "UIO",
                     "destino": "GYE", "fecha": f"2027-{random.randint(2, 12):02d}-{random.randint(1, 28):02d}",
                     "hora_salida": f"{hora:02d}:{random.choice(['00', '15', '30', '45'])}",
                     "hora_llegada": None, "precio": 80, "precio_ejecutiva": 120}
            datos.update(cambios)
            if datos["hora_llegada"] is None:
                h, m = map(int, datos["hora_salida"].split(":"))
                datos["hora_llegada"] = f"{h + 1:02d}:{m:02d}"
            r = admin.post("/api/admin/vuelos", json=datos)
            if r.status_code == 201:
                vuelo = r.json()["vuelo"]
                vuelo["asientos_generados"] = r.json()["asientos_generados"]
                creados.append(vuelo["id"])
                return vuelo
            if r.status_code != 409 or fijo:
                pytest.fail(f"No se pudo crear el vuelo de prueba: {r.status_code} {r.text}")
        pytest.fail("No se encontró un horario libre para el vuelo de prueba")

    yield crear
    for vid in creados:
        admin.put(f"/api/admin/vuelos/{vid}/cancelar", json={"motivo": "Limpieza de pruebas"})


@pytest.fixture(scope="session")
def avion_atr(admin):
    aviones = admin.get("/api/admin/aviones").json()
    atr = next((a for a in aviones if a["matricula"] == "HC-ATC"), None)
    assert atr, "Falta el avión HC-ATC (ejecute python -m scripts.sembrar --reset)"
    return atr


@pytest.fixture
def vuelo_nuevo(fabrica_vuelos, avion_atr):
    """Vuelo UIO→GYE en el ATR (72 asientos, columnas A C D F; filas 1 y 18 son salida de emergencia)."""
    return fabrica_vuelos(avion_atr["id"])


@pytest.fixture
def avion_pequeno(admin):
    """Avión de prueba: configuración A-C, 5 filas = 10 asientos (fila 3 salida de emergencia)."""
    r = admin.post("/api/admin/aviones", json={
        "modelo": "Avión de prueba", "matricula": matricula_aleatoria(), "configuracion": "A-C",
        "filas": 5, "filas_ejecutiva": 0, "filas_salida": [3]})
    assert r.status_code == 201, r.text
    avion = r.json()["avion"]
    yield avion
    admin.patch(f"/api/admin/aviones/{avion['id']}/estado", json={"activo": False})


@pytest.fixture
def vuelo_pequeno(avion_pequeno, fabrica_vuelos):
    return fabrica_vuelos(avion_pequeno["id"])
