import xml.etree.ElementTree as ET

import pytest

from utilidades import cuerpo_reserva, generar_cedula_valida, pasajero


@pytest.fixture
def P(vuelo_nuevo):
    """Constructor de pasajeros con edades calculadas a la fecha del vuelo de prueba."""
    return lambda asiento, **kw: pasajero(asiento, fecha_vuelo=vuelo_nuevo["fecha"], **kw)


def _estados(api, vuelo):
    m = api.get(f"/api/vuelos/{vuelo['id']}/asientos").json()
    return {a["codigo"]: a["estado"] for a in m["asientos"]}, m["resumen"]


def _disponibles(api, vuelo):
    return api.get(f"/api/vuelos/{vuelo['id']}").json()["asientos_disponibles"]


def _reservar(cliente, vuelo, pasajeros):
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo, pasajeros))
    assert r.status_code == 201, r.text
    return r.json()["reserva"]


def test_crear_sin_token_401(api, vuelo_nuevo, P):
    r = api.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [P("5A")]))
    assert r.status_code == 401


def test_crear_ok_ocupa_asientos_y_baja_disponibles(api, cliente, vuelo_nuevo, P):
    antes = _disponibles(api, vuelo_nuevo)
    reserva = _reservar(cliente, vuelo_nuevo, [P("5A"), P("5C", edad=10)])
    assert len(reserva["codigo_reserva"]) == 6 and reserva["estado"] == "confirmada"
    assert reserva["asientos"] == ["5A", "5C"] and reserva["cantidad_asientos"] == 2
    # 2 × $80 + IVA 15 % = 184.00
    assert (reserva["subtotal"], reserva["iva"], reserva["total"]) == (160.0, 24.0, 184.0)
    estados, resumen = _estados(api, vuelo_nuevo)
    assert estados["5A"] == estados["5C"] == "ocupado"
    assert _disponibles(api, vuelo_nuevo) == antes - 2 == resumen["disponibles"]


def test_asiento_ocupado_409_con_lista(cliente, otro_cliente, vuelo_nuevo, P):
    _reservar(cliente, vuelo_nuevo, [P("3A")])
    r = otro_cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [P("3A"), P("3C")]))
    assert r.status_code == 409
    assert r.json()["asientos_no_disponibles"] == ["3A"]


def test_asiento_inexistente_400(cliente, vuelo_nuevo, P):
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [P("9Z")]))
    assert r.status_code == 400
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [P("19A")]))  # fila inexistente en el ATR
    assert r.status_code == 400 and "inexistentes" in r.json()["error"]


def test_asientos_repetidos_400(cliente, vuelo_nuevo, P):
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [P("5A"), P("5A")]))
    assert r.status_code == 400 and "pasajeros[1].asiento" in r.json()["campos"]


def test_diez_pasajeros_400(cliente, vuelo_nuevo, P):
    pas = [P(f"{f}{c}") for f in (4, 5, 6) for c in "ACDF"][:10]
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, pas))
    assert r.status_code == 400 and "pasajeros" in r.json()["campos"]


def test_menor_de_2_anos_400(cliente, vuelo_nuevo, P):
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [P("5A"), P("5C", edad=1)]))
    assert r.status_code == 400 and "pasajeros[1].fecha_nacimiento" in r.json()["campos"]


def test_edad_mayor_a_110_400(cliente, vuelo_nuevo, P):
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [P("5A"), P("5C", edad=111)]))
    assert r.status_code == 400


def test_nino_en_salida_de_emergencia_400(cliente, vuelo_nuevo, P):
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [P("5A"), P("1A", edad=10)]))
    assert r.status_code == 400
    assert "salida de emergencia" in r.json()["campos"]["pasajeros[1].asiento"]


def test_adulto_en_salida_de_emergencia_ok(cliente, vuelo_nuevo, P):
    assert _reservar(cliente, vuelo_nuevo, [P("1A", edad=40)])["asientos"] == ["1A"]


