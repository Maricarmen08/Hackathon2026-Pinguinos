-- PREVUELO: no DDL ni escrituras de tablas.
-- Seleccionar la base manualmente: NO USE que oculte una seleccion incorrecta.
-- Conexion dedicada; DETENERSE ante cualquier error o bandera = 0.
-- Este SET sin SESSION falla con 1568 si ya hay transaccion abierta; no la confirma.
SET TRANSACTION READ WRITE;
SELECT CONNECTION_ID() AS conexion,
 VERSION() AS version_servidor,DATABASE() AS base_seleccionada,
 (SUBSTRING_INDEX(VERSION(),'.',2) <=> '8.4') AS mysql_84_ok,
 (DATABASE() <=> 'hackathon_pinguinos_dev') AS base_ok,
 (@@SESSION.autocommit <=> 1) AS autocommit_ok,
 (@@SESSION.foreign_key_checks <=> 1) AS fk_ok,
 (@@SESSION.unique_checks <=> 1) AS unique_ok,
 (@@SESSION.time_zone <=> '+00:00') AS utc_ok,
 ((FIND_IN_SET('STRICT_ALL_TABLES',@@SESSION.sql_mode)>0
   OR FIND_IN_SET('STRICT_TRANS_TABLES',@@SESSION.sql_mode)>0) <=> TRUE) AS sql_mode_estricto_ok;
SELECT ((SELECT COUNT(*) FROM information_schema.tables
 WHERE table_schema='hackathon_pinguinos_dev' AND table_type='BASE TABLE'
 AND engine='InnoDB' AND table_name IN ('schema_migraciones','schema_semillas','usuarios','dispositivos','sesiones','negocios','membresias','categorias','terceros','cuentas','comprobantes','extracciones','operaciones','transferencias','movimientos','aplicaciones','vinculos_comprobante','cierres_diarios','reportes','sync_contadores','comandos_procesados','cambios_sync','auditoria')) <=> 23) AS tablas_innodb_ok;
SELECT ((SELECT COUNT(*) FROM hackathon_pinguinos_dev.schema_migraciones
 WHERE (version=1 AND nombre='001_initial_schema.sql')
    OR (version=2 AND nombre='002_reporting_views.sql')) <=> 2) AS migraciones_ok;
SELECT ((SELECT COUNT(*) FROM information_schema.views
 WHERE table_schema='hackathon_pinguinos_dev'
 AND table_name IN ('v_operaciones_saldos','v_cuentas_saldos','v_operaciones_diarias','v_aplicaciones_diarias','v_dinero_diario')) <=> 5) AS vistas_ok;
SELECT ((SELECT COUNT(*) FROM information_schema.table_constraints
 WHERE constraint_schema='hackathon_pinguinos_dev' AND constraint_type='CHECK'
 AND enforced='YES' AND constraint_name IN ('ck_usuarios_uuid','ck_usuarios_estado','ck_usuarios_hash','ck_usuarios_nombre','ck_usuarios_version','ck_dispositivos_uuid','ck_dispositivos_plataforma','ck_dispositivos_version','ck_sesiones_uuid','ck_sesiones_expira','ck_negocios_uuid','ck_negocios_estado','ck_negocios_moneda','ck_negocios_documento','ck_negocios_nombre','ck_negocios_version','ck_membresias_uuid','ck_membresias_rol','ck_membresias_estado','ck_membresias_version','ck_categorias_uuid','ck_categorias_version','ck_categorias_tipo','ck_categorias_activa','ck_categorias_nombre','ck_terceros_uuid','ck_terceros_version','ck_terceros_documento','ck_terceros_activo','ck_terceros_nombre','ck_cuentas_uuid','ck_cuentas_version','ck_cuentas_tipo','ck_cuentas_moneda','ck_cuentas_saldo','ck_cuentas_activa','ck_cuentas_nombre','ck_comprobantes_uuid','ck_comprobantes_version','ck_comprobantes_tipo','ck_comprobantes_estado_archivo','ck_comprobantes_bytes','ck_comprobantes_total','ck_comprobantes_moneda','ck_comprobantes_archivo','ck_extracciones_uuid','ck_extracciones_version','ck_extracciones_tipo_entrada','ck_extracciones_estado','ck_extracciones_entrada','ck_extracciones_confirmacion','ck_extracciones_error','ck_operaciones_uuid','ck_operaciones_version','ck_operaciones_estado','ck_operaciones_anulacion','ck_operaciones_total_minor','ck_operaciones_tipo','ck_operaciones_condicion','ck_operaciones_origen','ck_operaciones_categoria','ck_operaciones_tercero','ck_operaciones_vencimiento','ck_operaciones_concepto','ck_transferencias_uuid','ck_transferencias_version','ck_transferencias_estado','ck_transferencias_anulacion','ck_transferencias_monto_minor','ck_transferencias_cuentas','ck_movimientos_uuid','ck_movimientos_version','ck_movimientos_estado','ck_movimientos_anulacion','ck_movimientos_monto_minor','ck_movimientos_direccion','ck_movimientos_clase','ck_movimientos_canal','ck_movimientos_clase_direccion','ck_movimientos_transferencia','ck_movimientos_concepto','ck_aplicaciones_uuid','ck_aplicaciones_version','ck_aplicaciones_monto_minor','ck_vinculos_comprobante_uuid','ck_vinculos_comprobante_version','ck_vinculos_destino','ck_cierres_diarios_uuid','ck_cierres_diarios_version','ck_cierres_tipo_dia','ck_reportes_uuid','ck_reportes_version','ck_reportes_estado','ck_reportes_periodo','ck_reportes_moneda','ck_reportes_corte','ck_reportes_listo','ck_reportes_error','ck_sync_contadores_seq','ck_comandos_procesados_uuid','ck_comandos_procesados_version','ck_comandos_actor','ck_comandos_seq','ck_cambios_seq','ck_auditoria_uuid','ck_auditoria_version','ck_auditoria_actor','ck_auditoria_versiones_entidad')) <=> 108) AS checks_enforced_ok;
