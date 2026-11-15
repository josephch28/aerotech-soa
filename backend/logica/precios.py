"""Cálculo de precios con Decimal."""
from decimal import Decimal

import config

CENT = Decimal("0.01")


def calcular(asientos: list[dict], vuelo: dict):
    """Devuelve (precio_por_asiento, subtotal, iva, total) respetando el orden de `asientos`."""
    detalle = [Decimal(vuelo["precio_ejecutiva"] if a["clase"] == "ejecutiva" else vuelo["precio"]).quantize(CENT)
               for a in asientos]
    subtotal = sum(detalle, Decimal("0")).quantize(CENT)
    iva = (subtotal * config.IVA).quantize(CENT)
    return detalle, subtotal, iva, (subtotal + iva).quantize(CENT)
