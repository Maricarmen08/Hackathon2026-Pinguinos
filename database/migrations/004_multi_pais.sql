-- Aplicar SOLO despues de un respaldo y con la base elegida (USE ...).
-- Requiere MySQL 8.4 y la migracion 003 ya aplicada. Si falla, detenerse y revisar.
-- Cambia CHECK (moneda = 'PEN') por una lista de monedas permitidas.
-- Los datos existentes (todos en PEN) no cambian.
DELIMITER $$
CREATE PROCEDURE finki_aplicar_004()
BEGIN
  IF DATABASE() IS NULL OR SUBSTRING_INDEX(VERSION(),'.',2) <> '8.4' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Selecciona primero la base MySQL 8.4 correcta';
  END IF;
  IF (SELECT COUNT(*) FROM schema_migraciones WHERE version IN (1,2,3)) <> 3
     OR EXISTS(SELECT 1 FROM schema_migraciones WHERE version=4) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Faltan migraciones previas o la 004 ya esta aplicada; revisar antes de seguir';
  END IF;
  ALTER TABLE negocios DROP CHECK ck_negocios_moneda;
  ALTER TABLE negocios ADD CONSTRAINT ck_negocios_moneda CHECK (moneda IN ('PEN','COP','MXN','USD','BOB','ARS'));
  ALTER TABLE cuentas DROP CHECK ck_cuentas_moneda;
  ALTER TABLE cuentas ADD CONSTRAINT ck_cuentas_moneda CHECK (moneda IN ('PEN','COP','MXN','USD','BOB','ARS'));
  ALTER TABLE comprobantes DROP CHECK ck_comprobantes_moneda;
  ALTER TABLE comprobantes ADD CONSTRAINT ck_comprobantes_moneda CHECK (moneda IS NULL OR moneda IN ('PEN','COP','MXN','USD','BOB','ARS'));
  ALTER TABLE reportes DROP CHECK ck_reportes_moneda;
  ALTER TABLE reportes ADD CONSTRAINT ck_reportes_moneda CHECK (moneda IN ('PEN','COP','MXN','USD','BOB','ARS'));
  INSERT INTO schema_migraciones(version,nombre,contrato_version) VALUES(4,'004_multi_pais.sql','1.2.0');
END$$
DELIMITER ;
CALL finki_aplicar_004();
