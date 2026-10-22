# FINKI V3 — estado y continuación

Fecha: 22/10/2026. Rama conservada: `feat/backend-v1`. No se reinició el proyecto ni la base de desarrollo. No hay commits ni push de esta entrega. Los cambios V1/V2 y archivos no versionados anteriores se conservaron.

## Implementado

- **A / base financiera:** integración HTTP real contra MySQL 8.4 aislado; fiado 100, abono 40, saldo 60 y liquidación; contado, compras, gastos, pagos parciales, concurrencia, sobreabonos, idempotencia, autorizaciones y anulaciones. Categoría opcional se resuelve como General dentro de la misma transacción. Negocios nuevos reciben Efectivo con saldo cero. Un cobro/pago EFECTIVO sin cuenta puede utilizar/preparar una cuenta de efectivo; crearla implícitamente requiere propietario. Yape/Plin/banco necesitan una cuenta elegida, sin inventar saldos.
- **B / constancia:** pantalla Mi constancia en Inicio y Reportes; periodo, resumen, generación real en Express, PDF con mascota FINKI, gráfico mensual, metodología y límites; botones abrir/descargar y compartir con printing. Snapshot en la tabla `reportes` existente, archivo privado SHA-256, comando idempotente y publicación en auditoría/sync. Listado para recuperar constancias emitidas; descargar no recalcula el documento. Un fallo de descarga permite recuperar el mismo PDF.
- **C-D / voz y fotografías:** captura PCM16/WAV hasta 45 segundos; permiso de micrófono Android; cámara/galería con image_picker, reducción a 1600 px/calidad 80; entrada escrita opcional. Adaptador OpenAI configurable para transcripción y extracción estructurada. Consentimiento explícito por entrada, límite de archivos 7 MiB, firma/dimensiones de imágenes y límite por usuario. Evidencia privada y extracción REQUIERE_REVISION, sin finanzas hasta confirmar. Propuestas pendientes recuperables. Formularios existentes permiten corregir antes de confirmar.
- **C-D / seguridad financiera:** captura de pago pide propósito; se puede crear operación, abonar una existente, pagar una deuda, transferir o solamente adjuntar evidencia a un registro existente. Adjuntar no crea ventas ni dinero. Hash evita reanalizar la misma evidencia en un negocio; referencia ya registrada impide otro movimiento por el flujo de confirmación. Confirmar extracción y finanzas/vínculos/auditoría es atómico e idempotente. No existe endpoint público para guardar propuestas internas arbitrarias.
- **E / consultas:** preguntas sugeridas y texto sencillo, con herramientas deterministas autorizadas. Hoy, mes, gastos principales, pendientes, mercadería, comparación mensual y resumen semanal. Cifras calculadas en una instantánea del negocio. Sin SQL generado por IA. Estas respuestas funcionan sin proveedor y se identifican como cálculos de registros; no se presentan como conversación generativa probada.
- **F / modo local:** caché persistente y snapshot por usuario/negocio, búsqueda/filtros locales de operaciones, cola cifrada mediante FlutterSecureStorage en Android, UUID y cuerpo de comando conservados, FIFO y reintentos sin duplicados. Desconexión durante primer envío conserva su resultado incierto con el mismo ID y permite continuar. Recuperación de doble registro local pending/outbox tras interrupción. Conflictos permanecen para revisión y frenan las dependencias; retirada solo con confirmación humana, sin anular datos del servidor. Reintenta al actualizar o volver a la app; botón Sincronizar ahora. Los totales consolidados nunca incorporan pendientes como si estuvieran aceptados. Registro/login inicial, IA y nuevas constancias requieren conexión.

## Decisión del usuario sobre IA

**Mantener IA desactivada por ahora.** `backend/.env` conserva secretos y tiene AI_ENABLED=0. No se hicieron llamadas externas a OpenAI ni se enviaron datos/imágenes del usuario a un proveedor. No habilitar llamadas de pago por cuenta propia.

Proveedor preparado: OpenAI, `AI_TRANSCRIPTION_MODEL=gpt-transcribe`, `AI_EXTRACTION_MODEL=gpt-4o-mini`. Son configurables; confirmar acceso real antes de habilitar. OPENAI_API_KEY pertenece solo al backend. `.env.example` contiene nombres y valores vacíos, nunca credenciales. Estado configurable en GET `/negocios/:id/ia/estado`.

Las pruebas de transcripción/extracción usan dobles explícitos. La prueba de archivo privado usa una imagen real de la mascota y respuesta de proveedor de prueba, únicamente en la base aislada. **No demuestra reconocimiento real de voz, boletas, Yape o Plin.**

Documentación oficial consultada para el adaptador: https://developers.openai.com/api/docs/guides/speech-to-text y https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=chat .

## Fórmulas de la constancia (1.1.0)

Solo registros confirmados. Fechas comerciales inclusivas en America/Lima; céntimos como texto/BigInt.

