# OCR de comprobantes: filas, total y revisión — 23/10/2026

## Diagnóstico reproducido

Se copió sin alterar la última evidencia de cámara desde el almacenamiento
privado del Android y se verificó que su SHA-256 coincide con el nombre original.
Tiene 3060×4080 y 4.737.537 bytes; contiene productos, precios y pie completos.
No estaba recortada ni se estaba redimensionando antes del OCR: ImagePicker no
recibe maxWidth/maxHeight/imageQuality. El original se conserva por hash antes
de analizarlo.

ML Kit real, en modo avión, devolvió todas las líneas de esa foto, pero agrupadas
por columnas: ARROZ/AZUCAR/SUBTOTAL/TOTAL y después S/12, S/8, S/20, S/20.
El parser anterior requería que TOTAL y su importe estuvieran juntos. El editor
de cuatro líneas solo dejaba ver el encabezado, aunque contenía más texto.

## Cambios puntuales

- `ocr_layout.dart`: reconstruye filas a partir de las cajas y ángulos de líneas
  de ML Kit; ordena los fragmentos de izquierda a derecha. Solo combina columnas
  sin solapamiento horizontal y con cercanía vertical acotada. Usa los ángulos
  reconocidos para normalizar la lectura en giros de 90/180/270 grados; no
  modifica píxeles, no reduce la foto ni inventa palabras. Si no hay geometría,
  conserva el texto completo nativo.
- `local_ocr.dart`: mantiene ML Kit latino local y libera el reconocedor; devuelve
  texto nativo completo y texto ordenado. No cambia el modelo ni usa Gemini.
- `local_rules.dart`: prioriza TOTAL/IMPORTE TOTAL/MONTO TOTAL frente a importes
  genéricos. Subtotal no es total; totales contradictorios quedan por completar.
  No suma productos para fabricar un total ausente ni usa RUC/fecha como importe.
- `receipt_details.dart`: establecimiento, RUC y líneas de productos con cantidad
  e importe explícitos. Los detalles son para revisión local; el contrato de la
  propuesta financiera permanece igual, sin cambios de backend ni esquema SQL.
- La captura conserva el archivo original, su hash y referencia, y guarda el
  OCR nativo y ordenado como metadatos privados de esa evidencia. Releer bytes
  idénticos reinterpreta el mismo pendiente; corregir texto conserva su ID.
  Repetir una foto desde el aviso reemplaza el pendiente actual y conserva los
  originales anteriores. Fotos distintas no se consideran duplicados solo por
  compartir fecha/total: eso podría unir comprobantes legítimos diferentes.
- Flujo: cámara → aceptar → «Analizando imagen en tu celular…» durante el trabajo
  real → interpretar → scroll a Esto entendí. Editor identificado como texto de
  imagen, hasta 6000 caracteres y acceso a texto completo editable. Propuesta con
  establecimiento, productos/precios, total, fecha y medio legibles. Si falta un
  total, aviso para repetir fotografía o completar manualmente. Sin botón Detener
  en fotos ni ocultación por temporizador.
- Una boleta de venta no determina el propósito del comerciante. La propuesta
  sigue DESCONOCIDO y pide elegir venta, compra, gasto u otra operación. Nada se
  confirma automáticamente. Consentimiento externo y controles del backend siguen
  intactos; metadatos adicionales no se envían como nuevos campos de propuesta.

## Validaciones automáticas

- 158 pruebas Flutter aprobadas y una omitida, analyzer sin incidencias antes de
  la compilación. Pruebas nuevas de columnas, total prioritario, contradicciones,
  subtotal/recorte sin total y texto vacío, productos, fecha y clasificación.
- Pruebas widget con dobles explícitos: indicador mientras OCR está pendiente,
  original conservado byte por byte, resultado visible, texto completo editable,
  retoma/relectura sin duplicados, cero POST y cero operaciones financieras en cola.
  Estas pruebas de UI no acreditan precisión del OCR real.
- `tool/test-receipt-ocr-android.ps1`: copias de la imagen adjunta y foto real,
  variantes de prueba rotadas, recortada y borrosa, más una repetición exacta.
  Las transformaciones son fixtures deterministas, no procesamiento destructivo
  de originales. Activity solo debug, protegida por DUMP, sin APIs de negocio.
  Modo avión, Wi-Fi apagado y reverse retirado durante los ensayos; se restauran
  al terminar. Las copias en el dispositivo se verifican con SHA-256.
- `receipt_device_results_test.dart`, ejecutado con
  `--dart-define=CHECK_RECEIPT_DEVICE=true`, aplica exactamente el ensamblador y
  parser de producción a texto/cajas/ángulos reales devueltos por ML Kit Android.
  Comprueba S/20, ARROZ S/12 y AZUCAR S/8, 23/10/2026, efectivo, RUC y negocio,
  y que las imágenes sin total no produzcan uno inventado. El test se omite si
  no se solicita expresamente el reporte físico; no usa datos de red.

Resultados físicos finales: ocho casos aprobados con ML Kit en el Android físico,
en modo avión y sin Wi-Fi: foto real conservada, original adjunto, giros de
90/180/270 grados, recorte sin total, desenfoque extremo y repetición del original.
El parser de producción pasó las ocho comprobaciones sobre esos resultados:
S/20.00, productos S/12.00 y S/8.00, fecha, efectivo, RUC y establecimiento en
las imágenes completas; ningún total inventado en recorte/desenfoque. En un giro
OCR leyó ARR0Z con cero: se conserva esa lectura para corrección humana.

APK debug compilado e instalado mediante `adb install -r` (Success), sin borrar
datos. Se abrió MainActivity y Express respondió `status: ready`; reverse 3000
restaurado. Queda pendiente la revisión humana de una captura nueva y de la
presentación en pantalla: el diagnóstico aislado no crea propuestas de negocio.

Reproducción desde la raíz, después de instalar el APK actualizado:

```powershell
.\tool\test-receipt-ocr-android.ps1 -SourceImagePath 'RUTA_ABSOLUTA_A_BOLETA_PNG' -AirplaneMode
.\tool\flutter-local.ps1 test --no-pub test/receipt_device_results_test.dart --dart-define=CHECK_RECEIPT_DEVICE=true
```

`-CameraEvidenceToken HASH` es opcional y solo acepta un SHA-256 de evidencia
privada ya existente en ese dispositivo. No lee ni modifica MySQL. Resultados y
fixtures en `build/tooling/`, ignorados; no se publican originales del comerciante.

## Revisión humana

Repetir Tomar foto en modo avión con consentimiento externo desmarcado; encuadrar
toda la boleta, esperar análisis, comprobar productos y S/20, abrir texto completo
y elegir el propósito correcto. Corregir y reinterpretar sin crear otro pendiente.
No confirmar datos ficticios. En fotos ilegibles, recortadas o con errores de OCR,
repetir o completar a mano. La cámara/aceptación debe probarla una persona; la
prueba aislada sobre el archivo ya tomado no equivale a operar la cámara nueva.
