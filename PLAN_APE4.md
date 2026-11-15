# PLAN DE EJECUCIÓN – APE 4: Servicios web con SOA
# Sistema distribuido de reservas de vuelos **"AeroTech"** (versión extendida con roles)

> **Para el modelo que ejecute este plan (léelo completo antes de empezar):**
> - Sigue las fases EN ORDEN. No avances sin cumplir el **✅ Criterio de aceptación** de la fase.
> - NO cambies el stack ni los nombres de tablas/campos/endpoints definidos aquí.
> - Todo texto visible (UI, mensajes de error, comentarios de código) va en **español**.
> - Entorno: **Windows 11**, raíz `C:\SEXTO SEMESTRE\DISTRIBUIDAS\APE4` (tiene espacios: usa comillas).
>   Instalado: Python 3.14, Flutter 3.47 (devices: `windows`, `chrome`, `edge`), git, node, gh.
>   **No hay emulador Android**: la app se prueba en **Windows desktop** y **Chrome**.
> - El informe NO es parte de este plan (luego se usará la skill `informe-ape`); la Fase 11 deja listas
>   las capturas y la documentación que ese informe necesita.
> - Modelo sugerido: Haiku/Sonnet sirve para todo; usa **Sonnet** como mínimo en las Fases 3 y 7
>   (lógica transaccional de asientos y mapa del avión).

---

## 0. Visión general

### 0.1 Base obligatoria (guía APE4 + diapositivas 62-63)
- Cliente **Flutter** ⇄ HTTP/HTTPS + JSON (y XML) ⇄ Backend **Flask** (API REST, desplegado en **Render**) ⇄ PostgreSQL + SSL ⇄ **Supabase**.
- Servicios mínimos: registro de usuarios, autenticación, consulta de vuelos, reserva de vuelos, gestión de reservas.
- Tablas base de la diapositiva: `usuarios`, `vuelos`, `reservas`, `tokens` (se conservan sus campos y se **amplían**).
- Seguridad: **JWT** + contraseñas con hash SHA-256 (werkzeug `pbkdf2:sha256`). Confiabilidad: transacciones + bloqueos para evitar sobreventa.

### 0.2 Extensiones de esta versión
1. **Roles**: `admin` y `cliente` (el rol se lee SIEMPRE de la BD, no del JWT, para que un cambio de rol aplique al instante).
2. **Administrador**: gestiona **flota de aviones**, **crea/edita/cancela vuelos** (los asientos se generan automáticamente según el avión), ve **todas las reservas**, ve el **manifiesto de pasajeros** de un vuelo, **gestiona usuarios** (activar/desactivar, cambiar rol) y tiene un **dashboard** con indicadores.
3. **Cliente**: busca vuelos, ve un **mapa de asientos que simula el avión real** (nariz, alas, cola, pasillo, clase ejecutiva/económica, filas de salida de emergencia), selecciona asientos, ingresa **datos de cada pasajero**, reserva, **edita la reserva** (cambiar asientos, pasajeros y **cantidad de asientos**), **cancela**, descarga **comprobante XML** y ve el **historial** de cambios.
4. **Validaciones completas** en backend (fuente de verdad) y replicadas en Flutter (UX): cédula ecuatoriana (módulo 10), teléfono, edades, salida de emergencia, plazos, solapamiento de aviones, documentos duplicados, etc.
5. **Auditoría**: tabla `historial_reservas` (creada / modificada / cancelada).

### 0.3 Servicios SOA (cada uno es un Blueprint Flask independiente)

| # | Servicio | Prefijo | Consumidor |
|---|---|---|---|
| 1 | Usuarios | `/api/usuarios` | cliente, admin |
| 2 | Autenticación | `/api/auth` | todos |
| 3 | Vuelos (consulta, aeropuertos, mapa de asientos) | `/api/vuelos`, `/api/aeropuertos` | público |
| 4 | Reservas | `/api/reservas` | cliente (y admin para cancelar) |
| 5 | Administración (flota, vuelos, usuarios, reservas) | `/api/admin` | solo admin |
| 6 | Reportes (dashboard) | `/api/reportes` | solo admin |

---

## 1. Estructura final del proyecto

```
APE4/
├── PLAN_APE4.md
├── README.md
├── .gitignore
├── render.yaml
├── docs/
│   ├── arquitectura.md            (diagramas Mermaid)
│   ├── *.mmd                      (cada diagrama por separado)
│   ├── contratos.md               (servicios, proveedores, consumidores, contratos)
│   └── pruebas.md                 (casos de prueba y resultados)
├── capturas/                      (evidencias PNG/TXT para el informe)
│   └── diagramas/
├── backend/
│   ├── app.py
│   ├── config.py
│   ├── db.py
│   ├── errores.py
│   ├── seguridad.py               (hash, JWT, @token_requerido, @rol_requerido)
│   ├── validaciones.py            (todas las reglas de validación reutilizables)
│   ├── logica/
│   │   ├── __init__.py
│   │   ├── asientos.py            (generar, ocupar, liberar, recontar)
│   │   ├── precios.py             (subtotal, IVA, total)
│   │   └── historial.py           (registrar eventos)
│   ├── servicios/
│   │   ├── __init__.py
│   │   ├── usuarios.py
│   │   ├── auth.py
│   │   ├── vuelos.py
│   │   ├── reservas.py
│   │   ├── admin.py
│   │   └── reportes.py
│   ├── scripts/
│   │   ├── __init__.py
│   │   ├── aplicar_esquema.py     (ejecuta sql/schema.sql)
│   │   ├── sembrar.py             (aeropuertos, aviones, vuelos, asientos, reservas demo)
│   │   └── crear_admin.py         (crea/actualiza el admin desde .env)
│   ├── sql/schema.sql
│   ├── static/openapi.yaml
│   ├── tests/
│   │   ├── conftest.py
│   │   ├── utilidades.py          (generar cédulas válidas, correos aleatorios)
│   │   └── test_*.py
│   ├── postman/AeroTech.postman_collection.json
│   ├── requirements.txt
│   ├── .env.example
│   └── .env                       (NO se sube a git)
└── cliente_flutter/               (creado con `flutter create`)
```

---

## 2. Modelo de datos

### 2.1 Diagrama lógico (9 tablas)
```
aeropuertos 1─N vuelos (origen/destino)
aviones     1─N vuelos
usuarios    1─N vuelos (creado_por, admin)
usuarios    1─N reservas
usuarios    1─N tokens
vuelos      1─N asientos
vuelos      1─N reservas
reservas    1─N pasajeros
reservas    1─N asientos (asientos.reserva_id, mientras están ocupados)
asientos    1─N pasajeros (histórico)
reservas    1─N historial_reservas
```

### 2.2 `backend/sql/schema.sql` (usar tal cual)
```sql
-- Reinicio completo (solo para desarrollo): el script se puede re-ejecutar
DROP TABLE IF EXISTS historial_reservas, pasajeros, asientos, reservas, vuelos,
                     aviones, aeropuertos, tokens, usuarios CASCADE;

CREATE TABLE usuarios (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(60) NOT NULL,
  apellido VARCHAR(60) NOT NULL,
  cedula CHAR(10) NOT NULL UNIQUE,
  telefono CHAR(10) NOT NULL,
  correo VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  rol VARCHAR(10) NOT NULL DEFAULT 'cliente' CHECK (rol IN ('admin','cliente')),
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tokens (
  id SERIAL PRIMARY KEY,
  usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  expiracion TIMESTAMPTZ NOT NULL,
  estado VARCHAR(10) NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo','revocado'))
);

CREATE TABLE aeropuertos (
  codigo CHAR(3) PRIMARY KEY,               -- IATA: UIO, GYE...
  ciudad VARCHAR(60) NOT NULL,
  nombre VARCHAR(120) NOT NULL,
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE aviones (
  id SERIAL PRIMARY KEY,
  modelo VARCHAR(60) NOT NULL,               -- "Airbus A320"
  matricula VARCHAR(10) NOT NULL UNIQUE,     -- "HC-ATA"
  configuracion VARCHAR(10) NOT NULL,        -- económica, grupos separados por pasillo: "ABC-DEF"
  configuracion_ejecutiva VARCHAR(10),       -- ejecutiva: "AC-DF" (NULL = igual a configuracion)
  filas INT NOT NULL CHECK (filas BETWEEN 5 AND 60),
  filas_ejecutiva INT NOT NULL DEFAULT 0 CHECK (filas_ejecutiva >= 0),
  filas_salida INT[] NOT NULL DEFAULT '{}',  -- filas de salida de emergencia: {12,13}
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (filas_ejecutiva < filas)
);

CREATE TABLE vuelos (
  id SERIAL PRIMARY KEY,
  codigo_vuelo VARCHAR(7) NOT NULL,          -- "AT1234"
  avion_id INT NOT NULL REFERENCES aviones(id),
  origen CHAR(3) NOT NULL REFERENCES aeropuertos(codigo),
  destino CHAR(3) NOT NULL REFERENCES aeropuertos(codigo),
  fecha DATE NOT NULL,
  hora_salida TIME NOT NULL,
  hora_llegada TIME NOT NULL,
  precio NUMERIC(10,2) NOT NULL CHECK (precio > 0),             -- económica
  precio_ejecutiva NUMERIC(10,2) NOT NULL,
  asientos_disponibles INT NOT NULL DEFAULT 0 CHECK (asientos_disponibles >= 0),
  estado VARCHAR(12) NOT NULL DEFAULT 'programado' CHECK (estado IN ('programado','cancelado')),
  creado_por INT REFERENCES usuarios(id),
  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (origen <> destino),
  CHECK (hora_llegada > hora_salida),
  CHECK (precio_ejecutiva >= precio),
  UNIQUE (codigo_vuelo, fecha)
);

CREATE TABLE reservas (
  id SERIAL PRIMARY KEY,
  codigo_reserva CHAR(6) NOT NULL UNIQUE,    -- localizador tipo "K7P2QX"
  usuario_id INT NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  vuelo_id INT NOT NULL REFERENCES vuelos(id),
  cantidad_asientos INT NOT NULL CHECK (cantidad_asientos BETWEEN 1 AND 9),
  subtotal NUMERIC(10,2) NOT NULL,
  iva NUMERIC(10,2) NOT NULL,
  total NUMERIC(10,2) NOT NULL,
  estado VARCHAR(12) NOT NULL DEFAULT 'confirmada' CHECK (estado IN ('confirmada','cancelada')),
  telefono_contacto CHAR(10) NOT NULL,
  correo_contacto VARCHAR(150) NOT NULL,
  motivo_cancelacion VARCHAR(200),
  fecha_reserva TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  fecha_modificacion TIMESTAMPTZ
);

CREATE TABLE asientos (
  id SERIAL PRIMARY KEY,
  vuelo_id INT NOT NULL REFERENCES vuelos(id) ON DELETE CASCADE,
  codigo VARCHAR(4) NOT NULL,                -- "12A"
  fila INT NOT NULL,
  columna CHAR(1) NOT NULL,
  clase VARCHAR(10) NOT NULL CHECK (clase IN ('ejecutiva','economica')),
  salida_emergencia BOOLEAN NOT NULL DEFAULT FALSE,
  estado VARCHAR(12) NOT NULL DEFAULT 'disponible' CHECK (estado IN ('disponible','ocupado')),
  reserva_id INT REFERENCES reservas(id) ON DELETE SET NULL,
  UNIQUE (vuelo_id, codigo),
  CHECK ((estado = 'ocupado') = (reserva_id IS NOT NULL))
);

CREATE TABLE pasajeros (
  id SERIAL PRIMARY KEY,
  reserva_id INT NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
  asiento_id INT NOT NULL REFERENCES asientos(id),
  nombres VARCHAR(60) NOT NULL,
  apellidos VARCHAR(60) NOT NULL,
  tipo_documento VARCHAR(10) NOT NULL CHECK (tipo_documento IN ('cedula','pasaporte')),
  numero_documento VARCHAR(15) NOT NULL,
  fecha_nacimiento DATE NOT NULL,
  precio NUMERIC(10,2) NOT NULL,             -- precio del asiento al momento de reservar
  UNIQUE (reserva_id, numero_documento)
);

CREATE TABLE historial_reservas (
  id SERIAL PRIMARY KEY,
  reserva_id INT NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
  usuario_id INT REFERENCES usuarios(id),    -- quién hizo el cambio
  accion VARCHAR(12) NOT NULL CHECK (accion IN ('creada','modificada','cancelada')),
  detalle JSONB,
  fecha TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_vuelos_busqueda ON vuelos(origen, destino, fecha);
CREATE INDEX idx_asientos_vuelo ON asientos(vuelo_id, estado);
CREATE INDEX idx_reservas_usuario ON reservas(usuario_id);
CREATE INDEX idx_reservas_vuelo ON reservas(vuelo_id);
CREATE INDEX idx_pasajeros_doc ON pasajeros(numero_documento);
CREATE INDEX idx_tokens_token ON tokens(token);
```

