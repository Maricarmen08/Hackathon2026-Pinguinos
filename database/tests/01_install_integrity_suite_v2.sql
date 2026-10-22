-- SOLO INSTALACION. NO ejecuta las pruebas. DDL con commit implicito.
-- Conexion NUEVA dedicada, autocommit activo, base de desarrollo seleccionada.
-- Ejecutar primero 00_preflight_integrity_v2.sql y DETENERSE ante cualquier error.
-- No DROP, CREATE OR REPLACE ni IF NOT EXISTS: una rutina existente produce error.
-- Esta version no llama ni reemplaza dbv1_test_integridad de V1.
SET TRANSACTION READ WRITE;
SET @integrity_v2_sql_mode_anterior = @@SESSION.sql_mode;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
DELIMITER $$
CREATE PROCEDURE hackathon_pinguinos_dev.dbv1_test_integridad_v2_0_0(
  IN p_release VARCHAR(80),
  IN p_base_invocadora VARCHAR(64),
  IN p_sql_mode_invocador TEXT
)
SQL SECURITY INVOKER
COMMENT 'pinguinos-integrity:2.0.0'
BEGIN
  DECLARE rechazado BOOLEAN DEFAULT FALSE;
  DECLARE v_transaccion BOOLEAN DEFAULT FALSE;
  DECLARE v_lock INT DEFAULT 0;
  DECLARE v_restantes BIGINT DEFAULT 0;
  DECLARE v_error_msg TEXT;
  DECLARE v_sqlstate CHAR(5);
  DECLARE v_errno INT;
  DECLARE v_abort_msg VARCHAR(128);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION, SQLWARNING
  BEGIN
    GET STACKED DIAGNOSTICS CONDITION 1
      v_sqlstate=RETURNED_SQLSTATE, v_errno=MYSQL_ERRNO, v_error_msg=MESSAGE_TEXT;
    IF v_transaccion THEN
      BEGIN
        DECLARE EXIT HANDLER FOR SQLEXCEPTION, SQLWARNING
        BEGIN
          IF v_lock=1 THEN DO RELEASE_LOCK('hackathon_pinguinos_dev:integrity-v2'); END IF;
          SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='CRITICO: fallo ROLLBACK/verificacion de limpieza; cerrar conexion y revisar sin borrar';
        END;
      ROLLBACK;
      SET v_transaccion=FALSE;
      -- Si la comprobacion de limpieza falla, no se emite PASS.
      SELECT SUM(f.n) INTO v_restantes
    FROM (
      SELECT COUNT(*) AS n FROM usuarios WHERE id IN ('00000000-0000-4000-8000-000000000900')
      UNION ALL
      SELECT COUNT(*) AS n FROM dispositivos WHERE id IN ('00000000-0000-4000-8000-000000000901')
      UNION ALL
      SELECT COUNT(*) AS n FROM negocios WHERE id IN ('00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000911')
      UNION ALL
      SELECT COUNT(*) AS n FROM membresias WHERE id IN ('00000000-0000-4000-8000-000000000912','00000000-0000-4000-8000-000000000913')
      UNION ALL
      SELECT COUNT(*) AS n FROM categorias WHERE id IN ('00000000-0000-4000-8000-000000000920','00000000-0000-4000-8000-000000000921')
      UNION ALL
      SELECT COUNT(*) AS n FROM terceros WHERE id IN ('00000000-0000-4000-8000-000000000940')
      UNION ALL
      SELECT COUNT(*) AS n FROM cuentas WHERE id IN ('00000000-0000-4000-8000-000000000930','00000000-0000-4000-8000-000000000931','00000000-0000-4000-8000-000000000932')
      UNION ALL
      SELECT COUNT(*) AS n FROM operaciones WHERE id IN ('00000000-0000-4000-8000-000000000950','00000000-0000-4000-8000-000000000951')
      UNION ALL
      SELECT COUNT(*) AS n FROM movimientos WHERE id IN ('00000000-0000-4000-8000-000000000951','00000000-0000-4000-8000-000000000960','00000000-0000-4000-8000-000000000961','00000000-0000-4000-8000-000000000964','00000000-0000-4000-8000-000000000967','00000000-0000-4000-8000-000000000968','00000000-0000-4000-8000-000000000969')
      UNION ALL
      SELECT COUNT(*) AS n FROM aplicaciones WHERE id IN ('00000000-0000-4000-8000-000000000962','00000000-0000-4000-8000-000000000963','00000000-0000-4000-8000-000000000965','00000000-0000-4000-8000-000000000983')
      UNION ALL
      SELECT COUNT(*) AS n FROM transferencias WHERE id IN ('00000000-0000-4000-8000-000000000966')
      UNION ALL
      SELECT COUNT(*) AS n FROM sync_contadores WHERE negocio_id IN ('00000000-0000-4000-8000-000000000910')
      UNION ALL
      SELECT COUNT(*) AS n FROM comandos_procesados WHERE id IN ('00000000-0000-4000-8000-000000000970','00000000-0000-4000-8000-000000000972')
      UNION ALL
      SELECT COUNT(*) AS n FROM auditoria WHERE id IN ('00000000-0000-4000-8000-000000000971')
      UNION ALL
      SELECT COUNT(*) AS n FROM comprobantes WHERE id IN ('00000000-0000-4000-8000-000000000980')
      UNION ALL
      SELECT COUNT(*) AS n FROM vinculos_comprobante WHERE id IN ('00000000-0000-4000-8000-000000000981','00000000-0000-4000-8000-000000000982','00000000-0000-4000-8000-000000000983')
    ) AS f;
      IF NOT (v_restantes <=> 0) THEN
        IF v_lock=1 THEN DO RELEASE_LOCK('hackathon_pinguinos_dev:integrity-v2'); END IF;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='CRITICO: quedaron fixtures tras ROLLBACK; no borrar manualmente';
      END IF;
      END;
    END IF;
    IF v_lock=1 THEN DO RELEASE_LOCK('hackathon_pinguinos_dev:integrity-v2'); END IF;
    IF LEFT(v_sqlstate,2)='01' THEN
      SET v_abort_msg=LEFT(CONCAT('Abortado por advertencia ',v_errno,': ',v_error_msg),128);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT=v_abort_msg;
    END IF;
    RESIGNAL;
  END;

  -- Contexto del caller se pasa explicitamente: DATABASE() dentro de una
  -- rutina calificada refleja su propio esquema, no necesariamente el del caller.
  IF NOT (p_release <=> 'pinguinos-integrity:2.0.0')
     OR NOT (p_base_invocadora <=> 'hackathon_pinguinos_dev')
     OR NOT (DATABASE() <=> 'hackathon_pinguinos_dev') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Release/base incorrectos; seleccionar hackathon_pinguinos_dev y usar runner V2';
  END IF;
  IF NOT (SUBSTRING_INDEX(VERSION(),'.',2) <=> '8.4') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Requiere servidor MySQL 8.4';
  END IF;
  IF NOT (@@SESSION.autocommit <=> 1) OR NOT (@@SESSION.foreign_key_checks <=> 1)
     OR NOT (@@SESSION.unique_checks <=> 1) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Requiere autocommit=1, foreign_key_checks=1 y unique_checks=1; no se cambian automaticamente';
  END IF;
  -- Sin SESSION: si ya existe transaccion, MySQL rechaza con 1568 sin confirmarla.
  -- El handler no hace ROLLBACK de transacciones ajenas.
  SET TRANSACTION READ WRITE;

  IF NOT ((FIND_IN_SET('STRICT_ALL_TABLES',p_sql_mode_invocador)>0
           OR FIND_IN_SET('STRICT_TRANS_TABLES',p_sql_mode_invocador)>0) <=> TRUE)
     OR NOT ((FIND_IN_SET('STRICT_ALL_TABLES',@@SESSION.sql_mode)>0
           OR FIND_IN_SET('STRICT_TRANS_TABLES',@@SESSION.sql_mode)>0) <=> TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='SQL mode estricto requerido tanto en caller como rutina instalada';
  END IF;
  IF NOT (@@SESSION.time_zone <=> '+00:00') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Configurar time_zone de esta conexion a +00:00 antes de ejecutar';
  END IF;
  IF NOT ((SELECT COUNT(*) FROM information_schema.routines
       WHERE routine_schema='hackathon_pinguinos_dev' AND routine_name='dbv1_test_integridad_v2_0_0'
       AND routine_type='PROCEDURE' AND routine_comment='pinguinos-integrity:2.0.0'
       AND security_type='INVOKER') <=> 1) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rutina/version instalada no coincide con release esperado';
  END IF;

  SELECT GET_LOCK('hackathon_pinguinos_dev:integrity-v2',0) INTO v_lock;
  IF NOT (v_lock <=> 1) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Otra ejecucion de integridad usa los mismos fixtures';
  END IF;
  IF NOT ((SELECT COUNT(*) FROM information_schema.tables
      WHERE table_schema='hackathon_pinguinos_dev' AND table_type='BASE TABLE'
      AND engine='InnoDB' AND table_name IN ('schema_migraciones','schema_semillas','usuarios','dispositivos','sesiones','negocios','membresias','categorias','terceros','cuentas','comprobantes','extracciones','operaciones','transferencias','movimientos','aplicaciones','vinculos_comprobante','cierres_diarios','reportes','sync_contadores','comandos_procesados','cambios_sync','auditoria')) <=> 23) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Faltan tablas requeridas o alguna no es InnoDB';
  END IF;
  IF NOT ((SELECT COUNT(*) FROM schema_migraciones
       WHERE (version=1 AND nombre='001_initial_schema.sql')
          OR (version=2 AND nombre='002_reporting_views.sql')) <=> 2) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Requiere migraciones 001 y 002 registradas con sus nombres';
  END IF;
  IF NOT ((SELECT COUNT(*) FROM information_schema.views
       WHERE table_schema='hackathon_pinguinos_dev'
       AND table_name IN ('v_operaciones_saldos','v_cuentas_saldos','v_operaciones_diarias','v_aplicaciones_diarias','v_dinero_diario')) <=> 5) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Faltan vistas financieras requeridas o no son visibles';
  END IF;
  IF NOT ((SELECT COUNT(*) FROM information_schema.table_constraints
       WHERE constraint_schema='hackathon_pinguinos_dev' AND constraint_type='CHECK'
       AND enforced='YES' AND constraint_name IN ('ck_usuarios_uuid','ck_usuarios_estado','ck_usuarios_hash','ck_usuarios_nombre','ck_usuarios_version','ck_dispositivos_uuid','ck_dispositivos_plataforma','ck_dispositivos_version','ck_sesiones_uuid','ck_sesiones_expira','ck_negocios_uuid','ck_negocios_estado','ck_negocios_moneda','ck_negocios_documento','ck_negocios_nombre','ck_negocios_version','ck_membresias_uuid','ck_membresias_rol','ck_membresias_estado','ck_membresias_version','ck_categorias_uuid','ck_categorias_version','ck_categorias_tipo','ck_categorias_activa','ck_categorias_nombre','ck_terceros_uuid','ck_terceros_version','ck_terceros_documento','ck_terceros_activo','ck_terceros_nombre','ck_cuentas_uuid','ck_cuentas_version','ck_cuentas_tipo','ck_cuentas_moneda','ck_cuentas_saldo','ck_cuentas_activa','ck_cuentas_nombre','ck_comprobantes_uuid','ck_comprobantes_version','ck_comprobantes_tipo','ck_comprobantes_estado_archivo','ck_comprobantes_bytes','ck_comprobantes_total','ck_comprobantes_moneda','ck_comprobantes_archivo','ck_extracciones_uuid','ck_extracciones_version','ck_extracciones_tipo_entrada','ck_extracciones_estado','ck_extracciones_entrada','ck_extracciones_confirmacion','ck_extracciones_error','ck_operaciones_uuid','ck_operaciones_version','ck_operaciones_estado','ck_operaciones_anulacion','ck_operaciones_total_minor','ck_operaciones_tipo','ck_operaciones_condicion','ck_operaciones_origen','ck_operaciones_categoria','ck_operaciones_tercero','ck_operaciones_vencimiento','ck_operaciones_concepto','ck_transferencias_uuid','ck_transferencias_version','ck_transferencias_estado','ck_transferencias_anulacion','ck_transferencias_monto_minor','ck_transferencias_cuentas','ck_movimientos_uuid','ck_movimientos_version','ck_movimientos_estado','ck_movimientos_anulacion','ck_movimientos_monto_minor','ck_movimientos_direccion','ck_movimientos_clase','ck_movimientos_canal','ck_movimientos_clase_direccion','ck_movimientos_transferencia','ck_movimientos_concepto','ck_aplicaciones_uuid','ck_aplicaciones_version','ck_aplicaciones_monto_minor','ck_vinculos_comprobante_uuid','ck_vinculos_comprobante_version','ck_vinculos_destino','ck_cierres_diarios_uuid','ck_cierres_diarios_version','ck_cierres_tipo_dia','ck_reportes_uuid','ck_reportes_version','ck_reportes_estado','ck_reportes_periodo','ck_reportes_moneda','ck_reportes_corte','ck_reportes_listo','ck_reportes_error','ck_sync_contadores_seq','ck_comandos_procesados_uuid','ck_comandos_procesados_version','ck_comandos_actor','ck_comandos_seq','ck_cambios_seq','ck_auditoria_uuid','ck_auditoria_version','ck_auditoria_actor','ck_auditoria_versiones_entidad')) <=> 108) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Falta algun CHECK esperado o no esta ENFORCED';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.triggers
      WHERE trigger_schema='hackathon_pinguinos_dev' AND event_object_table IN ('schema_migraciones','schema_semillas','usuarios','dispositivos','sesiones','negocios','membresias','categorias','terceros','cuentas','comprobantes','extracciones','operaciones','transferencias','movimientos','aplicaciones','vinculos_comprobante','cierres_diarios','reportes','sync_contadores','comandos_procesados','cambios_sync','auditoria')) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Hay triggers no previstos: revisar efectos secundarios antes de probar';
  END IF;

  -- Ausencia de TODOS los UUID de ensayo, incluidos INSERT rechazados.
  SELECT SUM(f.n) INTO v_restantes
    FROM (
      SELECT COUNT(*) AS n FROM usuarios WHERE id IN ('00000000-0000-4000-8000-000000000900')
      UNION ALL
      SELECT COUNT(*) AS n FROM dispositivos WHERE id IN ('00000000-0000-4000-8000-000000000901')
      UNION ALL
      SELECT COUNT(*) AS n FROM negocios WHERE id IN ('00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000911')
      UNION ALL
      SELECT COUNT(*) AS n FROM membresias WHERE id IN ('00000000-0000-4000-8000-000000000912','00000000-0000-4000-8000-000000000913')
      UNION ALL
      SELECT COUNT(*) AS n FROM categorias WHERE id IN ('00000000-0000-4000-8000-000000000920','00000000-0000-4000-8000-000000000921')
      UNION ALL
      SELECT COUNT(*) AS n FROM terceros WHERE id IN ('00000000-0000-4000-8000-000000000940')
      UNION ALL
      SELECT COUNT(*) AS n FROM cuentas WHERE id IN ('00000000-0000-4000-8000-000000000930','00000000-0000-4000-8000-000000000931','00000000-0000-4000-8000-000000000932')
      UNION ALL
      SELECT COUNT(*) AS n FROM operaciones WHERE id IN ('00000000-0000-4000-8000-000000000950','00000000-0000-4000-8000-000000000951')
      UNION ALL
      SELECT COUNT(*) AS n FROM movimientos WHERE id IN ('00000000-0000-4000-8000-000000000951','00000000-0000-4000-8000-000000000960','00000000-0000-4000-8000-000000000961','00000000-0000-4000-8000-000000000964','00000000-0000-4000-8000-000000000967','00000000-0000-4000-8000-000000000968','00000000-0000-4000-8000-000000000969')
      UNION ALL
      SELECT COUNT(*) AS n FROM aplicaciones WHERE id IN ('00000000-0000-4000-8000-000000000962','00000000-0000-4000-8000-000000000963','00000000-0000-4000-8000-000000000965','00000000-0000-4000-8000-000000000983')
      UNION ALL
      SELECT COUNT(*) AS n FROM transferencias WHERE id IN ('00000000-0000-4000-8000-000000000966')
      UNION ALL
      SELECT COUNT(*) AS n FROM sync_contadores WHERE negocio_id IN ('00000000-0000-4000-8000-000000000910')
      UNION ALL
      SELECT COUNT(*) AS n FROM comandos_procesados WHERE id IN ('00000000-0000-4000-8000-000000000970','00000000-0000-4000-8000-000000000972')
      UNION ALL
      SELECT COUNT(*) AS n FROM auditoria WHERE id IN ('00000000-0000-4000-8000-000000000971')
      UNION ALL
      SELECT COUNT(*) AS n FROM comprobantes WHERE id IN ('00000000-0000-4000-8000-000000000980')
      UNION ALL
      SELECT COUNT(*) AS n FROM vinculos_comprobante WHERE id IN ('00000000-0000-4000-8000-000000000981','00000000-0000-4000-8000-000000000982','00000000-0000-4000-8000-000000000983')
    ) AS f;
  IF NOT (v_restantes <=> 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Colision de UUID fixtures; abortado sin modificar ni eliminar registros';
  END IF;
  IF EXISTS (SELECT 1 FROM usuarios WHERE telefono_normalizado='SQL-TEST-NO-TEL') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Colision telefono de ensayo; no se modifica el registro existente';
  END IF;

  SET TRANSACTION READ WRITE;
  START TRANSACTION;
  SET v_transaccion=TRUE;
  INSERT INTO usuarios(id,nombre,telefono_normalizado,password_hash,estado)
    VALUES('00000000-0000-4000-8000-000000000900','Ensayo SQL sintetico','SQL-TEST-NO-TEL',NULL,'BLOQUEADO');
  INSERT INTO dispositivos(id,usuario_id,nombre,plataforma)
    VALUES('00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000900','Ensayo','ANDROID');
  INSERT INTO negocios(id,nombre,rubro,inicio_historial) VALUES
    ('00000000-0000-4000-8000-000000000910','Ensayo A','Pruebas','2026-10-01'),('00000000-0000-4000-8000-000000000911','Ensayo B','Pruebas','2026-10-01');
  INSERT INTO membresias(id,negocio_id,usuario_id,rol,creado_por) VALUES
    ('00000000-0000-4000-8000-000000000912','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000900','PROPIETARIO','00000000-0000-4000-8000-000000000900'),('00000000-0000-4000-8000-000000000913','00000000-0000-4000-8000-000000000911','00000000-0000-4000-8000-000000000900','PROPIETARIO','00000000-0000-4000-8000-000000000900');
  INSERT INTO categorias(id,negocio_id,nombre,nombre_normalizado,tipo,creado_por) VALUES
    ('00000000-0000-4000-8000-000000000920','00000000-0000-4000-8000-000000000910','Venta','venta','VENTA','00000000-0000-4000-8000-000000000900'),
    ('00000000-0000-4000-8000-000000000921','00000000-0000-4000-8000-000000000911','Venta B','venta b','VENTA','00000000-0000-4000-8000-000000000900');
  INSERT INTO terceros(id,negocio_id,nombre,creado_por) VALUES('00000000-0000-4000-8000-000000000940','00000000-0000-4000-8000-000000000910','Cliente ensayo','00000000-0000-4000-8000-000000000900');
  INSERT INTO cuentas(id,negocio_id,nombre,tipo,fecha_apertura,creado_por) VALUES
    ('00000000-0000-4000-8000-000000000930','00000000-0000-4000-8000-000000000910','Caja','EFECTIVO','2026-10-01','00000000-0000-4000-8000-000000000900'),
    ('00000000-0000-4000-8000-000000000931','00000000-0000-4000-8000-000000000910','Banco','BANCO','2026-10-01','00000000-0000-4000-8000-000000000900'),
    ('00000000-0000-4000-8000-000000000932','00000000-0000-4000-8000-000000000911','Caja B','EFECTIVO','2026-10-01','00000000-0000-4000-8000-000000000900');
  INSERT INTO operaciones(id,negocio_id,tipo,tercero_id,categoria_id,concepto,total_minor,fecha_operacion,condicion,origen,creado_por)
    VALUES('00000000-0000-4000-8000-000000000950','00000000-0000-4000-8000-000000000910','VENTA','00000000-0000-4000-8000-000000000940','00000000-0000-4000-8000-000000000920','Fiado 100',10000,'2026-10-01','CREDITO','MANUAL','00000000-0000-4000-8000-000000000900');
  IF NOT ((SELECT pendiente_minor FROM v_operaciones_saldos WHERE id='00000000-0000-4000-8000-000000000950') <=> 10000) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: venta fiada inicial debe 10000';
  END IF;

  IF NOT ((SELECT COUNT(*) FROM v_operaciones_saldos WHERE id='00000000-0000-4000-8000-000000000950') <=> 1) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: se requiere exactamente una fila de saldo';
  END IF;

  -- CHECK de importe cero y negativo; solo aceptar error MySQL 3819.
  SET rechazado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 3819
    BEGIN
      GET STACKED DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
      IF NOT (LOCATE('ck_operaciones_total_minor',v_error_msg)>0) THEN
        RESIGNAL;
      END IF;
      SET rechazado=TRUE;
    END;
    INSERT INTO operaciones(id,negocio_id,tipo,tercero_id,categoria_id,concepto,total_minor,fecha_operacion,condicion,origen,creado_por) VALUES('00000000-0000-4000-8000-000000000951','00000000-0000-4000-8000-000000000910','VENTA','00000000-0000-4000-8000-000000000940','00000000-0000-4000-8000-000000000920','Ensayo',0,'2026-10-01','CREDITO','MANUAL','00000000-0000-4000-8000-000000000900');
  END;
  IF NOT (rechazado <=> TRUE) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: monto cero debe rechazarse'; END IF;

  SET rechazado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 3819
    BEGIN
      GET STACKED DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
      IF NOT (LOCATE('ck_operaciones_total_minor',v_error_msg)>0) THEN
        RESIGNAL;
      END IF;
      SET rechazado=TRUE;
    END;
    INSERT INTO operaciones(id,negocio_id,tipo,tercero_id,categoria_id,concepto,total_minor,fecha_operacion,condicion,origen,creado_por) VALUES('00000000-0000-4000-8000-000000000951','00000000-0000-4000-8000-000000000910','VENTA','00000000-0000-4000-8000-000000000940','00000000-0000-4000-8000-000000000920','Ensayo',-1,'2026-10-01','CREDITO','MANUAL','00000000-0000-4000-8000-000000000900');
  END;
  IF NOT (rechazado <=> TRUE) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: monto negativo debe rechazarse'; END IF;

  SET rechazado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1452
    BEGIN
      GET STACKED DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
      IF NOT (LOCATE('fk_operaciones_categoria_id',v_error_msg)>0) THEN
        RESIGNAL;
      END IF;
      SET rechazado=TRUE;
    END;
    INSERT INTO operaciones(id,negocio_id,tipo,tercero_id,categoria_id,concepto,total_minor,fecha_operacion,condicion,origen,creado_por) VALUES('00000000-0000-4000-8000-000000000951','00000000-0000-4000-8000-000000000910','VENTA','00000000-0000-4000-8000-000000000940','00000000-0000-4000-8000-000000000921','Ensayo',100,'2026-10-01','CREDITO','MANUAL','00000000-0000-4000-8000-000000000900');
  END;
  IF NOT (rechazado <=> TRUE) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: categoria de otro negocio debe rechazarse'; END IF;

  SET rechazado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1452
    BEGIN
      GET STACKED DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
      IF NOT (LOCATE('fk_movimientos_cuenta_id',v_error_msg)>0) THEN
        RESIGNAL;
      END IF;
      SET rechazado=TRUE;
    END;
    INSERT INTO movimientos(id,negocio_id,cuenta_id,direccion,clase,monto_minor,fecha_movimiento,canal,concepto,creado_por) VALUES('00000000-0000-4000-8000-000000000951','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000932','ENTRADA','APORTE',100,'2026-10-01','EFECTIVO','Cruce','00000000-0000-4000-8000-000000000900');
  END;
  IF NOT (rechazado <=> TRUE) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: cuenta de otro negocio debe rechazarse'; END IF;

  INSERT INTO movimientos(id,negocio_id,cuenta_id,direccion,clase,monto_minor,fecha_movimiento,canal,concepto,creado_por) VALUES
    ('00000000-0000-4000-8000-000000000960','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000930','ENTRADA','COBRO',4000,'2026-10-01','EFECTIVO','Abono 40','00000000-0000-4000-8000-000000000900'),
    ('00000000-0000-4000-8000-000000000961','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000930','ENTRADA','COBRO',6000,'2026-10-02','EFECTIVO','Liquidacion 60','00000000-0000-4000-8000-000000000900');
  INSERT INTO aplicaciones(id,negocio_id,operacion_id,movimiento_id,monto_minor,creado_por)
    VALUES('00000000-0000-4000-8000-000000000962','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000950','00000000-0000-4000-8000-000000000960',4000,'00000000-0000-4000-8000-000000000900');
  IF NOT ((SELECT pendiente_minor FROM v_operaciones_saldos WHERE id='00000000-0000-4000-8000-000000000950') <=> 6000) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: abono 40 deja pendiente 60';
  END IF;
  IF NOT ((SELECT SUM(total_minor) FROM operaciones WHERE negocio_id='00000000-0000-4000-8000-000000000910' AND tipo='VENTA') <=> 10000) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: abono duplico ventas';
  END IF;
  INSERT INTO aplicaciones(id,negocio_id,operacion_id,movimiento_id,monto_minor,creado_por)
    VALUES('00000000-0000-4000-8000-000000000963','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000950','00000000-0000-4000-8000-000000000961',6000,'00000000-0000-4000-8000-000000000900');
  IF NOT ((SELECT pendiente_minor FROM v_operaciones_saldos WHERE id='00000000-0000-4000-8000-000000000950') <=> 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: liquidacion completa';
  END IF;

  IF NOT ((SELECT COUNT(*) FROM operaciones WHERE negocio_id='00000000-0000-4000-8000-000000000910') <=> 1) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: fiado y abonos deben conservar una sola operacion';
  END IF;

  -- LIMITACION EXPLICITA: CHECK no impide sumas de varias filas.
  -- Se demuestra que DML directo puede sobreabonar, y se revierte de inmediato.
  SAVEPOINT antes_sobreabono;
  INSERT INTO movimientos(id,negocio_id,cuenta_id,direccion,clase,monto_minor,fecha_movimiento,canal,concepto,creado_por)
    VALUES('00000000-0000-4000-8000-000000000964','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000930','ENTRADA','COBRO',1,'2026-10-02','EFECTIVO','Sobreabono ensayo','00000000-0000-4000-8000-000000000900');
  INSERT INTO aplicaciones(id,negocio_id,operacion_id,movimiento_id,monto_minor,creado_por)
    VALUES('00000000-0000-4000-8000-000000000965','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000950','00000000-0000-4000-8000-000000000964',1,'00000000-0000-4000-8000-000000000900');
  IF NOT ((SELECT pendiente_minor FROM v_operaciones_saldos WHERE id='00000000-0000-4000-8000-000000000950') <=> -1) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cambio de contrato: revisar prueba de limite multi-fila';
  END IF;
  ROLLBACK TO SAVEPOINT antes_sobreabono;
  IF NOT ((SELECT COUNT(*) FROM movimientos WHERE id='00000000-0000-4000-8000-000000000964') <=> 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: SAVEPOINT dejo movimiento de sobreabono';
  END IF;
  IF NOT ((SELECT COUNT(*) FROM aplicaciones WHERE id='00000000-0000-4000-8000-000000000965') <=> 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: SAVEPOINT dejo aplicacion de sobreabono';
  END IF;
  IF NOT ((SELECT pendiente_minor FROM v_operaciones_saldos WHERE id='00000000-0000-4000-8000-000000000950') <=> 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: SAVEPOINT no restauro pendiente cero';
  END IF;


  INSERT INTO transferencias(id,negocio_id,cuenta_origen_id,cuenta_destino_id,monto_minor,fecha,creado_por)
    VALUES('00000000-0000-4000-8000-000000000966','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000930','00000000-0000-4000-8000-000000000931',1000,'2026-10-02','00000000-0000-4000-8000-000000000900');
  INSERT INTO movimientos(id,negocio_id,cuenta_id,direccion,clase,monto_minor,fecha_movimiento,canal,concepto,transferencia_id,creado_por) VALUES
    ('00000000-0000-4000-8000-000000000967','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000930','SALIDA','TRANSFERENCIA',1000,'2026-10-02','TRANSFERENCIA','Sale','00000000-0000-4000-8000-000000000966','00000000-0000-4000-8000-000000000900'),
    ('00000000-0000-4000-8000-000000000968','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000931','ENTRADA','TRANSFERENCIA',1000,'2026-10-02','TRANSFERENCIA','Entra','00000000-0000-4000-8000-000000000966','00000000-0000-4000-8000-000000000900');
  IF NOT ((SELECT SUM(saldo_registrado_minor) FROM v_cuentas_saldos WHERE negocio_id='00000000-0000-4000-8000-000000000910') <=> 10000)
     OR NOT ((SELECT SUM(resultado_simplificado_minor) FROM v_operaciones_diarias WHERE negocio_id='00000000-0000-4000-8000-000000000910') <=> 10000) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: transferencia cambio saldo conjunto o resultado';
  END IF;
  IF NOT ((SELECT COUNT(*) FROM v_cuentas_saldos WHERE negocio_id='00000000-0000-4000-8000-000000000910') <=> 2) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: transferencia requiere dos cuentas visibles';
  END IF;

  SET rechazado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1062
    BEGIN
      GET STACKED DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
      IF NOT (LOCATE('uq_movimientos_pierna',v_error_msg)>0) THEN
        RESIGNAL;
      END IF;
      SET rechazado=TRUE;
    END;
    INSERT INTO movimientos(id,negocio_id,cuenta_id,direccion,clase,monto_minor,fecha_movimiento,canal,concepto,transferencia_id,creado_por) VALUES('00000000-0000-4000-8000-000000000969','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000931','ENTRADA','TRANSFERENCIA',1000,'2026-10-02','TRANSFERENCIA','Duplicada','00000000-0000-4000-8000-000000000966','00000000-0000-4000-8000-000000000900');
  END;
  IF NOT (rechazado <=> TRUE) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: tercera pierna duplicada debe rechazarse'; END IF;

  INSERT INTO sync_contadores(negocio_id,ultimo_seq) VALUES('00000000-0000-4000-8000-000000000910',1);
  INSERT INTO comandos_procesados(id,negocio_id,dispositivo_id,usuario_id,tipo,request_hash,respuesta,sync_seq,creado_por)
    VALUES('00000000-0000-4000-8000-000000000970','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000900','ENSAYO_SQL',REPEAT('a',64),JSON_OBJECT('ok',TRUE),1,'00000000-0000-4000-8000-000000000900');
  SET rechazado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1062
    BEGIN
      GET STACKED DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
      IF NOT (LOCATE('PRIMARY',v_error_msg)>0) THEN
        RESIGNAL;
      END IF;
      SET rechazado=TRUE;
    END;
    INSERT INTO comandos_procesados(id,negocio_id,dispositivo_id,usuario_id,tipo,request_hash,respuesta,sync_seq,creado_por) VALUES('00000000-0000-4000-8000-000000000970','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000900','ENSAYO_SQL',REPEAT('a',64),JSON_OBJECT('ok',TRUE),2,'00000000-0000-4000-8000-000000000900');
  END;
  IF NOT (rechazado <=> TRUE) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: command_id repetido debe rechazarse'; END IF;

  SET rechazado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 3819
    BEGIN
      GET STACKED DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
      IF NOT (LOCATE('ck_movimientos_anulacion',v_error_msg)>0) THEN
        RESIGNAL;
      END IF;
      SET rechazado=TRUE;
    END;
    UPDATE movimientos SET estado='ANULADO' WHERE id='00000000-0000-4000-8000-000000000961';
  END;
  IF NOT (rechazado <=> TRUE) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: anular sin motivo y autor debe rechazarse'; END IF;

  UPDATE movimientos SET estado='ANULADO',anulado_en=UTC_TIMESTAMP(6),anulado_por='00000000-0000-4000-8000-000000000900',
    motivo_anulacion='Error de registro ensayo',version=version+1,actualizado_en=UTC_TIMESTAMP(6) WHERE id='00000000-0000-4000-8000-000000000961';
  IF NOT (ROW_COUNT() <=> 1) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: anulacion debe afectar exactamente una fila';
  END IF;
  INSERT INTO auditoria(id,negocio_id,usuario_id,accion,entidad,entidad_id,version_anterior,version_nueva,detalle,creado_por)
    VALUES('00000000-0000-4000-8000-000000000971','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000900','ANULAR','movimientos','00000000-0000-4000-8000-000000000961',1,2,JSON_OBJECT('motivo','Error de registro ensayo'),'00000000-0000-4000-8000-000000000900');
  IF NOT ((SELECT pendiente_minor FROM v_operaciones_saldos WHERE id='00000000-0000-4000-8000-000000000950') <=> 6000)
     OR NOT ((SELECT COUNT(*) FROM movimientos WHERE id='00000000-0000-4000-8000-000000000961' AND estado='ANULADO' AND motivo_anulacion IS NOT NULL) <=> 1)
     OR NOT ((SELECT COUNT(*) FROM auditoria WHERE id='00000000-0000-4000-8000-000000000971') <=> 1) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: anulacion debe reabrir pendiente y conservar rastro';
  END IF;
  INSERT INTO comprobantes(id,negocio_id,tipo,mime_type,bytes,sha256,creado_por)
    VALUES('00000000-0000-4000-8000-000000000980','00000000-0000-4000-8000-000000000910','YAPE','image/png',1,REPEAT('b',64),'00000000-0000-4000-8000-000000000900');
  INSERT INTO vinculos_comprobante(id,negocio_id,comprobante_id,operacion_id,creado_por)
    VALUES('00000000-0000-4000-8000-000000000981','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000980','00000000-0000-4000-8000-000000000950','00000000-0000-4000-8000-000000000900');
  INSERT INTO vinculos_comprobante(id,negocio_id,comprobante_id,movimiento_id,creado_por)
    VALUES('00000000-0000-4000-8000-000000000982','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000980','00000000-0000-4000-8000-000000000960','00000000-0000-4000-8000-000000000900');
  SET rechazado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 3819
    BEGIN
      GET STACKED DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
      IF NOT (LOCATE('ck_vinculos_destino',v_error_msg)>0) THEN
        RESIGNAL;
      END IF;
      SET rechazado=TRUE;
    END;
    INSERT INTO vinculos_comprobante(id,negocio_id,comprobante_id,operacion_id,movimiento_id,creado_por) VALUES('00000000-0000-4000-8000-000000000983','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000980','00000000-0000-4000-8000-000000000950','00000000-0000-4000-8000-000000000960','00000000-0000-4000-8000-000000000900');
  END;
  IF NOT (rechazado <=> TRUE) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: evidencia con dos destinos debe rechazarse'; END IF;

  SET rechazado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1452
    BEGIN
      GET STACKED DIAGNOSTICS CONDITION 1 v_error_msg = MESSAGE_TEXT;
      IF NOT (LOCATE('fk_aplicaciones_operacion_id',v_error_msg)>0 OR LOCATE('fk_aplicaciones_movimiento_id',v_error_msg)>0) THEN
        RESIGNAL;
      END IF;
      SET rechazado=TRUE;
    END;
    INSERT INTO aplicaciones(id,negocio_id,operacion_id,movimiento_id,monto_minor,creado_por) VALUES('00000000-0000-4000-8000-000000000983','00000000-0000-4000-8000-000000000911','00000000-0000-4000-8000-000000000950','00000000-0000-4000-8000-000000000960',1,'00000000-0000-4000-8000-000000000900');
  END;
  IF NOT (rechazado <=> TRUE) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: aplicacion entre negocios debe rechazarse'; END IF;

  IF NOT ((SELECT SUM(total_minor) FROM operaciones WHERE negocio_id='00000000-0000-4000-8000-000000000910') <=> 10000) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: adjuntar evidencia creo una operacion';
  END IF;
  IF NOT ((SELECT COUNT(*) FROM vinculos_comprobante WHERE comprobante_id='00000000-0000-4000-8000-000000000980') <=> 2) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: evidencia debe tener dos vinculos distintos';
  END IF;
  IF NOT ((SELECT version FROM movimientos WHERE id='00000000-0000-4000-8000-000000000961') <=> 2) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: anulacion no incremento version';
  END IF;
  IF NOT ((SELECT actualizado_en IS NOT NULL FROM movimientos WHERE id='00000000-0000-4000-8000-000000000961') <=> TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: anulacion sin timestamp';
  END IF;
  -- UNIQUE de secuencia independiente de la PK command_id.
  SET rechazado=FALSE;
  BEGIN
    DECLARE CONTINUE HANDLER FOR 1062
    BEGIN
      GET STACKED DIAGNOSTICS CONDITION 1 v_error_msg=MESSAGE_TEXT;
      IF NOT (LOCATE('uq_comandos_seq',v_error_msg)>0) THEN RESIGNAL; END IF;
      SET rechazado=TRUE;
    END;
    INSERT INTO comandos_procesados(id,negocio_id,dispositivo_id,usuario_id,tipo,request_hash,respuesta,sync_seq,creado_por)
    VALUES('00000000-0000-4000-8000-000000000972','00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000901','00000000-0000-4000-8000-000000000900','ENSAYO_SQL',REPEAT('c',64),JSON_OBJECT('ok',TRUE),1,'00000000-0000-4000-8000-000000000900');
  END;
  IF NOT (rechazado <=> TRUE) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Fallo: secuencia repetida debe rechazarse';
  END IF;

  ROLLBACK;
  SET v_transaccion=FALSE;

  -- Solo permitir PASS despues de probar ausencia en las 16 tablas afectadas.
  SELECT SUM(f.n) INTO v_restantes
    FROM (
      SELECT COUNT(*) AS n FROM usuarios WHERE id IN ('00000000-0000-4000-8000-000000000900')
      UNION ALL
      SELECT COUNT(*) AS n FROM dispositivos WHERE id IN ('00000000-0000-4000-8000-000000000901')
      UNION ALL
      SELECT COUNT(*) AS n FROM negocios WHERE id IN ('00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000911')
      UNION ALL
      SELECT COUNT(*) AS n FROM membresias WHERE id IN ('00000000-0000-4000-8000-000000000912','00000000-0000-4000-8000-000000000913')
      UNION ALL
      SELECT COUNT(*) AS n FROM categorias WHERE id IN ('00000000-0000-4000-8000-000000000920','00000000-0000-4000-8000-000000000921')
      UNION ALL
      SELECT COUNT(*) AS n FROM terceros WHERE id IN ('00000000-0000-4000-8000-000000000940')
      UNION ALL
      SELECT COUNT(*) AS n FROM cuentas WHERE id IN ('00000000-0000-4000-8000-000000000930','00000000-0000-4000-8000-000000000931','00000000-0000-4000-8000-000000000932')
      UNION ALL
      SELECT COUNT(*) AS n FROM operaciones WHERE id IN ('00000000-0000-4000-8000-000000000950','00000000-0000-4000-8000-000000000951')
      UNION ALL
      SELECT COUNT(*) AS n FROM movimientos WHERE id IN ('00000000-0000-4000-8000-000000000951','00000000-0000-4000-8000-000000000960','00000000-0000-4000-8000-000000000961','00000000-0000-4000-8000-000000000964','00000000-0000-4000-8000-000000000967','00000000-0000-4000-8000-000000000968','00000000-0000-4000-8000-000000000969')
      UNION ALL
      SELECT COUNT(*) AS n FROM aplicaciones WHERE id IN ('00000000-0000-4000-8000-000000000962','00000000-0000-4000-8000-000000000963','00000000-0000-4000-8000-000000000965','00000000-0000-4000-8000-000000000983')
      UNION ALL
      SELECT COUNT(*) AS n FROM transferencias WHERE id IN ('00000000-0000-4000-8000-000000000966')
      UNION ALL
      SELECT COUNT(*) AS n FROM sync_contadores WHERE negocio_id IN ('00000000-0000-4000-8000-000000000910')
      UNION ALL
      SELECT COUNT(*) AS n FROM comandos_procesados WHERE id IN ('00000000-0000-4000-8000-000000000970','00000000-0000-4000-8000-000000000972')
      UNION ALL
      SELECT COUNT(*) AS n FROM auditoria WHERE id IN ('00000000-0000-4000-8000-000000000971')
      UNION ALL
      SELECT COUNT(*) AS n FROM comprobantes WHERE id IN ('00000000-0000-4000-8000-000000000980')
      UNION ALL
      SELECT COUNT(*) AS n FROM vinculos_comprobante WHERE id IN ('00000000-0000-4000-8000-000000000981','00000000-0000-4000-8000-000000000982','00000000-0000-4000-8000-000000000983')
    ) AS f;
  IF NOT (v_restantes <=> 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='CRITICO: ROLLBACK no elimino todos los fixtures; NO PASS';
  END IF;
  DO RELEASE_LOCK('hackathon_pinguinos_dev:integrity-v2');
  SET v_lock=0;
  SELECT 'pinguinos-integrity:2.0.0' AS release_suite,
    'PASS SQL: aserciones y ausencia de fixtures tras ROLLBACK verificadas' AS resultado,
    'Backend, permisos de producto y concurrencia financiera NO probados' AS limite;
END$$
DELIMITER ;
SET SESSION sql_mode = @integrity_v2_sql_mode_anterior;
-- NO CALL aqui. Abrir 02_run_integrity_suite_v2.sql en conexion dedicada.
