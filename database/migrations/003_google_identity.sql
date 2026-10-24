-- Apply ONLY after backup, on the explicitly selected database (USE ...).
-- MySQL DDL commits implicitly. On any failure STOP and inspect partial DDL.
DELIMITER $$
CREATE PROCEDURE finki_aplicar_003()
BEGIN
  IF DATABASE() IS NULL OR SUBSTRING_INDEX(VERSION(),'.',2) <> '8.4' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Select the intended MySQL 8.4 database first';
  END IF;
  IF (SELECT COUNT(*) FROM schema_migraciones WHERE version IN (1,2)) <> 2
     OR EXISTS(SELECT 1 FROM schema_migraciones WHERE version=3)
     OR EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='identidades_externas') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unexpected schema or partial/already applied migration 003; inspect before proceeding';
  END IF;
  CREATE TABLE identidades_externas (
    id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    usuario_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    proveedor VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    sujeto VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    correo_proveedor VARCHAR(254) NULL,
    correo_verificado BOOLEAN NOT NULL,
    ultimo_token_iat BIGINT NOT NULL,
    creado_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    ultimo_acceso_en DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_identidad_sujeto (proveedor,sujeto),
    UNIQUE KEY uq_identidad_usuario (usuario_id,proveedor),
    CONSTRAINT fk_identidad_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    CONSTRAINT ck_identidad_uuid CHECK (CHAR_LENGTH(id)=36 AND SUBSTRING(id,9,1)='-' AND SUBSTRING(id,14,1)='-' AND SUBSTRING(id,19,1)='-' AND SUBSTRING(id,24,1)='-'),
    CONSTRAINT ck_identidad_proveedor CHECK (proveedor='GOOGLE'),
    CONSTRAINT ck_identidad_sujeto CHECK (CHAR_LENGTH(TRIM(sujeto))>0),
    CONSTRAINT ck_identidad_correo CHECK (correo_verificado=1),
    CONSTRAINT ck_identidad_iat CHECK (ultimo_token_iat>0)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
  ALTER TABLE usuarios
    MODIFY telefono_normalizado VARCHAR(20) NULL,
    ADD COLUMN acceso_google BOOLEAN NOT NULL DEFAULT FALSE AFTER password_hash,
    DROP CHECK ck_usuarios_hash,
    ADD CONSTRAINT ck_usuarios_hash CHECK (password_hash IS NULL OR password_hash LIKE '$argon2id$%' OR password_hash LIKE '$scrypt$%'),
    ADD CONSTRAINT ck_usuarios_metodo CHECK (estado='BLOQUEADO' OR (password_hash IS NOT NULL AND telefono_normalizado IS NOT NULL) OR acceso_google=1);
  INSERT INTO schema_migraciones(version,nombre,contrato_version) VALUES(3,'003_google_identity.sql','1.1.0');
END$$
DELIMITER ;
CALL finki_aplicar_003();
-- Keep the routine for inspection; never rerun after a partial failure.
