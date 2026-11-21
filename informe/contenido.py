# -*- coding: utf-8 -*-
import os
RAIZ = r"C:\SEXTO SEMESTRE\DISTRIBUIDAS\APE4"
CAP = os.path.join(RAIZ, "capturas")
DIA = os.path.join(CAP, "diagramas")


def c(n):
    return os.path.join(CAP, n)


def d(n):
    return os.path.join(DIA, n)


def leer(rel):
    with open(os.path.join(RAIZ, rel), encoding="utf-8") as f:
        return f.read().replace("\r\n", "\n").rstrip("\n")


# ------------------------------------------------------------------ PORTADA
TEMA = "APE 4. Desarrollo de servicios web mediante Arquitectura Orientada a Servicios (SOA)"
NIVEL = "Sexto - A"
ALUMNOS = ["Chachalo Redrobán Joseph Damián", "Paredes Garzón Robert Andrés"]
ASIGNATURA = "Aplicaciones Distribuidas"
DOCENTE = "Ing. Alex Javier Maigua Quinteros, Mg."

# ---------------------------------------------------------------- OBJETIVOS
OBJ_GENERAL = ("Diseñar e implementar una aplicación distribuida basada en una Arquitectura Orientada a Servicios (SOA), "
               "mediante el desarrollo de servicios web REST o SOAP utilizando un framework de desarrollo, garantizando "
               "la interoperabilidad entre los componentes del sistema.")
OBJ_ESPECIFICOS = [
    "Diseñar la arquitectura SOA de un sistema de reservas de vuelos, identificando los seis servicios, sus contratos "
    "OpenAPI, sus proveedores y consumidores, y representándola en diagramas de arquitectura, secuencia, estados, "
    "entidad-relación y despliegue.",
    "Implementar con Flask los servicios de registro de usuarios, autenticación con JWT, consulta de vuelos, reserva de "
    "vuelos y gestión de reservas (más administración y reportes), desplegados en Render y conectados a PostgreSQL en "
    "Supabase, y consumirlos desde una aplicación cliente Flutter mediante HTTPS con datos en JSON y XML.",
    "Verificar la interoperabilidad, la disponibilidad y la confiabilidad de los servicios mediante 97 pruebas "
    "funcionales automatizadas, 14 pruebas de flujo de la aplicación cliente y pruebas de concurrencia, documentando el "
    "manejo de errores y las evidencias con capturas de pantalla.",
]
MODALIDAD = "Presencial"
PRESENCIALES = "12"
NO_PRESENCIALES = "0"

# ------------------------------------------------------------ INSTRUCCIONES
INSTRUCCIONES = [
    ("1. Diseño de la arquitectura SOA", [
        "Diseñar la arquitectura orientada a servicios para una aplicación de gestión de reservas.",
        "Identificar los servicios, contratos, consumidores y proveedores.",
        "Elaborar el diagrama de arquitectura del sistema.",
    ]),
    ("2. Desarrollo de los servicios web", [
        "Implementar los servicios web utilizando ASP.NET Core, WCF, Flask, Spring Boot u otro framework.",
        "Desarrollar al menos los siguientes servicios:",
        "Registro de usuarios.",
        "Autenticación.",
        "Consulta de vuelos.",
        "Reserva de vuelos.",
        "Gestión de reservas.",
        "Documentar los contratos o endpoints implementados.",
    ]),
    ("3. Integración de servicios", [
        "Consumir los servicios desde una aplicación cliente (web, escritorio o móvil).",
        "Verificar el intercambio de información mediante HTTP o HTTPS.",
        "Validar el envío y recepción de datos en formato JSON o XML.",
        "Comprobar la interoperabilidad entre cliente y servidor.",
    ]),
    ("4. Pruebas de funcionamiento", [
        "Ejecutar pruebas funcionales para cada servicio.",
        "Validar las respuestas obtenidas y el manejo de errores.",
        "Documentar las pruebas realizadas mediante capturas de pantalla.",
    ]),
]

MATERIALES = [
    "Inteligencia artificial, TAC",
    "Internet",
    "Bases de datos disponibles en la biblioteca virtual de la Universidad.",
    "Bibliografía de la asignatura.",
    "Material disponible en el aula virtual de la asignatura.",
]
TAC_MARCADAS = ["Inteligencia Artificial"]
TAC_OTROS = ("Flask, PostgreSQL, Supabase, Render, GitHub, Flutter, Postman, pytest, Swagger UI (OpenAPI 3.0), "
             "Mermaid.")
HABILIDADES = ["Liderazgo", "Trabajo en equipo", "Pensamiento crítico"]

