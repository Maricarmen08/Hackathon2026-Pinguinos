# Asistente de reportes — 23/10/2026

## Corrección tras las pruebas reales de periodos

«Mis ventas del día» no era reconocido y caía en el mes predeterminado.
Ahora se resuelve primero el periodo explícito: hoy/del día, ayer, semana actual,
mes actual, mes pasado, últimos siete días (hoy y seis anteriores), fecha o rango.
Tildes, mayúsculas y signos no cambian la interpretación. Fechas explícitas tienen
prioridad; periodos relativos contradictorios solicitan aclaración.

«Esta mañana» se reconoce como hoy, con advertencia breve de que se muestra el
día completo: los registros tienen fecha, no una hora financiera fiable para
separar solo la mañana. «Mañana» como futuro continúa sin soportarse.
La fecha civil se obtiene primero en la zona del negocio. UTC se usa únicamente
para sumar/restar días de calendario, sin convertir el día local en otro día.
El respaldo de Gemini también obtiene el periodo con la zona y permisos del
negocio; el modelo no elige fechas ni cifras.

Ventas presenta cifra y periodo, sin adjuntar cobros no solicitados. Los cálculos
de cobros, pagos, gastos, compras, fiados y abonos se conservan. Deudores vacíos:
«Nadie tiene una deuda pendiente registrada al DD/MM/AAAA». No se agrega a ese
saldo una advertencia sobre el mes, porque es un saldo al cierre, no ventas del
periodo. Para periodos incompletos se conserva una advertencia breve con la fecha
de inicio del historial, sin repetir el párrafo de movimientos ausentes.

«Quién eres»/saludos explican brevemente que Finki ayuda con el negocio.
«Quién soy» remite a Perfil sin inventar identidad. Son respuestas de orientación,
sin Gemini y sin atribuirles una fuente financiera. No cambia el diseño de la UI.
La caché de consultas usa versión 2: las respuestas anteriores quedan intactas,
pero no se recuperan respuestas que pudieran contener el periodo incorrecto.
Sesión, negocio y datos financieros no se borran.

Validación posterior: 84 pruebas backend, 22 MySQL aisladas y 163 Flutter aprobadas
(2 omitidas). Fixtures con importes diferentes hoy/ayer/semana/mes y negocio
temporal separado; ninguna escritura de prueba en `hackathon_pinguinos_dev`.
Pruebas de Lima frente a Tokio cerca de medianoche UTC y cambios de mes;
regresión de nueve sugerencias, fiados/abonos y autorización entre negocios.
No se realizaron llamadas reales a Gemini.

Actualización instalada en Android mediante `adb install -r` (Success), tras una
única compilación de 237,6 s; analyzer sin incidencias. Express reiniciado y ready,
reverse 3000 activo. Sesión y negocio conservados. Se verificaron en la interfaz,
comprobando el texto exacto antes de consultar:

- `mis ventas del dia` → S/0.00 en ventas, únicamente 23/10/2026.
- `quien me debe mas` → nadie tiene deuda pendiente registrada al 23/10/2026.
- `quien eres` → presentación breve de Finki.
- `quien soy` → acceso a Perfil, sin inventar identidad.

Los ceros corresponden al negocio seleccionado; no se crearon operaciones para
esta revisión. Los importes diferenciados se validaron solo en fixtures aislados.
Resultados privados de UI en `build/tooling/period-android-ui-results.json` y
captura `finki-period-answer.png`. Ayer, mes y siete días quedan cubiertos por
automatización; el usuario puede repetirlos visualmente sin crear operaciones.

## Antes

El endpoint POST `/api/v1/negocios/:id/consultas` admitía las nueve sugerencias:
ventas hoy/mes, mayor gasto, gastos semanales, saldo por cobrar, comparación con
mes anterior, cobros semanales, compras de mercadería y resumen semanal.
Una coincidencia genérica con «semana» interceptaba consultas específicas y
respondía con un resumen. Productos más vendidos tenía una explicación de límite.
La pantalla ya usaba Wrap, pero textos largos y el tema de chips producían una
lista alta; no había caché de respuestas POST ni desplazamiento al resultado.

## Ahora

- Acceso desde Reportes con separación de título, tarjeta compacta, icono,
  descripción y flecha. Inicio, Perfil, voz y OCR no se rediseñaron.
- Campo de pregunta y consulta antes de las sugerencias; nueve chips de etiquetas
  breves, pregunta completa en tooltip, resultado legible y scroll suave.
- Consultas deterministas por variantes de lenguaje: ventas, gastos operativos,
  compras, cobros de ventas y deudas iniciales, pagos operativos y deudas iniciales,
  pendientes por cobrar/pagar, mayores deudores agrupados por tercero, mayor gasto
  por categoría, entradas/salidas externas, comparaciones, resumen y recomendaciones
  prudentes basadas en registros.
- Periodos: hoy, ayer, semana actual (lunes a hoy), semana pasada, mes actual,
  mes pasado y una fecha o rango DD/MM/AAAA o AAAA-MM-DD. Fecha imposible, futura,
  rango invertido o demasiado largo: error claro. Meses por nombre/años naturales
  todavía requieren fechas explícitas. Cada respuesta identifica el periodo.