- Ventas = suma de VENTA por fecha_operacion. Compras y gastos se suman por sus respectivos tipos.
- Cobros = aplicaciones válidas a ventas, por fecha_movimiento. Pagos = aplicaciones válidas a compras/gastos. Deudas anteriores SALDO_CXC/CXP se muestran aparte. Un abono no añade ventas. Transferencias propias no añaden ventas ni gastos.
- Pendiente al cierre = total de operaciones hasta el corte menos aplicaciones de dinero confirmado hasta ese corte; separado por cobrar/pagar. Las anulaciones corrigen el estado vigente al emitir, no reescriben PDFs emitidos.
- Resultado simplificado = ventas - compras - gastos. No es utilidad neta: faltan inventarios valorizados, costo de ventas, depreciación y otros posibles costos/impuestos.
- Promedio de ventas mensual = suma de ventas de meses calendario completos dentro de [max(desde, inicio_historial), hasta] / número de esos meses. Incluye meses sin registros con cero, excluye parciales; redondeo final al céntimo mitad hacia arriba. Cero meses completos produce null, nunca un promedio inventado.
- Frecuencia = días distintos con venta / días calendario de esa ventana, ambos inclusive. Porcentaje redondeado a dos decimales. Es frecuencia registrada, no estabilidad ni cobertura auditada.
- Meses con información = meses distintos con operaciones confirmadas en el periodo. Inicio declarado, primera/última operación y meses transcurridos se presentan separados. Los meses sin filas tienen cobertura desconocida.
- Gráfico: ventas, cobros y pagos mensuales con la misma escala, importes exactos y distinción de meses parciales; compras y gastos registrados se detallan aparte.

El PDF informa que usa datos del usuario; no certifica SUNAT, impuestos, solvencia ni aprobación crediticia. No tiene QR de supuesta verificación pública. Corte sync y versión de fórmula quedan en el snapshot y documento. La descarga comprueba el SHA-256 del archivo.

## MySQL aislado y seguridad

Con autorización explícita del usuario se crearon `hackathon_pinguinos_test` y `finki_integration@127.0.0.1`. Contraseña aleatoria y JWT independientes solo en `backend/.env.test`, ignorado por Git. No tiene acceso concedido a desarrollo. Se aplicó el bootstrap existente a la base nueva vacía, sin semillas. Después se retiraron CREATE, CREATE VIEW y REFERENCES; conserva SELECT/INSERT/UPDATE únicamente sobre `_test`.

No se modificaron migraciones 001/002 ni las tablas/vistas de desarrollo. Las pruebas conservan sus propios datos sintéticos en `_test` para inspección. Los scripts de preparación no deben repetirse contra bases existentes; abortan antes de reemplazarlas. Los archivos privados están en `backend/private/`, fuera del servidor web e ignorados por Git. Respaldar ese directorio junto con la base: el hash no sustituye el archivo. Un rollback SQL posterior a escribir un archivo puede dejar un archivo privado huérfano; no se publica un reporte/evidencia sin commit. No hay borrado automático de huérfanos ni política automática de retención.

## Validación y límites pendientes

Resultados confirmados hasta esta revisión:

- `npm test`: **33 aprobadas**, cero fallos.
- `RUN_MYSQL_TESTS=1 npm run test:mysql`: **19 aprobadas**, cero fallos, con el usuario ya restringido a DML en `_test`.
- Flutter: **65 aprobadas**, una prueba opcional de API omitida; el estado real de Express/MySQL se comprobó además con check:db y health/ready.
- `flutter analyze`: **sin observaciones**.
- `node --check`: todos los JavaScript de src/scripts/test correctos.
- npm audit después de corregir image-size a 2.0.4: cero vulnerabilidades informadas en esta ejecución.
- Hashes de archivos database del baseline anterior: sin cambios.
- `.env`, `.env.test` y archivos privados: ignorados por Git.
- PDF real final de dos páginas con mascota y cifras de `_test`, renderizado e inspeccionado; sin recortes ni superposiciones observados.

Logs:

- Backend general: `build/tooling/finki-v3-backend-tests.log`.
- MySQL real: `build/tooling/finki-v3-mysql.log`.
- Flutter: `build/tooling/finki-v3-flutter-tests.log` y `finki-v3-analyze.log`.
- Persistencia offline: `build/tooling/finki-v3-offline-tests.log`; usa disco temporal y transporte de prueba. No sustituye modo avión y reinicio físico.
- PDF de ensayo aislado: `build/tooling/finki-v3-certificate-test.pdf`. Renderización inspeccionada en PNG; no corresponde a Bodega Finki Demo.

No declarar V3 totalmente terminada sin: proveedor habilitado/autorizado y pruebas reales de voz/boletas/Yape/Plin; abrir/compartir PDF en Android; desconexión, cierre y reconexión físicos con base aislada; recorrido humano completo. ADB dejó de detectar el teléfono durante esta ejecución. No se escribieron operaciones ficticias en desarrollo.

La compilación Android V3 se intentó de forma secuencial con límites de Gradle existentes, pero Windows agotó memoria y cerró PowerShell/Dart (`Out of memory`, fallo al crear DartWorker). **No existe una compilación Android V3 validada en esta entrega; no instalar un APK V2 anterior como si incluyera V3.** El backend sobrevivió y se comprobó health/ready=200. No se detuvieron procesos de VS Code/Java de otras sesiones.

