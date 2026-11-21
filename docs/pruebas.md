# Pruebas documentadas – AeroTech SOA

Sistema de reserva de vuelos: cliente Flutter ⇄ API Flask (6 servicios SOA) ⇄ PostgreSQL (Supabase).
API desplegada: https://aerotech-api-bbql.onrender.com · Repositorio: https://github.com/josephch28/aerotech-soa

Las pruebas se ejecutaron **dos veces** con los mismos casos: contra el backend local (`http://localhost:5000`) y contra el despliegue en Render (`API_URL=https://aerotech-api-bbql.onrender.com`). El resultado fue idéntico.

| Conjunto | Herramienta | Casos | Resultado | Evidencia |
|---|---|---|---|---|
| API (servicios, roles, validaciones, concurrencia) | pytest | 97 | 97 passed (local y Render; 17 min 48 s en Render) | `capturas/pytest_local.txt`, `capturas/pytest_render.txt` |
| Flujos de la app Flutter contra el backend real | flutter test | 14 | All tests passed | `capturas/flutter_test_todas.txt`, `capturas/flutter_test_render.txt` |
| Pruebas manuales de la app (navegador) | Flutter web | 22 | OK (capturas 00–33) | `capturas/` |
| Interoperabilidad (mismo endpoint, 3 clientes) | Flutter / Postman / pytest | 4 | OK (Postman pendiente de captura) | sección 4 |
| Concurrencia | pytest | 3 | OK | sección 5 |

Convenciones: **Rol** = quién llama (Anónimo, Cliente, Admin). Los casos con una ruta en «Entrada» repiten la misma prueba para varias rutas.

## 1. Pruebas automatizadas de la API (pytest, 97 casos)

Comandos:

```powershell
cd backend
.venv\Scripts\python -m pytest -v
$env:API_URL="https://aerotech-api-bbql.onrender.com"; .venv\Scripts\python -m pytest -v
```