def test_sin_adulto_400(cliente, vuelo_nuevo, P):
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [P("5A", edad=10), P("5C", edad=8)]))
    assert r.status_code == 400 and "adulto" in r.json()["error"]


def test_documento_ya_en_el_vuelo_409(cliente, otro_cliente, vuelo_nuevo, P):
    doc = generar_cedula_valida()
    _reservar(cliente, vuelo_nuevo, [P("5A", documento=doc)])
    r = otro_cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [P("6A", documento=doc)]))
    assert r.status_code == 409 and doc in r.json()["error"]


def test_documento_repetido_en_la_misma_reserva_400(cliente, vuelo_nuevo, P):
    doc = generar_cedula_valida()
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo,
                                                           [P("5A", documento=doc), P("5C", documento=doc)]))
    assert r.status_code == 400


def test_documento_invalido_400_con_campos(cliente, vuelo_nuevo, P):
    mal = P("5A")
    mal["numero_documento"] = "1234567890"  # cédula con dígito verificador incorrecto
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [mal]))
    assert r.status_code == 400 and "pasajeros[0].numero_documento" in r.json()["campos"]


def test_pasaporte_valido_ok(cliente, vuelo_nuevo, P):
    assert _reservar(cliente, vuelo_nuevo, [P("5A"), P("5C", tipo="pasaporte")])["cantidad_asientos"] == 2


def test_mis_reservas(cliente, otro_cliente, vuelo_nuevo, P):
    reserva = _reservar(cliente, vuelo_nuevo, [P("5A")])
    r = cliente.get("/api/reservas/")
    assert r.status_code == 200
    ids = [x["id"] for x in r.json()["reservas"]]
    assert reserva["id"] in ids
    mia = next(x for x in r.json()["reservas"] if x["id"] == reserva["id"])
    assert mia["asientos"] == ["5A"] and mia["vuelo"]["codigo_vuelo"] == vuelo_nuevo["codigo_vuelo"]
    assert otro_cliente.get("/api/reservas/").json()["total"] == 0
    assert cliente.get("/api/reservas/", params={"estado": "cancelada"}).json()["total"] == 0


def test_detalle_reserva(cliente, vuelo_nuevo, P):
    reserva = _reservar(cliente, vuelo_nuevo, [P("5A", edad=35), P("5C", edad=10)])
    r = cliente.get(f"/api/reservas/{reserva['id']}")
    assert r.status_code == 200
    d = r.json()
    assert d["codigo_reserva"] == reserva["codigo_reserva"] and len(d["pasajeros"]) == 2
    assert sorted(p["edad"] for p in d["pasajeros"]) == [10, 35]
    assert d["puede_editar"] is True and d["puede_cancelar"] is True
    assert {p["clase"] for p in d["pasajeros"]} == {"economica"}


def test_reserva_de_otro_usuario_404(cliente, otro_cliente, vuelo_nuevo, P):
    reserva = _reservar(cliente, vuelo_nuevo, [P("5A")])
    for ruta in ("", "/factura", "/historial"):
        assert otro_cliente.get(f"/api/reservas/{reserva['id']}{ruta}").status_code == 404
    assert otro_cliente.put(f"/api/reservas/{reserva['id']}/cancelar").status_code == 404
    assert otro_cliente.put(f"/api/reservas/{reserva['id']}",
                            json={"pasajeros": [P("6A")]}).status_code == 404


def test_editar_aumentando_cantidad(api, cliente, vuelo_nuevo, P):
    p1, p2 = P("5A"), P("5C")
    reserva = _reservar(cliente, vuelo_nuevo, [p1, p2])
    disp = _disponibles(api, vuelo_nuevo)
    p3 = P("5D")
    r = cliente.put(f"/api/reservas/{reserva['id']}", json={"pasajeros": [p1, p2, p3]})
    assert r.status_code == 200, r.text
    j = r.json()
    assert j["reserva"]["cantidad_asientos"] == 3 and j["reserva"]["asientos"] == ["5A", "5C", "5D"]
    assert j["diferencia"] == 92.0  # 80 + 15 % de IVA
    assert _disponibles(api, vuelo_nuevo) == disp - 1


