# Arquitectura de AeroTech (APE 4 – Servicios web con SOA)

Sistema distribuido de reservas de vuelos. Cada diagrama está escrito en Mermaid (archivos `docs/*.mmd`, que GitHub dibuja directamente) y también exportado a PNG en `capturas/diagramas/`.

**Pila:** Flutter (Windows, web y Android) ⇄ HTTPS · JSON/XML ⇄ Flask en Render ⇄ PostgreSQL con SSL ⇄ Supabase.

## 1. Arquitectura SOA

Los consumidores (app Flutter de cliente, app Flutter de administrador, Postman y pytest) usan **los mismos servicios** por HTTPS con JSON (y XML para el comprobante). El backend Flask expone 6 servicios independientes (un Blueprint por servicio) detrás de una capa de seguridad con JWT y roles; la lógica de asientos, precios e historial vive en el servidor y accede a PostgreSQL (Supabase) con transacciones y bloqueos. El contrato OpenAPI describe los 6 servicios.

```mermaid
flowchart LR
    subgraph CONS["Consumidores"]
        direction TB
        A["App Flutter<br/>Cliente"]
        B["App Flutter<br/>Administrador"]
        C["Postman"]
        D["pytest"]
    end

    OAS(["Contrato OpenAPI 3.0<br/>/static/openapi.yaml · /docs"])

    subgraph RND["Render · Flask + gunicorn"]
        direction TB
        SEG["Capa de seguridad<br/>JWT · rol leído de la BD"]
        subgraph SRV["6 servicios REST (Blueprints)"]
            direction TB
            S1["Usuarios<br/>/api/usuarios"]
            S2["Autenticación<br/>/api/auth"]
            S3["Vuelos<br/>/api/vuelos · /api/aeropuertos"]
            S4["Reservas<br/>/api/reservas"]
            S5["Administración<br/>/api/admin"]
            S6["Reportes<br/>/api/reportes"]
        end
        LOG["Lógica de negocio<br/>asientos · precios · historial"]
        VAL["Validaciones<br/>fuente de verdad"]
    end

    DB[("PostgreSQL + SSL<br/>Supabase · 9 tablas")]

    A -->|"HTTPS · JSON / XML"| SEG
    B -->|"HTTPS · JSON / XML"| SEG
    C -->|"HTTPS · JSON / XML"| SEG
    D -->|"HTTPS · JSON / XML"| SEG
    SEG --> SRV
    SRV --> VAL
    SRV --> LOG
    LOG -->|"transacciones + FOR UPDATE"| DB
    OAS -.->|"describe"| SRV
```

*PNG:* `capturas/diagramas/01_arquitectura_soa.png` · *fuente:* `docs/01_arquitectura_soa.mmd`

## 2. Casos de uso por rol

El cliente busca vuelos, elige asientos en el mapa del avión, reserva, edita, cancela y descarga el comprobante. El administrador gestiona flota, vuelos, reservas y usuarios, y consulta el dashboard. Ambos comparten el registro/inicio de sesión y la consulta de vuelos.

```mermaid
flowchart TB
    CL(["Cliente"])
    AD(["Administrador"])

    subgraph CLI["Casos de uso del cliente"]
        direction TB
        C1("Reservar vuelo<br/>(elige asientos en el mapa del avión<br/>y escribe los datos de cada pasajero)")
        C3("Editar reserva<br/>(asientos, pasajeros y cantidad)")
        C4("Cancelar reserva")
        C5("Descargar comprobante XML")
        C6("Ver historial de la reserva")
        C7("Editar perfil y contraseña")
    end
    subgraph COM["Casos de uso comunes"]
        direction TB
        U1("Registrarse")
        U2("Iniciar y cerrar sesión")
        U3("Consultar vuelos y aeropuertos")
        U4("Ver mapa de asientos")
    end
    subgraph ADM["Casos de uso del administrador"]
        direction TB
        A1("Gestionar flota de aviones")
        A2("Crear, editar y cancelar vuelos")
        A3("Ver manifiesto de pasajeros")
        A4("Ver todas las reservas y cancelarlas")
        A5("Activar, desactivar y cambiar rol<br/>de usuarios")
        A6("Consultar dashboard de indicadores")
    end

    CL --> CLI
    CL --> COM
    AD --> ADM
    AD --> COM
```