---

## 3. Reglas de negocio y validaciones (fuente única de verdad)

> Implementar TODAS en `backend/validaciones.py` / lógica de servicios, y replicarlas en
> `cliente_flutter/lib/utils/validadores.dart`. Los errores de validación devuelven **400** con
> `{"error": "Datos inválidos", "codigo": 400, "campos": {"campo": "mensaje"}}`
> (todos los campos con error a la vez, no solo el primero).

### 3.1 Formatos
| Dato | Regla | Mensaje |
|---|---|---|
| nombre / apellido / nombres / apellidos | `^[A-Za-zÁÉÍÓÚáéíóúÑñÜü' ]{2,60}$`, se aplica `strip()` y se colapsan espacios | "Solo letras y espacios (2-60 caracteres)" |
| cédula | 10 dígitos + **algoritmo módulo 10** (ver 3.2) | "Cédula ecuatoriana inválida" |
| pasaporte | `^[A-Z0-9]{6,15}$` (convertir a mayúsculas) | "Pasaporte inválido (6-15 letras/números)" |
| teléfono | `^09\d{8}$` | "Teléfono celular inválido (09XXXXXXXX)" |
| correo | `^[\w.+-]+@[\w-]+(\.[\w-]+)+$`, se guarda en minúsculas y sin espacios | "Correo inválido" |
| contraseña | ≥ 8 caracteres, al menos una letra y un número | "Mínimo 8 caracteres con letras y números" |
| código de vuelo | `^[A-Z]{2}\d{3,4}$` | "Formato: 2 letras y 3-4 números (AT123)" |
| matrícula | `^HC-[A-Z0-9]{3,4}$` | "Formato: HC-XXX" |
| configuración de avión | `^[A-K]{1,4}(-[A-K]{1,4}){1,2}$`, letras sin repetir, máx. 10 asientos por fila | "Configuración inválida (ej. ABC-DEF)" |
| fecha | `YYYY-MM-DD`; hora `HH:MM` | "Formato de fecha/hora inválido" |

### 3.2 Cédula ecuatoriana (módulo 10)
```python
def validar_cedula(c: str) -> bool:
    if not re.fullmatch(r"\d{10}", c or ""): return False
    provincia, tercero = int(c[:2]), int(c[2])
    if not (1 <= provincia <= 24 or provincia == 30) or tercero >= 6: return False
    suma = 0
    for i, coef in enumerate([2, 1, 2, 1, 2, 1, 2, 1, 2]):
        p = int(c[i]) * coef
        suma += p - 9 if p > 9 else p
    return (10 - suma % 10) % 10 == int(c[9])
```
Crear también `generar_cedula_valida()` (aleatoria) en `tests/utilidades.py` y usarla en `sembrar.py` y en los tests. **Nunca inventar cédulas a mano.**

### 3.3 Reglas de usuarios y roles
- El registro público SIEMPRE crea rol `cliente`. El admin se crea con `scripts/crear_admin.py` (lee `ADMIN_*` de `.env`).
- Correo y cédula únicos → **409** "El correo ya está registrado" / "La cédula ya está registrada".
- Usuario inactivo no puede iniciar sesión → **403** "Cuenta desactivada. Contacte al administrador".
- Al desactivar a un usuario o cambiarle la contraseña → se revocan todos sus tokens.
- Un admin no puede desactivarse ni quitarse el rol admin a sí mismo → **409**.
- Endpoint de admin llamado por cliente → **403** "No tiene permisos para esta operación".

### 3.4 Reglas de vuelos (admin)
- Origen ≠ destino; ambos aeropuertos existen y están activos.
- Fecha ≥ hoy; si es hoy, `hora_salida` ≥ ahora + 2 h (zona horaria **America/Guayaquil**).
- `hora_llegada > hora_salida` y duración ≤ 5 h.
- `precio` entre 20 y 2000; `precio_ejecutiva` ≥ `precio`.
- Avión existe y está **activo**.
- **Solapamiento**: el mismo avión no puede tener otro vuelo `programado` el mismo día cuyo horario se cruce, considerando 45 min de rotación → **409** "El avión HC-XXX ya opera el vuelo ATxxx en ese horario".
- `codigo_vuelo` + `fecha` únicos → **409**.
- Editar vuelo: solo si está `programado` y no ha salido. Si tiene reservas confirmadas **no se puede cambiar el avión** (409). Cambiar el precio NO altera reservas existentes (guardan su precio).
- Cancelar vuelo: `estado='cancelado'`; todas sus reservas confirmadas pasan a `cancelada` con `motivo_cancelacion='Vuelo cancelado por la aerolínea'`, se liberan asientos y se registra historial. No se borran vuelos.
- Aviones: no se puede desactivar un avión con vuelos programados futuros (409). Editar `configuracion/filas` solo si el avión no tiene vuelos (409); los vuelos ya creados conservan sus asientos.

### 3.5 Reglas de reservas
- Vuelo `programado` y salida ≥ ahora + **`HORAS_LIMITE_RESERVA` (1 h)**.
- 1 a 9 pasajeros; cantidad_asientos = número de pasajeros (cada pasajero tiene exactamente un asiento).
- Asientos sin repetir, existentes en ese vuelo (si no existe → 400) y disponibles (si no → **409** con lista `asientos_no_disponibles`).
- Documento sin repetir dentro de la reserva (400) y no presente en **otra reserva confirmada del mismo vuelo** (409 "El pasajero con documento X ya tiene reserva en este vuelo").
- Edad calculada a la **fecha del vuelo**: ≥ 2 años (menores de 2 no ocupan asiento) y ≤ 110.
- Asiento de **salida de emergencia**: pasajero ≥ 15 años (400 "Los asientos de salida de emergencia requieren pasajeros mayores de 15 años").
- Al menos un pasajero ≥ 18 años en la reserva (400 "Debe viajar al menos un adulto").
- Contacto: `telefono_contacto` y `correo_contacto` válidos (por defecto los del usuario).
- Precio por asiento: `precio_ejecutiva` si la clase es ejecutiva, si no `precio`. `subtotal = Σ precios`, `iva = round(subtotal × 0.15, 2)`, `total = subtotal + iva` (usar `Decimal`).
- **Editar** (cambiar asientos, pasajeros o cantidad): solo reserva `confirmada`, del propio usuario, y salida ≥ ahora + **`HORAS_LIMITE_CAMBIOS` (3 h)**. Mismas validaciones que crear. Los asientos propios actuales se consideran disponibles para la propia reserva.
- **Cancelar**: cliente → misma condición de 3 h; admin → en cualquier momento y debe enviar `motivo`. Reserva ya cancelada → 409.
- Una reserva de otro usuario → **404** (no revelar que existe). El admin puede ver cualquiera.

### 3.6 Códigos HTTP usados
`200` OK · `201` creado · `400` validación · `401` sin token / token inválido / expirado / revocado · `403` sin permisos o cuenta inactiva · `404` no existe · `409` conflicto (duplicado, asiento ocupado, solapamiento, estado inválido, fuera de plazo) · `500` error interno (sin detalles).

---

## FASE 1 – Base de datos en Supabase

### 1.1 Acción del USUARIO (el modelo NO puede hacerla; detenerse y pedirla)
1. Crear proyecto en https://supabase.com y guardar la contraseña de la BD.
2. Proyecto → **Connect** → **Connection string** → **Session pooler** (IPv4, puerto 5432). Copiar la URI.
   - ⚠️ NO usar "Direct connection" (solo IPv6; Render no la soporta).
   - ⚠️ Caracteres especiales de la contraseña codificados en URL (`@`→`%40`, `#`→`%23`, `/`→`%2F`).
3. Pegarla en `backend/.env` como `DATABASE_URL=...?sslmode=require`.

### 1.2 Archivos y ejecución
- Crear `sql/schema.sql` (sección 2.2), `scripts/aplicar_esquema.py`, `scripts/crear_admin.py` y `scripts/sembrar.py`.
- En esta fase `sembrar.py` implementa SOLO los pasos 1, 2 y 5. Los pasos 3 y 4 (vuelos, asientos y reservas demo) se agregan al **final de la Fase 4**, cuando ya existen `logica/asientos.py` y `crear_vuelo(...)`.
- `scripts/crear_admin.py` usa `seguridad.hashear` (Fase 2): si se ejecuta antes, implementar el hash con `werkzeug.security.generate_password_hash(..., method="pbkdf2:sha256")` directamente.
- `scripts/sembrar.py` (versión completa) debe:
  1. Insertar **aeropuertos**: UIO Quito (Mariscal Sucre), GYE Guayaquil (José Joaquín de Olmedo), CUE Cuenca (Mariscal Lamar), MEC Manta (Eloy Alfaro), LOH Loja (Ciudad de Catamayo), GPS Baltra – Galápagos (Seymour), ESM Esmeraldas (Carlos Concha Torres), OCC Coca (Francisco de Orellana).
  2. Insertar **aviones**:
     | modelo | matrícula | configuracion | config. ejecutiva | filas | filas ejecutiva | filas salida |
     |---|---|---|---|---|---|---|
     | Airbus A320 | HC-ATA | ABC-DEF | AC-DF | 30 | 3 | {12,13} |
     | Embraer E190 | HC-ATB | AC-DF | A-DF | 24 | 2 | {11} |
     | ATR 72-600 | HC-ATC | AC-DF | (null) | 18 | 0 | {1,18} |
  3. Crear **≥ 15 vuelos** futuros (diciembre 2026 – enero 2027) llamando a la MISMA función de creación de vuelos del servicio admin (para que genere asientos). Incluir obligatoriamente: Quito→Guayaquil 2026-12-21 09:45–10:40 $89; Quito→Cuenca 2026-12-21 12:20–13:15 $99; Quito→Manta 2026-12-21 14:50–15:40 $79; y un vuelo UIO→GPS en ATR para pruebas de llenado.
  4. Crear un usuario cliente **demo** (credenciales desde `.env`: `DEMO_CORREO`, `DEMO_PASSWORD`) y **reservas demo** que ocupen ~30 % de los asientos de varios vuelos (pasajeros con cédulas generadas por `generar_cedula_valida()`), para que el mapa se vea realista.
  5. Opción `--reset` que ejecuta `schema.sql` antes de sembrar, y al final ejecuta `crear_admin`.
