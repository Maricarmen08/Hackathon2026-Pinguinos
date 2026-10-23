# FINKI V4: reconocimiento local y respaldo externo

Actualización: el modelo Vosk independiente y la validación física más reciente
se documentan en [FINKI_OFFLINE_FINAL.md](FINKI_OFFLINE_FINAL.md). Las notas de
disponibilidad nativa y pruebas pendientes de esta guía son históricas.

Implementación del 22/10/2026 sobre V4, rama `danny`. No requiere migraciones,
reimportar el SQL consolidado ni cambiar los secretos existentes.

## Flujo y alcance

1. Hablar usa el reconocedor **on-device** de Android mediante el canal nativo
   `finki/local_speech`. Requiere Android 12/API 31 o posterior y un servicio
   compatible. Android 13+ consulta los idiomas instalados; prefiere `es-PE`,
   después `es-ES` y después otro español instalado. Un error de consulta no
   equivale a demostrar que exista un modelo español: se intenta y se informa
   el fallo. No se usa silenciosamente un reconocedor de voz en la nube.
2. La transcripción queda editable; «Interpretar texto corregido» aplica reglas
   locales. No se guarda una operación por terminar de hablar.
3. Si no hay servicio local, se ofrece escribir o la grabación WAV anterior.
   Esta última necesita conexión, disponibilidad externa y consentimiento;
   conserva el máximo de 45 segundos. La ruta antigua puede consumir una llamada
   de transcripción y otra de interpretación; la ruta local no consume ninguna.
4. Cámara/galería en Android conserva los bytes originales (PNG/JPEG, hasta 7 MB),
   ejecuta OCR latino incluido en la aplicación y muestra la misma tarjeta V4.
   No reduce la imagen ni envía contenido a Gemini automáticamente. El backend
   conserva sus comprobaciones de formato y dimensiones antes de aceptar archivos.
5. Reglas deterministas reconocen ventas, compras, gastos, fiados, abonos y pagos
   de deuda. Entienden importes numéricos y expresiones españolas habituales.
   Los datos ausentes quedan vacíos y los ambiguos requieren corrección humana.
   No constituyen un modelo general de comprensión de lenguaje.
6. Boletas y capturas permiten extraer texto/importe/referencia. Una imagen
   siempre pide clasificar la operación. Yape/Plin nunca crean una venta por sí
   mismos: se puede elegir cobro, pago, abono, traslado o adjuntar a un registro.
7. Se reutilizan los formularios, «Esto entendí», selección de pendiente y
   confirmación V4. El usuario puede cambiar el tipo y completar los datos.

## Corrección del ensayo de voz «Gasté 23 soles en azúcar»

El diagnóstico de solo lectura confirmó entrada AUDIO, proveedor Gemini y
transcripción exacta `Gasté 23 soles en azúcar.`. Su respuesta marcó `es_pago=true`;
el validador de protección de pagos la dejó como `DESCONOCIDO`. La regla local
de «gasté» ya clasificaba correctamente el texto, pero no se reaplicaba después
de la transcripción de la grabación alternativa. Esa ruta sí consultaba Gemini.
El teléfono en modo avión puede llegar a Express por USB y Express conserva
su propia conexión a internet: el modo avión por sí solo no demuestra voz local.

La corrección se limita a la recepción de una transcripción de audio: se identifica
su fuente como VOZ y se contrasta con las reglas locales. Si hay intención clara
y coincidencia exacta de importe, se corrigen intención, bandera de pago ambiguo
y pregunta. Se conservan importe, concepto, imagen/audio, ID de extracción y
confirmación humana. Una frase ambigua o un importe discrepante no se fuerza;
la clasificación protectora de fotografías Yape/Plin sigue vigente.

No se cambió la disponibilidad del reconocedor ni la grabación alternativa:
«Usar grabación alternativa» significa que la app no tiene reconocimiento local
disponible en ese momento (servicio/modelo español ausente, consulta pendiente
o fallo anterior). En el diagnóstico el indicador local estaba en falso. No se
puede atribuir solo a la versión Android ni asegurar reconocimiento sin conexión.
La grabación alternativa conserva su procesamiento externo y consumo anterior.
No se corrigieron ni guardaron propuestas existentes durante el diagnóstico.

