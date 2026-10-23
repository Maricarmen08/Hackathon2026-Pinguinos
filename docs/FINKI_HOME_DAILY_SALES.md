# Inicio: ventas de hoy — 23/10/2026

La tarjeta azul leía report.ventas_minor del endpoint general de indicadores,
desde inicio_historial hasta hoy. Por eso mostraba 22-23/10 en Bodega Finki Demo.
Ahora usa GET /api/v1/negocios/:id/ventas/hoy; los demás indicadores y secciones
siguen usando el reporte general. No se alteró la constancia ni su PDF.

La nueva lectura verifica sesión y membresía, filtra todas las entidades por el
negocio autorizado y utiliza buildReport con desde = hasta = fecha civil actual
en zona_horaria del negocio. Incluye VENTA CONFIRMADO (contado y crédito), excluye
anulaciones y propuestas, y no suma aplicaciones de abonos como ventas nuevas.
No hay cambios de esquema ni dependencias nuevas.

## Fecha y caché

El servidor devuelve el día y sus límites UTC exactos. Se calcula primero la fecha
civil con Intl y luego se buscan sus fronteras: no se supone que todos los días
tienen 24 horas ni que todos los negocios usan UTC-5. La app invalida el día al
llegar al límite y vuelve a consultar, además de los refrescos y retorno a la app.

La caché existente queda separada por usuario y ruta del negocio. Se conserva la
marca de que la respuesta diaria vino de caché aunque después otras consultas
recuperen conexión. Solo se acepta la respuesta si coincide negocio, fecha/rango,
importe entero y límites válidos.

- Caché del día vigente: importe guardado y aviso de posible desactualización.
- Caché de otro día: «Sin datos de hoy», fecha identificada como último dato y
  último importe solo en la aclaración histórica, nunca como total diario actual.
- Sin caché válida: estado informativo y petición de conectar; no se fabrica cero.
- Un cero confirmado por el servidor sí se muestra como S/0.00.
- No se usa el acumulado, la réplica parcial ni propuestas locales como sustituto.

Se mantiene el azul, icono, bordes, tipografía y orden de Inicio. Solo cambian
título, fecha, origen del importe y estados informativos de la tarjeta.

## Validación

- 90 pruebas backend aprobadas: contado/fiado, ayer, anulada/pendiente, abono,
  cero real, Lima cerca de medianoche UTC, Tokio y días de 23/25 h por DST.
- 22 MySQL aisladas aprobadas, con comprobación de la nueva ruta, permisos,
  acceso ajeno rechazado y cifras distintas por día en hackathon_pinguinos_test.
- 167 Flutter aprobadas (2 omitidas), incluidas caché hoy/ayer/ausente, cambio de
  negocio y regresión visual en seis tamaños de pantalla.
- Consulta real autorizada de solo lectura: Bodega Finki Demo, 23/10/2026,
  ventas 7000 céntimos. Coincide con Reportes para esa fecha y el asistente.
  No se ejecutaron comandos financieros ni la herramienta E2E de escritura.

Archivos principales: lib/v1/app.dart, lib/v1/daily_sales.dart,
backend/src/app.js, backend/src/services/queries.js y daily-sales.js.
Resultados de pruebas en build/tooling/home-daily-*.log; lectura real en
home-daily-real-readonly.json. Sin modificación de secretos, ramas, commits o push.

Analyzer sin incidencias. APK debug compilado en 325,5 s, una sola compilación,
sin clean ni herramientas nuevas. Instalación `adb install -r`: Success; reverse
3000 activo y Express ready. Sesión de Danny y Bodega Finki Demo conservadas.

Revisión real de XML de accesibilidad y captura de Android: «Ventas de hoy»,
«23 de octubre de 2026», «S/70.00» e inclusión de contado/fiado; azul, icono,
bordes y jerarquía sin cambios. Imagen: build/tooling/home-daily-android.png.
Modo sin conexión y cambio de día/negocio validados automáticamente; no se cambió
la fecha del teléfono ni se alteraron registros reales para simular otro día.
