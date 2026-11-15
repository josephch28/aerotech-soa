# Contratos de los servicios (SOA)

Contrato formal: **OpenAPI 3.0.3** en `backend/static/openapi.yaml`, visible en `/docs` (Swagger UI).
Catálogo de servicios (descubrimiento): `GET /`. URL de producción: `https://aerotech-api-bbql.onrender.com`.

Convenciones comunes a todos los servicios:

- **Formato:** JSON (`application/json; charset=utf-8`); el comprobante de la reserva es XML (`application/xml; charset=utf-8`).
- **Seguridad:** `Authorization: Bearer <JWT>` (HS256, 8 h). El **rol y el estado del usuario se leen de la BD en cada petición**, no del token. Contraseñas con `pbkdf2:sha256`.
- **Errores:** `{"error": "mensaje", "codigo": 4xx}`; los de validación añaden `"campos": {"campo": "mensaje"}` con **todos** los campos inválidos a la vez (claves como `pasajeros[1].numero_documento`).
- **Códigos HTTP:** `200` OK · `201` creado · `400` validación · `401` sin token / inválido / expirado / revocado · `403` sin permisos o cuenta desactivada · `404` no existe · `409` conflicto · `500` error interno (sin detalles).

## 1. Servicios, proveedores y consumidores

| # | Servicio | Prefijo | Proveedor (módulo) | Consumidores | Contrato | Formato | Seguridad | Rol |
|---|---|---|---|---|---|---|---|---|
| 1 | Usuarios | `/api/usuarios` | `servicios/usuarios.py` | App cliente, App admin, Postman, pytest | OpenAPI (tag *Usuarios*) | JSON | registro público; resto JWT | cliente / admin |
| 2 | Autenticación | `/api/auth` | `servicios/auth.py` | Todos | OpenAPI (tag *Autenticación*) | JSON | login público; logout JWT | todos |
| 3 | Vuelos | `/api/vuelos`, `/api/aeropuertos` | `servicios/vuelos.py` | App cliente, App admin (manifiesto), Postman, pytest | OpenAPI (tag *Vuelos*) | JSON | público (sin datos de pasajeros) | público |
| 4 | Reservas | `/api/reservas` | `servicios/reservas.py` | App cliente, App admin (ver y cancelar), Postman, pytest | OpenAPI (tag *Reservas*) | JSON y XML | JWT | cliente (admin: ver y cancelar) |
| 5 | Administración | `/api/admin` | `servicios/admin.py` | App admin, Postman, pytest | OpenAPI (tag *Administración*) | JSON | JWT + rol | **admin** |
| 6 | Reportes | `/api/reportes` | `servicios/reportes.py` | App admin, Postman, pytest | OpenAPI (tag *Reportes*) | JSON | JWT + rol | **admin** |

Servicios de sistema: `GET /` (catálogo), `GET /api/salud` (estado y BD; 503 si la BD falla) y `GET /docs` (Swagger UI).

## 2. Endpoints por servicio

Leyenda de errores: **V** = 400 validación · **A** = 401 · **P** = 403 permisos · **N** = 404 · **C** = 409 conflicto.

### 2.1 Usuarios — `/api/usuarios`

| Método y ruta | Auth / rol | Request | Response | Errores |
|---|---|---|---|---|
| `POST /api/usuarios/registro` | — | `{nombre, apellido, cedula, telefono, correo, password}` | `201 {mensaje, usuario}` (rol siempre `cliente`; nunca devuelve el hash) | V, C (correo o cédula ya registrados) |
| `GET /api/usuarios/perfil` | JWT | — | `200` usuario + `total_reservas`, `reservas_activas` | A |
| `PUT /api/usuarios/perfil` | JWT | `{nombre, apellido, telefono}` (correo y cédula no editables) | `200 {mensaje, usuario}` | V, A |
| `PUT /api/usuarios/password` | JWT | `{password_actual, password_nueva}` | `200 {mensaje}`; revoca los demás tokens | V (campo `password_actual` si es incorrecta), A |

Ejemplo — registro:

```json
POST /api/usuarios/registro
{"nombre": "Juan", "apellido": "Pérez", "cedula": "1710034065", "telefono": "0991234567",
 "correo": "juan@correo.com", "password": "Clave1234"}

201 {"mensaje": "Usuario registrado",
     "usuario": {"id": 7, "nombre": "Juan", "apellido": "Pérez", "cedula": "1710034065",
                 "telefono": "0991234567", "correo": "juan@correo.com", "rol": "cliente",
                 "activo": true, "fecha_registro": "2026-12-01T15:02:11+00:00"}}

400 {"error": "Datos inválidos", "codigo": 400,
     "campos": {"cedula": "Cédula ecuatoriana inválida", "password": "Mínimo 8 caracteres con letras y números"}}
409 {"error": "El correo ya está registrado", "codigo": 409}
```

### 2.2 Autenticación — `/api/auth`

| Método y ruta | Auth / rol | Request | Response | Errores |
|---|---|---|---|---|
| `POST /api/auth/login` | — | `{correo, password}` | `200 {mensaje, token, expira, usuario{id,nombre,apellido,correo,rol}}` | V, 401 `Credenciales incorrectas` (mismo mensaje si el correo no existe), P (`Cuenta desactivada. Contacte al administrador`) |
| `POST /api/auth/logout` | JWT | — | `200 {mensaje}`; revoca el token actual | A |

```json
POST /api/auth/login   {"correo": "juan@correo.com", "password": "Clave1234"}
200 {"mensaje": "Inicio de sesión exitoso", "token": "eyJhbGciOiJIUzI1NiIs...",
     "expira": "2026-12-01T23:02:11+00:00",
     "usuario": {"id": 7, "nombre": "Juan", "apellido": "Pérez", "correo": "juan@correo.com", "rol": "cliente"}}
```

### 2.3 Vuelos — `/api/vuelos` y `/api/aeropuertos` (público)

| Método y ruta | Auth / rol | Request | Response | Errores |
|---|---|---|---|---|
| `GET /api/aeropuertos` | — | — | `200 [{codigo, ciudad, nombre}]` (solo activos) | — |
| `GET /api/vuelos` | — | query: `origen`, `destino`, `fecha` (AAAA-MM-DD), `pasajeros` (1-9) | `200 {total, vuelos[]}`; solo `programado`, con salida ≥ ahora + 1 h y asientos libres ≥ pasajeros | V |
| `GET /api/vuelos/{id}` | — | — | `200` vuelo con ciudades, avión, duración, precios | N |
| `GET /api/vuelos/{id}/asientos` | — | — | `200 {vuelo, avion, resumen{total,disponibles,ocupados}, asientos[]}`; **no expone datos de pasajeros** | N |

```json
GET /api/vuelos?origen=UIO&destino=GYE&fecha=2026-12-21&pasajeros=2
200 {"total": 1, "vuelos": [{"id": 5, "codigo_vuelo": "AT101", "origen": "UIO", "destino": "GYE",
     "ciudad_origen": "Quito", "ciudad_destino": "Guayaquil", "fecha": "2026-12-21",
     "hora_salida": "09:45", "hora_llegada": "10:40", "duracion_minutos": 55,
     "precio": 89.0, "precio_ejecutiva": 189.0, "asientos_disponibles": 122,
     "estado": "programado", "modelo_avion": "Airbus A320", "matricula": "HC-ATA"}]}
```

### 2.4 Reservas — `/api/reservas` (JWT)

Cuerpo de crear/editar (en editar no se envía `vuelo_id`):

```json
{"vuelo_id": 5,
 "contacto": {"telefono": "0991234567", "correo": "juan@correo.com"},
 "pasajeros": [
   {"asiento": "12A", "nombres": "Juan", "apellidos": "Pérez", "tipo_documento": "cedula",
    "numero_documento": "1710034065", "fecha_nacimiento": "1990-05-10"},
   {"asiento": "12B", "nombres": "Ana", "apellidos": "Pérez", "tipo_documento": "pasaporte",
    "numero_documento": "AB123456", "fecha_nacimiento": "2016-03-02"}]}
```

