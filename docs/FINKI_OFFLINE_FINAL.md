# FINKI: voz independiente y validación híbrida

La corrección más reciente del ciclo de grabación se describe en
[FINKI_VOICE_SESSION_FIX.md](FINKI_VOICE_SESSION_FIX.md). Sustituye las notas
históricas sobre terminar por frase/silencio o mostrar Grabando antes del audio.

## Actualización 23/10/2026: voz, Inicio y Perfil

Sobre los cambios existentes, sin reiniciar el proyecto:

- Reglas locales: «Compré mercadería por 80/ochenta», «Dejé fiado 20/veinte de
  pan» y «Me abonaron 15/quince». Solo se aceptan montos sin moneda en cláusulas
  comerciales delimitadas; «Vendí 3 panes» no se convierte en S/3. Varios números
  requieren revisión. No se completan fecha, medio ni persona ausentes.
- La transcripción real «veintitrés soles son azúcar» conserva azúcar y S/23,
  pero el verbo perdido impide conocer si hubo venta, gasto o compra. Se pregunta
  el tipo en una tarjeta «Registro por completar», sin inferir un gasto. El motor
  Vosk y su modelo no cambiaron; no se promete mayor precisión acústica.
- Se conserva interpretación automática final, scroll, texto editable, mismo ID
  al reinterpretar, procesamiento local prioritario y confirmación humana.
  El diálogo externo se llama «Transcribir con ayuda por internet» y sigue
  exigiendo consentimiento y disponibilidad, sin fallback oculto.
- Inicio: saludo, resumen azul, acciones Hablar/Constancia, registro manual,
  movimientos, cuentas, tarjeta Herramientas del negocio y actividad reciente.
  Permisos de propietario/colaborador se conservan.
- Perfil: cabecera personal, información personal editable, negocio activo y
  rol, gestión, estado real de la cola, sincronización, privacidad, ayuda y salida.
  La edición usa PATCH /perfil existente, autenticado y con expected_version;
  presenta conflictos y requiere conexión. No hay cambio de contraseña ficticio.
  La ayuda y privacidad abren información real local, no servicios externos.

Pruebas: suite Flutter de 144 casos aprobados y uno omitido; nuevas pruebas de
variantes, ambigüedad, cantidades de productos, jerarquía del inicio y PATCH de
perfil simulado (éxito y conflicto de versión). No se editó el perfil real ni se
guardaron operaciones financieras de prueba. Backend y SQL sin cambios en esta
etapa; no se ejecutaron pruebas de escritura MySQL ni llamadas a Gemini.

Validación final: analyzer sin incidencias; 26 pruebas enfocadas de reglas,
perfil y diseño repetidas tras el ajuste final de la tarjeta de herramientas,
con capturas a móvil/tablet aprobadas. APK compilado secuencialmente en 302,0 s,
instalado con `install -r` (Success), actualización 23/10/2026 02:18:44.
Arranque COLD con Status: ok. Inspección visual real de Inicio y Perfil en el
Android: sesión de Danny y negocio conservados, nuevo orden y nuevas secciones
visibles. Express/MySQL ready y reverse tcp:3000 configurado. Sin excepciones
FATAL/E/flutter/MissingPlugin en los últimos 300 registros revisados del proceso.
La nueva precisión acústica no se da por probada: el motor no cambió. Dictado,
cámara/galería y guardado voluntario de datos personales requieren revisión humana.

Archivos: app.dart, local_rules.dart, intake_widgets.dart, intake_page.dart,
profile_edit_page.dart; pruebas polish_rules, profile_edit, redesign, y textos de
voz actualizados; esta documentación. Todos los cambios anteriores se conservan.

Revisión manual: dictar con y sin verbo, elegir tipo si falta, corregir texto y
verificar un solo pendiente; revisar el orden de Inicio, abrir Perfil y sus
acciones. Para probar cambios personales, usar datos propios y guardar solo si
se desea actualizar realmente el perfil. No confirmar operaciones ficticias.

## Actualización 23/10/2026: propuesta automática al terminar de hablar

El usuario confirmó una prueba nueva en su Android, con modo avión, sin red ni
autorización externa: Vosk transcribió «Gasté 23 soles en azúcar» y la interpretación
manual produjo Gasto · S/23.00 · azúcar. Esto acredita ese caso en vivo; el error
del WAV anterior, descrito más abajo, permanece como límite histórico de precisión.

Ahora el resultado final de voz se interpreta automáticamente con las mismas
reglas locales, después de detener/liberar la captura. Los eventos parciales solo
actualizan el texto editable. La propuesta usa una identidad local única; corregir
y reinterpretar actualiza esa misma propuesta. Ningún comando financiero se envía
durante este paso. Texto vacío, permisos, silencio y cancelación no disparan la
interpretación automática. Las ambigüedades conservan las preguntas y revisión
existentes. Gemini y su autorización no cambian.

