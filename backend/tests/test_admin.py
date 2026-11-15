import pytest

from utilidades import (codigo_vuelo_aleatorio, cuerpo_reserva, matricula_aleatoria, pasajero)

RUTAS_GET = ["/api/admin/aviones", "/api/admin/vuelos", "/api/admin/reservas", "/api/admin/usuarios",
             "/api/admin/aviones/1/vista-previa", "/api/admin/vuelos/1/manifiesto", "/api/reportes/dashboard"]


@pytest.mark.parametrize("ruta", RUTAS_GET)
def test_cliente_recibe_403_en_get_admin(cliente, ruta):
    r = cliente.get(ruta)
    assert r.status_code == 403
    assert r.json()["error"] == "No tiene permisos para esta operación"


def test_cliente_recibe_403_en_escrituras_admin(cliente):
    assert cliente.post("/api/admin/aviones", json={}).status_code == 403
    assert cliente.post("/api/admin/vuelos", json={}).status_code == 403
    assert cliente.put("/api/admin/vuelos/1", json={}).status_code == 403
    assert cliente.put("/api/admin/vuelos/1/cancelar", json={"motivo": "xxxxx"}).status_code == 403
    assert cliente.patch("/api/admin/usuarios/1", json={"activo": False}).status_code == 403
    assert cliente.patch("/api/admin/aviones/1/estado", json={"activo": False}).status_code == 403


def test_admin_sin_token_401(api):
    assert api.get("/api/admin/vuelos").status_code == 401


def test_crear_avion_configuracion_invalida_400(admin):
    base = {"modelo": "Test", "matricula": matricula_aleatoria(), "configuracion": "ABC-DEF", "filas": 6,
            "filas_ejecutiva": 0}
    for conf in ("ABC-ABC", "ZZ-XX", "ABC", "ABCDE-FGHIJ-K", "abc def"):
        r = admin.post("/api/admin/aviones", json={**base, "configuracion": conf})
        assert r.status_code == 400 and "configuracion" in r.json()["campos"], conf
    r = admin.post("/api/admin/aviones", json={**base, "matricula": "XX-123", "filas": 2})
    assert r.status_code == 400 and {"matricula", "filas"} <= set(r.json()["campos"])


def test_crear_avion_y_vista_previa(admin, avion_pequeno):
    assert avion_pequeno["capacidad"] == 10
    r = admin.get(f"/api/admin/aviones/{avion_pequeno['id']}/vista-previa")
    assert r.status_code == 200
    j = r.json()
    assert j["resumen"]["total"] == len(j["asientos"]) == 10 and j["vuelo"] is None
    assert {a["fila"] for a in j["asientos"] if a["salida_emergencia"]} == {3}


def test_matricula_duplicada_409(admin, avion_pequeno):
    r = admin.post("/api/admin/aviones", json={"modelo": "X1", "matricula": avion_pequeno["matricula"],
                                               "configuracion": "A-C", "filas": 5, "filas_ejecutiva": 0})
    assert r.status_code == 409


def test_crear_vuelo_genera_asientos_segun_avion(admin, api, vuelo_pequeno, avion_pequeno):
    assert vuelo_pequeno["asientos_generados"] == avion_pequeno["capacidad"] == 10
    m = api.get(f"/api/vuelos/{vuelo_pequeno['id']}/asientos").json()
    assert m["resumen"]["total"] == m["resumen"]["disponibles"] == 10


def test_crear_vuelo_a320_asientos_por_clase(admin, fabrica_vuelos, api):
    a320 = next(a for a in admin.get("/api/admin/aviones").json() if a["matricula"] == "HC-ATA")
    vuelo = fabrica_vuelos(a320["id"])
    m = api.get(f"/api/vuelos/{vuelo['id']}/asientos").json()
    assert m["resumen"]["total"] == a320["capacidad"] == 3 * 4 + 27 * 6
    assert sum(1 for a in m["asientos"] if a["clase"] == "ejecutiva") == 12


def test_origen_igual_destino_400(admin, vuelo_pequeno, avion_pequeno):
    r = admin.post("/api/admin/vuelos", json={
        "codigo_vuelo": codigo_vuelo_aleatorio(), "avion_id": avion_pequeno["id"], "origen": "UIO", "destino": "UIO",
        "fecha": "2027-07-07", "hora_salida": "10:00", "hora_llegada": "11:00", "precio": 80, "precio_ejecutiva": 100})
    assert r.status_code == 400 and "destino" in r.json()["campos"]