Pruebas añadidas: las tres frases de gasto/venta/compra en reglas y canal de voz
simulado; respuesta alternativa con `es_pago=true`; discrepancias/ambigüedad;
preservación del ID servidor y ausencia de comandos financieros automáticos.
También se verifica el rótulo de los pendientes y su reapertura sin escribir la
propuesta del servidor. Resultado final de esta corrección: análisis sin incidencias,
101 pruebas Flutter aprobadas y una externa opcional omitida; APK compilada en
253,7 segundos. No hubo llamadas Gemini reales durante la corrección ni pruebas
SQL de escritura. La evidencia del ensayo se consultó mediante una transacción
READ ONLY; no se restauró ni modificó su estado.

Archivos de esta corrección: `lib/v1/local_rules.dart`, `lib/v1/intake_page.dart`,
`test/local_rules_test.dart`, el nuevo `test/voice_intent_regression_test.dart`
y esta guía. No cambia backend, dependencias, esquema MySQL ni diseño.

Para repetir: abrir «Hablar con Finki» después de actualizar, dejar sin marcar
el consentimiento externo y activar modo avión, además de apagar Wi-Fi si sigue
habilitado. Pulsar Hablar. Si el servicio local está disponible, revisar que el
campo editable diga la frase completa y pulsar Interpretar: debe sugerir Gasto
y S/23.00. Si no hay reconocimiento local, detener ahí la prueba offline; escribir
la misma frase verifica únicamente la interpretación local, no la voz.
Para el respaldo externo se necesita conectividad con Express y consentimiento:
tras transcribir la misma frase, la nueva propuesta debe sugerir Gasto.
No pulsar la confirmación financiera en un ensayo con datos ficticios.

## Dependencias y compatibilidad

- Voz: integración Android nativa; no se añadió `speech_to_text` ni un motor ASR
  pesado. El servicio y los idiomas dependen del teléfono.
- `google_mlkit_text_recognition: 0.15.1`, con `google_mlkit_commons: 0.11.1`
  transitivo. Se eligió la versión Java del puente compatible con la configuración
  actual. Su dependencia Android `com.google.mlkit:text-recognition:16.0.1`
  incluye el modelo latino; no depende de descargarlo durante el primer OCR.
- `crypto: 3.0.7` y `path_provider: 2.1.6` pasan a ser dependencias directas para
  SHA-256 y archivos privados; ya estaban presentes transitivamente en V4.
- No se actualizaron Flutter, Gradle, Kotlin ni Java. Se mantienen los límites de
  [ANDROID_LOW_MEMORY.md](ANDROID_LOW_MEMORY.md). Compilar solo una tarea a la vez.
- Web conserva formularios, reglas y el flujo externo anterior. La voz nativa y
  ML Kit de esta implementación son Android; no se promete OCR/voz local en Chrome.

## Persistencia, evidencia y seguridad financiera

Las propuestas locales son borradores del dispositivo, aislados por usuario y
negocio en el almacenamiento seguro existente. Su UUID identifica el borrador;
**no** se envía como ID de extracción. Una propuesta externa que reemplaza un
borrador elimina esa versión local de la lista, para no ofrecer dos confirmaciones.

`entrada.id_local` conserva el UUID del borrador y se utiliza también como
`command_id`. El servidor exige que coincidan. Si falla la limpieza local y se
reabre un borrador ya enviado, repetir el contenido recupera el resultado; cambiar
sus identificadores/datos produce conflicto de idempotencia y requiere revisar
el historial. No se acepta como una segunda operación. El ID de extracción sigue
siendo generado por el servidor y es independiente de este identificador cliente.

`CONFIRMAR_PROPUESTA_LOCAL` contiene entrada, propuesta y comando financiero ya
revisado. El backend valida el contrato, sesión, rol, negocio y reglas financieras.
Dentro de la misma transacción crea una extracción con UUID del servidor y la
confirma con el servicio V4. Un fallo financiero revierte también la extracción.
La procedencia de voz queda en los metadatos de procesamiento; sin WAV se guarda
como entrada TEXTO y la operación conserva origen VOZ. No se simula un archivo.

La imagen original queda en el directorio privado de la app, bajo su SHA-256.
La relación usuario/negocio/UUID de evidencia se conserva en almacenamiento seguro.
Los archivos de imagen **no están cifrados por esta implementación**: los protege
el aislamiento de archivos de Android. No se borran automáticamente al confirmar
o descartar; una política de retención/limpieza queda para una mejora posterior.