*PNG:* `capturas/diagramas/02_casos_de_uso.png` · *fuente:* `docs/02_casos_de_uso.mmd`

## 3. Componentes y capas

Cliente: `screens → services → api_client` (con `models`, `utils` y `sesion` de apoyo). Servidor: `Blueprints → seguridad → validaciones/lógica → db`.

```mermaid
flowchart TB
    subgraph FL["Cliente Flutter"]
        direction TB
        F1["screens<br/>auth · cliente · admin"]
        F2["widgets<br/>mapa_asientos · vuelo_card · campos"]
        F3["services<br/>auth · usuario · vuelo · reserva · admin · reporte"]
        F4["api_client<br/>Bearer · timeout 60 s · ApiException"]
        F5["models · utils (validadores, formatos) · sesion"]
        F1 --> F2
        F1 --> F3
        F3 --> F4
        F1 --> F5
        F3 --> F5
    end

    subgraph BE["Backend Flask"]
        direction TB
        B1["app.py<br/>create_app · catálogo · /api/salud · /docs"]
        B2["servicios (Blueprints)<br/>usuarios · auth · vuelos · reservas · admin · reportes"]
        B3["seguridad.py<br/>@token_requerido · @rol_requerido"]
        B4["validaciones.py · errores.py"]
        B5["logica<br/>asientos · precios · historial"]
        B6["db.py<br/>transaccion() · serializar()"]
        B1 --> B2
        B2 --> B3
        B2 --> B4
        B2 --> B5
        B5 --> B6
        B3 --> B6
    end

    PG[("PostgreSQL · Supabase")]

    F4 ==>|"HTTPS · JSON / XML"| B1
    B6 -->|"psycopg 3 + SSL"| PG
```

*PNG:* `capturas/diagramas/03_componentes.png` · *fuente:* `docs/03_componentes.mmd`

## 4a. Secuencia: login con JWT

El servidor guarda cada token en la tabla `tokens`; en cada petición se comprueba que siga activo y vigente y se lee el rol y el estado del usuario **de la base de datos** (un cambio de rol o una desactivación aplican de inmediato).

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuario
    participant App as App Flutter
    participant API as API Flask (/api/auth)
    participant BD as PostgreSQL

    U->>App: correo y contraseña
    App->>API: POST /api/auth/login
    API->>BD: SELECT usuario por correo
    BD-->>API: fila (hash, rol, activo)
    alt credenciales incorrectas
        API-->>App: 401 Credenciales incorrectas
    else cuenta desactivada
        API-->>App: 403 Cuenta desactivada
    else correcto
        API->>API: verificar hash pbkdf2:sha256
        API->>API: generar JWT HS256 (sub, nombre, rol, jti, exp)
        API->>BD: INSERT INTO tokens (estado = activo)
        API-->>App: 200 token, expira y usuario
        App->>App: guardar token y enrutar por rol (admin / cliente)
    end
    Note over App,API: En cada llamada posterior: Authorization Bearer token
    App->>API: GET /api/usuarios/perfil
    API->>API: decodificar JWT (401 si expiró o es inválido)
    API->>BD: token activo y vigente + rol y activo del usuario
    BD-->>API: fila o vacío
    API-->>App: 200 perfil (o 401 revocado / 403 desactivada)
