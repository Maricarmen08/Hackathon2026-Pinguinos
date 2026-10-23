# Mi constancia: periodo, PDF y prueba real — 23/10/2026

## Ajustes finales de presentación

Se añadió «Alcance del documento» con la redacción legal proporcionada por el
usuario, en un recuadro de altura calculada y separado de observaciones y pie.
El pie solo muestra código completo y página; fórmula, corte y versión permanecen
en los indicadores originales y en metadatos internos del PDF (FinkiFormula,
FinkiCorte y FinkiDocumento). Concordancia: «1 mes con operaciones» y singular
también para un mes completo incluido.

Se leyó la instantánea más reciente en transacción READ ONLY y se regeneró una
copia de presentación local sin crear otra constancia ni escribir en MySQL.
No se sustituyen archivos históricos ni sus hashes registrados: la copia visual
tiene hash propio, vinculado al original en el informe local de auditoría.
PDF entregable: output/pdf/FINKI-constancia-presentacion-final.pdf.
Auditoría local: build/tooling/certificate-final-render-audit.json.
Se verificaron una hoja A4, texto legal exacto, código completo, siete importes,
periodo, singular/plural, metadatos internos y caracteres dentro de márgenes;
se inspeccionó además el render final a PNG.

## Periodo y pantalla

La pantalla usaba inicio_historial como fecha inicial: en Bodega Finki Demo era
22/10/2026 y el cierre era 23/10/2026. El rango era coherente con esas fechas,
pero no representaba una constancia diaria. Ahora abre con Hoy (desde = hasta).

Presets: Hoy, Últimos 7 días (hoy y seis anteriores), Este mes y Rango personalizado.
Se conserva el rango solicitado incluso si empieza antes del historial; el backend
no inventa actividad anterior. Fechas futuras/rangos inválidos siguen rechazados.
Una sola fecha se presenta completa; varias fechas mantienen el rango. La vista
previa, GENERAR_CONSTANCIA y la fila del historial conservan los mismos extremos.
Recuperar una constancia muestra su instantánea histórica, no recalcula su PDF.
Los documentos anteriores permanecen intactos, con su diseño y periodo originales.

UI: selector visible, sección Vista previa, filas compactas de concepto/importe,
promedio separado, generación y opciones de abrir/compartir, historial en tarjetas.
No se rediseñaron Inicio, Historial, Fiados, Reportes, Perfil, voz ni OCR.

## PDF 2.0

A4 vertical, logo real de assets/branding/finki_logo_display.png, identidad azul,
tipografía Helvetica, tabla alineada con siete indicadores y resultado destacado.
Encabezado con negocio, titular registrado (membresía propietaria), emisión en zona
del negocio, periodo y moneda. Promedio solo con meses completos, cobertura,
observaciones y límites: registros del usuario, sin auditoría, no oficial, sin
garantía de crédito ni reemplazo de documentos tributarios. Código, corte de datos,
versión de fórmula y paginación al pie. Anexo mensual solo cuando hay varios meses.

Se reutiliza buildReport: céntimos enteros y datos confirmados. No se suman cobros
como ventas ni pagos como nuevas compras/gastos. El titular y versión documental
se guardan en el JSON de indicadores existente; no se cambiaron tablas ni SQL.
Se conserva almacenamiento privado, hash SHA-256 y recuperación autorizada.

## Prueba REAL autorizada en Bodega Finki Demo

Se ejecutó mediante los endpoints HTTP y comandos reales del Express local con
MySQL hackathon_pinguinos_dev. No fue una simulación ni creación manual por SQL.
Se usó un token temporal en memoria ligado a una sesión Android ya existente y
válida del propietario, sin modificar la sesión del teléfono ni guardar tokens.
La creación por formularios táctiles no se sustituyó por una afirmación: los
registros de esta prueba se crearon por API y se revisaron después en Android.

Cada cuenta, categoría, tercero, operación y movimiento lleva prefijo PRUEBA FINKI
con fecha y sufijo único. Se creó una caja de pruebas, cliente y proveedor de pruebas
y tres categorías de pruebas. Registros financieros:

| Registro | Importe | Estado después de la prueba |
|---|---:|---|
| Venta de arroz al contado | S/50.00 | Cobrada |
| Gasto de bolsas | S/12.00 | Pagado |
| Compra de mercadería a crédito | S/80.00 | Pendiente S/50.00 |
| Venta fiada a cliente de prueba | S/20.00 | Pendiente S/10.00 |
| Abono del fiado | S/10.00 | Aplicado a la venta, sin nueva venta |
| Pago parcial al proveedor | S/30.00 | Aplicado a la compra, sin nueva compra |