La captura y tarjeta están en un mismo hijo del ListView para que la tarjeta
exista incluso fuera del área visible y `ensureVisible` pueda desplazarla suavemente
durante 300 ms. No cambia el diseño. Las pruebas a 360×740 verifican que «Esto
entendí» queda visible sin un desplazamiento adicional del usuario.

Pruebas de widget: gasto, venta, compra, fiado y transcripción incorrecta; parciales
sin propuesta, final automático, tarjeta visible, dos reinterpretaciones conservando
el mismo ID y un único pendiente, cero POST y ninguna operación en cola. Se
mantienen las pruebas de permisos denegados, silencio, cancelación y Gemini.

Para repetir en el teléfono: modo avión, Wi-Fi apagado, autorización externa
desmarcada, decir «Gasté 23 soles en azúcar» y esperar. Debe aparecer «Esto entendí»
sin pulsar Interpretar. Volver al texto, cambiar 23 por 25 y pulsar «Interpretar
texto corregido»: debe actualizar el mismo pendiente. Repetir venta, compra y
fiado; no confirmar datos ficticios en el negocio real. La comprobación humana
de esta automatización nueva queda pendiente hasta repetirla con el APK actualizado.

Archivos de esta mejora puntual: `lib/v1/intake_page.dart`,
`test/offline_voice_widget_test.dart` y esta documentación. No se modifica backend,
modelo de voz, MySQL, secretos ni otras pantallas.

Validación de la mejora: analyzer sin incidencias; suite Flutter 134 aprobadas y
1 omitida. Después de reforzar el caso de doble pulsación de Detener, las 9
pruebas del archivo de voz se repitieron y pasaron. Compilación secuencial correcta
en 273,3 s. `adb install -r`: Success; `lastUpdateTime=2026-10-23 01:51:17`;
MainActivity arrancó en frío con Status: ok. Reverse tcp:3000 configurado y
Express/MySQL ready. Sin desinstalar ni limpiar datos. No se crearon movimientos
financieros, ni se llamaron servicios externos, ni se hizo commit/push.

Fecha: 22/10/2026. Complementa `FINKI_HYBRID_LOCAL.md`; sus notas anteriores
sobre depender exclusivamente del español nativo ya no describen este APK.

## Implementación

Prioridad: SpeechRecognizer **on-device** si está disponible y admite español;
Vosk integrado cuando no lo está; Gemini solamente por elección y autorización
externa explícitas; texto manual siempre disponible. Un fallo de permisos,
silencio o cancelación nunca envía audio automáticamente a Gemini.

Vosk Android 0.3.75 y JNA 5.18.1 usan el canal Kotlin existente: no se añadió
otro paquete Flutter para voz. Modelo español pequeño 0.42, Apache 2.0, incluido
en assets con licencia y aviso. Archivo original: 39.817.833 bytes; contenido
descomprimido: 60.286.598 bytes. SHA-256:
`09b239888f633ef2f0b4e09736e3d9936acfd810bc65d53fad45261762c6511f`.
Gradle comprueba tamaño y hash antes de compilar. No hay descargador del modelo.

La primera preparación verifica y extrae el archivo a almacenamiento privado,
con límite de archivos/tamaño y protección de rutas. La instalación usa un
directorio temporal versionado y renombrado; solo reemplaza su propio modelo.
Modelo y reconocedor se cargan en un ejecutor serial fuera del hilo de interfaz,
y se liberan al terminar o cancelar. Audio PCM16 mono a 16 kHz; límite de 45 s,
silencio inicial de 8 s y transcripción editable. Se conservan robot y pantallas.
El tamaño y los tiempos de carga requieren medir el teléfono; no equivalen a la
memoria pico de una sesión Flutter completa.

Las reglas locales reconocen venta, gasto, compra, fiado, cobro y pago, incluyendo
cantidades en palabras y variantes separadas como «veinti tres». Las cantidades
mixtas ambiguas no se completan. Un subtotal de una boleta recortada no sustituye
al total. Fechas contradictorias quedan vacías; Yape/Plin no implica venta.
Se extraen referencias y conceptos explícitos, sin inventar medios de pago.

La evidencia local se verifica nuevamente por SHA-256 antes de sincronizar;
una alteración pasa a revisión. Se conserva el flujo previo: propuesta local,
edición, confirmación humana, comando pendiente y confirmación del servidor.
Reconocer voz u OCR no crea movimientos. Express sigue garantizando aislamiento,
idempotencia, abonos y validaciones financieras. No cambia el esquema MySQL.
Gemini conserva el circuito persistente de cuota y las pruebas con proveedor
simulado; ninguna validación de esta etapa llama al proveedor real.