def test_llegada_antes_de_salida_400(admin, avion_pequeno):
    r = admin.post("/api/admin/vuelos", json={
        "codigo_vuelo": codigo_vuelo_aleatorio(), "avion_id": avion_pequeno["id"], "origen": "UIO", "destino": "GYE",
        "fecha": "2027-07-07", "hora_salida": "10:00", "hora_llegada": "09:00", "precio": 80, "precio_ejecutiva": 100})
    assert r.status_code == 400 and "hora_llegada" in r.json()["campos"]


def test_validaciones_de_precio_fecha_y_formato(admin, avion_pequeno):
    base = {"codigo_vuelo": codigo_vuelo_aleatorio(), "avion_id": avion_pequeno["id"], "origen": "UIO",
            "destino": "GYE", "fecha": "2027-07-07", "hora_salida": "10:00", "hora_llegada": "11:00", "precio": 80,
            "precio_ejecutiva": 100}
    casos = {"precio": {"precio": 10}, "precio_ejecutiva": {"precio_ejecutiva": 50},
             "fecha": {"fecha": "2020-01-01"}, "codigo_vuelo": {"codigo_vuelo": "A1"},
             "hora_llegada": {"hora_llegada": "17:00"}, "avion_id": {"avion_id": 999999}}
    for campo, cambio in casos.items():
        r = admin.post("/api/admin/vuelos", json={**base, **cambio})
        assert r.status_code == 400 and campo in r.json()["campos"], campo


def test_solapamiento_del_mismo_avion_409(admin, fabrica_vuelos, avion_pequeno):
    v1 = fabrica_vuelos(avion_pequeno["id"], fecha="2027-08-10", hora_salida="10:00", hora_llegada="11:00")
    r = admin.post("/api/admin/vuelos", json={
        "codigo_vuelo": codigo_vuelo_aleatorio(), "avion_id": avion_pequeno["id"], "origen": "GYE", "destino": "UIO",
        "fecha": "2027-08-10", "hora_salida": "11:30", "hora_llegada": "12:20", "precio": 80, "precio_ejecutiva": 100})
    assert r.status_code == 409 and avion_pequeno["matricula"] in r.json()["error"]
    assert v1["codigo_vuelo"] in r.json()["error"]
    # con 45 min o más de rotación sí se puede
    ok = fabrica_vuelos(avion_pequeno["id"], fecha="2027-08-10", hora_salida="11:45", hora_llegada="12:30")
    assert ok["id"] != v1["id"]


def test_codigo_y_fecha_duplicados_409(admin, vuelo_nuevo):
    r = admin.post("/api/admin/vuelos", json={
        "codigo_vuelo": vuelo_nuevo["codigo_vuelo"], "avion_id": 1, "origen": "UIO", "destino": "GYE",
        "fecha": vuelo_nuevo["fecha"], "hora_salida": "05:00", "hora_llegada": "05:50", "precio": 80,
        "precio_ejecutiva": 100})
    assert r.status_code == 409


def test_editar_precio_no_altera_reservas_existentes(admin, cliente, api, vuelo_nuevo):
    p = pasajero("5A", fecha_vuelo=vuelo_nuevo["fecha"])
    reserva = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [p])).json()["reserva"]
    r = admin.put(f"/api/admin/vuelos/{vuelo_nuevo['id']}", json={"precio": 95, "precio_ejecutiva": 130})
    assert r.status_code == 200 and r.json()["vuelo"]["precio"] == 95
    assert cliente.get(f"/api/reservas/{reserva['id']}").json()["total"] == reserva["total"] == 92.0
    assert api.get(f"/api/vuelos/{vuelo_nuevo['id']}").json()["precio"] == 95


def test_cambiar_avion_con_reservas_409(admin, cliente, vuelo_nuevo):
    p = pasajero("5A", fecha_vuelo=vuelo_nuevo["fecha"])
    assert cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [p])).status_code == 201
    a320 = next(a for a in admin.get("/api/admin/aviones").json() if a["matricula"] == "HC-ATA")
    r = admin.put(f"/api/admin/vuelos/{vuelo_nuevo['id']}", json={"avion_id": a320["id"]})
    assert r.status_code == 409


def test_cambiar_avion_sin_reservas_regenera_asientos(admin, api, vuelo_nuevo, avion_pequeno):
    r = admin.put(f"/api/admin/vuelos/{vuelo_nuevo['id']}", json={"avion_id": avion_pequeno["id"]})
    assert r.status_code == 200
    m = api.get(f"/api/vuelos/{vuelo_nuevo['id']}/asientos").json()
    assert m["resumen"]["total"] == 10 and api.get(f"/api/vuelos/{vuelo_nuevo['id']}").json()["asientos_disponibles"] == 10


