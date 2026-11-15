"""Pruebas de concurrencia: nunca debe haber sobreventa de asientos."""
import threading
from concurrent.futures import ThreadPoolExecutor

from utilidades import cuerpo_reserva, pasajero


def _disparar(tareas):
    """Ejecuta las tareas a la vez (barrera) y devuelve sus respuestas."""
    barrera = threading.Barrier(len(tareas))

    def correr(tarea):
        barrera.wait()
        return tarea()

    with ThreadPoolExecutor(max_workers=len(tareas)) as pool:
        return list(pool.map(correr, tareas))


def test_ocho_usuarios_reservan_el_mismo_asiento(nuevo_cliente, api, vuelo_nuevo):
    usuarios = [nuevo_cliente() for _ in range(8)]
    cuerpos = [cuerpo_reserva(vuelo_nuevo, [pasajero("8A", fecha_vuelo=vuelo_nuevo["fecha"])]) for _ in usuarios]
    respuestas = _disparar([lambda u=u, c=c: u.post("/api/reservas/", json=c) for u, c in zip(usuarios, cuerpos)])
    codigos = sorted(r.status_code for r in respuestas)
    assert codigos == [201] + [409] * 7, codigos
    ganador = next(r for r in respuestas if r.status_code == 201).json()["reserva"]
    assert ganador["asientos"] == ["8A"]
    for r in respuestas:
        if r.status_code == 409:
            assert r.json()["asientos_no_disponibles"] == ["8A"]
    m = api.get(f"/api/vuelos/{vuelo_nuevo['id']}/asientos").json()
    assert m["resumen"]["ocupados"] == 1
    assert api.get(f"/api/vuelos/{vuelo_nuevo['id']}").json()["asientos_disponibles"] == 71


def test_vuelo_pequeno_nunca_sobrevende(nuevo_cliente, cliente, api, admin, vuelo_pequeno):
    f = vuelo_pequeno["fecha"]
    todos = [f"{fila}{col}" for fila in range(1, 6) for col in "AC"]
    previos, libres = todos[:7], todos[7:]                      # 7 reservados, quedan 3 libres
    r = cliente.post("/api/reservas/", json=cuerpo_reserva(
        vuelo_pequeno, [pasajero(a, fecha_vuelo=f) for a in previos]))
    assert r.status_code == 201, r.text
    assert api.get(f"/api/vuelos/{vuelo_pequeno['id']}").json()["asientos_disponibles"] == 3

    # 6 hilos: cada asiento libre lo piden 2 hilos; además uno pide un asiento ya ocupado
    pedidos = [libres[0], libres[0], libres[1], libres[1], libres[2], libres[2]]
    usuarios = [nuevo_cliente() for _ in pedidos]
    respuestas = _disparar([
        lambda u=u, a=a: u.post("/api/reservas/", json=cuerpo_reserva(vuelo_pequeno,
                                                                      [pasajero(a, fecha_vuelo=f)]))
        for u, a in zip(usuarios, pedidos)])
    estados = sorted(r.status_code for r in respuestas)
    assert estados == [201] * 3 + [409] * 3, estados

    asientos_vendidos = [a for r in respuestas if r.status_code == 201 for a in r.json()["reserva"]["asientos"]]
    assert sorted(asientos_vendidos) == sorted(libres)          # ningún asiento duplicado
    assert len(set(asientos_vendidos)) == len(asientos_vendidos)

    assert api.get(f"/api/vuelos/{vuelo_pequeno['id']}").json()["asientos_disponibles"] == 0
    m = api.get(f"/api/vuelos/{vuelo_pequeno['id']}/asientos").json()
    assert m["resumen"] == {"total": 10, "disponibles": 0, "ocupados": 10}

    # un asiento ya vendido sigue siendo rechazado, y el contador no baja de 0
    extra = nuevo_cliente().post("/api/reservas/", json=cuerpo_reserva(
        vuelo_pequeno, [pasajero(previos[0], fecha_vuelo=f)]))
    assert extra.status_code == 409
    assert api.get(f"/api/vuelos/{vuelo_pequeno['id']}").json()["asientos_disponibles"] == 0
    # el manifiesto muestra exactamente 10 pasajeros, uno por asiento
    man = admin.get(f"/api/admin/vuelos/{vuelo_pequeno['id']}/manifiesto").json()
    assert man["total"] == 10 and len({p["asiento"] for p in man["pasajeros"]}) == 10


def test_edicion_y_cancelacion_concurrentes_son_consistentes(nuevo_cliente, api, vuelo_nuevo):
    """Edita y cancela la misma reserva a la vez: el estado final debe ser coherente."""
    f = vuelo_nuevo["fecha"]
    dueno = nuevo_cliente()
    p1 = pasajero("9A", fecha_vuelo=f)
    r = dueno.post("/api/reservas/", json=cuerpo_reserva(vuelo_nuevo, [p1]))
    rid = r.json()["reserva"]["id"]
    nuevos = [p1, pasajero("9C", fecha_vuelo=f)]
    respuestas = _disparar([lambda: dueno.put(f"/api/reservas/{rid}", json={"pasajeros": nuevos}),
                            lambda: dueno.put(f"/api/reservas/{rid}/cancelar")])
    assert all(x.status_code in (200, 409) for x in respuestas)
    d = dueno.get(f"/api/reservas/{rid}").json()
    disp = api.get(f"/api/vuelos/{vuelo_nuevo['id']}").json()["asientos_disponibles"]
    if d["estado"] == "cancelada":
        assert disp == 72
    else:
        assert disp == 72 - d["cantidad_asientos"]