Antes del comando financiero, el cliente sube la imagen con UUID estable a
`POST /api/v1/negocios/:id/ia/evidencia-local?id=<UUID>`. Repetir el mismo UUID y
hash recupera la evidencia; cambiar el contenido o repetir el hash con otro UUID
se rechaza. El endpoint exige sesión y permiso de escritura, limita tamaño/tasa
y no llama a un proveedor. El archivo no se publica como recurso estático.

Después se aplica el bloqueo por negocio y la idempotencia V4 del comando. El
servidor rechaza reutilizar una imagen que ya tenga extracción. Referencias de
pago y vínculos conservan los controles V4. Un abono se aplica a un pendiente;
no se convierte en otra venta. Los traslados siguen siendo dos movimientos,
sin ingresos ficticios. La deduplicación por hash detecta el mismo archivo, no
todas las fotografías distintas del mismo recibo: siempre se debe revisar.

La subida y la confirmación son dos pasos. Si la segunda falla, puede quedar un
comprobante sin vínculo y su archivo privado; no una operación financiera parcial.
La cola conserva el mismo UUID de evidencia y `command_id`, incluso si se perdió
la respuesta después de que el servidor confirmó. Una imagen perdida o un
conflicto pasa a revisión: no se confirma automáticamente sin su evidencia.

## Gemini y cuota

«Interpretar» siempre es local. La ayuda externa aparece para propuestas ambiguas
o errores y exige una acción explícita, consentimiento y disponibilidad. Una
frase sencilla con intención e importe reconocidos vuelve al flujo local aunque
se intente pedir ayuda. El consentimiento se exige solamente al envío externo;
se conservan sus cabeceras y auditoría V4.

El backend conserva los límites existentes de presupuesto diario y frecuencia.
Un HTTP 429 activa `backend/private/gemini-circuit.json`, ignorado por Git: respeta
`Retry-After` entre 60 segundos y 24 horas, o usa espera exponencial de 15 minutos
hasta 24 horas. Un fallo de conexión/proveedor pausa 60 segundos. El estado
persiste al reiniciar y, si está corrupto o no puede guardarse, falla cerrado.
No se toca `.env`, la clave ni la facturación.

`GET /api/v1/negocios/:id/ia/estado` expone disponibilidad, motivo y próximo
intento permitido **sin consultar Gemini**. Mientras exista bloqueo, nuevas
peticiones no llegan al proveedor. Al vencerlo no hay llamada automática: una
nueva acción del usuario puede intentarla. En una instancia Express el bloqueo
de petición activa impide llamadas simultáneas; varias instancias necesitarían
un circuito/presupuesto compartido. El botón de disponibilidad no gasta cuota.

## Sin conexión

- Reglas, escritura y edición son locales. OCR usa el modelo latino incluido.
- Voz solo puede funcionar desconectada si el teléfono realmente dispone del
  servicio y modelo español. Se debe verificar en modo avión; una prueba del
  canal simulado o compilar la APK no demuestra esta capacidad.
- Con sesión y catálogos previamente guardados, la revisión usa la cola offline
  V4. Cobros/pagos requieren seleccionar un pendiente disponible en la réplica.
- «Guardado en este celular» no significa validado o consolidado en MySQL: el
  backend puede rechazar un sobreabono o conflicto al sincronizar.
- Login inicial, sincronización, confirmación central, datos no almacenados,
  generación de PDF en el servidor y Gemini necesitan conexión con Express.
  En este entorno USB, Express y MySQL locales no requieren internet público;
  Gemini sí. Fuera del USB se necesita un despliegue accesible y seguro.

## Verificación y prueba manual

Resultados automatizados:

- `flutter analyze --no-pub`: sin incidencias.
- `flutter test --no-pub --concurrency=1`: 91 aprobadas, una prueba externa
  opcional omitida. Incluye regresiones V4 de formularios/diseño y nuevos casos
  de reglas, voz/canal simulado, OCR/canal simulado, edición de transcripción,
  recuperación de propuesta, cola offline, imagen ausente y respuesta perdida.
- `npm test`: 42 aprobadas, incluidos circuito persistente 429/Retry-After,
  estado corrupto y contratos con transportes simulados.
