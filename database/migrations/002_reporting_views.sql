-- Migracion 002: vistas de consulta ACTUALES, no instantaneas historicas.
USE hackathon_pinguinos_dev;
SET SESSION time_zone = '+00:00';
DELIMITER $$
CREATE PROCEDURE hackathon_pinguinos_dev.dbv1_aplicar_002()
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
  SELECT GET_LOCK('hackathon_pinguinos_dev:migraciones',0) INTO v_lock;
  IF v_lock IS NULL OR v_lock <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Otra migracion tiene el bloqueo';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM schema_migraciones WHERE version=1)
     OR EXISTS (SELECT 1 FROM schema_migraciones WHERE version>=2) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Aplicar 001 primero; 002 no puede repetirse';
  END IF;

  CREATE SQL SECURITY INVOKER VIEW v_operaciones_saldos AS
  SELECT o.*,
    CASE WHEN o.estado='CONFIRMADO' THEN COALESCE(a.liquidado_minor,0) ELSE 0 END AS liquidado_minor,
    CASE WHEN o.estado='CONFIRMADO' THEN o.total_minor-COALESCE(a.liquidado_minor,0) ELSE 0 END AS pendiente_minor
  FROM operaciones o
  LEFT JOIN (
    SELECT a.negocio_id,a.operacion_id,SUM(a.monto_minor) AS liquidado_minor
    FROM aplicaciones a
    JOIN movimientos m ON m.negocio_id=a.negocio_id AND m.id=a.movimiento_id AND m.estado='CONFIRMADO'
    GROUP BY a.negocio_id,a.operacion_id
  ) a ON a.negocio_id=o.negocio_id AND a.operacion_id=o.id;

  CREATE SQL SECURITY INVOKER VIEW v_cuentas_saldos AS
  SELECT c.*,
    c.saldo_inicial_minor+COALESCE(m.neto_minor,0) AS saldo_registrado_minor
  FROM cuentas c
  LEFT JOIN (
    SELECT negocio_id,cuenta_id,
      SUM(CASE WHEN direccion='ENTRADA' THEN monto_minor ELSE -monto_minor END) AS neto_minor
    FROM movimientos WHERE estado='CONFIRMADO'
    GROUP BY negocio_id,cuenta_id
  ) m ON m.negocio_id=c.negocio_id AND m.cuenta_id=c.id;

  CREATE SQL SECURITY INVOKER VIEW v_operaciones_diarias AS
  SELECT negocio_id,fecha_operacion,
    SUM(CASE WHEN tipo='VENTA' THEN total_minor ELSE 0 END) AS ventas_minor,
    SUM(CASE WHEN tipo='COMPRA_MERCADERIA' THEN total_minor ELSE 0 END) AS compras_minor,
    SUM(CASE WHEN tipo='GASTO_OPERATIVO' THEN total_minor ELSE 0 END) AS gastos_minor,
    SUM(CASE WHEN tipo='VENTA' THEN total_minor
        WHEN tipo IN ('COMPRA_MERCADERIA','GASTO_OPERATIVO') THEN -total_minor ELSE 0 END) AS resultado_simplificado_minor
  FROM operaciones WHERE estado='CONFIRMADO'
  GROUP BY negocio_id,fecha_operacion;

  CREATE SQL SECURITY INVOKER VIEW v_aplicaciones_diarias AS
  SELECT a.negocio_id,m.fecha_movimiento,
    SUM(CASE WHEN o.tipo='VENTA' THEN a.monto_minor ELSE 0 END) AS cobros_ventas_minor,
    SUM(CASE WHEN o.tipo IN ('COMPRA_MERCADERIA','GASTO_OPERATIVO') THEN a.monto_minor ELSE 0 END) AS pagos_operativos_minor,
    SUM(CASE WHEN o.tipo='SALDO_CXC' THEN a.monto_minor ELSE 0 END) AS cobros_saldo_inicial_minor,
    SUM(CASE WHEN o.tipo='SALDO_CXP' THEN a.monto_minor ELSE 0 END) AS pagos_saldo_inicial_minor,
    SUM(CASE WHEN o.tipo='VENTA' THEN a.monto_minor
        WHEN o.tipo IN ('COMPRA_MERCADERIA','GASTO_OPERATIVO') THEN -a.monto_minor ELSE 0 END) AS flujo_operativo_minor
  FROM aplicaciones a
  JOIN operaciones o ON o.negocio_id=a.negocio_id AND o.id=a.operacion_id AND o.estado='CONFIRMADO'
  JOIN movimientos m ON m.negocio_id=a.negocio_id AND m.id=a.movimiento_id AND m.estado='CONFIRMADO'
  GROUP BY a.negocio_id,m.fecha_movimiento;

  CREATE SQL SECURITY INVOKER VIEW v_dinero_diario AS
  SELECT negocio_id,fecha_movimiento,
    SUM(CASE WHEN direccion='ENTRADA' AND clase<>'TRANSFERENCIA' THEN monto_minor ELSE 0 END) AS entradas_externas_minor,
    SUM(CASE WHEN direccion='SALIDA' AND clase<>'TRANSFERENCIA' THEN monto_minor ELSE 0 END) AS salidas_externas_minor,
    SUM(CASE WHEN direccion='ENTRADA' THEN monto_minor ELSE -monto_minor END) AS cambio_saldo_minor
  FROM movimientos WHERE estado='CONFIRMADO'
  GROUP BY negocio_id,fecha_movimiento;

  INSERT INTO schema_migraciones (version,nombre,contrato_version)
    VALUES (2,'002_reporting_views.sql','1.0.0');
  DO RELEASE_LOCK('hackathon_pinguinos_dev:migraciones');
END$$
DELIMITER ;
CALL hackathon_pinguinos_dev.dbv1_aplicar_002();
