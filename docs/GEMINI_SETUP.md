# FINKI V3 · Gemini preparado, apagado

Implementación del 22/10/2026. No se hizo ninguna llamada real a Gemini ni se activó facturación.

## Modelo y API

`gemini-3.5-flash-lite`, estable, admite texto, imagen, audio y salida estructurada.
Google documenta entrada/salida gratuitas en Standard para el nivel gratuito:
https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite
https://ai.google.dev/gemini-api/docs/pricing

Se usa REST oficial `v1beta/models/gemini-3.5-flash-lite:generateContent`,
cabecera `x-goog-api-key`, `generationConfig.responseFormat.text` con JSON Schema.
https://ai.google.dev/gemini-api/docs/generate-content/structured-output
Generate Content aparece como Legacy en la documentación actual, pero continúa
documentado; aquí se conserva su contrato sin introducir sesiones remotas ni SDK.
No hay herramientas Google Search, Maps, ejecución de código ni cambio automático de modelo/proveedor.
No se eligió 2.5: Google limita su acceso en proyectos nuevos.

La disponibilidad y cuota específica del proyecto todavía deben validarse en AI Studio
y con una llamada autorizada. La aplicación no puede verificar que la cuenta permanezca
sin facturación. Mantener `FINKI-HACKATHON-2026` en nivel gratuito, sin asociar facturación.
Google puede usar contenido del nivel gratuito para mejorar productos: probar solo
documentos ficticios o anonimizados. Nunca mandar credenciales o datos sensibles.

## Configurar manualmente

Abrir `backend/.env` en el editor y completar únicamente `GEMINI_API_KEY` con la clave
del proyecto. No compartirla por chat ni incorporarla a Flutter, capturas, logs o Git.
El archivo está ignorado. No ejecutar configure de nuevo ni sustituir secretos JWT.

```dotenv
AI_PROVIDER=gemini
GEMINI_API_KEY=
GEMINI_MODEL=gemini-3.5-flash-lite
AI_MAX_REQUESTS_PER_DAY=20
AI_ENABLED=0
```

Mantener `AI_ENABLED=0` incluso después de pegar la clave. **Solo después de la autorización
explícita del propietario para probar el nivel gratuito**, cambiarlo a `1` y reiniciar
el backend con `npm.cmd start` desde `backend/`. No iniciar dos instancias en el mismo puerto.
Para detener llamadas nuevas: volver a `0` y reiniciar. Una solicitud ya enviada no se revoca.
OpenAI se conserva: `AI_PROVIDER=openai` usa sus variables anteriores; no hay fallback automático.

## Límites y conservación financiera

- Gemini: una llamada simultánea, dos intentos/minuto por proceso, 20 intentos/día UTC
  por instalación (configurable 1–100). Reserva antes de enviar, también cuenta fallos.
- Contador diario en `backend/private/gemini-budget.json`, persiste al reiniciar.
  Corrupción/error de escritura bloquea llamadas. No borrarlo para evadir el límite.
  El límite/minuto se reinicia con el proceso. Ejecutar un único backend: no es un
  limitador distribuido para múltiples procesos o máquinas.
- HTTP autenticado además limita seis análisis/minuto por usuario. No reintenta solicitudes
  al proveedor automáticamente. Error 429 conserva mensaje de cuota y registro manual.
- 30 segundos por llamada, 1800 tokens máximos de salida, texto ≤6000 caracteres,
  imagen ≤7 MiB, imagen validada por firma/dimensiones en intake; WAV ≤1.5 MB (Flutter
  graba PCM16/16 kHz/mono, máximo 45 s). Respuesta ≤128 KiB.
- Texto/foto: una llamada. Audio grabado: dos (transcribir + interpretar), ambas consumen
  presupuesto. Reservar cuota suficiente y no enviar audios de nuevo si ya hay propuesta.
- Confirmación/corrección existente obligatoria. Analizar guarda una propuesta/evidencia
  privada, no ventas ni movimientos. Capturas de pago siempre exigen clasificación humana.
- Se conservan deduplicación SHA256/referencias por negocio, idempotencia del comando,
  aislamiento de membresía y vínculo de comprobante a operación existente.