```

*PNG:* `capturas/diagramas/04a_secuencia_login.png` · *fuente:* `docs/04a_secuencia_login.mmd`

## 4b. Secuencia: crear reserva (concurrencia)

Toda operación que cambia asientos bloquea primero el vuelo (`SELECT ... FOR UPDATE`) dentro de una sola transacción. Si dos clientes piden el mismo asiento, el segundo espera, el `UPDATE ... WHERE estado = 'disponible'` no encuentra la fila y la transacción hace `ROLLBACK` con 409.

```mermaid
sequenceDiagram
    autonumber
    actor C1 as Cliente A
    actor C2 as Cliente B
    participant API as API Flask (/api/reservas)
    participant BD as PostgreSQL

    C1->>API: POST /api/reservas (asiento 12A + pasajeros)
    C2->>API: POST /api/reservas (asiento 12A + pasajeros)
    API->>API: validar formatos (400 con campos)
    API->>BD: BEGIN
    API->>BD: SELECT vuelo FOR UPDATE (bloquea el vuelo)
    Note over API,BD: Las dos peticiones se serializan por vuelo: la del Cliente B espera aquí
    API->>BD: validar plazo, edades, documentos duplicados
    API->>BD: INSERT reservas RETURNING id
    API->>BD: UPDATE asientos SET ocupado WHERE estado = 'disponible' RETURNING
    BD-->>API: 12A actualizado
    API->>BD: INSERT pasajeros, recontar disponibles, INSERT historial (creada)
    API->>BD: COMMIT
    API-->>C1: 201 Reserva creada (código de 6 caracteres)
    Note over API,BD: Se libera el bloqueo y continúa la petición del Cliente B
    API->>BD: UPDATE asientos ... WHERE estado = 'disponible'
    BD-->>API: 0 filas (12A ya está ocupado)
    API->>BD: ROLLBACK
    API-->>C2: 409 asientos_no_disponibles ["12A"]
```

*PNG:* `capturas/diagramas/04b_secuencia_crear_reserva.png` · *fuente:* `docs/04b_secuencia_crear_reserva.mmd`

## 4c. Secuencia: editar reserva

La edición libera los asientos propios y vuelve a ocuparlos en la misma transacción; si algún asiento ya no está libre, el `ROLLBACK` deja la reserva exactamente como estaba.

```mermaid
sequenceDiagram
    autonumber
    actor C as Cliente
    participant API as API Flask (/api/reservas)
    participant BD as PostgreSQL

    C->>API: PUT /api/reservas/id (nuevos asientos y pasajeros)
    API->>API: validar formatos (400 con campos)
    API->>BD: BEGIN
    API->>BD: SELECT vuelo FOR UPDATE
    API->>BD: SELECT reserva FOR UPDATE
    API->>API: verificar dueño (404), estado confirmada (409) y plazo de 3 h (409)
    API->>BD: guardar estado anterior (asientos y total)
    API->>BD: liberar asientos de la reserva y DELETE pasajeros
    API->>BD: validar edades, salida de emergencia y documentos
    API->>BD: UPDATE asientos SET ocupado WHERE estado = 'disponible'
    alt algún asiento ya no está disponible
        BD-->>API: faltan filas
        API->>BD: ROLLBACK (la reserva queda como estaba)
        API-->>C: 409 asientos_no_disponibles
    else todo disponible
        API->>BD: INSERT pasajeros y UPDATE reservas (cantidad, subtotal, IVA, total)
        API->>BD: recontar disponibles e INSERT historial (modificada: antes y después)
        API->>BD: COMMIT
        API-->>C: 200 reserva actualizada y diferencia de total
    end