SELECT ((SELECT COUNT(*) FROM information_schema.triggers
 WHERE trigger_schema='hackathon_pinguinos_dev'
 AND event_object_table IN ('schema_migraciones','schema_semillas','usuarios','dispositivos','sesiones','negocios','membresias','categorias','terceros','cuentas','comprobantes','extracciones','operaciones','transferencias','movimientos','aplicaciones','vinculos_comprobante','cierres_diarios','reportes','sync_contadores','comandos_procesados','cambios_sync','auditoria')) <=> 0) AS sin_triggers_ok;
-- Inventario de rutinas: cero filas V2 es normal ANTES de instalar.
-- Rutina V1, si existe, NO sera llamada por el runner.
SELECT routine_name,routine_comment,security_type,sql_mode
FROM information_schema.routines
WHERE routine_schema='hackathon_pinguinos_dev'
 AND routine_name IN ('dbv1_test_integridad','dbv1_test_integridad_v2_0_0');
-- Todas las cantidades deben ser CERO. UUID exactos, incluidos intentos negativos.
SELECT 'usuarios' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.usuarios
WHERE id IN ('00000000-0000-4000-8000-000000000900');
SELECT 'dispositivos' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.dispositivos
WHERE id IN ('00000000-0000-4000-8000-000000000901');
SELECT 'negocios' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.negocios
WHERE id IN ('00000000-0000-4000-8000-000000000910','00000000-0000-4000-8000-000000000911');
SELECT 'membresias' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.membresias
WHERE id IN ('00000000-0000-4000-8000-000000000912','00000000-0000-4000-8000-000000000913');
SELECT 'categorias' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.categorias
WHERE id IN ('00000000-0000-4000-8000-000000000920','00000000-0000-4000-8000-000000000921');
SELECT 'terceros' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.terceros
WHERE id IN ('00000000-0000-4000-8000-000000000940');
SELECT 'cuentas' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.cuentas
WHERE id IN ('00000000-0000-4000-8000-000000000930','00000000-0000-4000-8000-000000000931','00000000-0000-4000-8000-000000000932');
SELECT 'operaciones' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.operaciones
WHERE id IN ('00000000-0000-4000-8000-000000000950','00000000-0000-4000-8000-000000000951');
SELECT 'movimientos' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.movimientos
WHERE id IN ('00000000-0000-4000-8000-000000000951','00000000-0000-4000-8000-000000000960','00000000-0000-4000-8000-000000000961','00000000-0000-4000-8000-000000000964','00000000-0000-4000-8000-000000000967','00000000-0000-4000-8000-000000000968','00000000-0000-4000-8000-000000000969');
SELECT 'aplicaciones' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.aplicaciones
WHERE id IN ('00000000-0000-4000-8000-000000000962','00000000-0000-4000-8000-000000000963','00000000-0000-4000-8000-000000000965','00000000-0000-4000-8000-000000000983');
SELECT 'transferencias' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.transferencias
WHERE id IN ('00000000-0000-4000-8000-000000000966');
SELECT 'sync_contadores' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.sync_contadores
WHERE negocio_id IN ('00000000-0000-4000-8000-000000000910');
SELECT 'comandos_procesados' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.comandos_procesados
WHERE id IN ('00000000-0000-4000-8000-000000000970','00000000-0000-4000-8000-000000000972');
SELECT 'auditoria' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.auditoria
WHERE id IN ('00000000-0000-4000-8000-000000000971');
SELECT 'comprobantes' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.comprobantes
WHERE id IN ('00000000-0000-4000-8000-000000000980');
SELECT 'vinculos_comprobante' AS tabla,COUNT(*) AS colisiones FROM hackathon_pinguinos_dev.vinculos_comprobante
WHERE id IN ('00000000-0000-4000-8000-000000000981','00000000-0000-4000-8000-000000000982','00000000-0000-4000-8000-000000000983');
SELECT COUNT(*) AS colisiones_telefono FROM hackathon_pinguinos_dev.usuarios
WHERE telefono_normalizado='SQL-TEST-NO-TEL';
-- Las precondiciones se repiten y ABORTAN dentro de V2 antes de cualquier INSERT.