def test_editar_cambiando_asiento_y_pasajero(api, cliente, vuelo_nuevo, P):
    p1, p2 = P("5A"), P("5C")
    reserva = _reservar(cliente, vuelo_nuevo, [p1, p2])
    disp = _disponibles(api, vuelo_nuevo)
    nuevo2 = P("6C")
    r = cliente.put(f"/api/reservas/{reserva['id']}", json={"pasajeros": [p1, nuevo2],
                                                           "contacto": {"telefono": "0911111111",
                                                                        "correo": "nuevo@correo.com"}})
    assert r.status_code == 200 and r.json()["diferencia"] == 0.0
    estados, _ = _estados(api, vuelo_nuevo)
    assert estados["5C"] == "disponible" and estados["6C"] == "ocupado"
    assert _disponibles(api, vuelo_nuevo) == disp
    d = cliente.get(f"/api/reservas/{reserva['id']}").json()
    assert d["contacto"] == {"telefono": "0911111111", "correo": "nuevo@correo.com"}


def test_editar_disminuyendo_libera_asientos(api, cliente, vuelo_nuevo, P):
    ps = [P("5A"), P("5C"), P("5D")]
    reserva = _reservar(cliente, vuelo_nuevo, ps)
    disp = _disponibles(api, vuelo_nuevo)
    r = cliente.put(f"/api/reservas/{reserva['id']}", json={"pasajeros": [ps[0]]})
    assert r.status_code == 200
    assert r.json()["reserva"]["cantidad_asientos"] == 1 and r.json()["diferencia"] == -184.0
    estados, _ = _estados(api, vuelo_nuevo)
    assert estados["5A"] == "ocupado" and estados["5C"] == estados["5D"] == "disponible"
    assert _disponibles(api, vuelo_nuevo) == disp + 2


def test_editar_a_asiento_ocupado_409_y_reserva_intacta(api, cliente, otro_cliente, vuelo_nuevo, P):
    p1, p2 = P("5A"), P("5C")
    reserva = _reservar(cliente, vuelo_nuevo, [p1, p2])
    _reservar(otro_cliente, vuelo_nuevo, [P("7A")])
    disp = _disponibles(api, vuelo_nuevo)
    r = cliente.put(f"/api/reservas/{reserva['id']}", json={"pasajeros": [p1, P("7A")]})
    assert r.status_code == 409 and r.json()["asientos_no_disponibles"] == ["7A"]
    d = cliente.get(f"/api/reservas/{reserva['id']}").json()
    assert sorted(p["asiento"] for p in d["pasajeros"]) == ["5A", "5C"] and d["cantidad_asientos"] == 2
    estados, _ = _estados(api, vuelo_nuevo)
    assert estados["5A"] == estados["5C"] == "ocupado"
    assert _disponibles(api, vuelo_nuevo) == disp


def test_editar_con_datos_invalidos_400(cliente, vuelo_nuevo, P):
    reserva = _reservar(cliente, vuelo_nuevo, [P("5A")])
    r = cliente.put(f"/api/reservas/{reserva['id']}", json={"pasajeros": []})
    assert r.status_code == 400


def test_cancelar_ok_libera_asientos(api, cliente, vuelo_nuevo, P):
    antes = _disponibles(api, vuelo_nuevo)
    reserva = _reservar(cliente, vuelo_nuevo, [P("5A"), P("5C")])
    r = cliente.put(f"/api/reservas/{reserva['id']}/cancelar")
    assert r.status_code == 200
    assert _disponibles(api, vuelo_nuevo) == antes
    d = cliente.get(f"/api/reservas/{reserva['id']}").json()
    assert d["estado"] == "cancelada" and d["motivo_cancelacion"] == "Cancelada por el cliente"
    assert d["puede_editar"] is False and d["puede_cancelar"] is False