**Web V3 compilada y servida correctamente:** `flutter build web --debug --no-pub --no-wasm-dry-run -O0 --output build/web-v3 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1` terminó con éxito. Después se copiaron sus archivos a build/web, servido por el proceso local existente. SHA-256 de main.dart.js origen/destino coincidente; HTML y JS responden 200. Acceso: http://localhost:5173/?v=3, recargar con Ctrl+F5. Express/MySQL health/ready=200 y CORS preflight de localhost:5173=204. Es compilación de revisión con optimización reducida. La automatización del navegador no pudo inicializar su runtime: no se afirma inspección interactiva de Chrome V3; sí compilación, HTTP, pruebas de widgets y revisión del PDF.

La cola sincroniza en primer plano; no hay servicio de background ni notificaciones programadas. No se integra sincronización incremental automática en background: se refresca snapshot y caché. Los catálogos nuevos pendientes no se proyectan todavía en todos los selectores hasta sincronizar. Formularios manuales no tienen borradores persistentes antes de confirmar; las propuestas IA sí se recuperan del servidor. Revisar escalabilidad del almacenamiento seguro para historiales grandes y política de retención antes de producción. No hay TTS, evaluación crediticia, referidos ni cobros. Las funciones esenciales no incluyen barreras de pago.

## Comandos

Backend (PowerShell):
```powershell
Set-Location D:\HACKATHON2026\Hackathon2026-Pinguinos\backend
npm.cmd run check:db
npm.cmd run dev
```
Si ya hay un servidor en 3000, conservarlo; no iniciar otro ni matar procesos ajenos.

Pruebas sin escribir en desarrollo:
```powershell
npm.cmd test
$env:RUN_MYSQL_TESTS='1'
try { npm.cmd run test:mysql } finally { Remove-Item Env:RUN_MYSQL_TESTS }
```
No repetir setup-test-db.js: el esquema aislado ya existe.

Flutter desde la raíz:
```powershell
.\tool\flutter-local.ps1 analyze
.\tool\flutter-local.ps1 test --no-pub --concurrency=1
& D:\Android\Sdk\platform-tools\adb.exe devices
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS reverse tcp:3000 tcp:3000
.\tool\flutter-local.ps1 run --no-pub -d 10AD370TQF002ZS --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```
Sustituir el ID si cambia. Mantener el mismo applicationId y no desinstalar/limpiar almacenamiento. Los plugins nativos nuevos requieren compilación, no basta hot reload sobre V2. Evitar procesos Flutter/Gradle simultáneos en este Windows de 8 GB.

## Recorrido humano pendiente

Usar siempre una instancia configurada contra `_test` para crear datos de ensayo. Crear cuenta/negocio; registrar venta y gasto sin categoría; fiado 100 y abonos 40/60; intentar sobreabono; consultar mes e indicadores; generar constancia, abrir/compartir; desactivar conexión, confirmar dos registros, cerrar/reabrir y reconectar; comprobar una sola aceptación por ID y conflicto de abonos concurrentes. Voz e imágenes quedan pendientes hasta nueva autorización y credenciales; nunca presentarlas como superadas usando un doble.
# Actualización Gemini · 22/10/2026

Gemini incorporado sin reemplazar OpenAI. `AI_PROVIDER=gemini`, modelo estable
`gemini-3.5-flash-lite`; `.env` conserva `AI_ENABLED=0` y clave Gemini sin configurar.
No se hicieron llamadas reales ni se habilitó facturación. Ver [GEMINI_SETUP](GEMINI_SETUP.md).

Verificación: 39/39 tests Node; 19/19 MySQL real exclusivamente en `_test`;
66 tests Flutter aprobados y una prueba live opcional omitida; análisis Flutter limpio;
build web debug actualizado. Express live/ready y MySQL listos en loopback.
El doble Gemini cubre REST/JSON/error/cuota/confirmación/aislamiento/deduplicación;
no equivale a validar el servicio Google real. Android físico queda pendiente.

# Android físico resuelto · 22/10/2026 14:19 Lima

FINKI V3 compilada debug ARM64 en 279 s, instalada con `adb install -r` y abierta
en `10AD370TQF002ZS`. Dashboard y sesión existente verificados mediante captura;
Express/MySQL ready comprobado desde Windows y Chrome del propio teléfono por
adb reverse. No hubo operaciones financieras de ensayo.

Corrección: liberar Gradle/analizadores de VS Code, heap 512 MiB, C1 sin C2,
caché de código 64 MiB, un worker; desactivar caché incremental Kotlin tras fallo
en image_picker_android; bloqueo de ejecuciones del wrapper. No clean, borrado
de cachés ni herramientas nuevas. Ver [ANDROID_LOW_MEMORY](ANDROID_LOW_MEMORY.md).
Esta verificación reemplaza el estado anterior de Android pendiente por falta
de memoria. Calidad de OCR/voz Gemini real sigue pendiente de clave y autorización;
no se modificó su configuración en esta tarea.
