from utilidades import cuerpo_reserva, pasajero


def test_aeropuertos(api):
    r = api.get("/api/aeropuertos")
    assert r.status_code == 200
    codigos = {a["codigo"] for a in r.json()}
    assert {"UIO", "GYE", "CUE", "MEC", "LOH", "GPS", "ESM", "OCC"} <= codigos


def test_listar_vuelos(api):
    r = api.get("/api/vuelos")
    assert r.status_code == 200
    assert r.json()["total"] == len(r.json()["vuelos"]) > 0


def test_filtro_origen_destino_fecha(api, vuelo_nuevo):
    r = api.get("/api/vuelos", params={"origen": "UIO", "destino": "GYE", "fecha": vuelo_nuevo["fecha"]})
    assert r.status_code == 200
    ids = [v["id"] for v in r.json()["vuelos"]]
    assert vuelo_nuevo["id"] in ids
    assert all(v["origen"] == "UIO" and v["destino"] == "GYE" and v["fecha"] == vuelo_nuevo["fecha"]
               for v in r.json()["vuelos"])
    v = next(v for v in r.json()["vuelos"] if v["id"] == vuelo_nuevo["id"])
    assert v["duracion_minutos"] == 60 and v["modelo_avion"] == "ATR 72-600"
    assert v["ciudad_origen"] == "Quito" and v["precio_ejecutiva"] >= v["precio"]


def test_filtro_fecha_sin_resultados(api):
    r = api.get("/api/vuelos", params={"origen": "UIO", "destino": "GYE", "fecha": "2030-01-01"})
    assert r.status_code == 200 and r.json()["total"] == 0


def test_filtro_pasajeros(api, cliente, vuelo_pequeno):
    p = [pasajero("1A", fecha_vuelo=vuelo_pequeno["fecha"]), pasajero("1C", fecha_vuelo=vuelo_pequeno["fecha"])]
    assert cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_pequeno, p)).status_code == 201
    base = {"origen": "UIO", "destino": "GYE", "fecha": vuelo_pequeno["fecha"]}
    quedan8 = [v["id"] for v in api.get("/api/vuelos", params={**base, "pasajeros": 8}).json()["vuelos"]]
    quedan9 = [v["id"] for v in api.get("/api/vuelos", params={**base, "pasajeros": 9}).json()["vuelos"]]
    assert vuelo_pequeno["id"] in quedan8 and vuelo_pequeno["id"] not in quedan9


def test_parametros_invalidos_400(api):
    assert api.get("/api/vuelos", params={"fecha": "21-12-2026"}).status_code == 400
    assert api.get("/api/vuelos", params={"pasajeros": 0}).status_code == 400
    assert api.get("/api/vuelos", params={"pasajeros": "x"}).status_code == 400
    assert api.get("/api/vuelos", params={"origen": "12"}).status_code == 400


def test_vuelo_inexistente_404(api):
    assert api.get("/api/vuelos/99999999").status_code == 404
    assert api.get("/api/vuelos/99999999/asientos").status_code == 404


def test_detalle_vuelo(api, vuelo_nuevo):
    r = api.get(f"/api/vuelos/{vuelo_nuevo['id']}")
    assert r.status_code == 200 and r.json()["codigo_vuelo"] == vuelo_nuevo["codigo_vuelo"]


def test_mapa_de_asientos(api, vuelo_nuevo):
    r = api.get(f"/api/vuelos/{vuelo_nuevo['id']}/asientos")
    assert r.status_code == 200
    m = r.json()
    assert m["resumen"]["total"] == len(m["asientos"]) == 72
    assert m["resumen"]["disponibles"] + m["resumen"]["ocupados"] == m["resumen"]["total"]
    assert m["avion"]["matricula"] == "HC-ATC" and m["avion"]["filas_salida"] == [1, 18]
    salida = {a["fila"] for a in m["asientos"] if a["salida_emergencia"]}
    assert salida == {1, 18}
    assert all("pasajero" not in a for a in m["asientos"])  # no expone datos de pasajeros