def test_cancelar_vuelo_cancela_reservas(admin, cliente, otro_cliente, api, vuelo_nuevo):
    f = vuelo_nuevo["fecha"]
    r1 = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [pasajero("5A", fecha_vuelo=f)])).json()["reserva"]
    r2 = otro_cliente.post("/api/reservas/", json=cuerpo_reserva(
        vuelo_nuevo, [pasajero("6A", fecha_vuelo=f), pasajero("6C", fecha_vuelo=f)])).json()["reserva"]
    assert admin.put(f"/api/admin/vuelos/{vuelo_nuevo['id']}/cancelar", json={"motivo": "ab"}).status_code == 400
    r = admin.put(f"/api/admin/vuelos/{vuelo_nuevo['id']}/cancelar", json={"motivo": "Mantenimiento no programado"})
    assert r.status_code == 200 and r.json()["reservas_afectadas"] == 2
    for cli, res in ((cliente, r1), (otro_cliente, r2)):
        d = cli.get(f"/api/reservas/{res['id']}").json()
        assert d["estado"] == "cancelada" and d["motivo_cancelacion"] == "Vuelo cancelado por la aerolínea"
        assert [e["accion"] for e in cli.get(f"/api/reservas/{res['id']}/historial").json()["eventos"]][-1] == "cancelada"
    assert api.get(f"/api/vuelos/{vuelo_nuevo['id']}").json()["asientos_disponibles"] == 72
    assert api.get(f"/api/vuelos/{vuelo_nuevo['id']}").json()["estado"] == "cancelado"
    ids = [v["id"] for v in api.get("/api/vuelos", params={"fecha": f, "origen": "UIO", "destino": "GYE"}).json()["vuelos"]]
    assert vuelo_nuevo["id"] not in ids
    assert admin.put(f"/api/admin/vuelos/{vuelo_nuevo['id']}/cancelar", json={"motivo": "Otra vez ya"}).status_code == 409
    assert admin.put(f"/api/admin/vuelos/{vuelo_nuevo['id']}", json={"precio": 90}).status_code == 409


def test_manifiesto(admin, cliente, vuelo_nuevo):
    f = vuelo_nuevo["fecha"]
    ps = [pasajero("6C", edad=40, fecha_vuelo=f), pasajero("2A", edad=8, fecha_vuelo=f)]
    cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, ps))
    r = admin.get(f"/api/admin/vuelos/{vuelo_nuevo['id']}/manifiesto")
    assert r.status_code == 200
    j = r.json()
    assert j["total"] == 2 and [p["asiento"] for p in j["pasajeros"]] == ["2A", "6C"]  # ordenado por asiento
    assert j["pasajeros"][0]["edad"] == 8 and j["pasajeros"][1]["documento"] == ps[0]["numero_documento"]
    assert {"codigo_reserva", "titular", "clase", "nombre"} <= set(j["pasajeros"][0])
    assert admin.get("/api/admin/vuelos/99999999/manifiesto").status_code == 404


def test_listado_admin_de_vuelos_con_ocupacion_e_ingresos(admin, cliente, vuelo_pequeno):
    f = vuelo_pequeno["fecha"]
    cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_pequeno, [pasajero("1A", fecha_vuelo=f),
                                                                       pasajero("1C", fecha_vuelo=f)]))
    r = admin.get("/api/admin/vuelos", params={"desde": f, "hasta": f, "estado": "programado"})
    assert r.status_code == 200
    v = next(v for v in r.json()["vuelos"] if v["id"] == vuelo_pequeno["id"])
    assert v["ocupacion"] == 20.0 and v["capacidad"] == 10 and v["ingresos"] == 184.0
    assert admin.get("/api/admin/vuelos", params={"estado": "x"}).status_code == 400


def test_admin_ve_todas_las_reservas_y_puede_cancelar_con_motivo(admin, cliente, vuelo_nuevo):
    p = pasajero("5A", fecha_vuelo=vuelo_nuevo["fecha"])
    reserva = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [p])).json()["reserva"]
    r = admin.get("/api/admin/reservas", params={"codigo": reserva["codigo_reserva"]})
    assert r.status_code == 200 and r.json()["total"] == 1
    assert admin.get(f"/api/reservas/{reserva['id']}").status_code == 200  # el admin puede ver cualquiera
    assert admin.put(f"/api/reservas/{reserva['id']}/cancelar", json={}).status_code == 400  # exige motivo
    assert admin.put(f"/api/reservas/{reserva['id']}", json={"pasajeros": [p]}).status_code == 403
    r = admin.put(f"/api/reservas/{reserva['id']}/cancelar", json={"motivo": "Solicitud del titular"})
    assert r.status_code == 200
    assert cliente.get(f"/api/reservas/{reserva['id']}").json()["motivo_cancelacion"] == "Solicitud del titular"