```

*PNG:* `capturas/diagramas/04c_secuencia_editar_reserva.png` · *fuente:* `docs/04c_secuencia_editar_reserva.mmd`

## 4d. Secuencia: el administrador cancela un vuelo

Cancelar un vuelo cancela en cascada todas sus reservas confirmadas, libera los asientos y registra el evento en el historial.

```mermaid
sequenceDiagram
    autonumber
    actor A as Administrador
    participant API as API Flask (/api/admin)
    participant BD as PostgreSQL
    actor C as Cliente

    A->>API: PUT /api/admin/vuelos/id/cancelar (motivo)
    API->>API: verificar token y rol admin (403 si es cliente)
    API->>BD: BEGIN
    API->>BD: SELECT vuelo FOR UPDATE
    API->>BD: SELECT reservas confirmadas FOR UPDATE
    loop cada reserva confirmada
        API->>BD: liberar asientos de la reserva
        API->>BD: UPDATE reserva = cancelada (Vuelo cancelado por la aerolínea)
        API->>BD: INSERT historial (cancelada)
    end
    API->>BD: UPDATE vuelo = cancelado y recontar disponibles
    API->>BD: COMMIT
    API-->>A: 200 reservas_afectadas = N
    C->>API: GET /api/reservas/id
    API-->>C: estado cancelada con el motivo
