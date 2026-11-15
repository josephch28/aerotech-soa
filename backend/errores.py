"""Errores de la API y manejadores globales."""
import traceback

import psycopg
from flask import jsonify


class ErrorApi(Exception):
    def __init__(self, mensaje, codigo=400, campos=None, extra=None):
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.codigo = codigo
        self.campos = campos
        self.extra = extra or {}


class ErrorValidacion(ErrorApi):
    def __init__(self, campos: dict):
        super().__init__("Datos inválidos", 400, campos=campos)


def _respuesta(mensaje, codigo, campos=None, extra=None):
    cuerpo = {"error": mensaje, "codigo": codigo}
    if campos:
        cuerpo["campos"] = campos
    if extra:
        cuerpo.update(extra)
    return jsonify(cuerpo), codigo


def registrar_manejadores(app):
    @app.errorhandler(ErrorApi)
    def _api(e):
        return _respuesta(e.mensaje, e.codigo, e.campos, e.extra)

    @app.errorhandler(404)
    def _404(e):
        return _respuesta("Recurso no encontrado", 404)

    @app.errorhandler(405)
    def _405(e):
        return _respuesta("Método no permitido", 405)

    @app.errorhandler(psycopg.errors.UniqueViolation)
    def _unico(e):
        return _respuesta("El registro ya existe", 409)

    @app.errorhandler(Exception)
    def _500(e):
        traceback.print_exc()
        return _respuesta("Error interno del servidor", 500)