def test_listar_y_filtrar_usuarios(admin, cliente):
    r = admin.get("/api/admin/usuarios", params={"rol": "cliente", "buscar": cliente.datos["correo"]})
    assert r.status_code == 200 and r.json()["total"] == 1
    assert "password_hash" not in r.json()["usuarios"][0]
    assert admin.get("/api/admin/usuarios", params={"rol": "x"}).status_code == 400


def test_desactivar_usuario_revoca_token_y_bloquea_login(admin, cliente, api):
    assert cliente.get("/api/usuarios/perfil").status_code == 200
    r = admin.patch(f"/api/admin/usuarios/{cliente.datos['id']}", json={"activo": False})
    assert r.status_code == 200 and r.json()["usuario"]["activo"] is False
    assert cliente.get("/api/usuarios/perfil").status_code in (401, 403)  # tokens revocados al desactivar
    login = api.post("/api/auth/login", json={"correo": cliente.datos["correo"], "password": cliente.datos["password"]})
    assert login.status_code == 403 and "desactivada" in login.json()["error"]
    admin.patch(f"/api/admin/usuarios/{cliente.datos['id']}", json={"activo": True})
    assert api.post("/api/auth/login", json={"correo": cliente.datos["correo"],
                                             "password": cliente.datos["password"]}).status_code == 200


def test_cambiar_rol_aplica_de_inmediato(admin, cliente):
    assert cliente.get("/api/admin/usuarios").status_code == 403
    assert admin.patch(f"/api/admin/usuarios/{cliente.datos['id']}", json={"rol": "admin"}).status_code == 200
    assert cliente.get("/api/admin/usuarios").status_code == 200  # el rol se lee de la BD, no del JWT
    assert admin.patch(f"/api/admin/usuarios/{cliente.datos['id']}", json={"rol": "cliente"}).status_code == 200
    assert cliente.get("/api/admin/usuarios").status_code == 403


def test_admin_no_puede_desactivarse_ni_quitarse_el_rol(admin):
    yo = next(u for u in admin.get("/api/admin/usuarios", params={"rol": "admin"}).json()["usuarios"]
              if u["correo"] == admin.datos["correo"])
    assert admin.patch(f"/api/admin/usuarios/{yo['id']}", json={"activo": False}).status_code == 409
    assert admin.patch(f"/api/admin/usuarios/{yo['id']}", json={"rol": "cliente"}).status_code == 409
    assert admin.patch("/api/admin/usuarios/99999999", json={"activo": False}).status_code == 404
    assert admin.patch(f"/api/admin/usuarios/{yo['id']}", json={}).status_code == 400


def test_no_se_desactiva_avion_con_vuelos_programados(admin, vuelo_pequeno, avion_pequeno):
    assert admin.patch(f"/api/admin/aviones/{avion_pequeno['id']}/estado", json={"activo": False}).status_code == 409


def test_no_se_edita_estructura_de_avion_con_vuelos(admin, vuelo_pequeno, avion_pequeno):
    r = admin.put(f"/api/admin/aviones/{avion_pequeno['id']}", json={"filas": 8})
    assert r.status_code == 409
    assert admin.put(f"/api/admin/aviones/{avion_pequeno['id']}", json={"modelo": "Nombre nuevo"}).status_code == 200


def test_editar_estructura_de_avion_sin_vuelos(admin, avion_pequeno):
    r = admin.put(f"/api/admin/aviones/{avion_pequeno['id']}", json={"filas": 8, "configuracion": "AB-CD"})
    assert r.status_code == 200 and r.json()["avion"]["capacidad"] == 32


def test_dashboard_con_todas_las_claves(admin):
    r = admin.get("/api/reportes/dashboard")
    assert r.status_code == 200
    j = r.json()
    assert set(j) == {"indicadores", "ocupacion_por_vuelo", "reservas_por_dia", "rutas_top"}
    assert set(j["indicadores"]) == {"vuelos_programados", "reservas_confirmadas", "pasajeros", "ingresos",
                                     "ocupacion_promedio", "usuarios_clientes"}
    assert len(j["ocupacion_por_vuelo"]) <= 10 and len(j["rutas_top"]) <= 5
    assert all({"codigo_vuelo", "fecha", "ruta", "ocupacion"} <= set(v) for v in j["ocupacion_por_vuelo"])