| ID | Servicio | Rol | Caso | Entrada | Esperado | Obtenido | Evidencia |
|---|---|---|---|---|---|---|---|
| P01 | Aviones/Vuelos/Usuarios/Reportes (admin) | Cliente | cliente recibe 403 en get admin | `/api/admin/aviones` | HTTP 403 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P02 | Aviones/Vuelos/Usuarios/Reportes (admin) | Cliente | cliente recibe 403 en get admin | `/api/admin/vuelos` | HTTP 403 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P03 | Aviones/Vuelos/Usuarios/Reportes (admin) | Cliente | cliente recibe 403 en get admin | `/api/admin/reservas` | HTTP 403 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P04 | Aviones/Vuelos/Usuarios/Reportes (admin) | Cliente | cliente recibe 403 en get admin | `/api/admin/usuarios` | HTTP 403 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P05 | Aviones/Vuelos/Usuarios/Reportes (admin) | Cliente | cliente recibe 403 en get admin | `/api/admin/aviones/1/vista-previa` | HTTP 403 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P06 | Aviones/Vuelos/Usuarios/Reportes (admin) | Cliente | cliente recibe 403 en get admin | `/api/admin/vuelos/1/manifiesto` | HTTP 403 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P07 | Aviones/Vuelos/Usuarios/Reportes (admin) | Cliente | cliente recibe 403 en get admin | `/api/reportes/dashboard` | HTTP 403 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P08 | Aviones/Vuelos/Usuarios/Reportes (admin) | Cliente | cliente recibe 403 en escrituras admin | Ver `tests/test_admin.py` | HTTP 403 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P09 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | admin sin token 401 | Ver `tests/test_admin.py` | HTTP 401 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P10 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | crear avion configuracion invalida 400 | Ver `tests/test_admin.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P11 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | crear avion y vista previa | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P12 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | matricula duplicada 409 | Ver `tests/test_admin.py` | HTTP 409 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P13 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | crear vuelo genera asientos segun avion | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P14 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | crear vuelo a320 asientos por clase | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P15 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | origen igual destino 400 | Ver `tests/test_admin.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P16 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | llegada antes de salida 400 | Ver `tests/test_admin.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P17 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | validaciones de precio fecha y formato | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P18 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | solapamiento del mismo avion 409 | Ver `tests/test_admin.py` | HTTP 409 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P19 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | codigo y fecha duplicados 409 | Ver `tests/test_admin.py` | HTTP 409 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P20 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | editar precio no altera reservas existentes | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P21 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | cambiar avion con reservas 409 | Ver `tests/test_admin.py` | HTTP 409 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P22 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | cambiar avion sin reservas regenera asientos | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P23 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | cancelar vuelo cancela reservas | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P24 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | manifiesto | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P25 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | listado admin de vuelos con ocupacion e ingresos | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P26 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | admin ve todas las reservas y puede cancelar con motivo | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P27 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | listar y filtrar usuarios | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P28 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | desactivar usuario revoca token y bloquea login | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P29 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | cambiar rol aplica de inmediato | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P30 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | admin no puede desactivarse ni quitarse el rol | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P31 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | no se desactiva avion con vuelos programados | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P32 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | no se edita estructura de avion con vuelos | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P33 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | editar estructura de avion sin vuelos | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P34 | Aviones/Vuelos/Usuarios/Reportes (admin) | Admin / Cliente | dashboard con todas las claves | Ver `tests/test_admin.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P35 | Reservas | Cliente (8 hilos) | ocho usuarios reservan el mismo asiento | Ver `tests/test_concurrencia.py` | Un solo ganador, sin sobreventa | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P36 | Reservas | Cliente (8 hilos) | vuelo pequeno nunca sobrevende | Ver `tests/test_concurrencia.py` | Un solo ganador, sin sobreventa | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P37 | Reservas | Cliente (8 hilos) | edicion y cancelacion concurrentes son consistentes | Ver `tests/test_concurrencia.py` | Un solo ganador, sin sobreventa | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P38 | Reservas | Cliente | crear sin token 401 | Ver `tests/test_reservas.py` | HTTP 401 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P39 | Reservas | Cliente | crear ok ocupa asientos y baja disponibles | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P40 | Reservas | Cliente | asiento ocupado 409 con lista | Ver `tests/test_reservas.py` | HTTP 409 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P41 | Reservas | Cliente | asiento inexistente 400 | Ver `tests/test_reservas.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P42 | Reservas | Cliente | asientos repetidos 400 | Ver `tests/test_reservas.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P43 | Reservas | Cliente | diez pasajeros 400 | Ver `tests/test_reservas.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P44 | Reservas | Cliente | menor de 2 anos 400 | Ver `tests/test_reservas.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P45 | Reservas | Cliente | edad mayor a 110 400 | Ver `tests/test_reservas.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P46 | Reservas | Cliente | nino en salida de emergencia 400 | Ver `tests/test_reservas.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P47 | Reservas | Cliente | adulto en salida de emergencia ok | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P48 | Reservas | Cliente | sin adulto 400 | Ver `tests/test_reservas.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P49 | Reservas | Cliente | documento ya en el vuelo 409 | Ver `tests/test_reservas.py` | HTTP 409 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P50 | Reservas | Cliente | documento repetido en la misma reserva 400 | Ver `tests/test_reservas.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P51 | Reservas | Cliente | documento invalido 400 con campos | Ver `tests/test_reservas.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P52 | Reservas | Cliente | pasaporte valido ok | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P53 | Reservas | Cliente | mis reservas | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P54 | Reservas | Cliente | detalle reserva | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P55 | Reservas | Cliente | reserva de otro usuario 404 | Ver `tests/test_reservas.py` | HTTP 404 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P56 | Reservas | Cliente | editar aumentando cantidad | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P57 | Reservas | Cliente | editar cambiando asiento y pasajero | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P58 | Reservas | Cliente | editar disminuyendo libera asientos | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P59 | Reservas | Cliente | editar a asiento ocupado 409 y reserva intacta | Ver `tests/test_reservas.py` | HTTP 409 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P60 | Reservas | Cliente | editar con datos invalidos 400 | Ver `tests/test_reservas.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P61 | Reservas | Cliente | cancelar ok libera asientos | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P62 | Reservas | Cliente | cancelar dos veces 409 | Ver `tests/test_reservas.py` | HTTP 409 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P63 | Reservas | Cliente | editar cancelada 409 | Ver `tests/test_reservas.py` | HTTP 409 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P64 | Reservas | Cliente | documento reutilizable tras cancelar | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P65 | Reservas | Cliente | factura xml | Ver `tests/test_reservas.py` | HTTP 200, XML válido | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P66 | Reservas | Cliente | historial con tres eventos | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P67 | Reservas | Cliente | vuelo cancelado no admite reservas | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P68 | Reservas | Cliente | precio ejecutiva | Ver `tests/test_reservas.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P69 | Usuarios y Auth | Anónimo / Cliente | salud | Ver `tests/test_usuarios_auth.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P70 | Usuarios y Auth | Anónimo / Cliente | catalogo de servicios | Ver `tests/test_usuarios_auth.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P71 | Usuarios y Auth | Anónimo / Cliente | registro ok | Ver `tests/test_usuarios_auth.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P72 | Usuarios y Auth | Anónimo / Cliente | registro no permite elegir rol | Ver `tests/test_usuarios_auth.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P73 | Usuarios y Auth | Anónimo / Cliente | correo duplicado 409 | Ver `tests/test_usuarios_auth.py` | HTTP 409 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P74 | Usuarios y Auth | Anónimo / Cliente | cedula duplicada 409 | Ver `tests/test_usuarios_auth.py` | HTTP 409 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P75 | Usuarios y Auth | Anónimo / Cliente | cedula invalida 400 con campos | Ver `tests/test_usuarios_auth.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P76 | Usuarios y Auth | Anónimo / Cliente | varios errores a la vez | Ver `tests/test_usuarios_auth.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P77 | Usuarios y Auth | Anónimo / Cliente | contrasena debil 400 | Ver `tests/test_usuarios_auth.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P78 | Usuarios y Auth | Anónimo / Cliente | login ok | Ver `tests/test_usuarios_auth.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P79 | Usuarios y Auth | Anónimo / Cliente | login malo 401 | Ver `tests/test_usuarios_auth.py` | HTTP 401 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P80 | Usuarios y Auth | Anónimo / Cliente | perfil sin token 401 | Ver `tests/test_usuarios_auth.py` | HTTP 401 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P81 | Usuarios y Auth | Anónimo / Cliente | perfil con token incluye totales | Ver `tests/test_usuarios_auth.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P82 | Usuarios y Auth | Anónimo / Cliente | token invalido 401 | Ver `tests/test_usuarios_auth.py` | HTTP 401 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P83 | Usuarios y Auth | Anónimo / Cliente | editar perfil | Ver `tests/test_usuarios_auth.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P84 | Usuarios y Auth | Anónimo / Cliente | editar perfil invalido 400 | Ver `tests/test_usuarios_auth.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P85 | Usuarios y Auth | Anónimo / Cliente | cambiar password | Ver `tests/test_usuarios_auth.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P86 | Usuarios y Auth | Anónimo / Cliente | cambiar password actual incorrecta 400 | Ver `tests/test_usuarios_auth.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P87 | Usuarios y Auth | Anónimo / Cliente | cambiar password revoca otros tokens | Ver `tests/test_usuarios_auth.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P88 | Usuarios y Auth | Anónimo / Cliente | logout revoca token | Ver `tests/test_usuarios_auth.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P89 | Vuelos | Público | aeropuertos | Ver `tests/test_vuelos.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P90 | Vuelos | Público | listar vuelos | Ver `tests/test_vuelos.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P91 | Vuelos | Público | filtro origen destino fecha | Ver `tests/test_vuelos.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P92 | Vuelos | Público | filtro fecha sin resultados | Ver `tests/test_vuelos.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P93 | Vuelos | Público | filtro pasajeros | Ver `tests/test_vuelos.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P94 | Vuelos | Público | parametros invalidos 400 | Ver `tests/test_vuelos.py` | HTTP 400 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P95 | Vuelos | Público | vuelo inexistente 404 | Ver `tests/test_vuelos.py` | HTTP 404 | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P96 | Vuelos | Público | detalle vuelo | Ver `tests/test_vuelos.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
| P97 | Vuelos | Público | mapa de asientos | Ver `tests/test_vuelos.py` | HTTP 2xx y datos correctos | PASSED (local y Render) | `capturas/pytest_render.txt` |
## 2. Pruebas de flujo de la app Flutter (14 casos, `flutter test`)