```

*PNG:* `capturas/diagramas/04d_secuencia_admin_cancela_vuelo.png` · *fuente:* `docs/04d_secuencia_admin_cancela_vuelo.mmd`

## 5. Modelo entidad-relación (9 tablas)

Tablas: `usuarios`, `tokens`, `aeropuertos`, `aviones`, `vuelos`, `reservas`, `asientos`, `pasajeros` e `historial_reservas`. Esquema completo en `backend/sql/schema.sql`.

```mermaid
erDiagram
    USUARIOS ||--o{ RESERVAS : "realiza"
    USUARIOS ||--o{ TOKENS : "tiene"
    USUARIOS ||--o{ VUELOS : "crea (admin)"
    USUARIOS ||--o{ HISTORIAL_RESERVAS : "registra"
    AEROPUERTOS ||--o{ VUELOS : "origen"
    AEROPUERTOS ||--o{ VUELOS : "destino"
    AVIONES ||--o{ VUELOS : "opera"
    VUELOS ||--o{ ASIENTOS : "genera"
    VUELOS ||--o{ RESERVAS : "recibe"
    RESERVAS ||--o{ PASAJEROS : "incluye"
    RESERVAS ||--o{ ASIENTOS : "ocupa"
    ASIENTOS ||--o{ PASAJEROS : "asignado a"
    RESERVAS ||--o{ HISTORIAL_RESERVAS : "audita"

    USUARIOS {
        int id PK
        string nombre
        string apellido
        char cedula UK
        char telefono
        string correo UK
        string password_hash
        string rol "admin o cliente"
        bool activo
        timestamptz fecha_registro
    }
    TOKENS {
        int id PK
        int usuario_id FK
        text token
        timestamptz expiracion
        string estado "activo o revocado"
    }
    AEROPUERTOS {
        char codigo PK "IATA"
        string ciudad
        string nombre
        bool activo
    }
    AVIONES {
        int id PK
        string modelo
        string matricula UK
        string configuracion "ABC-DEF"
        string configuracion_ejecutiva
        int filas
        int filas_ejecutiva
        int_array filas_salida
        bool activo
    }
    VUELOS {
        int id PK
        string codigo_vuelo "UK con fecha"
        int avion_id FK
        char origen FK
        char destino FK
        date fecha
        time hora_salida
        time hora_llegada
        numeric precio
        numeric precio_ejecutiva
        int asientos_disponibles
        string estado "programado o cancelado"
        int creado_por FK
    }
    RESERVAS {
        int id PK
        char codigo_reserva UK
        int usuario_id FK
        int vuelo_id FK
        int cantidad_asientos "1 a 9"
        numeric subtotal
        numeric iva
        numeric total
        string estado "confirmada o cancelada"
        char telefono_contacto
        string correo_contacto
        string motivo_cancelacion
    }
    ASIENTOS {
        int id PK
        int vuelo_id FK
        string codigo "UK con vuelo"
        int fila
        char columna
        string clase "ejecutiva o economica"
        bool salida_emergencia
        string estado "disponible u ocupado"
        int reserva_id FK
    }
    PASAJEROS {
        int id PK
        int reserva_id FK
        int asiento_id FK
        string nombres
        string apellidos
        string tipo_documento "cedula o pasaporte"
        string numero_documento
        date fecha_nacimiento
        numeric precio
    }
    HISTORIAL_RESERVAS {
        int id PK
        int reserva_id FK
        int usuario_id FK
        string accion "creada, modificada o cancelada"
        jsonb detalle
        timestamptz fecha
    }
```

*PNG:* `capturas/diagramas/05_er.png` · *fuente:* `docs/05_er.mmd`

## 6a. Estados de la reserva

Una reserva confirmada puede modificarse varias veces; cancelada es un estado final.

```mermaid
stateDiagram-v2
    [*] --> confirmada: crear reserva (201)
    confirmada --> confirmada: editar asientos, pasajeros o cantidad\n(historial: modificada)
    confirmada --> cancelada: cancelar el cliente\n(hasta 3 h antes de la salida)
    confirmada --> cancelada: cancelar el administrador\n(con motivo, en cualquier momento)
    confirmada --> cancelada: el administrador cancela el vuelo
    cancelada --> [*]
    note right of cancelada
        Estado final: no se puede editar
        ni cancelar de nuevo (409).
        Los pasajeros se conservan como histórico.
    end note
```

*PNG:* `capturas/diagramas/06a_estados_reserva.png` · *fuente:* `docs/06a_estados_reserva.mmd`

## 6b. Estados del asiento

La restricción `CHECK ((estado = 'ocupado') = (reserva_id IS NOT NULL))` impide asientos ocupados sin reserva.

```mermaid
stateDiagram-v2
    [*] --> disponible: el administrador crea el vuelo\n(asientos generados según el avión)
    disponible --> ocupado: crear o editar reserva\n(UPDATE ... WHERE estado = disponible)
    ocupado --> disponible: cancelar reserva
    ocupado --> disponible: editar reserva (suelta el asiento)
    ocupado --> disponible: cancelar vuelo
    note right of ocupado
        Un asiento ocupado siempre tiene reserva_id
        (restricción CHECK de la tabla).
        Si dos usuarios lo piden a la vez, solo
        uno lo consigue: el otro recibe 409.
    end note
```

*PNG:* `capturas/diagramas/06b_estados_asiento.png` · *fuente:* `docs/06b_estados_asiento.mmd`

## 7. Despliegue

Los clientes llegan por HTTPS a Render (gunicorn con 2 workers y 4 hilos); Flask se conecta a Supabase (AWS) por el Session pooler con SSL. El código se despliega desde GitHub con el Blueprint `render.yaml`.

```mermaid
flowchart LR
    subgraph PC["PC / navegador del usuario"]
        direction TB
        W["App Flutter Windows"]
        N["App Flutter web (Chrome)"]
        P["Postman · pytest"]
    end

    INT{{"Internet<br/>HTTPS (TLS)"}}

    subgraph RND["Render · plan gratuito"]
        direction TB
        G["gunicorn<br/>2 workers × 4 hilos"]
        F["Flask: app:app<br/>6 servicios + /docs"]
        G --> F
    end

    subgraph SUP["Supabase · AWS"]
        direction TB
        POOL["Session pooler :5432"]
        PG[("PostgreSQL<br/>9 tablas")]
        POOL --> PG
    end

    GH[("GitHub<br/>aerotech-soa")]

    W --> INT
    N --> INT
    P --> INT
    INT --> G
    F -->|"PostgreSQL + SSL<br/>DATABASE_URL"| POOL
    GH -.->|"Blueprint render.yaml<br/>despliegue automático"| RND
```

*PNG:* `capturas/diagramas/07_despliegue.png` · *fuente:* `docs/07_despliegue.mmd`
