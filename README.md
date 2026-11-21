# AeroTech – Reservas de vuelos (APE 4: Servicios web con SOA)

Sistema distribuido de reservas de vuelos con dos roles (**cliente** y **administrador**):

**Flutter** (Windows, web y Android) ⇄ HTTPS · JSON/XML ⇄ **Flask** (API REST en **Render**) ⇄ PostgreSQL con SSL ⇄ **Supabase**.

- **API en producción:** https://aerotech-api-bbql.onrender.com
- **Documentación interactiva (Swagger):** https://aerotech-api-bbql.onrender.com/docs
- **Estado del servicio:** https://aerotech-api-bbql.onrender.com/api/salud
- **Repositorio:** https://github.com/josephch28/aerotech-soa

> El plan gratuito de Render duerme el servicio tras 15 minutos sin uso: la primera petición puede tardar cerca de un minuto (la app muestra «Conectando con el servidor…»).

## Qué incluye

| Carpeta | Contenido |
|---|---|
| `backend/` | API Flask: 6 servicios (usuarios, auth, vuelos, reservas, admin, reportes), JWT y roles, lógica de asientos/precios/historial, esquema SQL, scripts de siembra, pruebas con pytest y colección Postman |
| `cliente_flutter/` | App Flutter: módulo cliente (búsqueda, **mapa de asientos que simula el avión**, reserva, edición, cancelación, comprobante XML) y módulo administrador (dashboard, vuelos, flota con vista previa, manifiesto, reservas, usuarios) |
| `docs/` | `arquitectura.md` (diagramas Mermaid), `contratos.md` (servicios, endpoints, reglas y principios SOA) |
| `capturas/` | Diagramas en PNG (`diagramas/`) y salidas de las pruebas (pytest local y Render, Flutter) |
| `render.yaml` | Blueprint de despliegue en Render |
| `PLAN_APE4.md` | Plan de ejecución y bitácora de cada fase |

Más detalle: [docs/arquitectura.md](docs/arquitectura.md) · [docs/contratos.md](docs/contratos.md).

## Flujo de compra (como en las aerolíneas reales)

La app abre en una **página de inicio pública** (inspirada en las de LATAM y Avianca) y **no exige iniciar sesión al empezar**:

1. **Inicio:** buscador en la portada (origen ⇄ destino, fecha y pasajeros), ofertas de vuelo, destinos más buscados y beneficios. La barra superior tiene «Iniciar sesión» y «Crear cuenta» como opción.
2. **Resultados:** lista pública de vuelos con orden por precio u hora y fechas alternativas si ese día no hay vuelos.
3. **Detalle del vuelo y mapa de asientos:** también públicos.
4. **Datos de los pasajeros y contacto:** el visitante los escribe sin cuenta.
5. **Resumen:** aquí aparece el aviso «Para confirmar tu reserva inicia sesión o crea tu cuenta». Al iniciar sesión (o registrarse) **se vuelve al resumen con los asientos y datos intactos**, y se confirma la reserva.
6. **Mis reservas:** al terminar se abre la cuenta del cliente. Editar, cancelar, comprobante XML e historial requieren sesión.

Los administradores entran por «Iniciar sesión» y van directo a su panel; no pueden reservar.

## Requisitos

- Python 3.12 o superior (probado con 3.14), `pip`.
- Flutter 3.x (para Windows desktop, Chrome/Edge o Android).
- Una base PostgreSQL en **Supabase** (use la cadena del **Session pooler**, puerto 5432; la conexión directa solo es IPv6 y Render no la soporta).
- Opcional: Node.js (solo para regenerar los diagramas con `@mermaid-js/mermaid-cli`).

## Configuración (`backend/.env`)

Copie `backend/.env.example` a `backend/.env` y complete los valores. **El `.env` no se versiona.**

| Variable | Descripción |
|---|---|
| `DATABASE_URL` | URI del Session pooler de Supabase terminada en `?sslmode=require` (sin corchetes alrededor de la contraseña; codifique `@`→`%40`, `#`→`%23`, `/`→`%2F`) |
| `JWT_SECRET`, `JWT_HORAS_EXPIRACION` | Secreto y duración de los tokens |
| `IVA`, `ZONA_HORARIA`, `HORAS_LIMITE_RESERVA`, `HORAS_LIMITE_CAMBIOS` | Reglas de negocio (15 %, America/Guayaquil, 1 h, 3 h) |
| `ADMIN_*` | Datos del administrador que crea `scripts/crear_admin.py` (nombre, apellido, cédula válida, teléfono, correo y contraseña) |
| `DEMO_CORREO`, `DEMO_PASSWORD` | Cliente demo de las semillas |

## Backend en local

```bash
cd backend
python -m venv .venv
source .venv/Scripts/activate        # PowerShell: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

python -m scripts.sembrar --reset    # reinicia las 9 tablas y siembra aeropuertos, aviones, vuelos, admin, cliente demo y reservas demo
python app.py                        # http://localhost:5000  (docs en /docs)
```

> `--reset` **borra todas las tablas** antes de sembrar: úselo solo en desarrollo.

### Entrar como administrador

El administrador lo crea `scripts/crear_admin.py` (la siembra lo ejecuta al final) con el correo `ADMIN_CORREO` y la contraseña `ADMIN_PASSWORD` de su `backend/.env`. El cliente demo usa `DEMO_CORREO` y `DEMO_PASSWORD`. Los clientes nuevos se registran desde la app; el rol `admin` solo se asigna desde el panel de administración o con el script.

## Pruebas

Con el backend corriendo en local:

```bash
cd backend
pytest -v                                                    # contra http://localhost:5000
API_URL=https://aerotech-api-bbql.onrender.com pytest -v     # contra Render
```

Las pruebas de administración usan `ADMIN_*` del `.env` local (misma base de datos). Incluyen concurrencia (8 usuarios sobre el mismo asiento). Postman: importe `backend/postman/AeroTech.postman_collection.json` y pegue la contraseña del admin en la variable `adminPassword`.

Flutter (usa el backend real):

```bash
cd cliente_flutter
flutter analyze
flutter test                                                         # contra localhost:5000
flutter test --dart-define=API_URL=https://aerotech-api-bbql.onrender.com
```

## App Flutter

```bash
cd cliente_flutter
flutter pub get

# contra el backend local
flutter run -d windows        # o: -d chrome
# contra Render
flutter run -d windows --dart-define=API_URL=https://aerotech-api-bbql.onrender.com
flutter run -d chrome  --dart-define=API_URL=https://aerotech-api-bbql.onrender.com
```

Sin `--dart-define`, la app usa `http://localhost:5000`. Android requiere un emulador o dispositivo (en el emulador use `http://10.0.2.2:5000` como `API_URL`).

## Despliegue en Render

1. Suba el repositorio a GitHub.
2. En Render: **New → Blueprint** y elija el repositorio (lee `render.yaml`).
3. Pegue `DATABASE_URL` (Session pooler de Supabase) y despliegue. El resto de variables ya vienen en `render.yaml`; `JWT_SECRET` se genera solo.
4. Compruebe `/api/salud` y `/docs`.

## Reglas principales

Cédula ecuatoriana (módulo 10), edades a la fecha del vuelo, asientos de salida de emergencia solo para mayores de 15 años, al menos un adulto por reserva, máximo 9 pasajeros, plazos de 1 h (reservar) y 3 h (editar o cancelar), un avión no puede solaparse con otro vuelo (45 min de rotación) y los asientos nunca se sobrevenden (transacciones con bloqueo por vuelo). La lista completa, con el código HTTP de cada violación, está en [docs/contratos.md](docs/contratos.md).