- Comando (desde `backend/` con venv activo): `python -m scripts.sembrar --reset`

**✅ Criterio (Fase 1):** las 9 tablas existen; 8 aeropuertos, 3 aviones y el usuario admin con `rol='admin'`.
**✅ Criterio (al completar sembrar en la Fase 4):** `SELECT count(*) FROM vuelos` ≥ 15; cada vuelo tiene `count(asientos)` = capacidad del avión y `asientos_disponibles` coincide con los asientos `disponible`.

---

## FASE 2 – Backend núcleo (config, BD, errores, seguridad, usuarios, auth)

### 2.1 Entorno
```bash
cd "/c/SEXTO SEMESTRE/DISTRIBUIDAS/APE4/backend"
python -m venv .venv
source .venv/Scripts/activate        # PowerShell: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```
`requirements.txt`:
```
Flask==3.1.*
flask-cors==6.*
psycopg[binary]==3.2.*
PyJWT==2.10.*
python-dotenv==1.*
tzdata==2025.*
gunicorn==23.*
pytest==8.*
requests==2.*
```
> Si `psycopg[binary]` no instala en Python 3.14: `py -3.12 -m venv .venv` (si existe) o usar `psycopg2-binary==2.9.*` adaptando `db.py`. `tzdata` es obligatorio en Windows para `zoneinfo`.

`.env.example` (el `.env` real tiene los valores; las credenciales de prueba se definen SOLO ahí):
```
DATABASE_URL=postgresql://postgres.xxxx:PASSWORD@aws-0-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require
JWT_SECRET=cambia-esto-por-un-secreto-largo
JWT_HORAS_EXPIRACION=8
IVA=0.15
ZONA_HORARIA=America/Guayaquil
HORAS_LIMITE_RESERVA=1
HORAS_LIMITE_CAMBIOS=3
ADMIN_NOMBRE=Administrador
ADMIN_APELLIDO=AeroTech
ADMIN_CEDULA=<cédula válida generada>
ADMIN_TELEFONO=0999999999
ADMIN_CORREO=admin@aerotech.ec
ADMIN_PASSWORD=<contraseña de prueba>
DEMO_CORREO=cliente@aerotech.ec
DEMO_PASSWORD=<contraseña de prueba>
```

### 2.2 Módulos
- **`config.py`**: carga `.env`; expone constantes tipadas (`IVA` como `Decimal`, horas como `int`, `ZONA = ZoneInfo(...)`), y `ahora()` → `datetime.now(ZONA)`.
- **`db.py`**: `get_conn()` con `psycopg.connect(DATABASE_URL, row_factory=dict_row)`; context manager `transaccion()` (commit / rollback / close); `serializar(obj)` recursivo (Decimal→float, date/time/datetime→isoformat, list/dict).
- **`errores.py`**: `ErrorApi(mensaje, codigo, campos=None, extra=None)`; `ErrorValidacion(campos: dict)` (400). Manejadores que siempre devuelven `{"error", "codigo", ["campos"], [extra...]}` para ErrorApi, 404, 405, `psycopg.errors.UniqueViolation` (409 genérico) y `Exception` (500, loguear traza en consola, no devolverla).
- **`validaciones.py`**: funciones puras de la sección 3.1/3.2 + helper `Validador` que acumula errores por campo y al final hace `raise ErrorValidacion(errores)` si hay alguno. Ejemplo de uso:
  ```python
  v = Validador(datos)
  v.texto("nombre", "Nombre"); v.cedula("cedula"); v.telefono("telefono")
  v.correo("correo"); v.password("password")
  v.verificar()            # lanza 400 con todos los campos inválidos
  ```
- **`seguridad.py`**:
  - `hashear`, `verificar` (werkzeug `pbkdf2:sha256`).
  - `generar_token(usuario)`: JWT HS256 con `sub` (id como **string**), `nombre`, `rol`, `exp`; inserta en `tokens`.
  - `@token_requerido`: lee `Authorization: Bearer`; decodifica (401 expirado / inválido); consulta
    `SELECT u.id, u.rol, u.activo FROM tokens t JOIN usuarios u ON u.id=t.usuario_id WHERE t.token=%s AND t.estado='activo' AND t.expiracion > NOW()` → si no hay fila 401 "Sesión cerrada o token revocado"; si `activo=false` 403. Guarda `g.usuario_id`, `g.rol`, `g.token`.
  - `@rol_requerido("admin")`: aplica después de `@token_requerido`; 403 si no coincide.
  - `revocar_tokens_usuario(cur, usuario_id)`.

### 2.3 Servicio Usuarios (`/api/usuarios`)
| Método | Ruta | Auth | Body / Respuesta |
|---|---|---|---|
| POST | `/registro` | — | `{nombre, apellido, cedula, telefono, correo, password}` → 201 `{mensaje, usuario}` (rol cliente; nunca devolver `password_hash`) |
| GET | `/perfil` | JWT | usuario + `total_reservas`, `reservas_activas` |
| PUT | `/perfil` | JWT | `{nombre, apellido, telefono}` (correo y cédula NO editables) → 200 |
| PUT | `/password` | JWT | `{password_actual, password_nueva}`; actual incorrecta → 400 en campo; revoca los demás tokens (deja el actual) → 200 |

### 2.4 Servicio Autenticación (`/api/auth`)
- `POST /login` `{correo, password}` → 200 `{mensaje, token, expira, usuario:{id,nombre,apellido,correo,rol}}`; credenciales malas 401 "Credenciales incorrectas" (mismo mensaje si el correo no existe); inactivo 403.
- `POST /logout` (JWT) → revoca el token actual → 200.

### 2.5 `app.py`
`create_app()`: `CORS(app)`, `app.json.ensure_ascii=False`, `app.json.sort_keys=False`, registra los 6 blueprints y manejadores. Rutas de sistema:
- `GET /` → nombre de la API, versión y **catálogo de servicios** (nombre, prefijo, descripción, endpoints) → actúa como registro/descubrimiento SOA.
- `GET /api/salud` → `{"estado":"ok","bd":"ok","hora_servidor":...}` (503 si falla `SELECT 1`).
- `GET /docs` → Swagger UI desde CDN (`https://unpkg.com/swagger-ui-dist@5.17.14/swagger-ui-bundle.js` y `.css`) apuntando a `/static/openapi.yaml`.
- `app = create_app()` a nivel de módulo; `__main__` con `port=int(os.getenv("PORT",5000))`.

**✅ Criterio:** con curl: registro (201), registro duplicado (409), registro con cédula inválida (400 con `campos`), login (200), perfil con token (200), perfil sin token (401), logout y reintento (401).

---

## FASE 3 – Backend: vuelos, asientos y reservas (usar Sonnet o superior)

### 3.1 `logica/asientos.py` (usar este diseño EXACTO)
```python
def letras(config: str) -> list[str]:            # "ABC-DEF" -> ["A","B","C","D","E","F"]
    return [c for c in config if c != "-"]

def generar_asientos(cur, vuelo_id: int, avion: dict) -> int:
    filas_salida = set(avion["filas_salida"] or [])
    filas = []
    for fila in range(1, avion["filas"] + 1):
        ejecutiva = fila <= avion["filas_ejecutiva"]
        conf = (avion["configuracion_ejecutiva"] or avion["configuracion"]) if ejecutiva else avion["configuracion"]
        for letra in letras(conf):
            filas.append((vuelo_id, f"{fila}{letra}", fila, letra,
                          "ejecutiva" if ejecutiva else "economica", fila in filas_salida))
    cur.executemany("""INSERT INTO asientos (vuelo_id, codigo, fila, columna, clase, salida_emergencia)
                       VALUES (%s,%s,%s,%s,%s,%s)""", filas)
    recontar(cur, vuelo_id)
    return len(filas)

def recontar(cur, vuelo_id):
    cur.execute("""UPDATE vuelos SET asientos_disponibles =
                   (SELECT count(*) FROM asientos WHERE vuelo_id=%s AND estado='disponible')
                   WHERE id=%s""", (vuelo_id, vuelo_id))

def bloquear_vuelo(cur, vuelo_id) -> dict:
    """SIEMPRE llamar primero en cualquier operación que cambie asientos: serializa por vuelo."""
    cur.execute("SELECT * FROM vuelos WHERE id=%s FOR UPDATE", (vuelo_id,))
    v = cur.fetchone()
    if not v: raise ErrorApi("Vuelo no encontrado", 404)
    return v

def obtener_asientos(cur, vuelo_id, codigos) -> dict[str, dict]:
    cur.execute("SELECT * FROM asientos WHERE vuelo_id=%s AND codigo = ANY(%s)", (vuelo_id, codigos))
    encontrados = {a["codigo"]: a for a in cur.fetchall()}
    inexistentes = sorted(set(codigos) - encontrados.keys())
    if inexistentes:
        raise ErrorApi(f"Asientos inexistentes: {', '.join(inexistentes)}", 400)
    return encontrados

def ocupar(cur, vuelo_id, reserva_id, codigos):
    cur.execute("""UPDATE asientos SET estado='ocupado', reserva_id=%s
                   WHERE vuelo_id=%s AND codigo = ANY(%s) AND estado='disponible'
                   RETURNING codigo""", (reserva_id, vuelo_id, codigos))
    ok = {r["codigo"] for r in cur.fetchall()}
    fallidos = sorted(set(codigos) - ok)
    if fallidos:   # la transacción completa hace rollback
        raise ErrorApi(f"Asientos no disponibles: {', '.join(fallidos)}", 409,
                       extra={"asientos_no_disponibles": fallidos})

def liberar_de_reserva(cur, reserva_id):
    cur.execute("UPDATE asientos SET estado='disponible', reserva_id=NULL WHERE reserva_id=%s", (reserva_id,))
```
`logica/precios.py`: `calcular(asientos: list[dict], vuelo) -> (detalle_por_asiento, subtotal, iva, total)` con `Decimal` y `quantize(Decimal("0.01"))`.
`logica/historial.py`: `registrar(cur, reserva_id, usuario_id, accion, detalle: dict)` (guardar `detalle` con `psycopg.types.json.Jsonb`).

