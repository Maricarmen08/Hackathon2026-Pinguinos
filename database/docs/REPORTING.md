# Indicadores y reportes — contrato fórmula 1.0.0

Ejemplos SQL de solo lectura en `queries/financial_reports.sql`; seleccionar el negocio autorizado y validar fechas antes de usarlos en una API.

## Fuentes y precisión

Las cinco vistas de 002 calculan estado ACTUAL completo. No filtran automáticamente negocio, período o fecha de corte. Aplicar negocio_id siempre. No usar la vista de pendientes actuales para reconstruir un saldo de una fecha pasada.

SUM de BIGINT puede devolverse como DECIMAL exacto por MySQL. Mantenerlo como texto/BigInt en API; mostrar soles con dos decimales sin división en punto flotante para sumas.

- v_operaciones_saldos: total, liquidado y pendiente por operación; anulado devuelve pendiente cero. Movimiento anulado no liquida.
- v_cuentas_saldos: saldo inicial + movimientos confirmados.
- v_operaciones_diarias: ventas, compras, gastos y resultado simplificado por fecha comercial.
- v_aplicaciones_diarias: cobros de ventas, pagos operativos y flujo; separa cobros/pagos de deudas iniciales.
- v_dinero_diario: entradas/salidas externas (excluye transferencias propias) y cambio de saldo.

No unir operaciones y aplicaciones sin preagrupar: duplicaría ventas al existir varios abonos.

## Fórmulas

Ventana comercial [desde,hasta], inclusiva, America/Lima en la demo. Confirmados únicamente.

- Ventas: SUM(total_minor) tipo VENTA por fecha_operacion.
- Compras: tipo COMPRA_MERCADERIA.
- Gastos: tipo GASTO_OPERATIVO.
- Resultado operativo simplificado: ventas - compras - gastos.
- Cobros: aplicaciones de movimientos COBRO confirmados a ventas confirmadas, por fecha_movimiento. No son ventas nuevas.
- Pagos operativos: aplicaciones a compras/gastos por fecha_movimiento.
- Flujo operativo: cobros de ventas - pagos operativos.
- Cobros/pagos SALDO_CXC/CXP: presentar aparte (antecedentes previos al historial), sin inventar ventas/compras del período.
- Entradas/egresos de dinero: movimientos externos confirmados, distinguiendo actividad operativa, aportes, retiros, financiamiento, inversión y ajustes.
- Pendiente al corte: total de operación con fecha<=corte menos aplicaciones cuyo movimiento confirmado tiene fecha<=corte. Separar por cobrar VENTA/SALDO_CXC y por pagar COMPRA_MERCADERIA/GASTO_OPERATIVO/SALDO_CXP.
- Saldo cuenta al corte: si fecha_apertura<=corte, saldo inicial + entradas - salidas con fecha<=corte.
- Atraso: pendiente>0 y vence_el<corte; fecha futura o ausencia de vencimiento no es atraso.

Las anulaciones corrigen el historial ACTUAL. Para un reporte ya emitido, conservar su snapshot indicadores, parámetros, corte_sync_seq, versión de fórmula y archivo/hash. Una nueva consulta puede producir un resultado histórico corregido; no reemplazar el PDF anterior.

Resultado simplificado NO es utilidad contable: compras no equivalen necesariamente a costo de ventas; no hay inventario, depreciación ni cálculo fiscal. No llamar “margen neto” ni “saldo bancario verificado” a estas aproximaciones.

## Promedio mensual

1. Definir ventana solicitada y observada (inicio_historial y corte).
2. Usar meses calendario completos dentro de esa intersección; excluir mes inicial parcial y mes final incompleto.
3. Enumerar los meses (incluidos los que no tienen filas).
4. Sumar ventas mensuales; meses sin registros aportan cero, pero indicar si su cobertura es desconocida.
5. Promedio = suma de ventas / número de meses elegibles. Redondear resultado final a céntimos, mitad hacia arriba para importes positivos.
6. Cero meses elegibles: NULL + motivo HISTORIAL_INSUFICIENTE, nunca división por cero o promedio inventado.
7. Mostrar N, meses con ventas, meses completos cubiertos y porcentaje de cobertura por cierres.

No seleccionar solo meses positivos, no dividir siempre por 12, no presentar ingresos anualizados como observados.

## Antigüedad y regularidad

- Mostrar primera/última venta y fecha de inicio de historial declarado.
- Meses completos transcurridos desde inicio_historial al corte (no desde creado_en del usuario).
- Meses distintos con ventas como indicador separado.
- Días con >=1 venta confirmada por mes.
- Cierres distinguen CON_ACTIVIDAD, SIN_VENTAS y NO_LABORABLE.
- Días sin cierre = cobertura desconocida; no asumir no laborables ni ausencia de ventas.
- Regularidad declarada: días laborables cubiertos con ventas / días laborables declarados y cubiertos; denominador visible.
- Rechazar cierres SIN_VENTAS con ventas válidas y advertir inconsistencias CON_ACTIVIDAD sin registros; estas son validaciones del backend.
- Sin cobertura suficiente: limitarse a frecuencia registrada. No calificar estabilidad/capacidad de pago.

## Generación PDF

En servidor: transacción de lectura consistente, obtener último seq visible y datos de esa instantánea; calcular con fórmula versionada y guardar snapshot. Publicar reporte mediante comando. Una cola debe conservar el snapshot, no recalcular con datos posteriores manteniendo el mismo corte.

Reportes listos requieren indicadores, archivo privado, hash y generado_en. No se genera PDF en esta entrega.

PDF: negocio/período/moneda; ventas, cobros, compras, gastos, flujo y resultado; pendientes; series y promedio; regularidad/cobertura; meses de historial; metodología y limitaciones; ID y corte de datos.

Advertir sobre comandos locales no sincronizados. Leyenda: “Reporte de actividad registrada por el usuario; no constituye certificación ni aprobación crediticia”.

La demo de un solo día NO proporciona historial suficiente de meses completos y cubiertos para evaluar estabilidad.