- Preguntas financieras existentes son deterministas, con consultas autorizadas y cifras
  MySQL. «¿Cuánto vendí hoy?», «¿Cuánto me deben?» y «¿En qué gasté más?» funcionan
  sin enviar datos financieros a Gemini. No se añadió SQL ni redacción de cifras por IA.

## Android: voz y foto tras autorización

Se evaluó reconocimiento de Android: depende de servicio/teclado instalado y puede
requerir red; no garantiza procesamiento offline. Para priorizar enviar solo texto,
usar el micrófono del teclado Android dentro de «También puedes escribir», revisar
la transcripción y pulsar «Interpretar texto». No se añadió un plugin nativo ni un
botón SpeechRecognizer propio. La grabación WAV existente permanece como alternativa.

Desde la raíz, con teléfono conectado y depuración autorizada:

```powershell
& D:\Android\Sdk\platform-tools\adb.exe devices
# Sustituir ID_TELEFONO por el ID mostrado, sin los signos < >.
& D:\Android\Sdk\platform-tools\adb.exe -s ID_TELEFONO reverse tcp:3000 tcp:3000
.\tool\flutter-local.ps1 run --no-pub -d ID_TELEFONO --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

No desinstalar ni limpiar almacenamiento. Mantener Laragon y backend activos.
No abrir MySQL a la red. `adb reverse` permite mantener backend en 127.0.0.1.
En «Hablar con Finki», consentir, dictar «Hoy vendí 45 soles en gaseosas», interpretar:
debe proponer venta, 4500 céntimos, gaseosas y fecha local; corregir antes de confirmar.
Probar foto ficticia/anonimizada por cámara/galería y captura Yape/Plin: debe preguntar
si es venta/abono/pago/traslado. Si ya existe, elegir solo adjuntar. Sin cuota, continuar manual.
Para ensayos de guardado utilizar una instancia del backend contra `_test`, nunca
Bodega Finki Demo. Los contratos de autenticación existentes se mantienen.

## Verificación y pendientes

Resultado local: 39 pruebas Node aprobadas; 19 pruebas MySQL aprobadas en `_test`;
66 Flutter aprobadas, una opcional live omitida; análisis Flutter sin incidencias;
compilación web debug exitosa. Express `/api/v1/health/live` y `/health/ready` 200.
Los 19 archivos de database del baseline disponible conservan sus hashes.

Archivos de esta integración (no incluye trabajo V3 previo):

- Nuevos: `backend/src/services/gemini-provider.js`, `backend/test/gemini.test.js`,
  `docs/GEMINI_SETUP.md`.
- Backend: `backend/src/services/ai-provider.js`, `backend/src/config.js`,
  `backend/src/app.js`, `backend/src/services/intake.js`, `backend/src/errors.js`.
- Configuración: `backend/.env` (ignorado, sin clave), `backend/.env.example`.
- Pruebas: `backend/test/scenarios.js`, `test/v3_pages_test.dart`.
- Flutter: `lib/v1/intake_page.dart` (proveedor dinámico, consentimiento, guía de dictado).
- Documentación: `backend/docs/API.md`, `docs/FINKI_V3_PROGRESS.md`.
- Salida generada ignorada: `build/web-gemini`, copiada a `build/web` para el servidor local.

Git sigue en `feat/backend-v1`, con cambios V3 anteriores y esta integración sin commit.
No hubo commits, push, cambios en migraciones ni escrituras de ensayo en `_dev`.

Pruebas: `npm.cmd test`; MySQL aislado existente: `$env:RUN_MYSQL_TESTS='1'` y
`npm.cmd run test:mysql` desde backend, retirar la variable al terminar.
Flutter: `.\tool\flutter-local.ps1 analyze` y
`.\tool\flutter-local.ps1 test --no-pub --concurrency=1` desde raíz.

Dobles HTTP prueban contratos y errores, no calidad ni acceso real a Google.
Pendientes: clave + autorización; disponibilidad/cuota real, OCR/voz reales,
latencia, reconocimiento del teclado y recorrido físico Android. No se garantiza
acierto OCR: el usuario revisa cada campo y el backend valida comandos financieros.
