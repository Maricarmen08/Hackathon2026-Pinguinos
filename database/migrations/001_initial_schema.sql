-- Migracion 001. SOLO MySQL 8.4, base nueva hackathon_pinguinos_dev.
-- No ejecutar schema.sql de V0.1. Leer database/README.md antes de importar.
-- DDL hace COMMIT implicito: un fallo parcial exige inspeccion, NO reintento ciego.
USE hackathon_pinguinos_dev;
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION time_zone = '+00:00';
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

DELIMITER $$
CREATE PROCEDURE hackathon_pinguinos_dev.dbv1_aplicar_001()
SQL SECURITY INVOKER
BEGIN
  DECLARE v_lock INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    IF v_lock = 1 THEN DO RELEASE_LOCK('hackathon_pinguinos_dev:migraciones'); END IF;
    RESIGNAL;
  END;
  IF DATABASE() <> 'hackathon_pinguinos_dev' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Base destino incorrecta';
  END IF;
  IF SUBSTRING_INDEX(VERSION(), '.', 2) <> '8.4' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Se requiere MySQL 8.4';
  END IF;
  SELECT GET_LOCK('hackathon_pinguinos_dev:migraciones', 0) INTO v_lock;
  IF v_lock IS NULL OR v_lock <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Otra migracion tiene el bloqueo';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE()) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '001 requiere base sin tablas ni vistas; inspeccionar estado/migraciones';
  END IF;

  CREATE TABLE schema_migraciones (
    version INT NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    contrato_version VARCHAR(20) NOT NULL,
    aplicada_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (version)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE schema_semillas (
    version INT NOT NULL,
    nombre VARCHAR(160) NOT NULL,
    aplicada_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (version)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE usuarios (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    telefono_normalizado VARCHAR(20) NOT NULL,
    correo_normalizado VARCHAR(254) NULL,
    password_hash VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NULL,
    estado VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'ACTIVO',
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    CONSTRAINT ck_usuarios_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_usuarios_telefono (telefono_normalizado),
    UNIQUE KEY uq_usuarios_correo (correo_normalizado),
    CONSTRAINT ck_usuarios_estado CHECK (estado IN ('ACTIVO', 'BLOQUEADO')),
    CONSTRAINT ck_usuarios_hash CHECK ((estado = 'BLOQUEADO' AND password_hash IS NULL) OR (password_hash IS NOT NULL AND (password_hash LIKE '$argon2id$%' OR password_hash LIKE '$scrypt$%'))),
    CONSTRAINT ck_usuarios_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0),
    CONSTRAINT ck_usuarios_version CHECK (version >= 1)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE dispositivos (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    usuario_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    plataforma VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    ultimo_acceso_en DATETIME(6) NULL,
    revocado_en DATETIME(6) NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    CONSTRAINT ck_dispositivos_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_dispositivos_usuario (usuario_id, id),
    CONSTRAINT fk_dispositivos_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
    CONSTRAINT ck_dispositivos_plataforma CHECK (plataforma IN ('ANDROID', 'IOS', 'WEB', 'OTRO')),
    CONSTRAINT ck_dispositivos_version CHECK (version >= 1)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE sesiones (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    dispositivo_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    refresh_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    familia_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    expira_en DATETIME(6) NOT NULL,
    revocado_en DATETIME(6) NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    CONSTRAINT ck_sesiones_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_sesiones_refresh (refresh_hash),
    KEY ix_sesiones_dispositivo (dispositivo_id, revocado_en, expira_en),
    KEY ix_sesiones_familia (familia_id),
    CONSTRAINT fk_sesiones_dispositivo FOREIGN KEY (dispositivo_id) REFERENCES dispositivos (id),
    CONSTRAINT ck_sesiones_expira CHECK (expira_en > creado_en)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE negocios (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    rubro VARCHAR(80) NOT NULL,
    documento_tipo VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NULL,
    documento_numero VARCHAR(20) NULL,
    ciudad VARCHAR(80) NULL,
    zona_horaria VARCHAR(64) NOT NULL DEFAULT 'America/Lima',
    moneda CHAR(3) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'PEN',
    inicio_historial DATE NOT NULL,
    estado VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'ACTIVO',
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    CONSTRAINT ck_negocios_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    CONSTRAINT ck_negocios_estado CHECK (estado IN ('ACTIVO', 'ARCHIVADO')),
    CONSTRAINT ck_negocios_moneda CHECK (moneda = 'PEN'),
    CONSTRAINT ck_negocios_documento CHECK ((documento_tipo IS NULL AND documento_numero IS NULL) OR (documento_tipo IS NOT NULL AND documento_numero IS NOT NULL AND documento_tipo IN ('DNI','RUC','OTRO'))),
    CONSTRAINT ck_negocios_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0),
    CONSTRAINT ck_negocios_version CHECK (version >= 1)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE membresias (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    usuario_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    rol VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    estado VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'ACTIVA',
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    PRIMARY KEY (id),
    CONSTRAINT ck_membresias_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_membresias_negocio_id (negocio_id, id),
    UNIQUE KEY uq_membresias_usuario (negocio_id, usuario_id),
    KEY ix_membresias_acceso (usuario_id, estado, negocio_id),
    CONSTRAINT fk_membresias_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_membresias_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios (id),
    CONSTRAINT fk_membresias_autor FOREIGN KEY (creado_por) REFERENCES usuarios (id),
    CONSTRAINT ck_membresias_rol CHECK (rol IN ('PROPIETARIO', 'OPERADOR', 'LECTOR')),
    CONSTRAINT ck_membresias_estado CHECK (estado IN ('ACTIVA', 'REVOCADA')),
    CONSTRAINT ck_membresias_version CHECK (version >= 1)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE categorias (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    nombre_normalizado VARCHAR(80) NOT NULL,
    tipo VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    icono VARCHAR(40) NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_categorias_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_categorias_negocio_id (negocio_id, id),
    CONSTRAINT fk_categorias_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_categorias_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_categorias_version CHECK (version >= 1),
    UNIQUE KEY uq_categorias_nombre (negocio_id, tipo, nombre_normalizado),
    CONSTRAINT ck_categorias_tipo CHECK (tipo IN ('VENTA', 'COMPRA_MERCADERIA', 'GASTO_OPERATIVO')),
    CONSTRAINT ck_categorias_activa CHECK (activa IN (0,1)),
    CONSTRAINT ck_categorias_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0 AND CHAR_LENGTH(TRIM(nombre_normalizado)) > 0)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE terceros (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    nombre VARCHAR(120) NOT NULL,
    telefono VARCHAR(20) NULL,
    documento_tipo VARCHAR(10) CHARACTER SET ascii COLLATE ascii_bin NULL,
    documento_numero VARCHAR(20) NULL,
    notas VARCHAR(500) NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_terceros_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_terceros_negocio_id (negocio_id, id),
    CONSTRAINT fk_terceros_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_terceros_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_terceros_version CHECK (version >= 1),
    UNIQUE KEY uq_terceros_documento (negocio_id, documento_tipo, documento_numero),
    KEY ix_terceros_nombre (negocio_id, nombre),
    CONSTRAINT ck_terceros_documento CHECK ((documento_tipo IS NULL AND documento_numero IS NULL) OR (documento_tipo IS NOT NULL AND documento_numero IS NOT NULL AND documento_tipo IN ('DNI','RUC','OTRO'))),
    CONSTRAINT ck_terceros_activo CHECK (activo IN (0,1)),
    CONSTRAINT ck_terceros_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE cuentas (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    tipo VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    moneda CHAR(3) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'PEN',
    saldo_inicial_minor BIGINT NOT NULL DEFAULT 0,
    fecha_apertura DATE NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_cuentas_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_cuentas_negocio_id (negocio_id, id),
    CONSTRAINT fk_cuentas_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_cuentas_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_cuentas_version CHECK (version >= 1),
    UNIQUE KEY uq_cuentas_nombre (negocio_id, nombre),
    CONSTRAINT ck_cuentas_tipo CHECK (tipo IN ('EFECTIVO', 'BANCO', 'YAPE', 'PLIN')),
    CONSTRAINT ck_cuentas_moneda CHECK (moneda = 'PEN'),
    CONSTRAINT ck_cuentas_saldo CHECK (saldo_inicial_minor BETWEEN -100000000000000 AND 100000000000000),
    CONSTRAINT ck_cuentas_activa CHECK (activa IN (0,1)),
    CONSTRAINT ck_cuentas_nombre CHECK (CHAR_LENGTH(TRIM(nombre)) > 0)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE comprobantes (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    tipo VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    storage_key VARCHAR(500) NULL,
    nombre_original VARCHAR(255) NULL,
    mime_type VARCHAR(100) NOT NULL,
    bytes BIGINT NOT NULL,
    sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    estado_archivo VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'PENDIENTE',
    emisor_nombre VARCHAR(160) NULL,
    emisor_documento VARCHAR(30) NULL,
    serie VARCHAR(20) NULL,
    numero VARCHAR(40) NULL,
    fecha_documento DATE NULL,
    total_minor BIGINT NULL,
    moneda CHAR(3) CHARACTER SET ascii COLLATE ascii_bin NULL,
    referencia_externa VARCHAR(120) NULL,
    archivo_eliminado_en DATETIME(6) NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_comprobantes_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_comprobantes_negocio_id (negocio_id, id),
    CONSTRAINT fk_comprobantes_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_comprobantes_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_comprobantes_version CHECK (version >= 1),
    KEY ix_comprobantes_hash (negocio_id, sha256),
    KEY ix_comprobantes_ref (negocio_id, referencia_externa),
    CONSTRAINT ck_comprobantes_tipo CHECK (tipo IN ('BOLETA', 'FACTURA', 'TICKET', 'YAPE', 'PLIN', 'TRANSFERENCIA', 'APUNTE', 'AUDIO', 'OTRO')),
    CONSTRAINT ck_comprobantes_estado_archivo CHECK (estado_archivo IN ('PENDIENTE', 'DISPONIBLE', 'RECHAZADO', 'ELIMINADO')),
    CONSTRAINT ck_comprobantes_bytes CHECK (bytes BETWEEN 1 AND 26214400),
    CONSTRAINT ck_comprobantes_total CHECK (total_minor IS NULL OR total_minor BETWEEN 1 AND 100000000000000),
    CONSTRAINT ck_comprobantes_moneda CHECK (moneda IS NULL OR moneda = 'PEN'),
    CONSTRAINT ck_comprobantes_archivo CHECK ((estado_archivo <> 'DISPONIBLE' OR storage_key IS NOT NULL) AND ((estado_archivo = 'ELIMINADO' AND archivo_eliminado_en IS NOT NULL) OR (estado_archivo <> 'ELIMINADO' AND archivo_eliminado_en IS NULL)))
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE extracciones (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    comprobante_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    tipo_entrada VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    texto_entrada TEXT NULL,
    texto_extraido TEXT NULL,
    proveedor VARCHAR(80) NULL,
    modelo VARCHAR(120) NULL,
    version_esquema VARCHAR(20) NOT NULL,
    estado VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'PENDIENTE',
    resultado JSON NULL,
    correccion_usuario JSON NULL,
    errores JSON NULL,
    codigo_error VARCHAR(60) NULL,
    confirmada_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    confirmada_en DATETIME(6) NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_extracciones_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_extracciones_negocio_id (negocio_id, id),
    CONSTRAINT fk_extracciones_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_extracciones_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_extracciones_version CHECK (version >= 1),
    CONSTRAINT fk_extracciones_comprobante_id FOREIGN KEY (negocio_id, comprobante_id) REFERENCES comprobantes (negocio_id, id),
    CONSTRAINT fk_extracciones_confirma FOREIGN KEY (negocio_id, confirmada_por) REFERENCES membresias (negocio_id, usuario_id),
    KEY ix_extracciones_cola (negocio_id, estado, creado_en),
    CONSTRAINT ck_extracciones_tipo_entrada CHECK (tipo_entrada IN ('TEXTO', 'AUDIO', 'IMAGEN')),
    CONSTRAINT ck_extracciones_estado CHECK (estado IN ('PENDIENTE', 'PROCESANDO', 'REQUIERE_REVISION', 'CONFIRMADA', 'FALLIDA')),
    CONSTRAINT ck_extracciones_entrada CHECK ((tipo_entrada = 'TEXTO' AND texto_entrada IS NOT NULL AND CHAR_LENGTH(TRIM(texto_entrada)) > 0) OR (tipo_entrada IN ('AUDIO','IMAGEN') AND comprobante_id IS NOT NULL)),
    CONSTRAINT ck_extracciones_confirmacion CHECK ((estado = 'CONFIRMADA' AND confirmada_por IS NOT NULL AND confirmada_en IS NOT NULL AND resultado IS NOT NULL) OR (estado <> 'CONFIRMADA' AND confirmada_por IS NULL AND confirmada_en IS NULL)),
    CONSTRAINT ck_extracciones_error CHECK (estado <> 'FALLIDA' OR codigo_error IS NOT NULL)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE operaciones (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    tipo VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    tercero_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    categoria_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    concepto VARCHAR(240) NOT NULL,
    total_minor BIGINT NOT NULL,
    fecha_operacion DATE NOT NULL,
    ocurrido_en DATETIME(6) NULL,
    condicion VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    vence_el DATE NULL,
    origen VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    extraccion_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    estado VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'CONFIRMADO',
    anulado_en DATETIME(6) NULL,
    anulado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    motivo_anulacion VARCHAR(300) NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_operaciones_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_operaciones_negocio_id (negocio_id, id),
    CONSTRAINT fk_operaciones_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_operaciones_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_operaciones_version CHECK (version >= 1),
    CONSTRAINT fk_operaciones_tercero_id FOREIGN KEY (negocio_id, tercero_id) REFERENCES terceros (negocio_id, id),
    CONSTRAINT fk_operaciones_categoria_id FOREIGN KEY (negocio_id, categoria_id) REFERENCES categorias (negocio_id, id),
    CONSTRAINT fk_operaciones_extraccion_id FOREIGN KEY (negocio_id, extraccion_id) REFERENCES extracciones (negocio_id, id),
    CONSTRAINT ck_operaciones_estado CHECK (estado IN ('CONFIRMADO', 'ANULADO')),
    CONSTRAINT fk_operaciones_anulado_por FOREIGN KEY (negocio_id, anulado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_operaciones_anulacion CHECK ((estado = 'CONFIRMADO' AND anulado_en IS NULL AND anulado_por IS NULL AND motivo_anulacion IS NULL) OR (estado = 'ANULADO' AND anulado_en IS NOT NULL AND anulado_por IS NOT NULL AND motivo_anulacion IS NOT NULL AND CHAR_LENGTH(TRIM(motivo_anulacion)) > 0)),
    CONSTRAINT ck_operaciones_total_minor CHECK (total_minor BETWEEN 1 AND 100000000000000),
    CONSTRAINT ck_operaciones_tipo CHECK (tipo IN ('VENTA', 'COMPRA_MERCADERIA', 'GASTO_OPERATIVO', 'SALDO_CXC', 'SALDO_CXP')),
    CONSTRAINT ck_operaciones_condicion CHECK (condicion IN ('CONTADO', 'CREDITO')),
    CONSTRAINT ck_operaciones_origen CHECK (origen IN ('MANUAL', 'VOZ', 'IMAGEN', 'IMPORTACION')),
    CONSTRAINT ck_operaciones_categoria CHECK ((tipo IN ('SALDO_CXC','SALDO_CXP') AND categoria_id IS NULL AND condicion = 'CREDITO') OR (tipo IN ('VENTA','COMPRA_MERCADERIA','GASTO_OPERATIVO') AND categoria_id IS NOT NULL)),
    CONSTRAINT ck_operaciones_tercero CHECK (condicion <> 'CREDITO' OR tercero_id IS NOT NULL),
    CONSTRAINT ck_operaciones_vencimiento CHECK (vence_el IS NULL OR (condicion = 'CREDITO' AND vence_el >= fecha_operacion)),
    CONSTRAINT ck_operaciones_concepto CHECK (CHAR_LENGTH(TRIM(concepto)) > 0),
    KEY ix_operaciones_fecha (negocio_id, fecha_operacion, id),
    KEY ix_operaciones_tipo (negocio_id, tipo, estado, fecha_operacion),
    KEY ix_operaciones_tercero (negocio_id, tercero_id, vence_el),
    KEY ix_operaciones_categoria (negocio_id, categoria_id, fecha_operacion)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE transferencias (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    cuenta_origen_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    cuenta_destino_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    monto_minor BIGINT NOT NULL,
    fecha DATE NOT NULL,
    concepto VARCHAR(240) NULL,
    estado VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'CONFIRMADO',
    anulado_en DATETIME(6) NULL,
    anulado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    motivo_anulacion VARCHAR(300) NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_transferencias_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_transferencias_negocio_id (negocio_id, id),
    CONSTRAINT fk_transferencias_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_transferencias_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_transferencias_version CHECK (version >= 1),
    CONSTRAINT fk_transferencias_cuenta_origen_id FOREIGN KEY (negocio_id, cuenta_origen_id) REFERENCES cuentas (negocio_id, id),
    CONSTRAINT fk_transferencias_cuenta_destino_id FOREIGN KEY (negocio_id, cuenta_destino_id) REFERENCES cuentas (negocio_id, id),
    CONSTRAINT ck_transferencias_estado CHECK (estado IN ('CONFIRMADO', 'ANULADO')),
    CONSTRAINT fk_transferencias_anulado_por FOREIGN KEY (negocio_id, anulado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_transferencias_anulacion CHECK ((estado = 'CONFIRMADO' AND anulado_en IS NULL AND anulado_por IS NULL AND motivo_anulacion IS NULL) OR (estado = 'ANULADO' AND anulado_en IS NOT NULL AND anulado_por IS NOT NULL AND motivo_anulacion IS NOT NULL AND CHAR_LENGTH(TRIM(motivo_anulacion)) > 0)),
    CONSTRAINT ck_transferencias_monto_minor CHECK (monto_minor BETWEEN 1 AND 100000000000000),
    CONSTRAINT ck_transferencias_cuentas CHECK (cuenta_origen_id <> cuenta_destino_id),
    KEY ix_transferencias_fecha (negocio_id, fecha, id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE movimientos (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    cuenta_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    direccion VARCHAR(8) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    clase VARCHAR(24) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    monto_minor BIGINT NOT NULL,
    fecha_movimiento DATE NOT NULL,
    ocurrido_en DATETIME(6) NULL,
    canal VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    referencia_externa VARCHAR(120) NULL,
    concepto VARCHAR(240) NOT NULL,
    transferencia_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    estado VARCHAR(12) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'CONFIRMADO',
    anulado_en DATETIME(6) NULL,
    anulado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    motivo_anulacion VARCHAR(300) NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_movimientos_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_movimientos_negocio_id (negocio_id, id),
    CONSTRAINT fk_movimientos_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_movimientos_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_movimientos_version CHECK (version >= 1),
    CONSTRAINT fk_movimientos_cuenta_id FOREIGN KEY (negocio_id, cuenta_id) REFERENCES cuentas (negocio_id, id),
    CONSTRAINT fk_movimientos_transferencia_id FOREIGN KEY (negocio_id, transferencia_id) REFERENCES transferencias (negocio_id, id),
    CONSTRAINT ck_movimientos_estado CHECK (estado IN ('CONFIRMADO', 'ANULADO')),
    CONSTRAINT fk_movimientos_anulado_por FOREIGN KEY (negocio_id, anulado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_movimientos_anulacion CHECK ((estado = 'CONFIRMADO' AND anulado_en IS NULL AND anulado_por IS NULL AND motivo_anulacion IS NULL) OR (estado = 'ANULADO' AND anulado_en IS NOT NULL AND anulado_por IS NOT NULL AND motivo_anulacion IS NOT NULL AND CHAR_LENGTH(TRIM(motivo_anulacion)) > 0)),
    CONSTRAINT ck_movimientos_monto_minor CHECK (monto_minor BETWEEN 1 AND 100000000000000),
    CONSTRAINT ck_movimientos_direccion CHECK (direccion IN ('ENTRADA', 'SALIDA')),
    CONSTRAINT ck_movimientos_clase CHECK (clase IN ('COBRO', 'PAGO', 'APORTE', 'RETIRO', 'PRESTAMO_RECIBIDO', 'AMORTIZACION', 'INVERSION', 'TRANSFERENCIA', 'AJUSTE')),
    CONSTRAINT ck_movimientos_canal CHECK (canal IN ('EFECTIVO', 'YAPE', 'PLIN', 'TRANSFERENCIA', 'OTRO')),
    CONSTRAINT ck_movimientos_clase_direccion CHECK ((clase IN ('COBRO','APORTE','PRESTAMO_RECIBIDO') AND direccion = 'ENTRADA') OR (clase IN ('PAGO','RETIRO','AMORTIZACION','INVERSION') AND direccion = 'SALIDA') OR clase IN ('TRANSFERENCIA','AJUSTE')),
    CONSTRAINT ck_movimientos_transferencia CHECK ((clase = 'TRANSFERENCIA' AND transferencia_id IS NOT NULL) OR (clase <> 'TRANSFERENCIA' AND transferencia_id IS NULL)),
    CONSTRAINT ck_movimientos_concepto CHECK (CHAR_LENGTH(TRIM(concepto)) > 0),
    UNIQUE KEY uq_movimientos_pierna (negocio_id, transferencia_id, direccion),
    KEY ix_movimientos_cuenta (negocio_id, cuenta_id, fecha_movimiento, id),
    KEY ix_movimientos_clase (negocio_id, clase, estado, fecha_movimiento),
    KEY ix_movimientos_ref (negocio_id, referencia_externa)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE aplicaciones (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    operacion_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    movimiento_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    monto_minor BIGINT NOT NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_aplicaciones_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_aplicaciones_negocio_id (negocio_id, id),
    CONSTRAINT fk_aplicaciones_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_aplicaciones_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_aplicaciones_version CHECK (version >= 1),
    CONSTRAINT fk_aplicaciones_operacion_id FOREIGN KEY (negocio_id, operacion_id) REFERENCES operaciones (negocio_id, id),
    CONSTRAINT fk_aplicaciones_movimiento_id FOREIGN KEY (negocio_id, movimiento_id) REFERENCES movimientos (negocio_id, id),
    CONSTRAINT ck_aplicaciones_monto_minor CHECK (monto_minor BETWEEN 1 AND 100000000000000),
    UNIQUE KEY uq_aplicaciones_par (negocio_id, operacion_id, movimiento_id),
    KEY ix_aplicaciones_movimiento (negocio_id, movimiento_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE vinculos_comprobante (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    comprobante_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    operacion_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    movimiento_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_vinculos_comprobante_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_vinculos_comprobante_negocio_id (negocio_id, id),
    CONSTRAINT fk_vinculos_comprobante_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_vinculos_comprobante_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_vinculos_comprobante_version CHECK (version >= 1),
    CONSTRAINT fk_vinculos_comprobante_id FOREIGN KEY (negocio_id, comprobante_id) REFERENCES comprobantes (negocio_id, id),
    CONSTRAINT fk_vinculos_operacion_id FOREIGN KEY (negocio_id, operacion_id) REFERENCES operaciones (negocio_id, id),
    CONSTRAINT fk_vinculos_movimiento_id FOREIGN KEY (negocio_id, movimiento_id) REFERENCES movimientos (negocio_id, id),
    CONSTRAINT ck_vinculos_destino CHECK ((operacion_id IS NOT NULL AND movimiento_id IS NULL) OR (operacion_id IS NULL AND movimiento_id IS NOT NULL)),
    UNIQUE KEY uq_vinculos_operacion (negocio_id, comprobante_id, operacion_id),
    UNIQUE KEY uq_vinculos_movimiento (negocio_id, comprobante_id, movimiento_id)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE cierres_diarios (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    fecha DATE NOT NULL,
    tipo_dia VARCHAR(20) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    nota VARCHAR(300) NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_cierres_diarios_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_cierres_diarios_negocio_id (negocio_id, id),
    CONSTRAINT fk_cierres_diarios_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_cierres_diarios_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_cierres_diarios_version CHECK (version >= 1),
    UNIQUE KEY uq_cierres_fecha (negocio_id, fecha),
    CONSTRAINT ck_cierres_tipo_dia CHECK (tipo_dia IN ('CON_ACTIVIDAD', 'SIN_VENTAS', 'NO_LABORABLE'))
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE reportes (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    desde DATE NOT NULL,
    hasta DATE NOT NULL,
    zona_horaria VARCHAR(64) NOT NULL,
    moneda CHAR(3) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'PEN',
    version_formula VARCHAR(20) NOT NULL,
    corte_sync_seq BIGINT NOT NULL,
    estado VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'PENDIENTE',
    parametros JSON NOT NULL,
    indicadores JSON NULL,
    storage_key VARCHAR(500) NULL,
    sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL,
    codigo_error VARCHAR(60) NULL,
    generado_en DATETIME(6) NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_reportes_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_reportes_negocio_id (negocio_id, id),
    CONSTRAINT fk_reportes_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_reportes_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_reportes_version CHECK (version >= 1),
    KEY ix_reportes_fecha (negocio_id, creado_en, id),
    CONSTRAINT ck_reportes_estado CHECK (estado IN ('PENDIENTE', 'GENERANDO', 'LISTO', 'FALLIDO')),
    CONSTRAINT ck_reportes_periodo CHECK (hasta >= desde),
    CONSTRAINT ck_reportes_moneda CHECK (moneda = 'PEN'),
    CONSTRAINT ck_reportes_corte CHECK (corte_sync_seq >= 0),
    CONSTRAINT ck_reportes_listo CHECK (estado <> 'LISTO' OR (indicadores IS NOT NULL AND storage_key IS NOT NULL AND sha256 IS NOT NULL AND generado_en IS NOT NULL)),
    CONSTRAINT ck_reportes_error CHECK (estado <> 'FALLIDO' OR codigo_error IS NOT NULL)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE sync_contadores (
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    ultimo_seq BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (negocio_id),
    CONSTRAINT fk_sync_contadores_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT ck_sync_contadores_seq CHECK (ultimo_seq >= 0)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE comandos_procesados (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    dispositivo_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    usuario_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    tipo VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    request_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    respuesta JSON NOT NULL,
    sync_seq BIGINT NOT NULL,
    procesado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_comandos_procesados_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_comandos_procesados_negocio_id (negocio_id, id),
    CONSTRAINT fk_comandos_procesados_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_comandos_procesados_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_comandos_procesados_version CHECK (version >= 1),
    CONSTRAINT fk_comandos_dispositivo FOREIGN KEY (usuario_id, dispositivo_id) REFERENCES dispositivos (usuario_id, id),
    CONSTRAINT fk_comandos_usuario FOREIGN KEY (negocio_id, usuario_id) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_comandos_actor CHECK (usuario_id = creado_por),
    CONSTRAINT ck_comandos_seq CHECK (sync_seq >= 1),
    UNIQUE KEY uq_comandos_seq (negocio_id, sync_seq)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE cambios_sync (
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    seq BIGINT NOT NULL,
    command_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    tipo VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    payload JSON NOT NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (negocio_id, seq),
    UNIQUE KEY uq_cambios_comando (negocio_id, command_id),
    CONSTRAINT fk_cambios_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_cambios_comando FOREIGN KEY (negocio_id, command_id) REFERENCES comandos_procesados (negocio_id, id),
    CONSTRAINT ck_cambios_seq CHECK (seq >= 1)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  CREATE TABLE auditoria (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    negocio_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    usuario_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    dispositivo_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    command_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    accion VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    entidad VARCHAR(40) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    entidad_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    version_anterior BIGINT NULL,
    version_nueva BIGINT NULL,
    detalle JSON NOT NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    actualizado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    version BIGINT NOT NULL DEFAULT 1,
    creado_por CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_auditoria_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    UNIQUE KEY uq_auditoria_negocio_id (negocio_id, id),
    CONSTRAINT fk_auditoria_negocio FOREIGN KEY (negocio_id) REFERENCES negocios (id),
    CONSTRAINT fk_auditoria_autor FOREIGN KEY (negocio_id, creado_por) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT ck_auditoria_version CHECK (version >= 1),
    CONSTRAINT fk_auditoria_usuario FOREIGN KEY (negocio_id, usuario_id) REFERENCES membresias (negocio_id, usuario_id),
    CONSTRAINT fk_auditoria_dispositivo FOREIGN KEY (usuario_id, dispositivo_id) REFERENCES dispositivos (usuario_id, id),
    CONSTRAINT fk_auditoria_command_id FOREIGN KEY (negocio_id, command_id) REFERENCES comandos_procesados (negocio_id, id),
    CONSTRAINT ck_auditoria_actor CHECK (usuario_id = creado_por),
    CONSTRAINT ck_auditoria_versiones_entidad CHECK ((version_anterior IS NULL OR version_anterior >= 1) AND (version_nueva IS NULL OR version_nueva >= 1)),
    KEY ix_auditoria_entidad (negocio_id, entidad, entidad_id, creado_en)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

  INSERT INTO schema_migraciones (version,nombre,contrato_version)
  VALUES (1,'001_initial_schema.sql','1.0.0');
  DO RELEASE_LOCK('hackathon_pinguinos_dev:migraciones');
END$$
DELIMITER ;
CALL hackathon_pinguinos_dev.dbv1_aplicar_001();
-- El procedimiento permanece como instalador identificable; no reemplazarlo ni borrarlo.
-- Una segunda importacion debe DETENERSE en CREATE PROCEDURE, sin continuar tras errores.