### 3.2 Servicio Vuelos (público)
| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/aeropuertos` | Aeropuertos activos |
| GET | `/api/vuelos?origen=UIO&destino=GYE&fecha=2026-12-21&pasajeros=2` | Solo `programado`, futuros (fecha+hora > ahora + 1 h), con `asientos_disponibles >= pasajeros`. Respuesta con ciudades, modelo de avión, duración en minutos, precio y precio_ejecutiva. `{"total": n, "vuelos": [...]}`. Parámetros inválidos → 400 |
| GET | `/api/vuelos/{id}` | Detalle (404 si no existe) |
| GET | `/api/vuelos/{id}/asientos` | **Mapa de asientos** (ver formato abajo). NO expone datos de pasajeros |

Formato de `/api/vuelos/{id}/asientos`:
```json
{
  "vuelo": {"id": 5, "codigo_vuelo": "AT101", "origen": "UIO", "destino": "GYE", "fecha": "2026-12-21",
            "hora_salida": "09:45", "precio": 89.0, "precio_ejecutiva": 189.0},
  "avion": {"modelo": "Airbus A320", "matricula": "HC-ATA", "configuracion": "ABC-DEF",
            "configuracion_ejecutiva": "AC-DF", "filas": 30, "filas_ejecutiva": 3, "filas_salida": [12, 13]},
  "resumen": {"total": 174, "disponibles": 120, "ocupados": 54},
  "asientos": [
    {"codigo": "1A", "fila": 1, "columna": "A", "clase": "ejecutiva", "salida_emergencia": false,
     "estado": "disponible", "precio": 189.0}
  ]
}
```

### 3.3 Servicio Reservas (`/api/reservas`, todo con JWT)
Body de crear/editar:
```json
{
  "vuelo_id": 5,
  "contacto": {"telefono": "0991234567", "correo": "juan@correo.com"},
  "pasajeros": [
    {"asiento": "12A", "nombres": "Juan", "apellidos": "Pérez", "tipo_documento": "cedula",
     "numero_documento": "1712345678", "fecha_nacimiento": "1990-05-10"},
    {"asiento": "12B", "nombres": "Ana", "apellidos": "Pérez", "tipo_documento": "pasaporte",
     "numero_documento": "AB123456", "fecha_nacimiento": "2016-03-02"}
  ]
}
```
(En editar no se envía `vuelo_id`; no se permite cambiar de vuelo — para eso se cancela y se reserva otro.)

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/` | Crear. 201 `{"mensaje":"Reserva creada","reserva": {id, codigo_reserva, cantidad_asientos, asientos, subtotal, iva, total, estado}}` |
| GET | `/` | Mis reservas (`?estado=confirmada|cancelada`), con datos del vuelo y lista de asientos |
| GET | `/{id}` | Detalle completo: vuelo, pasajeros (con asiento, clase, precio, edad), totales, contacto, flags `puede_editar` y `puede_cancelar` (calculados con las reglas de plazo) |
| PUT | `/{id}` | **Editar** pasajeros/asientos/cantidad. 200 con la reserva actualizada y `diferencia` (total nuevo − total anterior) |
| PUT | `/{id}/cancelar` | Cancelar. Admin debe enviar `{"motivo": "..."}` (mín. 5 caracteres) |
| GET | `/{id}/factura` | Comprobante **XML** (`application/xml; charset=utf-8`) |
| GET | `/{id}/historial` | Lista de eventos (acción, fecha, quién, detalle) |

**Algoritmo CREAR (todo dentro de `with transaccion()`):**
1. Validar estructura y formatos del body (Validador → 400 con `campos`, usando claves como `pasajeros[1].numero_documento`).
2. `vuelo = bloquear_vuelo(cur, vuelo_id)`; validar `programado` y plazo `HORAS_LIMITE_RESERVA` (409 si está fuera de plazo o cancelado).
3. `asientos = obtener_asientos(...)`; validar reglas de edad/salida de emergencia/adulto con la fecha del vuelo (400).
4. Validar documentos no repetidos en otra reserva confirmada del mismo vuelo (409).
5. Calcular precios; generar `codigo_reserva` (6 chars de `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` con `secrets`; reintentar si existe).
6. `INSERT reservas ... RETURNING id`; `ocupar(cur, vuelo_id, reserva_id, codigos)`; `INSERT pasajeros` (con `asiento_id` y `precio`); `recontar`; `historial.registrar(..., 'creada', {"asientos": [...], "total": ...})`.

**Algoritmo EDITAR:**
1. `SELECT * FROM reservas WHERE id=%s FOR UPDATE`; 404 si no existe o no es del usuario (admin no edita, solo cancela); 409 si cancelada; 409 si fuera de plazo `HORAS_LIMITE_CAMBIOS`.
2. `bloquear_vuelo`; guardar estado anterior (asientos, total) para el historial.
3. `liberar_de_reserva(cur, reserva_id)`; `DELETE FROM pasajeros WHERE reserva_id=%s`.
4. Repetir pasos 3-4 y 6 de CREAR (excluyendo la propia reserva en la validación de documentos duplicados). Si `ocupar` falla, la excepción hace **rollback de todo** y la reserva queda como estaba.
5. `UPDATE reservas SET cantidad_asientos, subtotal, iva, total, telefono_contacto, correo_contacto, fecha_modificacion=NOW()`; `recontar`; historial `'modificada'` con `{"antes": {...}, "despues": {...}}`.

**Algoritmo CANCELAR:** bloquear reserva → validar permisos/estado/plazo → `bloquear_vuelo` → `liberar_de_reserva` → `estado='cancelada'`, `motivo_cancelacion` (cliente: "Cancelada por el cliente") → `recontar` → historial `'cancelada'`. Los registros de `pasajeros` se conservan como histórico.

**Factura XML** (generar con `xml.etree.ElementTree`, declarar `<?xml version="1.0" encoding="UTF-8"?>`):
```xml
<factura>
  <numero>P001-000058</numero>
  <codigo_reserva>K7P2QX</codigo_reserva>
  <fecha_emision>2026-12-01</fecha_emision>
  <cliente><nombre>Juan Pérez</nombre><cedula>…</cedula><correo>…</correo></cliente>
  <vuelo><codigo>AT101</codigo><origen>Quito (UIO)</origen><destino>Guayaquil (GYE)</destino>
         <fecha>2026-12-21</fecha><hora_salida>09:45</hora_salida><avion>Airbus A320</avion></vuelo>
  <pasajeros>
    <pasajero><nombre>Juan Pérez</nombre><documento tipo="cedula">…</documento>
              <asiento>12A</asiento><clase>economica</clase><precio>89.00</precio></pasajero>
  </pasajeros>
  <subtotal>178.00</subtotal><iva porcentaje="15">26.70</iva><total>204.70</total>
  <estado>confirmada</estado>
</factura>
```

**✅ Criterio:** con curl/requests: crear reserva (201) y ver los asientos `ocupado` en el mapa; reservar un asiento ocupado (409 con `asientos_no_disponibles`); editar pasando de 2 a 3 asientos y cambiando uno (200, `asientos_disponibles` correcto); cancelar (asientos liberados); factura XML válida (`ET.fromstring` no falla).

---

## FASE 4 – Backend: administración, reportes y contrato OpenAPI

### 4.1 Servicio Administración (`/api/admin`, `@token_requerido` + `@rol_requerido("admin")`)
| Método | Ruta | Descripción |
|---|---|---|
| GET | `/aviones` | Lista con capacidad calculada y nº de vuelos futuros |
| POST | `/aviones` | Crear (validaciones 3.1 / 3.4) |
| PUT | `/aviones/{id}` | Editar (reglas 3.4) |
| PATCH | `/aviones/{id}/estado` | `{activo: bool}` |
| GET | `/aviones/{id}/vista-previa` | Mismo formato que el mapa de asientos pero sin vuelo (para previsualizar la configuración) |
| GET | `/vuelos?estado=&desde=&hasta=&origen=&destino=` | Todos los vuelos (incluye cancelados y pasados) con % de ocupación e ingresos |
| POST | `/vuelos` | Crear vuelo → genera asientos (`generar_asientos`) en la misma transacción; `creado_por = g.usuario_id`. 201 con vuelo y nº de asientos |
| PUT | `/vuelos/{id}` | Editar (reglas 3.4) |
| PUT | `/vuelos/{id}/cancelar` | `{motivo}` → cancela vuelo y reservas (regla 3.4) → 200 con nº de reservas afectadas |
| GET | `/vuelos/{id}/manifiesto` | Pasajeros confirmados ordenados por asiento: asiento, clase, nombre, documento, edad, código de reserva, titular |
| GET | `/reservas?estado=&vuelo_id=&codigo=&correo=` | Todas las reservas |
| GET | `/usuarios?rol=&activo=&buscar=` | Lista de usuarios (sin hash) con nº de reservas |
| PATCH | `/usuarios/{id}` | `{rol?, activo?}` (reglas 3.3) |

> La lógica de "crear vuelo" debe estar en una función reutilizable (`crear_vuelo(cur, datos, admin_id)`) para que `scripts/sembrar.py` la use.

### 4.2 Servicio Reportes (`/api/reportes`, solo admin)
- `GET /dashboard` →
  ```json
  {"indicadores": {"vuelos_programados": 15, "reservas_confirmadas": 40, "pasajeros": 96,
                   "ingresos": 12500.50, "ocupacion_promedio": 31.4, "usuarios_clientes": 12},
   "ocupacion_por_vuelo": [{"codigo_vuelo":"AT101","fecha":"2026-12-21","ruta":"UIO-GYE","ocupacion":45.2}],
   "reservas_por_dia": [{"fecha":"2026-12-01","reservas":5,"ingresos":890.0}],
   "rutas_top": [{"ruta":"UIO-GYE","pasajeros":40,"ingresos":4200.0}]}
  ```
  (ocupación por vuelo: próximos 10 vuelos; reservas por día: últimos 14 días; rutas top: 5.)

### 4.3 `static/openapi.yaml`
OpenAPI 3.0.3 completo: `info`, `servers` (local y Render), `tags` = 6 servicios, `securitySchemes.bearerAuth`, schemas (`Usuario`, `Aeropuerto`, `Avion`, `Vuelo`, `MapaAsientos`, `Asiento`, `Pasajero`, `ReservaRequest`, `Reserva`, `Dashboard`, `Error`, `ErrorValidacion`) y TODOS los endpoints con códigos 200/201/400/401/403/404/409 y ejemplos. La factura documenta `application/xml`.

### 4.4 Completar `scripts/sembrar.py`
Agregar los pasos 3 y 4 de la Fase 1.2 (vuelos con `crear_vuelo(...)` y reservas demo reutilizando la misma función interna de creación de reservas de la Fase 3) y ejecutar `python -m scripts.sembrar --reset`.

**✅ Criterio:** se cumple el criterio de semillas de la Fase 1; cliente llamando a `/api/admin/vuelos` → 403; admin crea un avión, crea un vuelo (asientos generados = capacidad), intenta crear otro vuelo solapado con el mismo avión (409), cancela un vuelo con reservas (reservas pasan a canceladas y asientos liberados); `/docs` muestra todos los endpoints.