## Pruebas y límites de evidencia

Los resultados finales de compilación y teléfono se consignan al terminar abajo.
Los tests automáticos de Flutter usan dobles del canal: comprueban selección de
motor, permisos, cancelación y ausencia de envío externo, no precisión acústica.

`tool/create-offline-fixtures.ps1` genera imágenes **ficticias** legibles,
recortadas y borrosas en `build/tooling/offline-fixtures`, además de silencio WAV.
No son fotografías de cámara. El audio `voice-real.wav` es una copia local de
la grabación previa del usuario, no audio sintético ni una nueva captura en vivo.
No se versiona ni se publica; para reproducir en otro equipo se necesita un WAV
propio PCM16 mono 16 kHz con encabezado WAV de 44 bytes.

`tool/test-offline-engines-android.ps1 -AirplaneMode` ejecuta Vosk y ML Kit reales
en el teléfono mediante una Activity **solo debug**, protegida por permiso DUMP
(shell/sistema). No existe en release ni accede a API, credenciales o propuestas.
Envía fixtures al directorio privado y recoge texto, errores, duración, CPU y
PSS muestreado (no pico). Repite Yape sin crear operaciones. Desactiva Wi-Fi,
activa modo avión y retira temporalmente reverse 3000; restaura los estados
anteriores en `finally`. Resultados ignorados en
`build/tooling/offline-device-results.json`.

Una prueba de archivo de audio acredita el decodificador y modelo en Android,
pero **no acredita la nueva captura de micrófono**. OCR sobre fixtures acredita
el motor local, pero no la cámara/galería ni precisión sobre documentos reales.
La ausencia de duplicados financieros se prueba aparte en el backend aislado.

## Repetición manual sin registrar datos de prueba

1. Abrir «Hablar con Finki»; dejar desmarcada autorización externa.
2. Activar modo avión y apagar Wi-Fi. Pulsar Hablar y esperar la preparación.
3. Decir «Gasté 23 soles en azúcar», detener y revisar la transcripción editable.
   Repetir ventas, compras, fiados y abonos. Probar silencio y cancelar.
4. Probar boleta/ticket y capturas propias o ficticias desde cámara/galería.
   Revisar texto, importe, fecha y referencia; dejar ambigüedades sin completar.
5. No confirmar operaciones de prueba en el negocio real. La confirmación y
   sincronización con datos ficticios corresponden al entorno `_test`.
6. Restaurar conectividad y reverse antes de usar Express.

## Actualizar sin borrar datos

Desde la raíz, una sola compilación a la vez, siguiendo `ANDROID_LOW_MEMORY.md`:

```powershell
.\tool\flutter-local.ps1 build apk --debug --no-pub --target-platform android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS install -r build\app\outputs\flutter-apk\app-debug.apk
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS reverse tcp:3000 tcp:3000
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS shell am start -W -n pe.pinguinos.hackathon_pinguinos_mvp/.MainActivity
```

Instalar únicamente tras compilación exitosa. No desinstalar, limpiar datos ni
ejecutar `flutter clean`. El APK dirigido a este teléfono es arm64; otros ABI
necesitan su propia compilación y prueba. No se actualizaron Java/Gradle/Kotlin.

## Fuentes primarias

- Modelos y licencia: https://alphacephei.com/vosk/models
- Dependencias oficiales Android: https://github.com/alphacep/vosk-android-demo/blob/master/app/build.gradle
- API: https://github.com/alphacep/vosk-api/blob/master/java/lib/src/main/java/org/vosk/Recognizer.java
- ML Kit: https://developers.google.com/ml-kit/vision/text-recognition/v2/android

## Estado de validación final

No equivale a «100 % funcional». Resultado reproducido en Android físico
`10AD370TQF002ZS`, API 34, ABI principal arm64-v8a:

| Área | Evidencia | Pendiente / límite |
|---|---|---|
| A. Voz offline | Vosk ejecutó el WAV real previo en modo avión, Wi-Fi apagado y reverse retirado. Silencio devolvió texto vacío. | **Precisión no aprobada**: produjo «este veintitrés ofrecen en azúcar», frente a «Gasté 23 soles en azúcar». Falta captura nueva en vivo, permisos, detener/cancelar y ruido reales. No se añade un reemplazo arbitrario para convertir «este» en «gasté». |
| B. Interpretación | Frases comerciales numéricas y en palabras aprobadas; texto acústico incorrecto queda DESCONOCIDO y sin importe. | La clasificación correcta depende de una transcripción suficientemente fiel o de su corrección humana. |
| C. OCR offline | ML Kit real procesó 7 ejecuciones de imágenes, con modo avión. Boleta S/50, ticket S/23, Yape/Plin S/40, fechas, conceptos y referencia 0012345 legibles. Yape repetido devolvió el mismo texto. Borrosa devolvió vacío; recortada omitió total. | Son imágenes ficticias, no fotografías tomadas desde cámara ni capturas reales de las apps bancarias. Falta probar los selectores y documentos reales con el usuario. |
| D. Gemini disponible | Contrato HTTP y adaptación aprobados con doble explícito; se conserva el flujo existente. | Sin llamadas reales al proveedor en esta etapa. |
| E. Gemini sin cuota | Pruebas del circuito persistente, bloqueo/reintento y continuidad local aprobadas. | Cuota simulada; no se agotó cuota real. |
| F. Editar y confirmar | Pruebas Flutter/backend de propuestas y confirmación humana aprobadas. Reconocimiento aislado no creó propuestas. | Interacción final de captura nueva y corrección en el teléfono pendiente. |
| G. Persistir/sincronizar | Pruebas de cola, reinicio, reintentos, identidad estable, evidencia, fiados/abonos y aislamiento; integración SQL solo en `_test`. | Ciclo manual nuevo sin red → confirmar → reconectar en el teléfono pendiente, con datos de pruebas en entorno aislado. |
| H. Regresiones | Flutter 126 aprobadas y 1 omitida, más 3 nuevas regresiones del texto exacto del dispositivo aprobadas; analyzer sin incidencias. Backend 42 y MySQL aislado 21 aprobadas. APK compilado, actualizado y abierto. | Android arm64 probado; otros ABI y release sin probar. No se recompiló web en esta etapa (la compilación JavaScript anterior se conserva). |

Compilación correcta: 260,4 s. Antes se corrigió un `Int`/`Long` en el diagnóstico
debug; no se borraron cachés ni se actualizaron herramientas. Se ejecutó una sola
compilación por vez. APK debug 226.230.461 bytes (~215,8 MiB), antes 158.041.282
bytes: incremento 68.189.179 bytes (~65,0 MiB). Incluye Flutter arm64 y bibliotecas
Vosk/JNA para arm64, armeabi-v7a y x86_64 procedentes de los AAR; esto no acredita
que el APK completo sea ejecutable en esos otros ABI. `libvosk.so` arm64 mide
10.042.800 bytes. No se añadieron filtros ABI que puedan afectar otros destinos.

Voz sobre el WAV de ~4,08 s: 7.737 ms transcurridos y 7.634 ms CPU acumulada del
proceso; PSS muestreado con modelo cargado 168.453 KiB. Silencio: 5.340 ms y
177.309 KiB. Es una medición del diagnóstico aislado, **no** de pico ni del consumo
total de Flutter durante una conversación. OCR: 377–1.182 ms por imagen en estas
muestras, CPU 787–2.236 ms; muestras PSS ~108–137 MiB. No se garantiza precisión
general ni tiempo real a partir de esta pequeña muestra.

Primera prueba descartada: el transporte `adb exec-in` truncaba fixtures. Se
cambió el script a bloques Base64 por comandos confirmados y SHA-256 de cada
archivo, y se repitió todo antes de aceptar resultados. Las entradas OCR y WAV
usadas en la tabla coinciden con sus originales por hash.

Instalación `adb install -r`: Success, `lastUpdateTime=2026-10-22 23:19:01`;
MainActivity `Status: ok`. Sin errores FATAL/E/flutter/MissingPlugin en los últimos
300 registros del proceso revisados. Se restauraron modo avión=0, Wi-Fi=0 (su
estado previo) y reverse tcp:3000. Express/MySQL `/api/v1/health/ready`: ready.
No se registraron movimientos ficticios en desarrollo. No se modificó SQL,
secretos ni configuración del proveedor.

La pantalla estaba apagada/bloqueada al intentar la inspección visual final;
se encendió sin desbloquearla. El arranque del componente está verificado por
ADB, pero la revisión visual de esta sesión y la captura nueva requieren que
el usuario desbloquee el teléfono. No se presenta la captura negra como prueba UI.

La sesión y datos de aplicación permanecen: no hubo desinstalación ni limpieza.
Rama `danny`, con un commit adelantado preexistente respecto a `origin/danny`;
esta ejecución no creó commits ni hizo push/merge/cambio de rama. Permanecen
también todos los cambios híbridos anteriores.

Archivos principales de esta etapa: `OfflineSpeech.kt`, `VoskModelStore.kt`,
`MainActivity.kt`, assets del modelo/licencia, `android/app/build.gradle.kts`,
`local_speech.dart`, `intake_page.dart`, `intake_widgets.dart`, `local_rules.dart`,
`local_media_io.dart`, pruebas de voz/reglas y textos físicos, Activity debug,
los dos scripts de fixtures/validación y esta documentación. La lógica financiera
del backend previamente implementada se preservó sin cambios en esta etapa.
