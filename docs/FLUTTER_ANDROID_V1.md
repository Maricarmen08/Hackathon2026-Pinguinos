# Flutter Android V1 · Khipu

## Archivos y alcance

- `lib/main.dart`: entrada V1 y tema compatible con Flutter 3.47.7.
- `lib/v1/api_client.dart`: HTTP real, refresh de sesión serializado, almacenamiento cifrado y reintentos idempotentes.
- `lib/v1/app.dart`: registro/login, negocios, inicio, historial, pendientes, detalle, perfil recuperado y logout.
- `lib/v1/forms.dart`: negocio, categorías, cuentas, clientes/proveedores, venta, compra, gasto y abonos/pagos.
- `lib/v1/money.dart`: conversión exacta de soles a céntimos con BigInt; no double.
- `android/`: plataforma creada con Flutter oficial. HTTP local permitido SOLO en debug; producción requiere HTTPS y firma propia.
- `test/`: pruebas HTTP simuladas, widgets y prueba de salud real optativa sin escrituras.

El código anterior de `lib/ui`, `lib/services` y `lib/models` se conserva como referencia V0.1. Sus pantallas simuladas, parser de texto, voz/cámara sin captura real y score ficticio NO se usan en la navegación V1. La nueva aplicación no carga ni empaqueta archivos .env; ninguna credencial MySQL/JWT del backend llega al móvil. Los únicos datos financieros visibles provienen de la API.

## Ejecutar

Desde PowerShell en la raíz del repositorio (agregar Flutter al PATH o usar `D:\desarrollo\flutter\bin\flutter.bat`):

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

El backend debe permanecer en `127.0.0.1:3000`; el emulador oficial llega a ese loopback mediante 10.0.2.2. Se puede elegir otro ID de dispositivo mostrado por flutter devices. URL centralizada en `lib/core/constants/api_constants.dart`, sin barra final. Valor predeterminado: http://10.0.2.2:3000/api/v1.

Para teléfono físico por USB, activar opciones de desarrollador y depuración USB y aceptar la clave de la computadora:

```powershell
D:\Android\Sdk\platform-tools\adb.exe devices
D:\Android\Sdk\platform-tools\adb.exe reverse tcp:3000 tcp:3000
flutter run -d <ID_DEL_TELEFONO> --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

No abrir 3306 ni cambiar permisos MySQL. No cambiar HOST a 0.0.0.0 bajo la excepción root local: el backend lo rechaza deliberadamente.

### Teléfono por red local, configuración posterior controlada

Con la configuración root sin contraseña actual, usar USB. Una exposición HTTP directa por LAN requiere primero credenciales MySQL de aplicación con contraseña y permisos mínimos, manteniendo DB_HOST=127.0.0.1; requiere una decisión posterior y no se ha hecho en esta entrega. Entonces se podrá fijar HOST a la IP privada exacta de la computadora, limitar con firewall el puerto 3000 al teléfono/red privada y configurar API_BASE_URL con esa IP. MySQL permanece en localhost y root nunca se habilita remoto. En redes compartidas usar HTTPS. No abrir puertos en el router ni publicar la API en Internet.

## Recorrido funcional

1. Registrar una cuenta NUEVA con teléfono peruano y contraseña de 12–128 caracteres. No se rellena ninguna contraseña por defecto. La cuenta demo bloqueada no puede iniciar sesión.
2. Crear un negocio; elegir fecha de inicio del historial real. El menú superior permite seleccionar otro negocio autorizado, crear otro y cerrar sesión.
3. En Inicio, crear al menos una cuenta y categorías compatibles: Venta, Gasto y Compra de mercadería. Las cuentas comienzan en cero, sin inventar ventas de apertura.
4. Crear cliente/proveedor antes de registrar crédito o pago parcial.
5. Registrar una venta al contado: categoría, concepto, S/100, pago completo, cuenta, canal y fecha. Revisar y confirmar. Debe aparecer en historial y en indicadores.
6. Registrar otra venta fiada S/100, elegir cliente y sin abono. Pendientes → Me deben → detalle: total S/100, abonado S/0, pendiente S/100.
7. Registrar abono S/40 desde el detalle. Pendiente esperado S/60, ventas de esa operación siguen S/100. Liquidar S/60 con otro abono. No registrar otra venta para reflejar un cobro.
8. Repetir compras/gastos con pago completo, pendiente o parcial. En Pendientes → Debo pagar registrar pagos a proveedores.
9. Historial permite filtro por tipo, búsqueda por concepto y paginación; detalle muestra total/abonado/pendiente y estado. Inicio presenta ventas, pendientes, resultado simplificado, saldos y promedio mensual de meses completos.
10. Cerrar sesión revoca la familia de tokens en backend y borra la sesión local cifrada; reiniciar exige autenticación. Una sesión válida se recupera y verifica con /auth/me.

Estas acciones del usuario ESCRIBEN datos reales del negocio que cree. No son una prueba automatizada contra las semillas. No usar negocios de demostración para ensayos de escritura. Hasta ejecutar este recorrido o la integración en base aislada no considerar validadas las escrituras reales de Express/MySQL.

## Sesión, errores y duplicados

Almacenamiento Android cifrado con flutter_secure_storage (EncryptedSharedPreferences/Keystore), backups deshabilitados. Nunca se guarda contraseña; access/refresh se conservan juntos. Un 401 intenta un único refresh compartido entre solicitudes concurrentes, rota tokens y conserva dispositivo_id. Si no es válida la sesión se vuelve al login y se retiran formularios privados. 403 muestra restricción de acceso, 409 exige revisar conflicto, 422 permite corregir el formulario. Sin conexión se muestra error, sin sustituir datos con ejemplos.

Antes de cada escritura se persiste un único comando cifrado con UUID, dispositivo, ruta y payload completos. Mientras esté pendiente no se permite otro envío ni logout. Se desactiva Guardar mientras se procesa y se confirma el importe antes de enviar. Ante caída de red o error 5xx se conserva el mismo comando incluso al reiniciar; Inicio permite reintentar EXACTAMENTE ese comando. Un error definitivo de validación/autorización libera el formulario; conflicto idempotente requiere revisión. Un nuevo dispositivo/sesión no reenvía automáticamente el comando antiguo.

Si hay un envío de sesión anterior o resultado incierto, copiar su command_id, revisar el historial y solo después usar «Revisar y descartar». Descartar NO anula un registro del servidor. No desinstalar/borrar datos de la app mientras haya envíos pendientes.

La implementación permite preservar/reintentar un envío incierto; NO implementa todavía base local de todo el historial, trabajo financiero completamente offline ni sincronización incremental.

## Verificación sin escrituras

```powershell
flutter test test/live_api_test.dart --dart-define=RUN_LIVE_API=true
# URL alternativa del servidor:
flutter test test/live_api_test.dart --dart-define=RUN_LIVE_API=true --dart-define=LIVE_API_URL=http://127.0.0.1:3000/api/v1
```

Este ensayo usa el cliente Dart real contra health/live, health/ready y comprueba 401 sin token. No registra usuarios, no inicia sesión y no escribe datos. Las otras pruebas usan HTTP simulado y almacenamiento de test en memoria; no certifican escrituras ni transacciones MySQL.

## Pendiente

Voz real, cámara/OCR/IA, PDF, gráficos avanzados, invitaciones, transferencias/anulaciones desde UI, edición de perfiles, inventario, cierres diarios y offline completo. La V1 no presenta estas funciones como implementadas. La app no hace promesas de crédito ni muestra score ficticio. La firma de distribución Android y HTTPS de producción son posteriores.

## Herramientas locales y recursos de esta computadora

Se creó `tool/flutter-local.ps1` para poner TEMP/TMP y GRADLE_USER_HOME en `build/tooling` sobre D:, sin cambiar variables permanentes del sistema. Usarlo en esta computadora, donde C: quedó sin espacio durante las descargas. Se trasladaron únicamente las cachés creadas en esta tarea; los archivos recuperados se conservan bajo build/tooling. No ejecutar flutter clean mientras use esas herramientas.

```powershell
.\tool\flutter-local.ps1 analyze
.\tool\flutter-local.ps1 test --concurrency=1
.\tool\flutter-local.ps1 build apk --debug
$env:ANDROID_AVD_HOME = Join-Path (Get-Location) 'build\tooling\avd'
D:\Android\Sdk\emulator\emulator.exe -avd Pinguinos_API_36
# En otra terminal, una vez iniciado el emulador:
.\tool\flutter-local.ps1 run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