---

## FASE 5 – Pruebas automatizadas del backend

### 5.1 `tests/` (pytest + requests contra `API_URL`, por defecto `http://localhost:5000`)
- `conftest.py`: fixtures `cliente` (registra usuario aleatorio y hace login → headers), `otro_cliente`, `admin` (login con `ADMIN_*` de `.env`), `vuelo_nuevo` (el admin crea un vuelo en el ATR para el test, con fecha futura aleatoria en 2027, hora aleatoria y código único; si responde 409 por solapamiento, reintentar con otra fecha/hora — así los tests son **repetibles** sin resembrar), `avion_pequeno` (el admin crea un avión de prueba con configuración `A-C`, 5 filas = 10 asientos y matrícula aleatoria `HC-` + 4 caracteres).
- `utilidades.py`: `generar_cedula_valida()`, `correo_aleatorio()`, `pasajero(asiento, edad=30, ...)`.
- Archivos y casos mínimos (nombres en español):
  - `test_usuarios_auth.py`: salud; registro ok; correo duplicado 409; cédula duplicada 409; cédula inválida 400 con `campos.cedula`; contraseña débil 400; login ok; login malo 401; perfil sin token 401; editar perfil; cambiar contraseña (y el login con la anterior falla); logout revoca token.
  - `test_vuelos.py`: aeropuertos; listar; filtro origen/destino/fecha; filtro pasajeros; vuelo inexistente 404; mapa de asientos con `resumen.total == len(asientos)`.
  - `test_reservas.py`: sin token 401; crear ok (asientos pasan a ocupado y `asientos_disponibles` baja); asiento ocupado 409 con lista; asiento inexistente 400; asientos repetidos 400; 10 pasajeros 400; menor de 2 años 400; niño en salida de emergencia 400; sin adulto 400; documento ya en el vuelo 409; mis reservas; detalle; reserva de otro usuario 404; **editar aumentando cantidad** (2→3); **editar disminuyendo** (3→1) libera asientos; editar a asiento ocupado 409 y la reserva queda intacta; cancelar ok; cancelar dos veces 409; editar cancelada 409; factura XML; historial con 3 eventos (creada, modificada, cancelada).
  - `test_admin.py`: cliente → 403 en todos los endpoints admin; crear avión con configuración inválida 400; crear vuelo (asientos = capacidad); origen = destino 400; llegada antes de salida 400; solapamiento 409; editar precio; cambiar avión con reservas 409; cancelar vuelo cancela reservas; manifiesto; desactivar usuario → su token da 403 y no puede loguear; admin no puede desactivarse a sí mismo 409; dashboard con todas las claves.
  - `test_concurrencia.py`: 8 hilos (`ThreadPoolExecutor`) de 8 usuarios distintos intentan reservar **el mismo asiento** → exactamente **1** respuesta 201 y 7 respuestas 409; y, con un vuelo creado sobre `avion_pequeno` (10 asientos) donde antes se reservan 7, 6 hilos intentan reservar cada uno uno de los asientos (unos libres y otros repetidos entre hilos) → nunca hay dos reservas sobre el mismo asiento, `asientos_disponibles` termina en 0 y nunca es negativo.
- Ejecutar: `pytest -v` (servidor local corriendo) → guardar salida en `capturas/pytest_local.txt`.

### 5.2 Colección Postman `postman/AeroTech.postman_collection.json` (v2.1)
Variables `baseUrl`, `token`, `tokenAdmin`, `vueloId`, `reservaId`. Carpetas por servicio (6). Scripts de test que guardan token e ids. Incluir requests de error (400, 401, 403, 404, 409).

**✅ Criterio:** todos los tests en verde en local.

---

## FASE 6 – Flutter: base, sesión y ruteo por rol

### 6.1 Crear proyecto
```bash
cd "/c/SEXTO SEMESTRE/DISTRIBUIDAS/APE4"
flutter create --org ec.uta --project-name aerotech --platforms=windows,web,android cliente_flutter
cd cliente_flutter
flutter pub add http shared_preferences intl fl_chart
```
Sin gestores de estado externos: `setState` + una clase singleton `Sesion`.

### 6.2 Estructura `lib/`
```
lib/
├── main.dart                    (MaterialApp Material 3, tema azul, locale es, splash que decide ruta)
├── config.dart                  (apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:5000'))
├── sesion.dart                  (token, usuario, rol; cargar/guardar/borrar en shared_preferences; esAdmin)
├── models/                      usuario, aeropuerto, avion, vuelo, asiento, mapa_asientos, pasajero, reserva, evento_historial, dashboard
├── services/
│   ├── api_client.dart          (get/post/put/patch; Bearer; timeout 60 s; lanza ApiException(mensaje, codigo, campos, extra);
│   │                             si 401 → Sesion.cerrar() y navegar a Login con un navigatorKey global)
│   ├── auth_service.dart        usuario_service.dart   vuelo_service.dart
│   ├── reserva_service.dart     admin_service.dart     reporte_service.dart
├── utils/
│   ├── validadores.dart         (MISMAS reglas de la sección 3, incluida cédula módulo 10 y edad a la fecha del vuelo)
│   └── formatos.dart            (moneda $, fechas "21 dic 2026", horas, duración "55 min")
├── widgets/
│   ├── campo_texto.dart         (TextFormField estándar; muestra errores de `campos` del backend)
│   ├── estado_chip.dart         (confirmada=verde, cancelada=rojo, programado=azul)
│   ├── vuelo_card.dart          (ruta UIO → GYE con avión, horas, duración, precio "desde", asientos libres)
│   ├── cargando.dart / vacio.dart / error_reintentar.dart
│   └── mapa_asientos/           (ver Fase 7.2)
└── screens/
    ├── auth/        login_screen, registro_screen
    ├── cliente/     ...         (Fase 7)
    └── admin/       ...         (Fase 8)
```

### 6.3 Pantallas base
- **Login**: logo (`Icons.flight_takeoff`) + "AeroTech – Reservas de vuelos", correo, contraseña con ojo, "Iniciar sesión", enlace "Crear cuenta". Errores 401/403 en SnackBar.
- **Registro**: nombre, apellido, cédula, teléfono, correo, contraseña, confirmar contraseña; validación en vivo (`autovalidateMode: onUserInteraction`); errores de `campos` del backend se muestran bajo cada campo.
- **Ruteo por rol** tras login o al abrir la app con token guardado (verificar con `GET /api/usuarios/perfil`): `admin` → `AdminHome`; `cliente` → `ClienteHome`.
- Manejo uniforme: indicador de carga en cada llamada, SnackBar rojo con `error` del backend, botón "Reintentar" en pantallas de lista, mensaje especial "Conectando con el servidor (puede tardar hasta 1 min)…" si una llamada supera 5 s.

**✅ Criterio:** `flutter analyze` sin errores; registro → login como cliente abre `ClienteHome`; login como admin abre `AdminHome`; cerrar sesión vuelve a Login.

---

## FASE 7 – Flutter: módulo CLIENTE (usar Sonnet o superior)

### 7.1 Pantallas (`screens/cliente/`)
1. **`cliente_home.dart`**: `NavigationBar` (o `NavigationRail` si ancho > 800) con 3 pestañas: **Vuelos**, **Mis reservas**, **Perfil**.
2. **`buscar_vuelos_screen.dart`**: dropdowns origen/destino (desde `/api/aeropuertos`, con botón ⇅ para intercambiar), selector de fecha (`showDatePicker`, `locale es`, sin fechas pasadas), contador de pasajeros (1-9), botón "Buscar"; lista de `VueloCard`. Sin filtros = mostrar próximos vuelos.
3. **`detalle_vuelo_screen.dart`**: datos del vuelo y avión, precios económica/ejecutiva, asientos libres, botón "Elegir asientos".
4. **`seleccion_asientos_screen.dart`**: el **mapa de asientos** (7.2). Barra inferior fija: "Asientos: 12A, 12B · Total parcial $178.00 · [Continuar]". El usuario elige libremente de 1 a 9 asientos (la cantidad de la reserva = asientos elegidos). Al tocar un asiento de salida de emergencia por primera vez, mostrar diálogo informativo con las condiciones (≥ 15 años, ayudar en evacuación).
5. **`datos_pasajeros_screen.dart`**: un `ExpansionTile`/tarjeta por asiento con: nombres, apellidos, tipo de documento (segmented button Cédula/Pasaporte), número, fecha de nacimiento (date picker); checkbox "Soy yo quien viaja" en el primer pasajero para precargar datos del usuario; validaciones locales (sección 3, edad respecto a la fecha del vuelo); sección "Contacto" (teléfono y correo precargados).
6. **`resumen_reserva_screen.dart`**: vuelo, tabla de pasajeros con asiento/clase/precio, subtotal, IVA 15 %, total; en modo edición muestra "Total anterior / Nuevo total / Diferencia (+/−)". Botón "Confirmar reserva" / "Guardar cambios". Si el backend responde **409 con `asientos_no_disponibles`** → SnackBar explicativo, volver al mapa, recargarlo y quitar esos asientos de la selección (conservando los datos ya escritos de los demás pasajeros).
7. **Éxito**: diálogo con **código de reserva** grande (ej. `K7P2QX`), total, botones "Ver comprobante XML" y "Ir a mis reservas".
8. **`mis_reservas_screen.dart`**: pestañas "Activas" / "Canceladas"; tarjeta con código, ruta, fecha, nº asientos (chips con los códigos), total y estado.
9. **`detalle_reserva_screen.dart`**: todo el detalle + pasajeros + **línea de tiempo del historial** (creada / modificada / cancelada con fecha y detalle). Botones según flags del backend:
   - **Editar reserva** (`puede_editar`): abre el mapa en **modo edición** (asientos actuales marcados como "Tus asientos" y seleccionados; se pueden soltar y elegir otros o agregar/quitar → cambia la cantidad), luego pasajeros precargados, luego resumen con diferencia.
   - **Cancelar reserva** (`puede_cancelar`): diálogo de confirmación con resumen ("Se liberarán 2 asientos…").
   - **Comprobante XML**.
   - Si no se puede editar/cancelar, mostrar el motivo ("Faltan menos de 3 horas para el vuelo" / "Reserva cancelada").
10. **`comprobante_screen.dart`**: XML con fondo oscuro, fuente monoespaciada, resaltado simple de etiquetas (colores para `<tag>` y contenido), `SelectableText`, botones "Copiar" y "Guardar" (Windows: escribir el archivo en Descargas con `dart:io` usando la variable de entorno `USERPROFILE`; en web, ocultar "Guardar").
11. **`perfil_screen.dart`**: datos del usuario, estadísticas (reservas totales/activas), editar nombre/apellido/teléfono, cambiar contraseña, cerrar sesión.

### 7.2 Mapa de asientos que simula el avión (`widgets/mapa_asientos/`)
Archivos: `mapa_asientos.dart`, `asiento_widget.dart`, `fuselaje_painter.dart`, `leyenda_asientos.dart`.