Usan las pantallas reales y el backend real (sin mocks). Comando: `flutter test --dart-define=API_URL=https://aerotech-api-bbql.onrender.com`.

| ID | Servicio | Rol | Caso | Entrada | Esperado | Obtenido | Evidencia |
|---|---|---|---|---|---|---|---|
| F01 | Usuarios/Auth | Anónimo | Validador de cédula (módulo 10) coincide con el backend | Cédulas válidas e inválidas | Mismo resultado que el servidor | OK | `capturas/flutter_test_todas.txt` |
| F02 | Usuarios/Auth | Anónimo | Registro con cédula inválida | Cédula inválida | Muestra el error y no crea la cuenta | OK | ídem |
| F03 | Usuarios/Auth | Anónimo | Registro → inicio con sesión → Mi cuenta → cerrar sesión | Datos válidos | Vuelve al inicio | OK | ídem |
| F04 | Usuarios/Auth | Anónimo | Correo duplicado | Correo ya registrado | Error 409 bajo el campo correo | OK | ídem |
| F05 | Usuarios/Auth | Anónimo | Login con clave incorrecta | Clave errónea | SnackBar y permanece en Login | OK | ídem |
| F06 | Usuarios/Auth | Admin | Login admin → AdminHome → cerrar sesión | Credenciales admin | Panel admin y salida al inicio | OK | ídem |
| F07 | Usuarios/Auth | Cliente | Token guardado se valida con `/perfil` y se enruta por rol | Token en almacenamiento | Sesión restaurada con el rol del servidor | OK | ídem |
| F08 | Usuarios/Auth | Visitante | Token guardado vencido | Token vencido | Entra al inicio como visitante, sin errores | OK | ídem |
| F09 | Landing | Visitante | Página de inicio pública | Abrir la app sin sesión | Ofertas, destinos y botones de acceso visibles | OK | ídem |
| F10 | Vuelos/Reservas | Visitante→Cliente | Busca, elige asientos y llena pasajeros sin cuenta; el login se pide al final | Búsqueda y datos de pasajeros | La reserva continúa tras iniciar sesión | OK | `capturas/flutter_test_publico.txt` |
| F11 | Reservas | Cliente | Reservar, comprobante, editar a 3 asientos, historial y cancelar | Flujo completo | Totales con IVA, diferencia al editar, asientos liberados | OK | `capturas/flutter_test_todas.txt` |
| F12 | Reservas | Cliente | Conflicto 409: otro usuario toma el asiento | Asiento tomado antes de confirmar | Aviso, mapa actualizado y datos conservados | OK | ídem |
| F13 | Aviones/Vuelos/Reportes | Admin | Avión con vista previa → vuelo → reserva de cliente → manifiesto → cancelar vuelo → dashboard → desactivar cliente | Flujo completo | Cada paso refleja el cambio en el backend | OK | ídem |
| F14 | Usuarios | Cliente desactivado | Expulsión en la siguiente acción | Admin desactiva al cliente con sesión activa | Vuelve a Login y ve el motivo | OK | ídem |