def test_cancelar_dos_veces_409(cliente, vuelo_nuevo, P):
    reserva = _reservar(cliente, vuelo_nuevo, [P("5A")])
    assert cliente.put(f"/api/reservas/{reserva['id']}/cancelar").status_code == 200
    assert cliente.put(f"/api/reservas/{reserva['id']}/cancelar").status_code == 409


def test_editar_cancelada_409(cliente, vuelo_nuevo, P):
    p = P("5A")
    reserva = _reservar(cliente, vuelo_nuevo, [p])
    cliente.put(f"/api/reservas/{reserva['id']}/cancelar")
    assert cliente.put(f"/api/reservas/{reserva['id']}", json={"pasajeros": [p]}).status_code == 409


def test_documento_reutilizable_tras_cancelar(cliente, otro_cliente, vuelo_nuevo, P):
    doc = generar_cedula_valida()
    reserva = _reservar(cliente, vuelo_nuevo, [P("5A", documento=doc)])
    cliente.put(f"/api/reservas/{reserva['id']}/cancelar")
    assert _reservar(otro_cliente, vuelo_nuevo, [P("5A", documento=doc)])["asientos"] == ["5A"]


def test_factura_xml(cliente, vuelo_nuevo, P):
    reserva = _reservar(cliente, vuelo_nuevo, [P("5A"), P("2A", edad=12)])
    r = cliente.get(f"/api/reservas/{reserva['id']}/factura")
    assert r.status_code == 200 and "application/xml" in r.headers["Content-Type"]
    raiz = ET.fromstring(r.content)
    assert raiz.tag == "factura" and raiz.find("codigo_reserva").text == reserva["codigo_reserva"]
    assert raiz.find("total").text == "184.00" and raiz.find("iva").get("porcentaje") == "15"
    assert len(raiz.findall("pasajeros/pasajero")) == 2
    assert raiz.find("vuelo/origen").text == "Quito (UIO)"


def test_historial_con_tres_eventos(cliente, vuelo_nuevo, P):
    p1 = P("5A")
    reserva = _reservar(cliente, vuelo_nuevo, [p1])
    assert cliente.put(f"/api/reservas/{reserva['id']}", json={"pasajeros": [p1, P("5C")]}).status_code == 200
    assert cliente.put(f"/api/reservas/{reserva['id']}/cancelar").status_code == 200
    r = cliente.get(f"/api/reservas/{reserva['id']}/historial")
    assert r.status_code == 200
    eventos = r.json()["eventos"]
    assert [e["accion"] for e in eventos] == ["creada", "modificada", "cancelada"]
    assert eventos[1]["detalle"]["antes"]["asientos"] == ["5A"]
    assert eventos[1]["detalle"]["despues"]["asientos"] == ["5A", "5C"]


def test_vuelo_cancelado_no_admite_reservas(admin, cliente, vuelo_nuevo, P):
    assert admin.put(f"/api/admin/vuelos/{vuelo_nuevo['id']}/cancelar", json={"motivo": "Prueba automática"}).status_code == 200
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [P("5A")]))
    assert r.status_code == 409


def test_precio_ejecutiva(cliente, fabrica_vuelos, admin):
    avion_a320 = next(a for a in admin.get("/api/admin/aviones").json() if a["matricula"] == "HC-ATA")
    vuelo = fabrica_vuelos(avion_a320["id"], precio=80, precio_ejecutiva=150)
    p = [pasajero("1A", fecha_vuelo=vuelo["fecha"]), pasajero("10A", fecha_vuelo=vuelo["fecha"])]
    reserva = _reservar(cliente, vuelo, p)
    assert reserva["subtotal"] == 230.0 and reserva["iva"] == 34.5 and reserva["total"] == 264.5
