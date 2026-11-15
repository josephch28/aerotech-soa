"""AeroTech – API REST (Flask). Punto de entrada."""
import os

from flask import Flask, jsonify
from flask_cors import CORS

import config
from db import get_conn
from errores import registrar_manejadores
from servicios import admin, auth, reportes, reservas, usuarios, vuelos

CATALOGO = [
    {"nombre": "Usuarios", "prefijo": "/api/usuarios", "descripcion": "Registro y perfil de usuarios",
     "endpoints": ["POST /registro", "GET /perfil", "PUT /perfil", "PUT /password"]},
    {"nombre": "Autenticación", "prefijo": "/api/auth", "descripcion": "Inicio y cierre de sesión (JWT)",
     "endpoints": ["POST /login", "POST /logout"]},
    {"nombre": "Vuelos", "prefijo": "/api/vuelos, /api/aeropuertos",
     "descripcion": "Consulta de vuelos, aeropuertos y mapa de asientos",
     "endpoints": ["GET /api/aeropuertos", "GET /api/vuelos", "GET /api/vuelos/{id}",
                   "GET /api/vuelos/{id}/asientos"]},
    {"nombre": "Reservas", "prefijo": "/api/reservas", "descripcion": "Gestión de reservas del cliente",
     "endpoints": ["POST /", "GET /", "GET /{id}", "PUT /{id}", "PUT /{id}/cancelar",
                   "GET /{id}/factura", "GET /{id}/historial"]},
    {"nombre": "Administración", "prefijo": "/api/admin",
     "descripcion": "Flota, vuelos, usuarios y reservas (solo admin)",
     "endpoints": ["/aviones", "/vuelos", "/reservas", "/usuarios"]},
    {"nombre": "Reportes", "prefijo": "/api/reportes", "descripcion": "Dashboard (solo admin)",
     "endpoints": ["GET /dashboard"]},
]

SWAGGER_HTML = """<!doctype html><html lang="es"><head><meta charset="utf-8"><title>AeroTech API</title>
<link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.17.14/swagger-ui.css"></head>
<body><div id="swagger-ui"></div>
<script src="https://unpkg.com/swagger-ui-dist@5.17.14/swagger-ui-bundle.js"></script>
<script>SwaggerUIBundle({url: "/static/openapi.yaml", dom_id: "#swagger-ui"});</script></body></html>"""


def create_app():
    app = Flask(__name__)
    CORS(app)
    app.json.ensure_ascii = False
    app.json.sort_keys = False
    registrar_manejadores(app)
    for modulo in (usuarios, auth, vuelos, reservas, admin, reportes):
        app.register_blueprint(modulo.bp)

    @app.get("/")
    def raiz():
        return jsonify({"api": "AeroTech – Reservas de vuelos", "version": "1.0.0", "servicios": CATALOGO})

    @app.get("/api/salud")
    def salud():
        try:
            with get_conn() as conn:
                conn.execute("SELECT 1")
        except Exception:
            return jsonify({"estado": "error", "bd": "error", "hora_servidor": config.ahora().isoformat()}), 503
        return jsonify({"estado": "ok", "bd": "ok", "hora_servidor": config.ahora().isoformat()})

    @app.get("/docs")
    def docs():
        return SWAGGER_HTML

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", 5000)))
