from conftest import Sesion
from utilidades import correo_aleatorio, generar_cedula_valida


def _datos():
    return {"nombre": "Juan", "apellido": "Pérez", "cedula": generar_cedula_valida(), "telefono": "0991234567",
            "correo": correo_aleatorio(), "password": "Clave1234"}


def test_salud(api):
    r = api.get("/api/salud")
    assert r.status_code == 200
    assert r.json()["estado"] == "ok" and r.json()["bd"] == "ok"


def test_catalogo_de_servicios(api):
    r = api.get("/")
    assert r.status_code == 200 and len(r.json()["servicios"]) == 6


def test_registro_ok(api):
    r = api.post("/api/usuarios/registro", json=_datos())
    assert r.status_code == 201
    u = r.json()["usuario"]
    assert u["rol"] == "cliente" and "password_hash" not in u


def test_registro_no_permite_elegir_rol(api):
    r = api.post("/api/usuarios/registro", json={**_datos(), "rol": "admin"})
    assert r.status_code == 201 and r.json()["usuario"]["rol"] == "cliente"


def test_correo_duplicado_409(api):
    d = _datos()
    assert api.post("/api/usuarios/registro", json=d).status_code == 201
    r = api.post("/api/usuarios/registro", json={**d, "cedula": generar_cedula_valida()})
    assert r.status_code == 409 and "correo" in r.json()["error"]


def test_cedula_duplicada_409(api):
    d = _datos()
    assert api.post("/api/usuarios/registro", json=d).status_code == 201
    r = api.post("/api/usuarios/registro", json={**d, "correo": correo_aleatorio()})
    assert r.status_code == 409 and "cédula" in r.json()["error"]


def test_cedula_invalida_400_con_campos(api):
    r = api.post("/api/usuarios/registro", json={**_datos(), "cedula": "1234567890"})
    assert r.status_code == 400
    assert "cedula" in r.json()["campos"]


def test_varios_errores_a_la_vez(api):
    r = api.post("/api/usuarios/registro", json={"nombre": "1", "apellido": "", "cedula": "x", "telefono": "1",
                                                 "correo": "malo", "password": "abc"})
    assert r.status_code == 400
    assert set(r.json()["campos"]) == {"nombre", "apellido", "cedula", "telefono", "correo", "password"}


def test_contrasena_debil_400(api):
    r = api.post("/api/usuarios/registro", json={**_datos(), "password": "abcdefgh"})
    assert r.status_code == 400 and "password" in r.json()["campos"]


def test_login_ok(cliente, api):
    r = api.post("/api/auth/login", json={"correo": cliente.datos["correo"], "password": cliente.datos["password"]})
    assert r.status_code == 200
    j = r.json()
    assert j["token"] and j["usuario"]["rol"] == "cliente" and "expira" in j


def test_login_malo_401(cliente, api):
    r = api.post("/api/auth/login", json={"correo": cliente.datos["correo"], "password": "incorrecta1"})
    assert r.status_code == 401
    r2 = api.post("/api/auth/login", json={"correo": correo_aleatorio(), "password": "incorrecta1"})
    assert r2.status_code == 401 and r2.json()["error"] == r.json()["error"]


def test_perfil_sin_token_401(api):
    assert api.get("/api/usuarios/perfil").status_code == 401


def test_perfil_con_token_incluye_totales(cliente):
    r = cliente.get("/api/usuarios/perfil")
    assert r.status_code == 200
    assert r.json()["total_reservas"] == 0 and r.json()["reservas_activas"] == 0


def test_token_invalido_401(api):
    assert Sesion("token.falso.xxx").get("/api/usuarios/perfil").status_code == 401


def test_editar_perfil(cliente):
    r = cliente.put("/api/usuarios/perfil", json={"nombre": "Nuevo", "apellido": "Nombre", "telefono": "0987654321"})
    assert r.status_code == 200
    p = cliente.get("/api/usuarios/perfil").json()
    assert p["nombre"] == "Nuevo" and p["telefono"] == "0987654321"
    assert p["correo"] == cliente.datos["correo"]  # el correo no es editable


def test_editar_perfil_invalido_400(cliente):
    r = cliente.put("/api/usuarios/perfil", json={"nombre": "X", "apellido": "Ok", "telefono": "123"})
    assert r.status_code == 400 and {"nombre", "telefono"} <= set(r.json()["campos"])


def test_cambiar_password(cliente, api):
    nueva = "Nueva5678"
    r = cliente.put("/api/usuarios/password", json={"password_actual": cliente.datos["password"],
                                                    "password_nueva": nueva})
    assert r.status_code == 200
    viejo = api.post("/api/auth/login", json={"correo": cliente.datos["correo"],
                                              "password": cliente.datos["password"]})
    assert viejo.status_code == 401
    nuevo = api.post("/api/auth/login", json={"correo": cliente.datos["correo"], "password": nueva})
    assert nuevo.status_code == 200
    assert cliente.get("/api/usuarios/perfil").status_code == 200  # el token actual se conserva


def test_cambiar_password_actual_incorrecta_400(cliente):
    r = cliente.put("/api/usuarios/password", json={"password_actual": "equivocada1", "password_nueva": "Nueva5678"})
    assert r.status_code == 400 and "password_actual" in r.json()["campos"]


def test_cambiar_password_revoca_otros_tokens(cliente, api):
    otro = api.post("/api/auth/login", json={"correo": cliente.datos["correo"], "password": cliente.datos["password"]})
    sesion2 = Sesion(otro.json()["token"])
    assert sesion2.get("/api/usuarios/perfil").status_code == 200
    cliente.put("/api/usuarios/password", json={"password_actual": cliente.datos["password"],
                                                "password_nueva": "Nueva5678"})
    assert sesion2.get("/api/usuarios/perfil").status_code == 401


def test_logout_revoca_token(cliente):
    assert cliente.get("/api/usuarios/perfil").status_code == 200
    assert cliente.post("/api/auth/logout").status_code == 200
    assert cliente.get("/api/usuarios/perfil").status_code == 401
    assert cliente.post("/api/auth/logout").status_code == 401