| Método y ruta | Auth / rol | Request | Response | Errores |
|---|---|---|---|---|
| `POST /api/reservas/` | JWT | cuerpo anterior | `201 {mensaje, reserva{id, codigo_reserva, cantidad_asientos, asientos, subtotal, iva, total, estado}}` | V, A, N (vuelo), C (`asientos_no_disponibles`, documento duplicado, vuelo cancelado o fuera de plazo) |
| `GET /api/reservas/` | JWT | query `estado=confirmada\|cancelada` | `200 {total, reservas[]}` con vuelo y asientos | V, A |
| `GET /api/reservas/{id}` | JWT | — | `200` detalle: vuelo, pasajeros (asiento, clase, precio, edad), totales, contacto, `puede_editar`, `puede_cancelar` | A, N (también si es de otro usuario) |
| `PUT /api/reservas/{id}` | JWT (dueño; el admin no edita → P) | cuerpo anterior sin `vuelo_id` | `200 {mensaje, reserva, diferencia}` | V, A, P, N, C (cancelada, fuera de plazo de 3 h, asiento ocupado: la reserva queda intacta) |
| `PUT /api/reservas/{id}/cancelar` | JWT (dueño o admin) | admin: `{motivo}` (5-200 caracteres) | `200 {mensaje, motivo}` | V, A, N, C (ya cancelada, fuera de plazo de 3 h para el cliente) |
| `GET /api/reservas/{id}/factura` | JWT (dueño o admin) | — | `200` XML `<factura>` | A, N |
| `GET /api/reservas/{id}/historial` | JWT (dueño o admin) | — | `200 {total, eventos[{accion, fecha, usuario, detalle}]}` | A, N |

```json
201 {"mensaje": "Reserva creada",
     "reserva": {"id": 58, "codigo_reserva": "K7P2QX", "cantidad_asientos": 2, "asientos": ["12A", "12B"],
                 "subtotal": 178.0, "iva": 26.7, "total": 204.7, "estado": "confirmada"}}

409 {"error": "Asientos no disponibles: 12A", "codigo": 409, "asientos_no_disponibles": ["12A"]}
```

```xml
GET /api/reservas/58/factura
<?xml version='1.0' encoding='UTF-8'?>
<factura>
  <numero>P001-000058</numero>
  <codigo_reserva>K7P2QX</codigo_reserva>
  <fecha_emision>2026-12-01</fecha_emision>
  <cliente><nombre>Juan Pérez</nombre><cedula>1710034065</cedula><correo>juan@correo.com</correo></cliente>
  <vuelo><codigo>AT101</codigo><origen>Quito (UIO)</origen><destino>Guayaquil (GYE)</destino>
         <fecha>2026-12-21</fecha><hora_salida>09:45</hora_salida><avion>Airbus A320</avion></vuelo>
  <pasajeros>
    <pasajero><nombre>Juan Pérez</nombre><documento tipo="cedula">1710034065</documento>
              <asiento>12A</asiento><clase>economica</clase><precio>89.00</precio></pasajero>
  </pasajeros>
  <subtotal>178.00</subtotal><iva porcentaje="15">26.70</iva><total>204.70</total>
  <estado>confirmada</estado>
</factura>
```

### 2.5 Administración — `/api/admin` (JWT + rol admin; un cliente recibe 403 `No tiene permisos para esta operación`)