- Comparar con mes pasado muestra mes actual parcial frente al anterior completo;
  otras comparaciones usan el periodo anterior de igual duración. Se advierte si
  el historial no cubre todo el periodo. No se calculan porcentajes de crecimiento
  sobre una base cero ni se fabrican tendencias.
- Datos escasos: cero registrado no demuestra ausencia de actividad. Resultado
  simplificado no es utilidad contable ni efectivo disponible. No se atribuyen
  causas externas a un resultado negativo.

## Cálculos, permisos y privacidad

Se reutiliza buildReport, céntimos BigInt y registros CONFIRMADO. Aplicaciones de
abonos reducen pendientes; cobros no crean ventas. Se excluyen transferencias de
entradas/salidas externas. Anulaciones conservan las reglas existentes.
El servicio verifica sesión y membresía antes de leer cada negocio; terceros y
categorías se filtran por negocio. Un LECTOR puede consultar; un usuario ajeno no.
Las preguntas no se convierten en SQL. No hay cambios de esquema ni migraciones.

## Gemini opcional

Primero se intenta resolver con reglas. Solo tras una pregunta no soportada se
ofrece autorización explícita para enviar **esa pregunta**, sin registros ni
indicadores, a Gemini. El proveedor devuelve una intención enumerada, no cifras,
SQL ni fechas. Las fechas se resuelven localmente y los cálculos se repiten en el
servicio autorizado. Un resultado externo no permitido se rechaza.

Se reutilizan presupuesto y circuito persistentes del proveedor: sin reintentos
automáticos, cuota agotada bloquea llamadas repetidas. La pantalla pausa el botón
externo tras un 503; las consultas deterministas siguen funcionando. No se
realizaron llamadas reales a Gemini durante esta validación; se usaron dobles.
La interpretación externa de preguntas está disponible con Gemini, no OpenAI.

## Sin conexión

Se conserva la última respuesta exitosa para la pregunta exacta, usuario y negocio,
con fecha/hora. Solo se recupera ante error de red (no ante 401/403/422).
La pantalla la identifica como histórica y posiblemente desactualizada; «hoy»
corresponde al periodo original mostrado en esa respuesta, no al día actual.
Sin respuesta guardada se informa la limitación; no se calculan totales nuevos con
una réplica posiblemente incompleta. Cambiar de usuario/negocio no reutiliza caché.

## Validación

- Flutter: 163 aprobadas, 2 omitidas; analyzer sin incidencias.
- Backend: 63 aprobadas. Incluyen nueve sugerencias, variantes libres, periodos,
  comparaciones, fiados, abonos, ranking de deudores, ausencia de datos, límites,
  consentimiento, cuota agotada y acceso ajeno rechazado.
- MySQL: 21 aprobadas exclusivamente en `hackathon_pinguinos_test`; no se preparó
  ni reinicializó el esquema. Fixtures creados únicamente en esa base aislada.
- Desarrollo: seis evaluaciones de consultas sobre dos negocios existentes dentro
  de snapshot READ ONLY, sin modificar registros ni publicar información personal.
- UI con dobles: nueve chips, consulta libre, respuesta visible en 360×800,
  botón vacío deshabilitado, errores útiles, caché histórica y aislamiento por negocio.
- APK debug compilado en 311,1 s con configuración de baja memoria, sin clean,
  cambios de dependencias ni compilaciones simultáneas. Instalado con `adb install -r`
  (Success), reverse 3000 restablecido y Express `status: ready`.
- Verificación visual en Android físico: acceso Reportes, tarjeta nueva, pantalla
  de preguntas con las nueve sugerencias compactas, consulta real «Ventas de hoy»
  y tarjeta de respuesta visible tras scroll. La sesión y Bodega Finki Demo se
  conservaron. La consulta devolvió ventas/cobros S/0.00 con explicación de ausencia
  de movimientos confirmados; no se creó ninguna operación.
- Capturas locales de verificación en `build/tooling/finki-reports.png`,
  `finki-questions.png` y `finki-answer.png` (ignoradas, no publicadas).

## Límites y revisión humana

No predice ventas/crédito, consulta bancos, inventa causas o reconstruye inventario
por producto. Una pregunta con periodo no reconocido debe reformularse con fechas.
La cobertura declarada no prueba que el comerciante registró toda su actividad.

En Android: Reportes → Pregúntale a Finki; comprobar chips, teclado y scroll.
Probar «Dime mis ventas de esta semana», «¿Quién me debe más?», «¿Cómo va mi
negocio?» y comparación mensual. Sin movimientos deben aparecer ceros registrados
y límites, no conclusiones. Repetir una pregunta consultada en modo avión para
ver la advertencia de respuesta histórica; otra no guardada debe explicar el error.
No hace falta confirmar ni crear operaciones para estas comprobaciones.

Sin commits, push, cambio de rama ni modificaciones de secretos.