- `RUN_MYSQL_TESTS=1 npm run test:mysql`: 21 aprobadas, con guardia que exige
  `NODE_ENV=test` y `DB_NAME=hackathon_pinguinos_test`. Verifica fiado 100, abono
  40, saldo 60 y liquidación, transferencia, anulación y el nuevo comando local
  con evidencia, idempotencia, aislamiento y rollback.

Las pruebas simuladas de voz y OCR verifican contratos/integración, no precisión
del reconocimiento real ni disponibilidad de idioma en el teléfono.

Android físico `10AD370TQF002ZS`, API 34: primera compilación correcta en 552,4 s;
compilación final con la protección de identidad estable correcta en 308,1 s.
Nunca se compilaron dos tareas Android simultáneamente. `adb install -r` terminó
en `Success`; inicio de `.MainActivity`: `Status: ok`, `LaunchState: COLD`;
`lastUpdateTime=2026-10-22 21:59:07`. No se desinstaló ni limpió almacenamiento.
Se inspeccionaron capturas del dashboard con la sesión y negocio existentes y
de «Hablar con Finki», sin errores Flutter/MissingPlugin/FATAL en los últimos
300 registros revisados del proceso. Se dejó la captura abierta y el consentimiento
externo desmarcado. No se grabó audio ni se eligieron imágenes reales.

`adb reverse --list` confirma `tcp:3000`; Express escucha en `127.0.0.1:3000`
y `/api/v1/health/ready` responde `{"status":"ready"}`. Las lecturas de negocio y
propuestas se muestran en el teléfono. Se reinició Express para cargar el nuevo
contrato sin cambiar su configuración. No se escribieron operaciones de prueba
en desarrollo. Evidencias locales ignoradas por Git:
`build/tooling/finki-hybrid-android.png`, `finki-hybrid-intake.png` y logs
`hybrid-{analyze,flutter,node,mysql,android-final,web}.log` del mismo directorio.

La compilación web JavaScript también terminó correctamente en 90,6 s, en
`build/web-hybrid`, sin sustituir las salidas web anteriores. El diagnóstico
adicional de WebAssembly advierte incompatibilidades de dependencias existentes
(`flutter_secure_storage_web` e `image`); no se afirma compatibilidad Wasm.

No se enviaron peticiones reales a Gemini. Las escrituras financieras de las
pruebas se limitan a `hackathon_pinguinos_test`; no se usan datos ficticios en dev.

Prueba manual pendiente: permitir micrófono, comprobar español instalado, hablar
una frase real y corregirla; repetir sin internet. Abrir una boleta y capturas
Yape/Plin legibles en modo avión, revisar importe/referencia y elegir su propósito.
Sin confirmar datos de prueba en la base principal. Para comprobar sincronización
y cuotas con datos ficticios, usar el entorno aislado y el proveedor simulado.

Actualizar sin desinstalar ni borrar almacenamiento, desde la raíz:

```powershell
.\tool\flutter-local.ps1 build apk --debug --no-pub --target-platform android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS reverse tcp:3000 tcp:3000
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS install -r build\app\outputs\flutter-apk\app-debug.apk
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS shell am start -W -n pe.pinguinos.hackathon_pinguinos_mvp/.MainActivity
```

Instalar solo después de una compilación correcta; repetir `adb reverse` al
reconectar USB. Mantener Laragon y `node server.js` en `backend/` funcionando.

## Archivos de implementación

Modificados: `pubspec.yaml`, `pubspec.lock`; `android/app/src/main/AndroidManifest.xml`
y `android/app/src/main/kotlin/pe/pinguinos/hackathon_pinguinos_mvp/MainActivity.kt`;
`lib/v1/{api_client,forms,intake_page,intake_widgets,transfer_page}.dart`;
`backend/src/app.js`, `backend/src/errors.js`, `backend/src/validators.js`,
`backend/src/services/{commands,gemini-provider,intake}.js`;
`backend/test/{gemini.test,scenarios}.js`;
`test/{v3_pages_test,v4_intake_test}.dart`.

Nuevos: `lib/v1/{local_speech,local_ocr,local_rules,local_entry,local_media,
local_media_io,local_media_stub}.dart`;
`backend/src/services/{local-intake,provider-circuit}.js`;
`backend/test/provider-circuit.test.js`;
`test/{local_speech_test,local_ocr_test,local_rules_test,hybrid_flow_test}.dart`
y esta guía. La nota V4 enlaza este complemento.