| Método y ruta | Request | Response | Errores |
|---|---|---|---|
| `GET /api/admin/aviones` | — | `200 [avión + capacidad + vuelos_futuros]` | A, P |
| `POST /api/admin/aviones` | `{modelo, matricula, configuracion, configuracion_ejecutiva?, filas, filas_ejecutiva, filas_salida[]}` | `201 {mensaje, avion}` | V, A, P, C (matrícula repetida) |
| `PUT /api/admin/aviones/{id}` | campos parciales | `200 {mensaje, avion}` | V, A, P, N, C (la estructura solo se cambia si el avión no tiene vuelos) |
| `PATCH /api/admin/aviones/{id}/estado` | `{activo: bool}` | `200 {mensaje, avion}` | V, A, P, N, C (no se desactiva con vuelos programados) |
| `GET /api/admin/aviones/{id}/vista-previa` | — | `200` mismo formato que el mapa de asientos, sin vuelo | A, P, N |
| `GET /api/admin/vuelos` | query: `estado`, `desde`, `hasta`, `origen`, `destino` | `200 {total, vuelos[]}` con `capacidad`, `ocupacion` (%) e `ingresos` | V, A, P |
| `POST /api/admin/vuelos` | `{codigo_vuelo, avion_id, origen, destino, fecha, hora_salida, hora_llegada, precio, precio_ejecutiva}` | `201 {mensaje, vuelo, asientos_generados}` | V, A, P, C (código y fecha repetidos; solapamiento del avión) |
| `PUT /api/admin/vuelos/{id}` | campos parciales | `200 {mensaje, vuelo}` | V, A, P, N, C (vuelo cancelado o ya salido; avión con reservas) |
| `PUT /api/admin/vuelos/{id}/cancelar` | `{motivo}` (5-200) | `200 {mensaje, reservas_afectadas}` | V, A, P, N, C (ya cancelado) |
| `GET /api/admin/vuelos/{id}/manifiesto` | — | `200 {vuelo, total, pasajeros[{asiento, clase, nombre, documento, edad, codigo_reserva, titular}]}` ordenado por asiento | A, P, N |
| `GET /api/admin/reservas` | query: `estado`, `vuelo_id`, `codigo`, `correo` | `200 {total, reservas[]}` | V, A, P |
| `GET /api/admin/usuarios` | query: `rol`, `activo`, `buscar` | `200 {total, usuarios[]}` (sin hash, con `total_reservas`) | V, A, P |
| `PATCH /api/admin/usuarios/{id}` | `{rol?, activo?}` | `200 {mensaje, usuario}`; al desactivar se revocan sus tokens | V, A, P, N, C (el admin no puede desactivarse ni quitarse el rol a sí mismo) |

```json
POST /api/admin/vuelos
{"codigo_vuelo": "AT301", "avion_id": 1, "origen": "UIO", "destino": "GYE", "fecha": "2026-12-30",
 "hora_salida": "09:45", "hora_llegada": "10:40", "precio": 89, "precio_ejecutiva": 189}
201 {"mensaje": "Vuelo creado", "vuelo": {"id": 31, "codigo_vuelo": "AT301", "...": "..."}, "asientos_generados": 174}
409 {"error": "El avión HC-ATA ya opera el vuelo AT101 en ese horario", "codigo": 409}
```

### 2.6 Reportes — `/api/reportes` (JWT + rol admin)

| Método y ruta | Request | Response | Errores |
|---|---|---|---|
| `GET /api/reportes/dashboard` | — | `200 {indicadores{vuelos_programados, reservas_confirmadas, pasajeros, ingresos, ocupacion_promedio, usuarios_clientes}, ocupacion_por_vuelo[próximos 10], reservas_por_dia[últimos 14 días], rutas_top[5]}` | A, P |

## 3. Reglas de negocio y código HTTP de cada violación