## 3. Pruebas manuales de la app (Flutter web, navegador)

Ejecutadas contra Render con datos de demostración. Capturas en `capturas/`.

| ID | Servicio | Rol | Caso | Entrada | Esperado | Obtenido | Evidencia |
|---|---|---|---|---|---|---|---|
| M01 | Landing | Anónimo | Página de inicio pública con buscador y ofertas | Abrir `/#/inicio` | Se ve sin iniciar sesión | OK | `00_landing_publica.jpg` |
| M02 | Usuarios/Auth | Anónimo | Pantalla de login | Abrir login | Formulario correo y contraseña | OK | `15_app_login.jpg` |
| M03 | Usuarios/Auth | Anónimo | Registro con validaciones | Campos vacíos/inválidos | Errores por campo en español | OK | `16_app_registro_validaciones.jpg` |
| M04 | Vuelos | Anónimo | Búsqueda de vuelos | Origen, destino, fecha, pasajeros | Lista con precio y disponibilidad | OK | `17_cliente_busqueda.jpg` |
| M05 | Vuelos | Anónimo | Mapa de asientos por clase | Detalle de vuelo | Libres/ocupados/seleccionados | OK | `18_cliente_mapa_asientos.png` |
| M06 | Vuelos | Anónimo | Salidas de emergencia visibles | Mapa de asientos | Filas de salida marcadas | OK | `18b_cliente_mapa_salidas_emergencia.jpg` |
| M07 | Reservas | Anónimo | Datos de pasajeros | 2 pasajeros | Formulario por asiento | OK | `19_cliente_pasajeros.jpg` |
| M08 | Reservas | Visitante | Login tardío: el resumen pide iniciar sesión antes de confirmar | Resumen sin sesión | Banner y botón «Iniciar sesión para confirmar»; los datos se conservan | OK (verificado con la prueba F10; sin captura propia) | `capturas/flutter_test_publico.txt` |
| M09 | Reservas | Cliente | Resumen de cambios al editar una reserva | Agregar pasajero | Nuevo total, total anterior y diferencia | OK | `20_cliente_resumen.jpg` |
| M10 | Reservas | Cliente | Reserva actualizada con su código | Guardar cambios | Código y diferencia | OK | `21_cliente_exito.jpg` |
| M11 | Reservas | Cliente | Editar reserva: mapa con asientos actuales | Mapa de edición | Asientos actuales marcados | OK | `22_cliente_editar_mapa.jpg`, `23_cliente_editar_diferencia.jpg` |
| M12 | Reservas | Cliente | Mis reservas | Menú Mis reservas | Lista con estado | OK | `23b_cliente_mis_reservas.jpg` |
| M13 | Reservas | Cliente | Historial de eventos | Detalle de reserva | Creación/edición/cancelación | OK | `24_cliente_historial.jpg` |
| M14 | Reservas | Cliente | Cancelar reserva | Confirmar cancelación | Estado cancelada, asientos liberados | OK | `25_cliente_cancelar.jpg` |
| M15 | Reservas | Cliente | Comprobante XML | Descargar factura | XML con los datos de la reserva | OK | `26_comprobante_xml.jpg` |
| M16 | Reservas | Cliente | Conflicto 409 | Asiento tomado por otro | Aviso y mapa actualizado | OK | `27_conflicto_409.jpg` |
| M17 | Reportes | Admin | Dashboard | Abrir `/admin` | KPIs, ocupación, reservas por día, rutas top | OK | `28_admin_dashboard.jpg` |
| M18 | Vuelos | Admin | Gestión de vuelos | Listado con filtros | Ocupación e ingresos por vuelo | OK | `29_admin_vuelos.jpg` |
| M19 | Vuelos | Admin | Formulario de vuelo | Elegir avión | Asientos generados según el avión | OK | `30_admin_form_vuelo.jpg` |
| M20 | Aviones | Admin | Flota con vista previa | Configurar avión | Mapa de vista previa en vivo | OK | `31_admin_flota_vista_previa.jpg` |
| M21 | Vuelos | Admin | Manifiesto de pasajeros | Abrir manifiesto | Lista y mapa de ocupación | OK | `32_admin_manifiesto.jpg`, `32a_admin_manifiesto_mapa.jpg` |
| M22 | Usuarios | Admin | Gestión de usuarios | Buscar «aerotech» | Filtra; el admin no puede desactivarse | OK | `33_admin_usuarios.jpg` |