**Diseño visual (vista superior del avión, nariz arriba):**
- **Fuselaje** dibujado con `CustomPainter`: nariz redondeada arriba, cuerpo recto, cola afinada abajo; **alas** trapezoidales a ambos lados a la altura de las filas de salida de emergencia (o al 40 % del largo si no hay); **estabilizadores** pequeños en la cola; borde gris azulado, relleno claro. Ventanillas como pequeños óvalos a lo largo de ambos costados (una por fila).
- **Cabina** en la nariz: ícono `Icons.airline_seat_flat` o texto "CABINA" + `Icons.wc` y "Galley" como elementos decorativos.
- **Filas**: cada fila es un `Row` con los grupos de la configuración separados por un **pasillo** (28 px) que muestra el **número de fila** centrado. Letras de columna (A B C · D E F) como encabezado de cada sección.
- **Secciones**: divisor con etiqueta "CLASE EJECUTIVA" (fondo dorado suave) y "CLASE ECONÓMICA"; los asientos ejecutivos son más anchos (configuración ejecutiva con menos asientos) y se centran.
- **Filas de salida de emergencia**: etiqueta roja "SALIDA" con `Icons.exit_to_app` en ambos extremos de la fila y un espacio extra (legroom) antes de la fila.
- **Asiento** (`AsientoWidget`, 36×40 económica, 46×44 ejecutiva): forma de butaca = respaldo (rectángulo redondeado arriba) + cojín; `AnimatedContainer` (150 ms) al cambiar de estado; `Tooltip` "12A · Económica · Ventana · $89.00" (A/F = Ventana, C/D = Pasillo, resto = Centro; adaptar a cada configuración: primera y última letra = ventana, letras junto al guion = pasillo).
- **Colores / estados** (con leyenda abajo):
  | Estado | Estilo |
  |---|---|
  | Disponible económica | blanco, borde azul |
  | Disponible ejecutiva | dorado claro, borde dorado |
  | Salida de emergencia disponible | borde rojo discontinuo/grueso |
  | Seleccionado | azul sólido, texto blanco, ícono ✓ |
  | Tus asientos (modo edición) | verde, con ✓ (si se deselecciona pasa a "disponible") |
  | Ocupado | gris, ícono `Icons.close`, deshabilitado |
- **Interacción**: tocar alterna selección; si se alcanza el máximo (9) → SnackBar "Máximo 9 asientos por reserva". `InteractiveViewer` (zoom 0.6×–2.5×) dentro de un scroll vertical; botón flotante "Centrar". Encabezado fijo con vuelo, avión y contador "120 de 174 libres". En pantallas anchas (Windows), mostrar el mapa a la izquierda y el panel de selección/resumen a la derecha.
- **Solo lectura**: parámetro `soloLectura` (lo usa el manifiesto del admin para ver ocupación).

**Esqueleto del painter (completar estilo):**
```dart
class FuselajePainter extends CustomPainter {
  final double yAlas;          // posición vertical (px) donde empiezan las alas
  final int filas;             // para dibujar una ventanilla por fila
  final double altoFila;
  final double inicioFilas;    // y donde empieza la primera fila
  FuselajePainter({required this.yAlas, required this.filas, required this.altoFila, required this.inicioFilas});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height, nariz = w * 0.85, cola = w * 0.9;
    final relleno = Paint()..color = const Color(0xFFF3F6FA);
    final borde = Paint()..color = const Color(0xFF8FA3BF)..style = PaintingStyle.stroke..strokeWidth = 2.5;
    final alaP = Paint()..color = const Color(0xFFDCE3EE);

    // Alas (se dibujan primero, quedan detrás del fuselaje)
    final ala = w * 1.1;
    canvas.drawPath(Path()..moveTo(0, yAlas)..lineTo(-ala, yAlas + w * 0.5)
        ..lineTo(-ala, yAlas + w * 0.75)..lineTo(0, yAlas + w * 0.55)..close(), alaP);
    canvas.drawPath(Path()..moveTo(w, yAlas)..lineTo(w + ala, yAlas + w * 0.5)
        ..lineTo(w + ala, yAlas + w * 0.75)..lineTo(w, yAlas + w * 0.55)..close(), alaP);
    // Estabilizadores horizontales en la cola
    final yc = h - cola * 0.6;
    canvas.drawPath(Path()..moveTo(w * 0.3, yc)..lineTo(-w * 0.35, yc + w * 0.3)
        ..lineTo(-w * 0.35, yc + w * 0.42)..lineTo(w * 0.35, yc + w * 0.3)..close(), alaP);
    canvas.drawPath(Path()..moveTo(w * 0.7, yc)..lineTo(w * 1.35, yc + w * 0.3)
        ..lineTo(w * 1.35, yc + w * 0.42)..lineTo(w * 0.65, yc + w * 0.3)..close(), alaP);

    // Fuselaje
    final cuerpo = Path()
      ..moveTo(0, nariz)
      ..cubicTo(0, nariz * 0.25, w * 0.25, 0, w / 2, 0)
      ..cubicTo(w * 0.75, 0, w, nariz * 0.25, w, nariz)
      ..lineTo(w, h - cola)
      ..cubicTo(w, h - cola * 0.3, w * 0.6, h, w / 2, h)
      ..cubicTo(w * 0.4, h, 0, h - cola * 0.3, 0, h - cola)
      ..close();
    canvas.drawPath(cuerpo, relleno);
    canvas.drawPath(cuerpo, borde);

    // Ventanillas
    final v = Paint()..color = const Color(0xFF9EC5F0);
    for (var i = 0; i < filas; i++) {
      final y = inicioFilas + i * altoFila + altoFila / 2;
      canvas.drawOval(Rect.fromCenter(center: Offset(5, y), width: 4, height: 10), v);
      canvas.drawOval(Rect.fromCenter(center: Offset(w - 5, y), width: 4, height: 10), v);
    }
  }
  @override
  bool shouldRepaint(covariant FuselajePainter o) => false;
}
```
Uso: calcular el ancho de forma determinista
`anchoCabina = (asientosEconómicaPorFila × 40) + (nPasillos × 28) + 40` y las posiciones `y` de cada fila (alto fijo por fila: 46 económica, 52 ejecutiva, +16 extra antes de filas de salida). Envolver en
`Padding(horizontal: anchoCabina * 1.15)` (espacio para las alas) → `CustomPaint(painter: FuselajePainter(...), child: Padding(EdgeInsets.fromLTRB(20, nariz + 40, 20, cola + 20), child: Column(filas)))`.

**✅ Criterio:** flujo completo como cliente: buscar → elegir 2 asientos (uno ejecutivo) → datos pasajeros → confirmar → código de reserva → comprobante XML → editar a 3 asientos cambiando uno → ver diferencia de precio → historial muestra creada/modificada → cancelar. Probar el conflicto: abrir el mismo vuelo en Chrome y en Windows con dos usuarios, reservar el mismo asiento → el segundo ve el aviso 409 y el mapa se actualiza.

---

## FASE 8 – Flutter: módulo ADMINISTRADOR

### 8.1 `admin_home.dart`
`NavigationRail` (Windows) / `Drawer` (pantalla angosta) con: **Dashboard**, **Vuelos**, **Flota**, **Reservas**, **Usuarios**, **Cerrar sesión**. AppBar con chip "ADMIN".

### 8.2 Pantallas (`screens/admin/`)
1. **`dashboard_screen.dart`**: tarjetas KPI (vuelos programados, reservas, pasajeros, ingresos, ocupación promedio, clientes) + gráficos `fl_chart`: barras de ocupación por vuelo, línea de reservas/ingresos por día, lista de rutas top. Botón refrescar.
2. **`vuelos_admin_screen.dart`**: `DataTable`/lista con filtros (estado, rango de fechas, origen/destino), columnas código, ruta, fecha/hora, avión, ocupación (barra de progreso), ingresos, estado. Acciones: Editar, Ver manifiesto, Cancelar vuelo (diálogo con motivo obligatorio y aviso "Se cancelarán N reservas"). FAB "Nuevo vuelo".
3. **`vuelo_form_screen.dart`** (crear/editar): código de vuelo, avión (dropdown solo activos, mostrando modelo/matrícula/capacidad), origen/destino (dropdown, no iguales), fecha, hora salida/llegada (time pickers), duración calculada en vivo, precio económica y ejecutiva (deshabilitar ejecutiva si el avión no tiene filas ejecutivas, y entonces enviar el mismo precio). Validaciones locales de la sección 3.4; errores 409 del backend (solapamiento, código duplicado) en SnackBar. En edición, el avión se bloquea si hay reservas.
4. **`manifiesto_screen.dart`**: encabezado del vuelo + pestañas "Mapa" (mapa de asientos en **solo lectura**) y "Pasajeros" (tabla por asiento con nombre, documento, edad, código de reserva). Botón copiar como texto.
5. **`flota_screen.dart`** + **`avion_form_screen.dart`**: lista de aviones (modelo, matrícula, capacidad, vuelos futuros, activo switch). Formulario con modelo, matrícula, configuración económica/ejecutiva, filas, filas ejecutivas, filas de salida (chips), y **vista previa en vivo del mapa de asientos** (construida localmente con el mismo widget `MapaAsientos` en modo solo lectura) que se actualiza al cambiar la configuración, mostrando la capacidad total.
6. **`reservas_admin_screen.dart`**: buscador por código de reserva / correo, filtros por estado y vuelo; detalle reutilizando `detalle_reserva_screen` en modo admin (sin editar; cancelar con motivo).
7. **`usuarios_admin_screen.dart`**: lista con búsqueda, filtro por rol/estado; switch activo y dropdown de rol con confirmación; deshabilitar esas acciones sobre uno mismo.

**✅ Criterio:** como admin: crear avión con vista previa → crear vuelo → verlo como cliente en la búsqueda → reservar como cliente → ver manifiesto como admin → cancelar el vuelo → el cliente ve la reserva cancelada con motivo → dashboard refleja los cambios; desactivar a un cliente lo expulsa en su siguiente acción (403 → Login con mensaje).

---

## FASE 9 – Despliegue en Render (HTTPS)

### 9.1 Repositorio
- `.gitignore` raíz: `.venv/`, `__pycache__/`, `*.pyc`, `.env`, `.pytest_cache/`, `cliente_flutter/build/`, `cliente_flutter/.dart_tool/`, `node_modules/`.
- `git init` + commit. **Pedir confirmación al usuario** antes de `gh repo create aerotech-soa --private --source . --push`. Verificar que solo `.env.example` esté versionado (`git ls-files | grep -i env`).

### 9.2 `render.yaml`
```yaml
services:
  - type: web
    name: aerotech-api
    runtime: python
    rootDir: backend
    plan: free
    buildCommand: pip install -r requirements.txt
    startCommand: gunicorn app:app --bind 0.0.0.0:$PORT --workers 2 --threads 4 --timeout 120
    healthCheckPath: /api/salud
    envVars:
      - key: PYTHON_VERSION
        value: 3.12.7
      - key: DATABASE_URL
        sync: false
      - key: JWT_SECRET
        generateValue: true
      - key: JWT_HORAS_EXPIRACION
        value: "8"
      - key: IVA
        value: "0.15"
      - key: ZONA_HORARIA
        value: America/Guayaquil
      - key: HORAS_LIMITE_RESERVA
        value: "1"
      - key: HORAS_LIMITE_CAMBIOS
        value: "3"
```

