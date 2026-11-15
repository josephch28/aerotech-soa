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