## 4. Interoperabilidad

El mismo servicio responde igual a tres clientes distintos (JSON por HTTPS):

| ID | Endpoint | Cliente | Esperado | Obtenido | Evidencia |
|---|---|---|---|---|---|
| I01 | `POST /api/auth/login`, `GET /api/vuelos` | App Flutter (web) | 200 + token / lista de vuelos | OK | capturas 15, 17 |
| I02 | Todos los endpoints (una colección por servicio) | Postman | Mismos códigos y cuerpos que Flutter | Pendiente de captura del usuario | `capturas/04…12` |
| I03 | Todos los endpoints | pytest (`requests`) | 97 casos OK | OK | `capturas/pytest_render.txt` |
| I04 | Factura XML de una reserva | Flutter / navegador / pytest | Mismo XML | OK | captura 26, caso P65 |

## 5. Concurrencia

| ID | Caso | Entrada | Esperado | Obtenido | Evidencia |
|---|---|---|---|---|---|
| C01 | 8 usuarios reservan el mismo asiento a la vez | 8 hilos, mismo asiento | 1×201 y 7×409 | 1×201 y 7×409 en Render (gunicorn 2×4) | caso P35 |
| C02 | Vuelo pequeño nunca se sobrevende | Más compradores que asientos | Reservas ≤ asientos | OK | caso P36 |
| C03 | Edición y cancelación simultáneas | Hilos mezclados | Estado final consistente | OK | caso P37 |

Mecanismo: `SELECT … FOR UPDATE` sobre el vuelo y `UPDATE asientos … WHERE estado='disponible'` (si no afecta filas → 409).

## 6. Evidencias que aporta el estudiante

Capturas que dependen de herramientas externas: 01 Supabase (tablas), 04–12 Postman (una por servicio y errores), 13–14 terminal de pytest, 34 panel de Render, 35 DevTools (Network) y la ejecución de la app en Windows. Listado en la bitácora de `PLAN_APE4.md`.