Resultados confirmados por backend, consultas y PDF del 23/10/2026:

| Indicador | Resultado |
|---|---:|
| Ventas (incluye fiado) | S/70.00 |
| Cobros de ventas | S/60.00 |
| Gastos operativos | S/12.00 |
| Compras | S/80.00 |
| Pagos operativos | S/42.00 |
| Por cobrar | S/10.00 |
| Por pagar | S/50.00 |
| Saldo de la caja de pruebas | S/18.00 |
| Resultado simplificado | -S/22.00 |

Se comprobaron deltas frente al estado inicial, cuatro operaciones identificadas,
deudas y abonos, indicadores, reporte de actividad, seis preguntas financieras,
historial de constancias y PDF con los mismos indicadores y SHA-256 correcto.
Una repetición con los mismos command_id no creó duplicados. Se compararon hashes
de operaciones y movimientos previos: no cambiaron. No se eliminaron fixtures:
son registros de prueba reales persistentes, como se autorizó.

## Herramienta de ejecución controlada

backend/scripts/demo-certificate-e2e.js solo admite NODE_ENV=development, MySQL
local y la base dev indicada, un negocio único llamado Bodega Finki Demo y sesión
Android vigente del propietario. Requiere FINKI_DEMO_E2E=AUTORIZADO. No se ejecuta
con npm test. Nunca usar en producción ni crear nuevos manifiestos para repetir.

Manifiesto privado de reintento: build/tooling/certificate-demo-e2e.json. Contiene
UUID y cuerpos de comandos para reproducir exactamente las mismas identidades;
no contiene contraseñas ni tokens. Conservarlo; borrarlo y volver a ejecutar podría
crear otro conjunto legítimo de pruebas con UUID nuevos.

PDF real: output/pdf/FINKI-constancia-PRUEBA-FINKI.pdf.
Constancia guardada: 2ef19e7d-629f-4edf-a841-26e153469a6c.

## Validación y revisión pendiente

164 pruebas Flutter aprobadas (2 omitidas), 86 backend y 22 MySQL aisladas.
Los datos ficticios automatizados ajenos al flujo demo se crean exclusivamente
en memoria o en hackathon_pinguinos_test. Analyzer sin incidencias.
PDF real renderizado y revisado: una página A4, titular, fecha y siete importes
verificados por extracción de texto. Pruebas adicionales de nombre largo/anexo de
22 meses: sin caracteres fuera del margen; primera y última página revisadas.

APK compilado en 233,5 s e instalado con `adb install -r` (Success), sin clean,
dependencias nuevas ni compilaciones simultáneas. Android mantuvo sesión y negocio.
Comprobaciones reales de interfaz con estos registros:

- Inicio: ventas S/70.00.
- Historial: operaciones PRUEBA FINKI confirmadas; API verificó cuatro operaciones.
- Fiados: venta S/20.00, abonado S/10.00, pendiente S/10.00.
- Debo pagar: compra S/80.00, abonado S/30.00, pendiente S/50.00.
- Reportes: ventas S/70.00, gastos S/12.00, compras S/80.00 y resultado -S/22.00.
- Asistente: consulta de ventas de hoy respondió S/70.00 para 23/10/2026.
- Mi constancia: las siete cifras coinciden; Hoy muestra 23 de octubre de 2026.
  Siete días mostró 17-23, mes mostró 1-23; el calendario personalizado permitió
  seleccionar y guardar 22-23. No se generaron PDFs adicionales para cada preset.
- Se pulsó Generar constancia desde Android para 22-23. Apareció «Tu constancia
  está lista», nueva fila del historial de las 09:41 y apertura real en el visor
  de impresión/guardar PDF de Android: una página ISO A4 con el diseño nuevo.
- Historial conserva tres documentos: nuevo rango 22-23 (09:41), diario 23 (09:26)
  y anterior 22-23 (08:22). Son documentos de periodos distintos, no duplicados de
  operaciones. Se recuperó el documento diario sin volver a generarlo.

Se inspeccionaron capturas Android de cada módulo en build/tooling/certificate-*.png
y JSON de UI correspondientes. Se dejó abierta FINKI; Express sigue ready.
La creación financiera real fue por API, no mediante escritura táctil de formularios;
la generación y apertura de la constancia de rango sí se ejecutaron desde la UI.
No se realizaron llamadas a Gemini, impresiones ni envíos externos.

Validación humana restante: elegir un destino personal para guardar/compartir el
PDF y revisar su legibilidad a tu gusto. No hay un bloqueo técnico conocido del
flujo probado; no se afirma cobertura del 100% de todos los dispositivos/destinos.

No se cambiaron rama, secretos ni esquema. Sin commits ni push.
