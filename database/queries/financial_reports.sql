-- SOLO LECTURA de tablas; variables de sesion para ejemplos DEMO.
-- El backend debe validar permisos, fechas y ejecutar en snapshot consistente.
USE hackathon_pinguinos_dev;
SET @negocio='00000000-0000-4000-8000-000000000010';
SET @desde=CAST('2026-10-01' AS DATE);
SET @hasta=CAST('2026-10-22' AS DATE);
-- No unir operaciones a varias aplicaciones antes de sumar ventas.
SELECT COALESCE(SUM(ventas_minor),0) AS ventas_minor,
 COALESCE(SUM(compras_minor),0) AS compras_minor,
 COALESCE(SUM(gastos_minor),0) AS gastos_minor,
 COALESCE(SUM(resultado_simplificado_minor),0) AS resultado_simplificado_minor
FROM v_operaciones_diarias
WHERE negocio_id=@negocio AND fecha_operacion BETWEEN @desde AND @hasta;
SELECT COALESCE(SUM(cobros_ventas_minor),0) AS cobros_minor,
 COALESCE(SUM(pagos_operativos_minor),0) AS pagos_minor,
 COALESCE(SUM(flujo_operativo_minor),0) AS flujo_operativo_minor
FROM v_aplicaciones_diarias
WHERE negocio_id=@negocio AND fecha_movimiento BETWEEN @desde AND @hasta;

-- Pendiente a fecha de corte: excluye abonos POSTERIORES al corte.
SELECT o.id,o.tipo,o.total_minor,
 o.total_minor-COALESCE(a.pagado_minor,0) AS pendiente_al_corte_minor
FROM operaciones o
LEFT JOIN (
 SELECT a.negocio_id,a.operacion_id,SUM(a.monto_minor) AS pagado_minor
 FROM aplicaciones a
 JOIN movimientos m ON m.negocio_id=a.negocio_id AND m.id=a.movimiento_id
 WHERE m.estado='CONFIRMADO' AND m.fecha_movimiento<=@hasta AND a.negocio_id=@negocio
 GROUP BY a.negocio_id,a.operacion_id
) a ON a.negocio_id=o.negocio_id AND a.operacion_id=o.id
WHERE o.negocio_id=@negocio AND o.estado='CONFIRMADO' AND o.fecha_operacion<=@hasta;

SELECT c.id,c.nombre,c.saldo_inicial_minor+COALESCE(m.neto_minor,0) AS saldo_al_corte_minor
FROM cuentas c LEFT JOIN (
 SELECT negocio_id,cuenta_id,SUM(CASE WHEN direccion='ENTRADA' THEN monto_minor ELSE -monto_minor END) AS neto_minor
 FROM movimientos WHERE negocio_id=@negocio AND estado='CONFIRMADO' AND fecha_movimiento<=@hasta
 GROUP BY negocio_id,cuenta_id
) m ON m.negocio_id=c.negocio_id AND m.cuenta_id=c.id
WHERE c.negocio_id=@negocio AND c.fecha_apertura<=@hasta;

-- Promedio de meses COMPLETOS observados, con meses sin filas = 0.
-- Solicitudes backend limitadas a 120 meses; no depender de limite CTE para validar entrada.
SET @inicio=(SELECT GREATEST(inicio_historial,@desde) FROM negocios WHERE id=@negocio);
SET @primer_mes=CASE WHEN DAY(@inicio)=1 THEN @inicio
 ELSE DATE_ADD(LAST_DAY(@inicio),INTERVAL 1 DAY) END;
SET @ultimo_mes=CASE WHEN @hasta=LAST_DAY(@hasta)
 THEN DATE_SUB(@hasta,INTERVAL (DAY(@hasta)-1) DAY)
 ELSE DATE_SUB(DATE_SUB(@hasta,INTERVAL (DAY(@hasta)-1) DAY),INTERVAL 1 MONTH) END;
WITH RECURSIVE meses AS (
 SELECT @primer_mes AS mes WHERE @primer_mes<=@ultimo_mes
 UNION ALL
 SELECT DATE_ADD(mes,INTERVAL 1 MONTH) FROM meses WHERE mes<@ultimo_mes
), totales AS (
 SELECT meses.mes,COALESCE(SUM(o.total_minor),0) AS ventas_minor
 FROM meses LEFT JOIN operaciones o ON o.negocio_id=@negocio AND o.tipo='VENTA'
  AND o.estado='CONFIRMADO' AND o.fecha_operacion>=meses.mes
  AND o.fecha_operacion<DATE_ADD(meses.mes,INTERVAL 1 MONTH)
 GROUP BY meses.mes
)
SELECT COUNT(*) AS meses_completos,
 ROUND(SUM(ventas_minor)/NULLIF(COUNT(*),0),0) AS promedio_ventas_minor,
 CASE WHEN COUNT(*)=0 THEN 'HISTORIAL_INSUFICIENTE' ELSE 'VERIFICAR_COBERTURA' END AS advertencia
FROM totales;

SELECT COUNT(DISTINCT fecha_operacion) AS dias_con_ventas,
 COUNT(DISTINCT DATE_FORMAT(fecha_operacion,'%Y-%m')) AS meses_con_ventas,
 MIN(fecha_operacion) AS primera_venta,MAX(fecha_operacion) AS ultima_venta
FROM operaciones WHERE negocio_id=@negocio AND tipo='VENTA' AND estado='CONFIRMADO'
 AND fecha_operacion BETWEEN @desde AND @hasta;
SELECT tipo_dia,COUNT(*) AS dias_declarados FROM cierres_diarios
WHERE negocio_id=@negocio AND fecha BETWEEN @desde AND @hasta GROUP BY tipo_dia;
SELECT inicio_historial,
 GREATEST(0,TIMESTAMPDIFF(MONTH,inicio_historial,@hasta)) AS meses_transcurridos
FROM negocios WHERE id=@negocio;
-- La ausencia de cierres no implica ausencia de ventas. Ver docs/REPORTING.md.