# ================================================================ ACTIVIDADES
ACTIVIDADES = [
    ("p", "Con base en las instrucciones de la guía y las recomendaciones del docente, se construyó **AeroTech**, un "
          "sistema distribuido de reservas de vuelos con dos tipos de usuario (cliente y administrador). Una arquitectura "
          "orientada a servicios organiza la aplicación como un conjunto de servicios independientes, cada uno con un "
          "contrato público, que los consumidores invocan a través de la red [1]. La pila final es: aplicación Flutter "
          "(Windows, web y Android) ⇄ HTTPS con JSON y XML ⇄ API Flask desplegada en Render ⇄ PostgreSQL con SSL ⇄ "
          "Supabase. A continuación se detallan las cuatro actividades solicitadas."),
    ("sp",),
    # ---------------------------------------------------------------- 1
    ("h", "1. Diseño de la arquitectura SOA"),
    ("h", "1.1 Servicios, proveedores y consumidores"),
    ("p", "Se definieron seis servicios, cada uno implementado como un Blueprint de Flask independiente (un módulo "
          "Python con su propio prefijo de rutas). Los consumidores son la aplicación Flutter de cliente, la aplicación "
          "Flutter de administrador, Postman y pytest, y todos usan exactamente los mismos servicios. La Tabla "
          "{T:servicios} resume el catálogo; la Figura {F:arq} muestra la arquitectura."),
    ("tbl", "servicios",
     ["#", "Servicio", "Prefijo", "Proveedor (módulo)", "Formato", "Acceso"],
     [["1", "Usuarios", "/api/usuarios", "servicios/usuarios.py", "JSON", "Registro público; resto con JWT"],
      ["2", "Autenticación", "/api/auth", "servicios/auth.py", "JSON", "Login público; logout con JWT"],
      ["3", "Vuelos", "/api/vuelos, /api/aeropuertos", "servicios/vuelos.py", "JSON", "Público"],
      ["4", "Reservas", "/api/reservas", "servicios/reservas.py", "JSON y XML", "JWT (dueño; admin solo cancela)"],
      ["5", "Administración", "/api/admin", "servicios/admin.py", "JSON", "JWT + rol admin"],
      ["6", "Reportes", "/api/reportes", "servicios/reportes.py", "JSON", "JWT + rol admin"]],
     [350, 1350, 2150, 2100, 1000, 2400],
     "Catálogo de servicios SOA, proveedores y forma de acceso."),
    ("fig", "arq", d("01_arquitectura_soa.png"), 15.0,
     "Arquitectura SOA de AeroTech: consumidores, capa de seguridad, seis servicios REST y base de datos."),
    ("h", "1.2 Contratos de los servicios"),
    ("p", "El contrato de cada servicio se publica en formato OpenAPI 3.0 [2] en `/static/openapi.yaml` y se visualiza "
          "de forma interactiva con Swagger UI en `/docs` (Figura {F:swagger}). El documento `docs/contratos.md` "
          "describe, para cada endpoint, el método, la autorización, el cuerpo de la solicitud, la respuesta y los códigos "
          "de error posibles. Los errores se devuelven siempre con el mismo formato "
          "`{\"error\": \"...\", \"campos\": {...}}` y con códigos HTTP coherentes: 400 (validación), 401 (sin sesión), "
          "403 (sin permisos), 404 (no existe) y 409 (conflicto de negocio)."),
    ("fig", "swagger", c("02_swagger_docs.jpg"), 11.5,
     "Documentación interactiva de los contratos en Swagger UI (https://aerotech-api-bbql.onrender.com/docs)."),
    ("h", "1.3 Casos de uso, flujos y modelo de datos"),
    ("p", "Los casos de uso se dividen por rol (Figura {F:cu}). El cliente busca vuelos, elige asientos en un mapa que "
          "simula el avión, reserva, edita, cancela y descarga el comprobante; el administrador gestiona la flota, los "
          "vuelos, las reservas y los usuarios, y consulta el manifiesto y el dashboard. El flujo más crítico, la creación "
          "de una reserva, se modeló con un diagrama de secuencia (Figura {F:sec}) en el que la API bloquea el vuelo, "
          "valida a cada pasajero, ocupa los asientos y registra el historial dentro de una sola transacción."),
    ("fig", "cu", d("02_casos_de_uso.png"), 15.0, "Casos de uso del cliente y del administrador."),
    ("fig", "sec", d("04b_secuencia_crear_reserva.png"), 12.5,
     "Diagrama de secuencia de la creación de una reserva (transacción con bloqueo del vuelo)."),
    ("p", "El modelo relacional tiene nueve tablas (Figura {F:er}): `usuarios`, `tokens`, `aeropuertos`, `aviones`, "
          "`vuelos`, `reservas`, `asientos`, `pasajeros` e `historial_reservas`. Las tablas base de la guía (usuarios, "
          "vuelos, reservas y tokens) se conservaron y se ampliaron. Los asientos se generan automáticamente al crear un "
          "vuelo según la configuración del avión, y las restricciones `UNIQUE (vuelo_id, codigo)` y "
          "`UNIQUE (reserva_id, numero_documento)` impiden duplicados desde la propia base de datos."),
    ("fig", "er", d("05_er.png"), 8.5, "Modelo entidad-relación de la base de datos (9 tablas)."),
    ("p", "El ciclo de vida de una reserva y el despliegue se muestran en las Figuras {F:est} y {F:desp}."),
    ("fig", "est", d("06a_estados_reserva.png"), 8.0, "Diagrama de estados de una reserva."),
    ("fig", "desp", d("07_despliegue.png"), 15.0, "Diagrama de despliegue: Flutter, Render y Supabase."),
    ("sp",),
    # ---------------------------------------------------------------- 2
    ("h", "2. Desarrollo de los servicios web"),
    ("h", "2.1 Framework y estructura del backend"),
    ("p", "Se eligió Flask [3] por ser un microframework ligero que permite organizar cada servicio como un Blueprint "
          "independiente sin imponer una estructura. La conexión a PostgreSQL se hace con `psycopg` 3 y SQL escrito a "
          "mano, sin ORM, de modo que cada consulta y cada bloqueo son visibles. La estructura es:"),
    ("code", "backend/\n├── app.py              # crea la app y registra los 6 Blueprints\n"
             "├── config.py           # variables de entorno (BD, JWT, IVA, plazos)\n"
             "├── db.py               # conexión y transaccion() (commit/rollback)\n"
             "├── seguridad.py        # hash, JWT y decoradores de acceso\n"
             "├── validaciones.py     # cédula (módulo 10), teléfono, correo...\n"
             "├── errores.py          # ErrorApi / ErrorValidacion → JSON uniforme\n"
             "├── servicios/          # usuarios, auth, vuelos, reservas, admin, reportes\n"
             "├── logica/             # asientos (bloqueos), precios, historial\n"
             "├── sql/schema.sql      # esquema de la base de datos\n"
             "├── static/openapi.yaml # contrato OpenAPI\n"
             "├── postman/            # colección de Postman\n"
             "└── tests/              # 97 pruebas pytest"),
    ("h", "2.2 Registro de usuarios y autenticación"),
    ("p", "El registro (`POST /api/usuarios/registro`) valida los datos en el servidor, que es la fuente de verdad: "
          "cédula ecuatoriana con el algoritmo del módulo 10, teléfono `09XXXXXXXX`, correo, contraseña de al menos ocho "
          "caracteres con letra y número. Los errores de varios campos se devuelven juntos con el código HTTP 400 [4], y "
          "un correo o cédula repetidos devuelven 409. El rol siempre es `cliente`: el cuerpo de la solicitud no puede "
          "elegirlo. La contraseña se guarda con `pbkdf2:sha256` y nunca se devuelve."),
    ("p", "El inicio de sesión (`POST /api/auth/login`) devuelve un token JWT firmado con HS256 [5] y válido por 8 horas. "
          "Cada token se registra en la tabla `tokens`, lo que permite revocarlo al cerrar sesión, al cambiar la contraseña "
          "o cuando un administrador desactiva la cuenta. Además, el rol se lee de la base de datos en cada solicitud y no "
          "del token, de modo que un cambio de rol o una desactivación se aplican de inmediato. Un mensaje único "
          "(«Credenciales incorrectas») evita revelar si el correo existe."),
    ("code", "def token_requerido(f):\n"
             "    # 1. firma y expiración\n"
             "    jwt.decode(token, config.JWT_SECRET, algorithms=[\"HS256\"])\n"
             "    # 2. el token debe seguir activo en la tabla tokens; el rol sale de usuarios\n"
             "    SELECT u.id, u.rol, u.activo FROM tokens t JOIN usuarios u ON u.id=t.usuario_id\n"
             "     WHERE t.token=%s AND t.estado='activo' AND t.expiracion > NOW()\n"
             "    # 3. 401 si fue revocado · 403 si la cuenta está desactivada\n"
             "    g.usuario_id, g.rol, g.token = fila[\"id\"], fila[\"rol\"], token"),
    ("h", "2.3 Consulta de vuelos"),
    ("p", "El servicio de vuelos es público: `GET /api/vuelos` filtra por origen, destino, fecha y número de pasajeros y "
          "solo muestra vuelos programados con salida a más de una hora; `GET /api/vuelos/{id}/asientos` entrega el mapa "
          "de asientos del vuelo sin exponer datos de otros pasajeros. Un índice sobre `(origen, destino, fecha)` acelera "
          "la búsqueda."),
    ("h", "2.4 Reserva de vuelos y control de concurrencia"),
    ("p", "El riesgo principal de un sistema de reservas es vender dos veces el mismo asiento cuando varios usuarios "
          "actúan a la vez; es un problema clásico de exclusión mutua en sistemas concurrentes [6]. Se resolvió con "
          "transacciones y bloqueos de fila en PostgreSQL [7]: toda operación que cambia asientos comienza con "
          "`SELECT … FOR UPDATE` sobre el vuelo, lo que serializa las reservas de ese vuelo, y el asiento se ocupa con un "
          "`UPDATE … WHERE estado='disponible'`; si no se actualizan todas las filas pedidas, la transacción completa "
          "hace rollback y se responde 409 con la lista de asientos no disponibles. Para evitar interbloqueos siempre se "
          "bloquea primero el vuelo y después la reserva."),
    ("code", "def bloquear_vuelo(cur, vuelo_id) -> dict:\n"
             "    cur.execute(\"SELECT * FROM vuelos WHERE id=%s FOR UPDATE\", (vuelo_id,))\n\n"
             "def ocupar(cur, vuelo_id, reserva_id, codigos):\n"
             "    cur.execute(\"\"\"UPDATE asientos SET estado='ocupado', reserva_id=%s\n"
             "                   WHERE vuelo_id=%s AND codigo = ANY(%s) AND estado='disponible'\n"
             "                   RETURNING codigo\"\"\", (reserva_id, vuelo_id, codigos))\n"
             "    ...  # faltan asientos → ErrorApi(409, asientos_no_disponibles=[...]) y rollback"),
    ("p", "Las reglas de negocio validadas en el servidor son: de 1 a 9 pasajeros por reserva; edad entre 2 y 110 años "
          "a la fecha del vuelo; al menos un adulto; los asientos de salida de emergencia exigen pasajeros de 15 años o "
          "más; un mismo documento no puede estar dos veces en el mismo vuelo; reservar requiere al menos 1 hora de "
          "anticipación y editar o cancelar, 3 horas. El precio depende de la clase (ejecutiva o económica) y se agrega "
          "un IVA del 15 %."),
    ("h", "2.5 Gestión de reservas, administración y reportes"),
    ("p", "El cliente puede listar sus reservas, ver el detalle, **editar** (agregar o quitar pasajeros, cambiar asientos "
          "con el cálculo de la diferencia de precio), **cancelar** (se liberan los asientos), consultar el historial "
          "de eventos (creada, modificada, cancelada) y obtener el comprobante en **XML** (`GET /api/reservas/{id}/factura`). "
          "Una reserva ajena responde 404 para no revelar que existe. El administrador gestiona la flota de aviones "
          "(con vista previa del mapa), crea, edita y cancela vuelos (la cancelación cancela sus reservas), ve todas las "
          "reservas, el manifiesto de pasajeros, los usuarios y un dashboard con indicadores. Los endpoints de "
          "administración responden 403 a un cliente."),
    ("h", "2.6 Documentación de los endpoints"),
    ("p", "La Tabla {T:endpoints} lista los endpoints principales de los servicios exigidos por la guía; el resto se "
          "describe en el contrato OpenAPI y en `docs/contratos.md`."),
    ("tbl", "endpoints",
     ["Servicio", "Método y ruta", "Acceso", "Respuesta exitosa"],
     [["Usuarios", "POST /api/usuarios/registro", "Público", "201 usuario creado"],
      ["Usuarios", "GET /api/usuarios/perfil", "JWT", "200 perfil y totales"],
      ["Autenticación", "POST /api/auth/login", "Público", "200 token, expiración y usuario"],
      ["Autenticación", "POST /api/auth/logout", "JWT", "200 token revocado"],
      ["Vuelos", "GET /api/vuelos?origen&destino&fecha&pasajeros", "Público", "200 lista de vuelos"],
      ["Vuelos", "GET /api/vuelos/{id}/asientos", "Público", "200 mapa de asientos"],
      ["Reservas", "POST /api/reservas/", "JWT", "201 reserva con totales"],
      ["Reservas", "GET /api/reservas/ · GET /api/reservas/{id}", "JWT", "200 lista o detalle"],
      ["Reservas", "PUT /api/reservas/{id}", "JWT (dueño)", "200 reserva y diferencia"],
      ["Reservas", "PUT /api/reservas/{id}/cancelar", "JWT", "200 cancelada"],
      ["Reservas", "GET /api/reservas/{id}/factura", "JWT", "200 XML"],
      ["Administración", "/api/admin/aviones · vuelos · reservas · usuarios", "Admin", "200/201 según la operación"],
      ["Reportes", "GET /api/reportes/dashboard", "Admin", "200 indicadores y gráficos"]],
     [1500, 3550, 1300, 2650],
     "Endpoints principales de los servicios."),
    ("sp",),
    # ---------------------------------------------------------------- 3
    ("h", "3. Integración de servicios"),
    ("h", "3.1 Despliegue en Render y Supabase"),
    ("p", "La base de datos se creó en Supabase (PostgreSQL con SSL, mediante el Session pooler) y el esquema se aplicó "
          "con `scripts/aplicar_esquema.py`. El código se publicó en GitHub y la API se desplegó en Render [8] mediante "
          "el Blueprint `render.yaml`, que define el comando de compilación, el servidor `gunicorn` con 2 procesos y 4 "
          "hilos y las variables de entorno. Las credenciales (`DATABASE_URL`, `JWT_SECRET`) se configuran solo en el "
          "panel de Render y nunca se versionan. La verificación de salud es `GET /api/salud` (Figura {F:salud}). Con el "
          "plan gratuito, la primera solicitud tras 15 minutos de inactividad puede tardar cerca de un minuto, por lo que "
          "el cliente muestra «Conectando con el servidor…»."),
    ("fig", "salud", c("03_salud_https.jpg"), 9.0,
     "Verificación del servicio desplegado por HTTPS: /api/salud responde estado y base de datos «ok»."),
    ("h", "3.2 Aplicación cliente Flutter"),
    ("p", "El cliente es una aplicación Flutter que se ejecuta en Windows, web y Android y consume la API por HTTPS. "
          "Una clase `ApiClient` agrega el encabezado `Authorization: Bearer`, define un tiempo de espera de 60 s, "
          "convierte los errores en excepciones con el mensaje del servidor y, ante un 401 o una cuenta desactivada, "
          "cierra la sesión y vuelve al inicio de sesión con un aviso. Las mismas reglas de validación del servidor se "
          "replican en el formulario para mejorar la experiencia, pero el servidor sigue siendo la fuente de verdad."),
    ("p", "Siguiendo el comportamiento de las aerolíneas reales, se diseñó una página de inicio pública con el buscador "
          "(Figura {F:landing}) y el inicio de sesión se solicita tarde: el usuario puede buscar, elegir vuelo, asientos "
          "y datos de pasajeros sin cuenta, y la aplicación pide iniciar sesión o registrarse solo en el resumen, justo "
          "antes de confirmar. Al volver, los datos ingresados se conservan; este flujo se verificó con una prueba "
          "automatizada de la aplicación (Resultado 4)."),
    ("fig", "landing", c("00_landing_publica.jpg"), 11.5, "Página de inicio pública con el buscador de vuelos."),
    ("h", "3.3 Intercambio de datos en JSON y XML"),
    ("p", "Todas las solicitudes y respuestas usan JSON, salvo el comprobante de la reserva, que se entrega en XML con "
          "`Content-Type: application/xml`. La Figura {F:xml} muestra el comprobante y la Tabla {T:json} un ejemplo de "
          "ida y vuelta del intercambio al crear una reserva."),
    ("tbl", "json",
     ["Dirección", "Contenido (resumido)"],
     [["Solicitud\nPOST /api/reservas/", "{\"vuelo_id\": 7, \"telefono_contacto\": \"09XXXXXXXX\", \"pasajeros\": [{\"asiento\": \"20A\", "
       "\"nombre\": ..., \"numero_documento\": ..., \"fecha_nacimiento\": ...}, {\"asiento\": \"20B\", ...}]}"],
      ["Respuesta\n201 Created", "{\"mensaje\": \"Reserva creada\", \"reserva\": {\"codigo_reserva\": \"7DV3L6\", "
       "\"asientos\": [\"20A\", \"20B\"], \"subtotal\": 178.0, \"iva\": 26.7, \"total\": 204.7, \"estado\": \"confirmada\"}}"],
      ["Respuesta con conflicto\n409 Conflict", "{\"error\": \"Asientos no disponibles: 20A\", \"asientos_no_disponibles\": [\"20A\"]}"]],
     [2200, 6800],
     "Intercambio JSON al crear una reserva (ejemplo real de la prueba)."),
    ("fig", "xml", c("26_comprobante_xml.jpg"), 12.5, "Comprobante de la reserva recibido en formato XML."),
    ("h", "3.4 Flujo completo del cliente"),
    ("p", "Las Figuras {F:busq} a {F:hist} recorren el flujo del cliente contra el servicio desplegado en Render: "
          "búsqueda de vuelos, mapa de asientos con las filas de salida de emergencia, datos de los pasajeros, "
          "edición de una reserva con el resumen de cambios y su confirmación, listado de reservas e historial de eventos."),
    ("fig", "busq", c("17_cliente_busqueda.jpg"), 10.5, "Resultados de la búsqueda de vuelos."),
    ("fig", "mapa", c("18_cliente_mapa_asientos.png"), 10.5, "Mapa de asientos que simula el avión (libres, ocupados, seleccionados)."),
    ("fig", "emerg", c("18b_cliente_mapa_salidas_emergencia.jpg"), 10.5, "Filas de salida de emergencia marcadas en el mapa."),
    ("fig", "pasaj", c("19_cliente_pasajeros.jpg"), 10.5, "Formulario de datos de los pasajeros con validaciones."),
    ("fig", "resumen", c("20_cliente_resumen.jpg"), 10.5, "Resumen de cambios al editar la reserva: nuevo total, total anterior y diferencia a pagar."),
    ("fig", "exito", c("21_cliente_exito.jpg"), 10.5, "Confirmación de la reserva actualizada con su código y la diferencia."),
    ("fig", "mis", c("23b_cliente_mis_reservas.jpg"), 10.5, "Listado «Mis reservas»."),
    ("fig", "hist", c("24_cliente_historial.jpg"), 10.5, "Historial de eventos de una reserva."),
    ("h", "3.5 Aplicación del administrador"),
    ("p", "El mismo cliente ofrece un panel de administración (Figuras {F:dash} a {F:users}): dashboard con indicadores, "
          "gestión de vuelos, formulario de vuelo con selección de avión, flota con vista previa en vivo del mapa de "
          "asientos, manifiesto de pasajeros y gestión de usuarios."),
    ("fig", "dash", c("28_admin_dashboard.jpg"), 10.5, "Dashboard del administrador: indicadores, ocupación y reservas por día."),
    ("fig", "vuelosadm", c("29_admin_vuelos.jpg"), 10.5, "Gestión de vuelos con ocupación e ingresos."),
    ("fig", "flota", c("31_admin_flota_vista_previa.jpg"), 10.5, "Flota de aviones con vista previa del mapa de asientos."),
    ("fig", "manif", c("32_admin_manifiesto.jpg"), 10.5, "Manifiesto de pasajeros de un vuelo."),
    ("fig", "users", c("33_admin_usuarios.jpg"), 10.5, "Gestión de usuarios: búsqueda, rol y estado."),
    ("sp",),
    # ---------------------------------------------------------------- 4
    ("h", "4. Pruebas de funcionamiento"),
    ("h", "4.1 Estrategia de pruebas"),
    ("p", "Las pruebas se organizaron en cuatro niveles, todos documentados en `docs/pruebas.md` con una tabla por caso "
          "(servicio, rol, entrada, resultado esperado y obtenido, evidencia): (1) 97 pruebas funcionales de la API con "
          "pytest, que usan HTTP real y se ejecutan contra el servidor local o contra Render cambiando solo la variable "
          "`API_URL`; (2) 14 pruebas de flujo de la aplicación Flutter que ejercitan las pantallas reales contra el "
          "backend real, sin simulaciones; (3) pruebas de concurrencia con varios hilos; y (4) pruebas manuales con "
          "capturas de pantalla."),
    ("code", "cd backend\npython -m pytest -v                    # contra el servidor local\n"
             "$env:API_URL=\"https://aerotech-api-bbql.onrender.com\"\npython -m pytest -v                    # contra Render\n\n"
             "cd ..\\cliente_flutter\n"
             "flutter test --dart-define=API_URL=https://aerotech-api-bbql.onrender.com"),
    ("h", "4.2 Problemas encontrados y cómo se resolvieron"),
    ("p", "Las pruebas y las capturas permitieron detectar y corregir varios problemas reales:"),
    ("b", "**Datos del pasajero perdidos tras un conflicto 409.** Al perder un asiento frente a otro usuario, la "
          "aplicación borraba los datos del pasajero asignado a ese asiento aunque el aviso decía que se conservaban. "
          "Se corrigió para reasignarlos al nuevo asiento y se cubrió con una prueba de flujo."),
    ("b", "**Lista «Mis reservas» lenta.** El usuario de demostración tiene 163 reservas y la lista tardaba 22 s por "
          "hacer consultas por cada reserva. Se reescribió con tres consultas por lote y bajó a 3,8 s."),
    ("b", "**Navegación del splash.** El splash navegaba dentro de `initState`; se movió a un "
          "callback posterior al primer fotograma."),
    ("b", "**Gráfico del dashboard.** La curva suavizada bajaba de cero entre días con pocos datos; se cambió a líneas rectas."),
    ("b", "**Datos de prueba acumulados en la base compartida.** Tras cada corrida se eliminaron los usuarios, vuelos y "
          "aviones `test_*`, de modo que la base queda con los datos de demostración."),
    ("sp",),
]

