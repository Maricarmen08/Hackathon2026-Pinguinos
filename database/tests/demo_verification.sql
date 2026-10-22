-- SOLO LECTURA. Resultados esperados tras semillas 001, sin otros cambios.
USE hackathon_pinguinos_dev;
SET @demo_negocio = '00000000-0000-4000-8000-000000000010';
SELECT 'Ventas=15000 compras=8000 gastos=2000 resultado=5000 (centimos)' AS esperado,
  SUM(ventas_minor) AS ventas_minor,SUM(compras_minor) AS compras_minor,
  SUM(gastos_minor) AS gastos_minor,SUM(resultado_simplificado_minor) AS resultado_minor
FROM v_operaciones_diarias WHERE negocio_id=@demo_negocio;
SELECT 'Cobros=9000 pagos=5000 flujo=4000 (centimos)' AS esperado,
  SUM(cobros_ventas_minor) AS cobros_minor,SUM(pagos_operativos_minor) AS pagos_minor,
  SUM(flujo_operativo_minor) AS flujo_minor
FROM v_aplicaciones_diarias WHERE negocio_id=@demo_negocio;
SELECT 'Venta fiada pendiente=6000; compra pendiente=5000 (centimos)' AS esperado,
  id,tipo,total_minor,liquidado_minor,pendiente_minor
FROM v_operaciones_saldos WHERE negocio_id=@demo_negocio ORDER BY id;
SELECT 'Efectivo=2000; billetera=2000; conjunto=4000 (centimos)' AS esperado,
  nombre,saldo_registrado_minor FROM v_cuentas_saldos WHERE negocio_id=@demo_negocio;
SELECT 'Un usuario bloqueado, hash NULL; no habilitado para login' AS esperado,
  nombre,estado,password_hash IS NULL AS sin_credencial
FROM usuarios WHERE id='00000000-0000-4000-8000-000000000001';
SELECT * FROM schema_migraciones ORDER BY version;
SELECT * FROM schema_semillas ORDER BY version;
