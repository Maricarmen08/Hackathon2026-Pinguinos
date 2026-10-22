-- SOLO LECTURA. Esperado: CERO filas en cada consulta, sobre datos consolidados.
-- Detectores, no restricciones ni reparaciones. Revisar anomalías; no ajustar automáticamente.
USE hackathon_pinguinos_dev;
SELECT 'SOBREABONO' AS alerta,id,pendiente_minor
FROM v_operaciones_saldos WHERE estado='CONFIRMADO' AND pendiente_minor<0;

SELECT 'CONTADO_INCOMPLETO' AS alerta,id,pendiente_minor
FROM v_operaciones_saldos WHERE estado='CONFIRMADO' AND condicion='CONTADO' AND pendiente_minor<>0;

SELECT 'CATEGORIA_INCOMPATIBLE' AS alerta,o.id
FROM operaciones o JOIN categorias c ON c.negocio_id=o.negocio_id AND c.id=o.categoria_id
WHERE o.tipo<>c.tipo;

SELECT 'APLICACION_INCOMPATIBLE' AS alerta,a.id
FROM aplicaciones a
JOIN movimientos m ON m.negocio_id=a.negocio_id AND m.id=a.movimiento_id
JOIN operaciones o ON o.negocio_id=a.negocio_id AND o.id=a.operacion_id
WHERE (m.estado='CONFIRMADO' AND o.estado='ANULADO')
 OR NOT ((m.clase='COBRO' AND o.tipo IN ('VENTA','SALDO_CXC'))
      OR (m.clase='PAGO' AND o.tipo IN ('COMPRA_MERCADERIA','GASTO_OPERATIVO','SALDO_CXP')));

SELECT 'MOVIMIENTO_NO_DISTRIBUIDO' AS alerta,m.id,m.monto_minor,COALESCE(SUM(a.monto_minor),0) AS aplicado_minor
FROM movimientos m LEFT JOIN aplicaciones a ON a.negocio_id=m.negocio_id AND a.movimiento_id=m.id
WHERE m.estado='CONFIRMADO' AND m.clase IN ('COBRO','PAGO')
GROUP BY m.id,m.monto_minor HAVING m.monto_minor<>COALESCE(SUM(a.monto_minor),0);

SELECT 'MOVIMIENTO_VARIOS_TERCEROS' AS alerta,a.movimiento_id
FROM aplicaciones a JOIN operaciones o ON o.negocio_id=a.negocio_id AND o.id=a.operacion_id
GROUP BY a.negocio_id,a.movimiento_id
HAVING COUNT(DISTINCT COALESCE(o.tercero_id,'SIN_TERCERO'))>1;

SELECT 'TRANSFERENCIA_INCONSISTENTE' AS alerta,t.id
FROM transferencias t LEFT JOIN movimientos m ON m.negocio_id=t.negocio_id AND m.transferencia_id=t.id
GROUP BY t.id,t.estado,t.monto_minor,t.cuenta_origen_id,t.cuenta_destino_id,t.fecha
HAVING COUNT(m.id)<>2
 OR SUM(CASE WHEN m.direccion='SALIDA' AND m.cuenta_id=t.cuenta_origen_id
       AND m.monto_minor=t.monto_minor AND m.fecha_movimiento=t.fecha AND m.estado=t.estado THEN 1 ELSE 0 END)<>1
 OR SUM(CASE WHEN m.direccion='ENTRADA' AND m.cuenta_id=t.cuenta_destino_id
       AND m.monto_minor=t.monto_minor AND m.fecha_movimiento=t.fecha AND m.estado=t.estado THEN 1 ELSE 0 END)<>1;

SELECT 'MOVIMIENTO_ANTES_APERTURA' AS alerta,m.id
FROM movimientos m JOIN cuentas c ON c.negocio_id=m.negocio_id AND c.id=m.cuenta_id
WHERE m.fecha_movimiento<c.fecha_apertura;

SELECT 'COMANDO_SIN_EVENTO' AS alerta,c.id
FROM comandos_procesados c LEFT JOIN cambios_sync s ON s.negocio_id=c.negocio_id AND s.command_id=c.id AND s.seq=c.sync_seq
WHERE s.seq IS NULL;

SELECT 'CONTADOR_INCONSISTENTE' AS alerta,c.negocio_id,c.ultimo_seq,COALESCE(MAX(s.seq),0) AS max_seq
FROM sync_contadores c LEFT JOIN cambios_sync s ON s.negocio_id=c.negocio_id
GROUP BY c.negocio_id,c.ultimo_seq HAVING c.ultimo_seq<>COALESCE(MAX(s.seq),0);

SELECT 'NEGOCIO_SIN_PROPIETARIO' AS alerta,n.id
FROM negocios n LEFT JOIN membresias m ON m.negocio_id=n.id AND m.rol='PROPIETARIO' AND m.estado='ACTIVA'
WHERE n.estado='ACTIVO' GROUP BY n.id HAVING COUNT(m.id)=0;

SELECT 'NEGOCIO_SIN_CONTADOR' AS alerta,n.id
FROM negocios n LEFT JOIN sync_contadores c ON c.negocio_id=n.id WHERE c.negocio_id IS NULL;