# ================================================================== RESULTADOS
RESULTADOS = [
    ("p", "Los resultados se obtuvieron ejecutando las pruebas contra el backend local y contra el servicio desplegado "
          "en Render (https://aerotech-api-bbql.onrender.com). La salida completa se conserva en el repositorio, en la "
          "carpeta `capturas/`."),
    ("h", "Resultado 1. Arquitectura SOA diseñada y documentada"),
    ("p", "Se obtuvo una arquitectura de seis servicios REST con sus contratos OpenAPI, once diagramas (arquitectura, "
          "casos de uso, componentes, cuatro de secuencia, entidad-relación, dos de estados y despliegue) y los "
          "documentos `docs/arquitectura.md` y `docs/contratos.md`. La Tabla {T:res_dis} resume los entregables."),
    ("tbl", "res_dis",
     ["Entregable", "Contenido", "Ubicación"],
     [["Contratos", "6 servicios, 33 operaciones, reglas de negocio y códigos HTTP", "static/openapi.yaml, docs/contratos.md"],
      ["Diagramas", "11 diagramas Mermaid con su PNG", "docs/*.mmd, capturas/diagramas/"],
      ["Modelo de datos", "9 tablas con restricciones e índices", "backend/sql/schema.sql"],
      ["Despliegue", "Blueprint de Render y variables de entorno", "render.yaml"]],
     [1700, 4300, 3000],
     "Entregables del diseño de la arquitectura."),
    ("h", "Resultado 2. Servicios web implementados y desplegados"),
    ("p", "Los cinco servicios exigidos por la guía (registro, autenticación, consulta de vuelos, reserva y gestión de "
          "reservas), más administración y reportes, están implementados y responden por HTTPS en Render. El servicio de "
          "salud confirmó la conexión a la base de datos de Supabase (Figura {F:salud}) y la documentación interactiva "
          "está disponible en `/docs` (Figura {F:swagger})."),
    ("h", "Resultado 3. Pruebas funcionales de la API (pytest)"),
    ("p", "Las 97 pruebas pasaron tanto en local como en Render (Tabla {T:pytest}). Cubren las respuestas correctas, la "
          "validación de datos y el manejo de errores 400, 401, 403, 404 y 409 de cada servicio."),
    ("tbl", "pytest",
     ["Archivo", "Servicio", "Casos", "Qué verifica", "Resultado"],
     [["test_usuarios_auth.py", "Usuarios y autenticación", "20", "Registro, validaciones, login, token, perfil, contraseña, logout", "20 passed"],
      ["test_vuelos.py", "Vuelos", "9", "Aeropuertos, filtros, detalle, mapa de asientos, parámetros inválidos", "9 passed"],
      ["test_reservas.py", "Reservas", "31", "Crear, editar, cancelar, reglas de edad y salida de emergencia, documentos, XML, historial", "31 passed"],
      ["test_admin.py", "Administración y reportes", "34", "Permisos por rol, aviones, vuelos, solapamientos, manifiesto, usuarios, dashboard", "34 passed"],
      ["test_concurrencia.py", "Reservas (concurrencia)", "3", "Ocho usuarios sobre el mismo asiento, sin sobreventa, edición y cancelación simultáneas", "3 passed"],
      ["Total", "", "97", "", "97 passed"]],
     [1850, 1600, 650, 3200, 1700],
     "Resultado de las 97 pruebas pytest por archivo."),
    ("code", "======================= 97 passed in 1068.61s (0:17:48) =======================\n"
             "(API_URL=https://aerotech-api-bbql.onrender.com, gunicorn 2 procesos x 4 hilos)"),
    ("h", "Resultado 4. Interoperabilidad entre cliente y servidor"),
    ("p", "El mismo servicio respondió de forma idéntica a tres clientes distintos: la aplicación Flutter, Postman y "
          "pytest (cliente HTTP `requests`), todos por HTTPS con JSON y, en el comprobante, XML. Las 14 pruebas de flujo de "
          "Flutter, que usan las pantallas reales y el backend real, pasaron correctamente (Tabla {T:flutter})."),
    ("tbl", "flutter",
     ["Archivo de prueba", "Casos", "Flujo verificado"],
     [["flujo_auth_test.dart", "9", "Validador de cédula (módulo 10) igual al del backend, registro con cédula inválida, registro y cierre de sesión, correo duplicado, clave incorrecta, login de administrador, token guardado validado con /perfil, token vencido (entra como visitante) y página de inicio pública"],
      ["flujo_publico_test.dart", "1", "Visitante que busca, elige asientos y llena pasajeros sin cuenta; el login se pide al final y la reserva continúa"],
      ["flujo_cliente_test.dart", "2", "Reservar, comprobante, editar a 3 asientos, historial y cancelar; conflicto 409 con aviso, mapa actualizado y datos conservados"],
      ["flujo_admin_test.dart", "2", "Avión con vista previa, vuelo, reserva de cliente, manifiesto, cancelar vuelo, dashboard y desactivar cliente; el cliente desactivado es expulsado y ve el motivo"],
      ["Total", "14", "All tests passed"]],
     [2200, 700, 6100],
     "Pruebas de flujo de la aplicación Flutter contra el backend real."),
    ("h", "Resultado 5. Confiabilidad ante concurrencia"),
    ("p", "En Render, con ocho usuarios intentando reservar el mismo asiento al mismo tiempo, se obtuvo exactamente una "
          "respuesta 201 y siete 409, sin sobreventa. En un vuelo pequeño con más compradores que asientos nunca se "
          "reservaron más asientos de los existentes, y la edición y cancelación simultáneas dejaron un estado "
          "consistente (Tabla {T:conc}). El conflicto se muestra al usuario con un aviso y el mapa actualizado (Figura {F:c409})."),
    ("tbl", "conc",
     ["Prueba", "Entrada", "Esperado", "Obtenido"],
     [["Mismo asiento", "8 hilos reservan el mismo asiento", "1 × 201 y 7 × 409", "1 × 201 y 7 × 409"],
      ["Sin sobreventa", "Más compradores que asientos", "Reservas ≤ asientos", "Cumplido"],
      ["Edición y cancelación", "Hilos simultáneos sobre una reserva", "Estado final consistente", "Cumplido"]],
     [1800, 3000, 2200, 2000],
     "Pruebas de concurrencia en Render."),
    ("fig", "c409", c("27_conflicto_409.jpg"), 10.5, "Conflicto 409 en la aplicación: aviso y mapa de asientos actualizado."),
    ("h", "Resultado 6. Manejo de errores y seguridad"),
    ("p", "Los errores se devuelven con un formato uniforme y el código HTTP correcto (Tabla {T:errores}). Las pantallas "
          "muestran el mensaje del servidor bajo el campo correspondiente (Figura {F:valid})."),
    ("tbl", "errores",
     ["Situación", "Código", "Mensaje"],
     [["Datos inválidos (cédula, teléfono, contraseña)", "400", "Errores por campo en el mismo formato"],
      ["Sin token, token inválido o revocado", "401", "Token requerido / Token inválido / Sesión cerrada o token revocado"],
      ["Cliente llama a un endpoint de administrador", "403", "No tiene permisos para esta operación"],
      ["Reserva de otro usuario", "404", "Reserva no encontrada"],
      ["Asiento ocupado, correo o documento repetido", "409", "Asientos no disponibles / El correo ya está registrado"]],
     [3600, 800, 4600],
     "Códigos de error verificados con pytest."),
    ("fig", "valid", c("16_app_registro_validaciones.jpg"), 10.5, "Validaciones del registro mostradas bajo cada campo."),
    ("h", "Resumen de pruebas ejecutadas"),
    ("tbl", "resumen",
     ["#", "Prueba", "Comando o herramienta", "Resultado"],
     [["1", "Servicios, roles y validaciones de la API", "pytest -v (local)", "97 passed"],
      ["2", "Los mismos casos contra el despliegue", "API_URL=Render pytest -v", "97 passed en 17 min 48 s"],
      ["3", "Flujos de la aplicación cliente", "flutter test --dart-define=API_URL=...", "14 passed"],
      ["4", "Concurrencia sobre el mismo asiento", "pytest test_concurrencia.py", "1 × 201 y 7 × 409, sin sobreventa"],
      ["5", "Salud y base de datos por HTTPS", "GET /api/salud", "200, estado y bd «ok»"],
      ["6", "Contratos publicados", "Swagger UI en /docs", "6 servicios documentados"],
      ["7", "Flujo manual del cliente y del administrador", "App Flutter web contra Render", "22 pruebas manuales correctas"],
      ["8", "Comprobante en XML", "GET /api/reservas/{id}/factura", "200, XML válido"]],
     [450, 3100, 2900, 2550],
     "Resumen de las pruebas ejecutadas y sus resultados."),
]