### 9.3 Acción del USUARIO
Render → **New → Blueprint** → repo de GitHub → pegar `DATABASE_URL` → Deploy. Compartir la URL `https://aerotech-api-xxxx.onrender.com`.

### 9.4 Verificación
- `/api/salud` por HTTPS; `/docs`.
- `API_URL=https://<url> pytest -v` → guardar en `capturas/pytest_render.txt`. (Los tests de admin necesitan el `.env` local con `ADMIN_*`: es la misma BD.)
- Actualizar `servers` del OpenAPI con la URL real.
- `flutter run -d windows --dart-define=API_URL=https://<url>` y `flutter run -d chrome --dart-define=API_URL=https://<url>`.

> Plan free: el servicio se duerme tras 15 min; la primera petición tarda ~50 s (de ahí el timeout de 60 s y el mensaje "Conectando con el servidor…").

**✅ Criterio:** API pública por HTTPS y app (cliente y admin) funcionando contra ella.

---

## FASE 10 – Documentación de arquitectura y contratos (insumo del informe)

### 10.1 `docs/arquitectura.md` + un `.mmd` por diagrama
1. **Arquitectura SOA** (`flowchart LR`): consumidores (App Flutter cliente, App Flutter admin, Postman, pytest) → HTTPS JSON/XML → Render [Flask: 6 servicios + capa de seguridad JWT/roles + lógica (asientos, precios, historial)] → PostgreSQL/SSL → Supabase (9 tablas). Contrato OpenAPI como nodo.
2. **Casos de uso por rol** (`flowchart` con actores Cliente / Administrador y sus casos).
3. **Componentes/capas** (cliente: screens → services → api_client; servidor: blueprints → seguridad → lógica → db).
4. **Secuencias** (`sequenceDiagram`): login con JWT; crear reserva (`BEGIN → SELECT … FOR UPDATE → UPDATE asientos … WHERE estado='disponible' → INSERT → COMMIT` y la rama 409 con ROLLBACK); editar reserva; admin cancela vuelo.
5. **ER** (`erDiagram`) de las 9 tablas.
6. **Estados** (`stateDiagram-v2`) de reserva (confirmada → modificada* → cancelada) y de asiento (disponible ⇄ ocupado).
7. **Despliegue**: PC/Navegador del usuario → Internet HTTPS → Render (gunicorn) → Supabase (AWS).

Renderizar a PNG: `npx -y @mermaid-js/mermaid-cli -i docs/<diag>.mmd -o capturas/diagramas/<diag>.png -b white -w 1800`.

### 10.2 `docs/contratos.md`
- Tabla **Servicio / Proveedor / Consumidores / Contrato / Formato / Seguridad / Rol** para los 6 servicios.
- Por endpoint: método, ruta, auth/rol, request y response de ejemplo, errores posibles.
- Tabla de **reglas de negocio** (sección 3) con el código HTTP de cada violación.
- **Principios SOA aplicados**: contrato estandarizado (OpenAPI), bajo acoplamiento, abstracción (el cliente no conoce Supabase), reutilización (mismos servicios para app cliente, app admin, Postman y pytest), autonomía (un blueprint por servicio), sin estado (JWT), descubribilidad (`GET /`, `/docs`), composición (reserva compone vuelos + asientos + precios + historial), interoperabilidad (Dart ⇄ Python ⇄ PostgreSQL vía HTTP/JSON/XML).

### 10.3 `README.md`
Requisitos, `.env`, `python -m scripts.sembrar --reset`, correr backend, tests, Flutter (local/Render), URL desplegada, `/docs`, cómo entrar como admin (referenciar las variables `ADMIN_*` del `.env`, sin escribir la contraseña).

**✅ Criterio:** 7 diagramas en PNG; `contratos.md` cubre todos los endpoints y reglas.

---

## FASE 11 – Pruebas documentadas y capturas

### 11.1 `docs/pruebas.md`
Tabla **ID | Servicio | Rol | Caso | Entrada | Esperado | Obtenido | Evidencia**: todos los casos de la Fase 5 + pruebas manuales en la app (cliente y admin) + interoperabilidad (mismo endpoint desde Flutter, Postman y pytest) + concurrencia.

### 11.2 Capturas (`capturas/`)
| Archivo | Contenido |
|---|---|
| `01_supabase_tablas.png` | Table Editor con las 9 tablas |
| `02_swagger_docs.png` | `/docs` en Render |
| `03_salud_https.png` | `/api/salud` por HTTPS |
| `04`–`12_postman_*.png` | Un servicio por captura + errores 400/401/403/404/409 |
| `13_pytest_local.png`, `14_pytest_render.png` | Suites en verde |
| `15_app_login.png`, `16_app_registro_validaciones.png` | Auth con errores de validación visibles |
| `17_cliente_busqueda.png` | Búsqueda de vuelos |
| `18_cliente_mapa_asientos.png` | **Mapa del avión** con seleccionados/ocupados/ejecutiva/salida |
| `19_cliente_pasajeros.png`, `20_cliente_resumen.png`, `21_cliente_exito.png` | Flujo de reserva |
| `22_cliente_editar_mapa.png`, `23_cliente_editar_diferencia.png` | Edición (cambio de cantidad) |
| `24_cliente_historial.png`, `25_cliente_cancelar.png`, `26_comprobante_xml.png` | Gestión |
| `27_conflicto_409.png` | Asiento tomado por otro usuario |
| `28_admin_dashboard.png` … `33_admin_usuarios.png` | Dashboard, vuelos, form vuelo, flota con vista previa, manifiesto, usuarios |
| `34_render_dashboard.png` | Servicio en Render |
| `35_devtools_red.png` | Flutter web → DevTools Network con request/response JSON por HTTPS |
| `diagramas/*.png` | Fase 10 |

El modelo puede tomar las capturas de navegador (Swagger, salud, Flutter web) con el navegador integrado y guardar salidas de consola en `.txt`; las de la app Windows, Supabase, Render y Postman las toma el usuario (indicarle la lista exacta).

**✅ Criterio final (entregables diapositiva 63, sección 9):** diagrama SOA ✔ · servicios REST Flask ✔ · modelo BD Supabase ✔ · app Flutter (cliente + admin) ✔ · pruebas y resultados ✔ · (PDF del informe → se hace aparte con la skill `informe-ape`).

---

## Reglas para el modelo ejecutor
1. Actualiza la **Bitácora** al terminar cada fase (fecha + notas + desviaciones).
2. Nunca escribas la contraseña real de Supabase, `JWT_SECRET` ni las contraseñas de prueba en archivos versionados ni las repitas en el chat; viven solo en `backend/.env`.
3. Si una acción requiere cuenta o sitio externo (Supabase, Render, push a GitHub) **detente y pide al usuario** que la haga o la confirme.
4. Si algo falla (versión de librería, API de Flutter cambiada), aplica la alternativa indicada o el cambio mínimo, y anótalo en la bitácora.
5. No agregues frameworks extra (ni SQLAlchemy, ni Provider/Riverpod/Bloc, ni Docker).
6. Toda operación que cambie asientos: **bloquear el vuelo primero** (`bloquear_vuelo`) y hacerlo dentro de una sola transacción.
7. Las validaciones del backend son la fuente de verdad; las de Flutter son solo para UX y deben coincidir.
8. Al terminar cada fase, ejecuta su criterio de aceptación y muestra el resultado.

