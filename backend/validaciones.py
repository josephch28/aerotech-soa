"""Reglas de validación reutilizables (fuente de verdad)."""
import re
from datetime import date, datetime

from errores import ErrorValidacion

RE_TEXTO = re.compile(r"^[A-Za-zÁÉÍÓÚáéíóúÑñÜü' ]{2,60}$")
RE_PASAPORTE = re.compile(r"^[A-Z0-9]{6,15}$")
RE_TELEFONO = re.compile(r"^09\d{8}$")
RE_CORREO = re.compile(r"^[\w.+-]+@[\w-]+(\.[\w-]+)+$")
RE_CODIGO_VUELO = re.compile(r"^[A-Z]{2}\d{3,4}$")
RE_MATRICULA = re.compile(r"^HC-[A-Z0-9]{3,4}$")
RE_CONFIG = re.compile(r"^[A-K]{1,4}(-[A-K]{1,4}){1,2}$")
RE_FECHA = re.compile(r"^\d{4}-\d{2}-\d{2}$")
RE_HORA = re.compile(r"^\d{2}:\d{2}$")


def limpiar_texto(s) -> str:
    return re.sub(r"\s+", " ", str(s or "").strip())


def validar_cedula(c) -> bool:
    c = c or ""
    if not re.fullmatch(r"\d{10}", c):
        return False
    provincia, tercero = int(c[:2]), int(c[2])
    if not (1 <= provincia <= 24 or provincia == 30) or tercero >= 6:
        return False
    suma = 0
    for i, coef in enumerate([2, 1, 2, 1, 2, 1, 2, 1, 2]):
        p = int(c[i]) * coef
        suma += p - 9 if p > 9 else p
    return (10 - suma % 10) % 10 == int(c[9])


def validar_texto(s) -> bool:
    return bool(RE_TEXTO.fullmatch(limpiar_texto(s)))


def validar_telefono(s) -> bool:
    return bool(RE_TELEFONO.fullmatch(str(s or "")))


def validar_correo(s) -> bool:
    return bool(RE_CORREO.fullmatch(str(s or "").strip().lower()))


def validar_password(s) -> bool:
    s = s or ""
    return (isinstance(s, str) and len(s) >= 8
            and re.search(r"[A-Za-z]", s) is not None and re.search(r"\d", s) is not None)


def validar_pasaporte(s) -> bool:
    return bool(RE_PASAPORTE.fullmatch(str(s or "").strip().upper()))


def parsear_fecha(s):
    if not isinstance(s, str) or not RE_FECHA.fullmatch(s):
        return None
    try:
        return date.fromisoformat(s)
    except ValueError:
        return None


def parsear_hora(s):
    if not isinstance(s, str) or not RE_HORA.fullmatch(s):
        return None
    try:
        return datetime.strptime(s, "%H:%M").time()
    except ValueError:
        return None


class Validador:
    """Acumula errores por campo; `verificar()` lanza 400 con todos a la vez.
    Los valores normalizados quedan en `self.limpio`."""

    def __init__(self, datos, prefijo=""):
        self.datos = datos if isinstance(datos, dict) else {}
        self.prefijo = prefijo
        self.errores: dict[str, str] = {}
        self.limpio: dict = {}

    def _err(self, campo, msg):
        self.errores.setdefault(self.prefijo + campo, msg)

    def texto(self, campo, etiqueta=""):
        v = limpiar_texto(self.datos.get(campo))
        if RE_TEXTO.fullmatch(v):
            self.limpio[campo] = v
        else:
            self._err(campo, "Solo letras y espacios (2-60 caracteres)")

    def cedula(self, campo):
        v = str(self.datos.get(campo) or "").strip()
        if validar_cedula(v):
            self.limpio[campo] = v
        else:
            self._err(campo, "Cédula ecuatoriana inválida")

    def pasaporte(self, campo):
        v = str(self.datos.get(campo) or "").strip().upper()
        if RE_PASAPORTE.fullmatch(v):
            self.limpio[campo] = v
        else:
            self._err(campo, "Pasaporte inválido (6-15 letras/números)")

    def telefono(self, campo):
        v = str(self.datos.get(campo) or "").strip()
        if RE_TELEFONO.fullmatch(v):
            self.limpio[campo] = v
        else:
            self._err(campo, "Teléfono celular inválido (09XXXXXXXX)")

    def correo(self, campo):
        v = str(self.datos.get(campo) or "").strip().lower()
        if RE_CORREO.fullmatch(v):
            self.limpio[campo] = v
        else:
            self._err(campo, "Correo inválido")

    def password(self, campo):
        v = self.datos.get(campo)
        if validar_password(v):
            self.limpio[campo] = v
        else:
            self._err(campo, "Mínimo 8 caracteres con letras y números")

    def regex(self, campo, patron, mensaje, mayusculas=False):
        v = str(self.datos.get(campo) or "").strip()
        if mayusculas:
            v = v.upper()
        if patron.fullmatch(v):
            self.limpio[campo] = v
        else:
            self._err(campo, mensaje)

    def fecha(self, campo):
        f = parsear_fecha(self.datos.get(campo))
        if f:
            self.limpio[campo] = f
        else:
            self._err(campo, "Formato de fecha/hora inválido")

    def hora(self, campo):
        h = parsear_hora(self.datos.get(campo))
        if h:
            self.limpio[campo] = h
        else:
            self._err(campo, "Formato de fecha/hora inválido")

    def verificar(self):
        if self.errores:
            raise ErrorValidacion(self.errores)
        return self.limpio