# ================================================================ CONCLUSIONES
CONCLUSIONES = [
    "El diseño de la arquitectura SOA permitió dividir el sistema de reservas en seis servicios independientes, cada uno "
    "con su contrato OpenAPI, su proveedor y sus consumidores, y representar el sistema con once diagramas. Separar los "
    "servicios en Blueprints y centralizar las reglas de negocio en el servidor hizo que la aplicación Flutter, Postman y "
    "pytest consumieran exactamente los mismos servicios.",
    "La implementación con Flask, PostgreSQL en Supabase y el despliegue en Render produjo servicios que gestionan de "
    "forma eficiente y segura las reservas: JWT revocable con el rol leído de la base de datos, contraseñas con "
    "pbkdf2:sha256, validaciones en el servidor y transacciones con bloqueo de fila que evitan la sobreventa (1 respuesta "
    "201 y 7 respuestas 409 con ocho usuarios sobre el mismo asiento). La aplicación Flutter consumió los servicios por "
    "HTTPS con JSON y XML.",
    "La evaluación mediante 97 pruebas de la API (en local y en Render), 14 pruebas de flujo de la aplicación y pruebas "
    "de concurrencia confirmó la interoperabilidad, la confiabilidad y el correcto manejo de errores de los servicios. "
    "Las pruebas también detectaron problemas reales (datos del pasajero perdidos tras un 409 y una lista que tardaba 22 s) "
    "que se corrigieron, y evidenciaron que el plan gratuito de Render introduce una demora inicial tras la inactividad.",
]
RECOMENDACIONES = [
    "Definir primero el contrato de cada servicio y los códigos de error antes de programar, porque así el backend y el "
    "cliente pueden desarrollarse y probarse en paralelo sin ambigüedades.",
    "Validar en el servidor todas las reglas de negocio y replicarlas en el cliente solo para mejorar la experiencia, "
    "y proteger las operaciones críticas con transacciones y bloqueos de fila para evitar condiciones de carrera.",
    "Probar siempre contra el servicio desplegado y no solo en local, y limpiar los datos de prueba después de cada "
    "corrida, ya que los tiempos de respuesta y los datos acumulados pueden revelar errores que el entorno local oculta.",
    "No versionar credenciales: guardar DATABASE_URL y JWT_SECRET en variables de entorno de la plataforma de "
    "despliegue y cambiar las contraseñas de demostración antes de poner el sistema en uso real.",
]
REFERENCIAS = [
    "A. Cardador, Desarrollo de aplicaciones web distribuidas, 1.ª ed., IC Editorial, 2024.",
    "OpenAPI Initiative, «OpenAPI Specification v3.0.3». [En línea]. Disponible en: https://spec.openapis.org/oas/v3.0.3. "
    "[Consultado: 21-nov-2026].",
    "Pallets, «Flask Documentation». [En línea]. Disponible en: https://flask.palletsprojects.com/. [Consultado: 21-nov-2026].",
    "R. Fielding, M. Nottingham y J. Reschke, Eds., «HTTP Semantics», IETF, RFC 9110, jun. 2022. [En línea]. Disponible en: "
    "https://www.rfc-editor.org/rfc/rfc9110. [Consultado: 21-nov-2026].",
    "M. Jones, J. Bradley y N. Sakimura, «JSON Web Token (JWT)», IETF, RFC 7519, may. 2015. [En línea]. Disponible en: "
    "https://www.rfc-editor.org/rfc/rfc7519. [Consultado: 21-nov-2026].",
    "E. Argente, A. Espinosa, P. Galdámez y D. Muñoz, Concurrencia y sistemas distribuidos, Valencia, España: Editorial "
    "Universitat Politècnica de València, 2013.",
    "The PostgreSQL Global Development Group, «Explicit Locking», PostgreSQL Documentation. [En línea]. Disponible en: "
    "https://www.postgresql.org/docs/current/explicit-locking.html. [Consultado: 21-nov-2026].",
    "Render Services Inc., «Blueprint Specification (render.yaml)», Render Docs. [En línea]. Disponible en: "
    "https://render.com/docs/blueprint-spec. [Consultado: 21-nov-2026].",
]

_res = leer(r"backend\servicios\reservas.py").split("\n")
_ini = next(i for i, l in enumerate(_res) if l.startswith("def crear_reserva"))
_fin = next(i for i, l in enumerate(_res) if i > _ini and l.startswith("def _usuario_actual"))
_crear = "\n".join(_res[_ini:_fin]).rstrip()
ANEXOS = [
    ("Anexo A. Esquema de la base de datos (schema.sql).", "backend/sql/schema.sql", leer(r"backend\sql\schema.sql")),
    ("Anexo B. Seguridad: hash de contraseñas, JWT y decoradores de autorización (seguridad.py).",
     "backend/seguridad.py", leer(r"backend\seguridad.py")),
    ("Anexo C. Control de asientos con bloqueos (logica/asientos.py).", "backend/logica/asientos.py",
     leer(r"backend\logica\asientos.py")),
    ("Anexo D. Creación transaccional de una reserva (fragmento de servicios/reservas.py).",
     "backend/servicios/reservas.py", _crear),
    ("Anexo E. Blueprint de despliegue en Render (render.yaml).", "render.yaml", leer("render.yaml")),
]
