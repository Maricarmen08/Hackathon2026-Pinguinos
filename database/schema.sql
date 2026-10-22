CREATE DATABASE IF NOT EXISTS `hackathon_pinguinos`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE `hackathon_pinguinos`;

DROP TABLE IF EXISTS `referidos`;
DROP TABLE IF EXISTS `solicitudes_credito`;
DROP TABLE IF EXISTS `historial_crediticio`;
DROP TABLE IF EXISTS `transacciones`;
DROP TABLE IF EXISTS `categorias`;
DROP TABLE IF EXISTS `negocios`;
DROP TABLE IF EXISTS `usuarios`;

CREATE TABLE `usuarios` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `nombre_completo` VARCHAR(120) NOT NULL,
  `telefono` VARCHAR(30) NOT NULL UNIQUE,
  `correo` VARCHAR(120) DEFAULT NULL UNIQUE,
  `clave` VARCHAR(120) NOT NULL,
  `creado_en` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE `negocios` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `usuario_id` INT UNSIGNED NOT NULL,
  `nombre_negocio` VARCHAR(120) NOT NULL,
  `documento_identidad` VARCHAR(30) DEFAULT NULL,
  `rubro` VARCHAR(80) DEFAULT 'Bodega y Abarrotes',
  `ciudad` VARCHAR(80) DEFAULT 'Lima, Perú',
  `moneda` VARCHAR(10) DEFAULT 'PEN',
  `codigo_referido` VARCHAR(20) UNIQUE DEFAULT NULL,
  `puntos_difusion` INT DEFAULT 0,
  `score_crediticio` INT DEFAULT 78,
  `creado_en` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_negocios_usuario`
    FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE `categorias` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `nombre` VARCHAR(80) NOT NULL,
  `tipo` ENUM('INGRESO', 'GASTO') NOT NULL,
  `icono` VARCHAR(40) DEFAULT 'shopping-bag'
) ENGINE=InnoDB;

CREATE TABLE `transacciones` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `negocio_id` INT UNSIGNED NOT NULL,
  `categoria_id` INT UNSIGNED DEFAULT NULL,
  `tipo` ENUM('INGRESO', 'GASTO') NOT NULL,
  `concepto` VARCHAR(200) NOT NULL,
  `categoria` VARCHAR(80) NOT NULL DEFAULT 'General',
  `monto` DECIMAL(10, 2) NOT NULL,
  `origen_ia` ENUM('VOZ', 'FOTO_BOLETA', 'MANUAL') NOT NULL DEFAULT 'VOZ',
  `prompt_original` TEXT DEFAULT NULL,
  `nombre_archivo_boleta` VARCHAR(255) DEFAULT NULL,
  `fecha_transaccion` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_tx_negocio`
    FOREIGN KEY (`negocio_id`) REFERENCES `negocios` (`id`)
    ON DELETE CASCADE,
  CONSTRAINT `fk_tx_categoria`
    FOREIGN KEY (`categoria_id`) REFERENCES `categorias` (`id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE `solicitudes_credito` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `negocio_id` INT UNSIGNED NOT NULL,
  `entidad_financiera` VARCHAR(100) NOT NULL,
  `monto_solicitado` DECIMAL(12, 2) NOT NULL,
  `plazo_meses` INT NOT NULL DEFAULT 6,
  `cuota_mensual` DECIMAL(10, 2) NOT NULL,
  `score_actual` INT NOT NULL,
  `estado` ENUM('PRE_APROBADO', 'EN_REVISION', 'DESEMBOLSADO') NOT NULL DEFAULT 'PRE_APROBADO',
  `fecha_solicitud` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_credito_negocio`
    FOREIGN KEY (`negocio_id`) REFERENCES `negocios` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE `referidos` (
  `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `negocio_id` INT UNSIGNED NOT NULL,
  `nombre_comerciante` VARCHAR(120) NOT NULL,
  `telefono_comerciante` VARCHAR(30) NOT NULL,
  `puntos_ganados` INT NOT NULL DEFAULT 15,
  `fecha_registro` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_referidos_negocio`
    FOREIGN KEY (`negocio_id`) REFERENCES `negocios` (`id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

INSERT INTO `usuarios` (`id`, `nombre_completo`, `telefono`, `correo`, `clave`)
VALUES
  (1, 'Rosa Quispe', '987654321', 'rosa@khipu.pe', '123456');

INSERT INTO `negocios` (`id`, `usuario_id`, `nombre_negocio`, `documento_identidad`, `rubro`, `ciudad`, `moneda`, `codigo_referido`, `puntos_difusion`, `score_crediticio`)
VALUES
  (1, 1, 'Bodega Doña Rosa', '10458932101', 'Bodega y Abarrotes', 'Lima, Perú', 'PEN', 'ROSA2026', 30, 82);

INSERT INTO `categorias` (`id`, `nombre`, `tipo`, `icono`)
VALUES
  (1, 'Abarrotes', 'INGRESO', 'shopping-bag'),
  (2, 'Bebidas', 'INGRESO', 'coffee'),
  (3, 'Venta mostrador', 'INGRESO', 'store'),
  (4, 'Proveedores', 'GASTO', 'truck'),
  (5, 'Servicios', 'GASTO', 'zap');

INSERT INTO `transacciones` (`negocio_id`, `categoria_id`, `tipo`, `concepto`, `categoria`, `monto`, `origen_ia`, `prompt_original`)
VALUES
  (1, 1, 'INGRESO', 'Aceite y Leche', 'Abarrotes', 26.00, 'VOZ', 'Vendí dos botellas de aceite y leche a 26 soles'),
  (1, 1, 'INGRESO', 'Arroz y Azúcar 5kg', 'Abarrotes', 32.00, 'VOZ', 'Cinco kilos de arroz y azúcar por 32 soles'),
  (1, 4, 'GASTO', 'Distribuidora Alicorp', 'Proveedores', 42.00, 'FOTO_BOLETA', 'Boleta Distribuidora Alicorp S/ 42.00'),
  (1, 2, 'INGRESO', 'Gaseosas y Galletas', 'Bebidas', 18.50, 'VOZ', 'Tres gaseosas y galletas a 18.50');

INSERT INTO `solicitudes_credito` (`negocio_id`, `entidad_financiera`, `monto_solicitado`, `plazo_meses`, `cuota_mensual`, `score_actual`, `estado`)
VALUES
  (1, 'Caja Municipal Huancayo', 2500.00, 6, 445.00, 82, 'PRE_APROBADO');

INSERT INTO `referidos` (`negocio_id`, `nombre_comerciante`, `telefono_comerciante`, `puntos_ganados`)
VALUES
  (1, 'Bodega Don Pepe', '912345678', 15),
  (1, 'Verdulería Carmen', '945678123', 15);