| Regla | Código | Mensaje / campo |
|---|---|---|
| Formato de nombre, cédula (módulo 10), pasaporte, teléfono (`09XXXXXXXX`), correo, contraseña (≥ 8 con letra y número), código de vuelo (`AT123`), matrícula (`HC-XXX`), configuración (`ABC-DEF`), fecha y hora | 400 | `campos` con el mensaje de cada campo |
| Correo o cédula ya registrados | 409 | `El correo ya está registrado` / `La cédula ya está registrada` |
| Credenciales incorrectas | 401 | `Credenciales incorrectas` |
| Cuenta desactivada (login o token) | 403 | `Cuenta desactivada. Contacte al administrador` |
| Token ausente, inválido, expirado o revocado | 401 | `Token requerido` / `Token inválido` / `Token expirado` / `Sesión cerrada o token revocado` |
| Endpoint de administrador llamado por un cliente | 403 | `No tiene permisos para esta operación` |
| Un administrador se desactiva o se quita el rol a sí mismo | 409 | |
| Reserva de otro usuario (consultar, editar, cancelar) | 404 | `Reserva no encontrada` (no revela que existe) |
| De 1 a 9 pasajeros por reserva | 400 | `pasajeros`: `Debe incluir de 1 a 9 pasajeros` |
| Asientos repetidos o inexistentes en el vuelo | 400 | `Asientos inexistentes: ...` / `pasajeros[i].asiento` |
| Asiento ya ocupado | 409 | `asientos_no_disponibles: [...]` |
| Documento repetido dentro de la reserva | 400 | `pasajeros[i].numero_documento` |
| Documento ya presente en otra reserva confirmada del mismo vuelo | 409 | `El pasajero con documento X ya tiene reserva en este vuelo` |
| Edad a la fecha del vuelo: mínimo 2 años y máximo 110 | 400 | `pasajeros[i].fecha_nacimiento` |
| Salida de emergencia: pasajero de 15 años o más | 400 | `Los asientos de salida de emergencia requieren pasajeros mayores de 15 años` |
| Al menos un adulto (18 años o más) por reserva | 400 | `Debe viajar al menos un adulto` |
| Reservar con menos de 1 h de anticipación, o en un vuelo cancelado | 409 | `Fuera de plazo...` / `El vuelo está cancelado` |
| Editar o cancelar (cliente) con menos de 3 h de anticipación | 409 | `Fuera de plazo...` |
| Editar una reserva cancelada, o cancelar dos veces | 409 | |
| Cancelación por el admin sin motivo válido (5-200 caracteres) | 400 | `motivo` |
| Origen igual al destino; aeropuerto inexistente o inactivo | 400 | `destino` / `origen` |
| Fecha pasada; hoy con salida a menos de 2 h | 400 | `fecha` / `hora_salida` |
| Llegada anterior a la salida; duración mayor a 5 h | 400 | `hora_llegada` |
| Precio fuera de 20-2000; precio ejecutiva menor que el económico | 400 | `precio` / `precio_ejecutiva` |
| Avión inexistente o inactivo | 400 | `avion_id` |
| Solapamiento del avión (45 min de rotación) | 409 | `El avión HC-XXX ya opera el vuelo ATxxx en ese horario` |
| Código de vuelo y fecha repetidos | 409 | `Ya existe el vuelo ... en esa fecha` |
| Cambiar el avión de un vuelo que tiene reservas | 409 | |
| Editar un vuelo cancelado o que ya salió | 409 | |
| Cancelar un vuelo ya cancelado | 409 | |
| Cambiar la estructura de un avión que ya tiene vuelos | 409 | |
| Desactivar un avión con vuelos programados | 409 | |
| Matrícula repetida | 409 | |
| Error interno del servidor | 500 | `Error interno del servidor` (sin detalles) |

## 4. Principios SOA aplicados

| Principio | Cómo se aplica en AeroTech |
|---|---|
| **Contrato estandarizado** | OpenAPI 3.0.3 (`/docs`): rutas, esquemas, códigos de error y ejemplos de los 6 servicios. |
| **Bajo acoplamiento** | El cliente solo conoce URLs y JSON; puede cambiar la implementación del servidor sin tocar la app. |
| **Abstracción** | La app Flutter no conoce Supabase ni PostgreSQL: solo habla con la API. |
| **Reutilización** | Los mismos servicios sirven a la app de cliente, la app de administrador, Postman y pytest. |
| **Autonomía** | Un Blueprint por servicio, con su responsabilidad y su prefijo propios. |
| **Sin estado** | La sesión viaja en el JWT; el servidor no guarda estado de conversación (los tokens se registran solo para poder revocarlos). |
| **Descubribilidad** | `GET /` devuelve el catálogo de servicios y `/docs` el contrato. |
| **Composición** | Crear una reserva compone vuelos + asientos + precios + historial en una sola transacción. |
| **Interoperabilidad** | Dart ⇄ Python ⇄ PostgreSQL por HTTP, JSON y XML. |