## Bitácora
- [x] Fase 1 – BD Supabase y semillas — **COMPLETADA (2026-11-14)**: esquema aplicado, 9 tablas / 8 aeropuertos / 3 aviones / admin verificados (`capturas/fase1_verificacion.txt`). Incidencia: la URI traía la contraseña entre corchetes `[ ]` (marcador de Supabase); el usuario la corrigió. Los pasos 3 y 4 de `sembrar.py` quedan para la Fase 4. Detalle del trabajo: creados `sql/schema.sql`, `scripts/{aplicar_esquema,crear_admin,sembrar}.py`, `requirements.txt` (instalado en `.venv` con Python 3.14, psycopg 3.2 OK), `.env.example`, `.env` (secretos generados; falta `DATABASE_URL`), `.gitignore`, `tests/utilidades.py` (cédula válida). **Pendiente: el usuario debe pegar `DATABASE_URL` (Session pooler de Supabase) en `backend/.env`**; luego `python -m scripts.sembrar --reset` y verificar 9 tablas / 8 aeropuertos / 3 aviones / admin. Desviación: `crear_admin.py` usa werkzeug directo (como indica 1.2).
- [x] Fase 2 – Backend núcleo (usuarios, auth) — **COMPLETADA (2026-11-14)**: `config`, `db`, `errores`, `validaciones`, `seguridad`, servicios `usuarios` y `auth`, `app.py` (catálogo `/`, `/api/salud`, `/docs`). Criterio verificado: registro 201, duplicado 409, cédula inválida 400 con `campos`, login 200, perfil 200/401, logout y reintento 401 (`capturas/fase2_criterio.txt`). Desviaciones: verificado con script Python `requests` en vez de curl (mismas llamadas); blueprints vuelos/reservas/admin/reportes creados vacíos y `openapi.yaml` es un borrador mínimo (se completan en Fases 3-4); el JWT incluye `jti` para que cada token sea único.
- [x] Fase 3 – Backend vuelos, asientos, reservas — **COMPLETADA (2026-11-14)**: `logica/{asientos,precios,historial}.py`, `servicios/vuelos.py` (aeropuertos, búsqueda, detalle, mapa de asientos) y `servicios/reservas.py` (crear, listar, detalle, editar, cancelar, factura XML, historial). Criterio verificado con vuelo de prueba (luego eliminado): crear 201, asiento ocupado 409 con `asientos_no_disponibles`, editar 2→3 cambiando un asiento 200 (disponibles 69), editar a asiento ocupado 409 con reserva intacta, cancelar libera asientos, factura XML parseable, historial creada/modificada/cancelada (`capturas/fase3_criterio.txt`). Desviaciones: (1) en editar/cancelar se bloquea primero el vuelo y luego la reserva (orden global único, evita interbloqueos con la cancelación de vuelos de la Fase 4); (2) la creación está en la función reutilizable `crear_reserva(cur, usuario, datos)` para `sembrar.py`; (3) pruebas ejecutadas con el cliente de pruebas de Flask, sin servidor; (4) observación del esquema: `asientos.reserva_id ON DELETE SET NULL` choca con el CHECK al borrar físicamente una reserva con asientos ocupados; la app nunca borra reservas (solo cancela), así que no afecta; en limpiezas de pruebas se liberan los asientos antes.
- [x] Fase 4 – Backend admin, reportes, OpenAPI — **COMPLETADA (2026-11-14)**: `servicios/admin.py` (aviones, vuelos, manifiesto, reservas, usuarios; `crear_vuelo` reutilizable), `servicios/reportes.py` (dashboard), `static/openapi.yaml` (28 rutas, 33 operaciones, 13 schemas; Swagger en `/docs` muestra las 33) y `scripts/sembrar.py` completo. Semillas verificadas: 17 vuelos, asientos = capacidad del avión, `asientos_disponibles` = asientos libres, 161 reservas demo (~30 % de ocupación en los 10 primeros vuelos). Criterio admin verificado (`capturas/fase4_criterio.txt`): cliente → 403, avión creado, vuelo con asientos = capacidad, solape 409, cancelar vuelo cancela reservas y libera asientos, desactivar usuario revoca token, dashboard con las 4 claves. Desviaciones: (1) `sembrar.py` crea el admin antes de los vuelos (se necesita `creado_por`); (2) cancelar vuelo exige `motivo` (5-200 caracteres); (3) editar vuelo acepta campos parciales y la regla de fecha futura solo se revisa si cambia fecha/hora; (4) cambiar el avión de un vuelo se bloquea si tiene cualquier reserva (también canceladas) porque sus pasajeros referencian asientos; (5) `crear_reserva` (Fase 3) se reutiliza para las reservas demo; (6) el servidor de Render del `servers` en OpenAPI es un nombre provisional hasta la Fase 9; (7) se instaló `pyyaml` solo en el Python global para validar el YAML (no en requirements).
- [x] Fase 5 – Pruebas automatizadas — **COMPLETADA (2026-11-14)**: `tests/{conftest,utilidades,test_usuarios_auth,test_vuelos,test_reservas,test_admin,test_concurrencia}.py` y `postman/AeroTech.postman_collection.json` (v2.1, 6 carpetas, 48 requests, variables `baseUrl/token/tokenAdmin/vueloId/reservaId`, incluye errores 400/401/403/404/409). **Resultado: 97 passed en 32 min 49 s** contra servidor local (`capturas/pytest_local.txt`); incluye 8 hilos sobre el mismo asiento (1×201 y 7×409) y 6 hilos sobre el avión de 10 asientos (3×201, 3×409, `asientos_disponibles`=0, sin duplicados). Desviaciones: (1) al desactivar un usuario sus tokens se revocan, por lo que su token da 401 (no 403 como sugería el plan); el login sí da 403 — el test acepta 401/403; (2) las pruebas son lentas (~20 s por prueba) porque cada petición abre una conexión nueva a Supabase desde Ecuador; en Render (misma región que Supabase) será mucho más rápido; no se agregó pool de conexiones para no añadir dependencias; (3) cada prueba crea su propio vuelo y lo cancela al terminar, así que son repetibles sin resembrar; (4) la colección Postman trae `adminPassword` con un marcador (no se escribe la contraseña real) y hace login automático si falta el token; (5) se añadieron pruebas extra (edad > 110, pasaporte, reutilizar documento tras cancelar, cambio de rol inmediato, edición/cancelación concurrentes, precio ejecutiva).
- [x] Fase 6 – Flutter base y roles — **COMPLETADA (2026-11-14)**: proyecto `cliente_flutter` (windows/web/android; deps http, shared_preferences, intl, fl_chart, flutter_localizations), `config`, `sesion` (singleton + shared_preferences), 10 modelos, 7 servicios (`api_client` con Bearer, timeout 60 s, `ApiException`, 401 → cerrar sesión y volver a Login, banner "Conectando con el servidor…" a los 5 s), `validadores.dart` (mismas reglas del backend), `formatos.dart`, widgets base (campo_texto, estado_chip, vuelo_card, cargando, vacio, error_reintentar), pantallas Login/Registro/Splash y `ClienteHome`/`AdminHome` provisionales (con cerrar sesión). **Criterio:** `flutter analyze` → No issues found; `flutter build web` compila; 8 pruebas de flujo en `test/flujo_auth_test.dart` contra el backend real, todas OK (`capturas/flutter_test_fase6.txt`): cédula inválida bloquea el registro, registro → ClienteHome → cerrar sesión → Login, correo duplicado se muestra bajo el campo, clave incorrecta → SnackBar, login admin → AdminHome → logout, token guardado se valida con /perfil y el rol viene del servidor, token inválido → Login. Desviaciones: (1) la verificación visual en el navegador integrado no pudo teclear en los campos de Flutter web (la herramienta no entrega el texto al motor), por eso el flujo se probó con widget tests contra el backend real; (2) las pruebas encontraron y corrigieron un error real: el splash navegaba dentro de `initState` (ahora usa `addPostFrameCallback`); (3) el login de admin en la prueba lee `ADMIN_CORREO/ADMIN_PASSWORD` de `backend/.env` en tiempo de ejecución (no se copian al código); un intento previo de crear un admin extra directamente en la BD fue bloqueado y se descartó; (4) tras registrarse se hace login automático; (5) se borró de la BD el usuario `test_flutter_*` que crearon las pruebas; (6) no se probó aún en Windows desktop (pendiente en la Fase 11 con capturas).
- [x] Fase 7 – Flutter cliente (mapa de asientos) — **COMPLETADA (2026-11-14)**: `widgets/mapa_asientos/` (`MapaAvion`, `AsientoWidget`, `FuselajePainter`, `LeyendaAsientos`) y `screens/cliente/` (home con NavigationRail/Bar, buscar vuelos, detalle, selección de asientos, datos de pasajeros, resumen, éxito con código, mis reservas, detalle con línea de tiempo del historial, comprobante XML, perfil) más `reserva_flujo.dart`. **Criterio:** `flutter analyze` sin problemas; `test/flujo_cliente_test.dart` (backend real) pasa 2/2 (`capturas/flutter_test_fase7.txt`): buscar → elegir 1A (ejecutiva) + 5A → pasajeros → confirmar ($264.50) → código de 6 caracteres → comprobante XML → editar soltando 5A y eligiendo 6A y 6C (3 asientos, diferencia +$92.00) → historial «Creada/Modificada» → cancelar; y conflicto 409 (otro usuario toma 8C): aviso, mapa recargado con 8C ocupado y 8D conservado. Revisión visual en Chrome (build web servido, sesión inyectada): fuselaje con nariz/parabrisas, alas a la altura de las filas de salida, etiquetas SALIDA rojas, ventanillas, números de fila en el pasillo, ocupados en gris. Desviaciones: (1) el widget se llama `MapaAvion` (el modelo ya se llama `MapaAsientos`); el painter recibe `centrosFilas` en vez de `inicioFilas/altoFila` porque las filas ejecutivas y las de salida tienen alturas distintas, y `shouldRepaint` compara sus campos (el esqueleto devolvía `false`, lo que rompería la vista previa en vivo de la Fase 8); (2) el mapa usa `InteractiveViewer` (zoom 0.3×–2.5×, arrastrar) con botones acercar/alejar/centrar, sin scroll vertical anidado (la rueda del mouse hace zoom); el zoom mínimo se bajó de 0.6× a 0.3× para que el avión completo quepa en pantallas angostas; (3) los datos de un pasajero que pierde su asiento al editar se reutilizan en los asientos nuevos; (4) tras confirmar se regresa a ClienteHome (pestaña Mis reservas); (5) `DetalleReservaScreen` ya soporta modo admin (sin editar, cancelar con motivo) para la Fase 8; (6) la prueba de widgets no puede probar el 409 entre Chrome y Windows reales; se simuló con un segundo usuario por la API. No se probó aún en Windows desktop. (7) limpieza: se borraron los usuarios `test_flutter_*` (hubo que borrar antes sus filas de `historial_reservas` por la FK `usuario_id`; en la BD quedan además los usuarios `test_*` de las corridas de pytest).
- [x] Fase 8 – Flutter admin — **COMPLETADA (2026-11-15)**: `screens/admin/` con `admin_home` (NavigationRail/Drawer + chip ADMIN), `dashboard_screen` (KPIs, barras de ocupación y línea de reservas con fl_chart, rutas top), `vuelos_admin_screen` (filtros, ocupación, ingresos, editar/manifiesto/cancelar con motivo y aviso de N reservas), `vuelo_form_screen`, `manifiesto_screen` (pestañas Mapa en solo lectura y Pasajeros, copiar como texto), `flota_screen` + `avion_form_screen` (vista previa en vivo con `utils/vista_previa.dart`), `reservas_admin_screen` (reutiliza `DetalleReservaScreen` en modo admin) y `usuarios_admin_screen` (switch y rol con confirmación; deshabilitado sobre uno mismo). **Criterio:** `flutter analyze` sin problemas; toda la suite de Flutter pasa 12/12 contra el backend real (`capturas/flutter_test_todas.txt`; `flujo_admin_test.dart` en `capturas/flutter_test_fase8.txt`): crear avión con vista previa (120→10 asientos, configuración inválida bloqueada) → vuelo → el cliente lo ve en la búsqueda y reserva → manifiesto → edición con avión bloqueado → cancelar vuelo (aviso «Se cancelarán 1 reserva», motivo obligatorio) → el cliente ve la reserva cancelada con el motivo → dashboard → buscar reserva por correo → desactivar usuario (token revocado); y un cliente desactivado con la app abierta es expulsado en su siguiente acción y ve «Su sesión ya no es válida…» en Login, sin poder volver a entrar. Revisión visual en Chrome: dashboard con KPIs y gráficos y formulario de avión con vista previa. Errores reales que encontraron las pruebas y se corrigieron: (1) `mostrarError` mostraba «error inesperado» al recibir un texto (afectaba al aviso origen=destino de la búsqueda); (2) FloatingActionButtons de Flota y Vuelos con el mismo Hero tag (`heroTag: null`); (3) dropdowns de filtros desbordaban (`isExpanded`); (4) respuestas atrasadas pisaban búsquedas más nuevas en vuelos/reservas/usuarios (contador de petición); (5) los aviones se listan de más reciente a más antiguo. Desviaciones: (1) el plan dice «403 → Login con mensaje»: al desactivar a un usuario el backend revoca sus tokens, así que la siguiente acción devuelve 401 (y el login 403); el cliente trata ambos casos (401, o 403 «desactivada») cerrando sesión y mostrando el aviso en Login; (2) el formulario de vuelo se verificó por API/edición y apertura (avión bloqueado con reservas); la selección de fecha y hora con los pickers no se automatizó en las pruebas; (3) las pruebas viejas de la Fase 6 se adaptaron a las pantallas reales y su `esperar` ya no usa `pumpAndSettle` (adelantaba el reloj simulado y vencía las llamadas pendientes); (4) `ApiClient.pendientes` se expone para las pruebas; (5) se inyectó una sesión de admin en el navegador para la revisión visual y se revocó al terminar (logout); (6) limpieza: se borraron 138 usuarios de prueba `test_*` con sus reservas, se cancelaron 6 vuelos de prueba y se desactivaron 17 aviones de prueba; la BD quedó con 2 usuarios, 17 vuelos y 161 reservas demo.
- [ ] Fase 9 – Despliegue Render
- [ ] Fase 10 – Arquitectura y contratos
- [ ] Fase 11 – Pruebas documentadas y capturas