Imagen oficial Android 36 Google APIs x86_64 instalada en D:/Android/Sdk. AVD Pinguinos_API_36 creado en build/tooling/avd sin sobrescribir dispositivos previos. Aceleración WHPX disponible. Gradle limitado a un worker, sin paralelismo y sin daemon persistente. No se cerraron aplicaciones del usuario ni se modificó la memoria virtual de Windows.

## Resultados de validación

- flutter pub get: completado.
- flutter analyze: sin incidencias (ejecutado con el emulador detenido).
- flutter test --concurrency=1: 15 pruebas aprobadas, una prueba live omitida por defecto.
- Prueba live activada aparte: aprobada contra Express real; health/live=ok, health/ready=ready y ruta protegida=401. Sin escrituras.
- flutter build apk --debug: APROBADO. APK en build/app/outputs/flutter-apk/app-debug.apk (158003704 bytes).
- La primera compilación requirió descargar Gradle, NDK 28.2.13676358, plataformas SDK adicionales y CMake. No se modificaron migraciones ni servicios Express.
- Los primeros intentos sufrieron falta de disco/memoria. Cachés/temporales reubicados a D:, límites de Gradle ajustados y compilación completada después de liberar memoria.

Android 36 exige al menos 2560 MB para este AVD, incluso al solicitar menos RAM. No ejecutar el emulador simultáneamente con analyze/tests/build en esta computadora. Si falta memoria, usar un teléfono físico por USB. Para reducir recursos gráficos en el emulador:

```powershell
$env:ANDROID_AVD_HOME = Join-Path (Get-Location) 'build\tooling\avd'
D:\Android\Sdk\emulator\emulator.exe -avd Pinguinos_API_36 -memory 2560 -cores 2 -gpu swiftshader -feature -Vulkan -no-snapshot -no-audio
```

No se certifican todavía altas ni movimientos de Express sobre MySQL mediante Flutter: las pruebas financieras usaron respuestas HTTP simuladas. El recorrido manual de esta guía permitirá verificarlos sin utilizar las semillas de demostración.

### Comprobación del dispositivo

APK instalado correctamente en emulator-5554 con `adb install --no-streaming -r` → Success. Android confirmó sys.boot_completed=1. Se envió el intent de MainActivity; `am start -W` agotó la espera y el emulador después dejó de responder bajo presión de memoria. NO se confirmó visualmente la pantalla inicial y NO se declara recorrido funcional completo en Android. El emulador de esta tarea quedó detenido para liberar recursos; su configuración se conserva.

Paso manual pendiente recomendado: conectar un teléfono físico con depuración USB y aceptar la computadora. Después:

```powershell
D:\Android\Sdk\platform-tools\adb.exe devices
D:\Android\Sdk\platform-tools\adb.exe -s <ID_DEL_TELEFONO> reverse tcp:3000 tcp:3000
.\tool\flutter-local.ps1 run -d <ID_DEL_TELEFONO> --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

El APK ya generado utiliza la URL predeterminada del emulador (10.0.2.2). El comando anterior recompila para USB con 127.0.0.1. Mantener Laragon/Express activos. No ejecutar dos compilaciones ni emulador simultáneamente en este equipo de 8 GB.
