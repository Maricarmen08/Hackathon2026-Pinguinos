# FINKI V2 — cambios y verificación

## Resultado implementado

- Saludo con el primer nombre autenticado, jerarquía visible y nombre del negocio.
- Acciones Venta / Gasto / Compra / Ver fiados en cuadrícula 2 × 2, con botones de altura cómoda.
- Tarjetas financieras con superficie azul suave, importes protagonistas y manejo de cifras grandes.
- `FinkiMascot` con variantes bienvenida, rostro compacto, vacío y confirmación. Los vacíos usan la ilustración completa con `BoxFit.contain`, dentro de una superficie circular que no recorta la imagen.
- Vacíos específicos para historial, búsqueda y fiados. Registrar una venta fiada abre el formulario real con crédito seleccionado.
- Scroll hasta el último contenido con espacio inferior, comprobado frente a la posición de la navegación.
- Fechas en español y soles con agrupación de miles sin convertir dinero a double. El calendario usa la localización oficial de Flutter para es_PE.
- `FinkiSelect` compartido: menú redondeado, contraste, altura máxima relativa a pantalla, desplazamiento y selección nativa con teclado/tacto.
- Filtros reales de historial por tipo, estado, periodo y búsqueda (máximo 100 caracteres según API).
- Categoría opcional conforme al contrato de Express. Se conservan validaciones de cuentas y terceros, montos y sobreabonos; las fechas respetan historial, apertura de cuenta, operación y límite de hoy en Lima.
- Edición del negocio para el propietario, mediante ACTUALIZAR_NEGOCIO con expected_version y el envelope idempotente existente. No crea otro negocio.
- Perfil, formularios, detalles y diálogos conservan la identidad y las funciones existentes.

Paleta central: primary `#185FC9`, primaryContainer `#EAF3FF`, secondary `#09AFDC`, secondaryContainer `#E6F7FA`, surface blanco, surfaceVariant `#EDF3FA`, background `#F4F8FE`, texto principal `#102F5C`, secundario `#52647C`, outline `#D5E2F0`. Éxito, advertencia y error se reservan para estados semánticos.

## Archivos de esta etapa

`lib/core/theme/app_theme.dart`, `lib/main.dart`, `lib/ui/widgets/finki_brand.dart`, `lib/ui/widgets/finki_components.dart`, `lib/v1/app.dart`, `lib/v1/forms.dart`, `lib/v1/money.dart`, nuevo `lib/v1/presentation.dart`, `pubspec.yaml` y `pubspec.lock` (localización SDK).

QA: `test/home_test.dart`, `test/redesign_test.dart`, nuevo `test/v2_regression_test.dart` y un caso adicional en `backend/test/scenarios.js`. No se modificaron servicios, contratos ni configuración del backend, migraciones o datos MySQL.

## Verificaciones reproducibles

- Analizador: sin incidencias.
- Flutter: 43 pruebas aprobadas. Incluyen 320, 360, 390, 412, 768 y 1280 px, scroll final, teclado, navegación, formularios, selector de 50 opciones, texto ampliado, importes grandes, fechas, edición versionada, venta sin categoría y actualización de indicadores.
- Backend: 21 pruebas aprobadas; HTTP Express real con repositorio EN MEMORIA. Incluyen registro/login/refresh/logout, roles, aislamiento, fiado 100, abono 40, pendiente 60, liquidación, sobreabono, idempotencia, transferencias, anulaciones y edición versionada del negocio.
- Lectura real: salud Express/MySQL y rechazo de consulta protegida sin sesión. No se crean cuentas ni operaciones en desarrollo.
- La integración MySQL con escritura permanece omitida, sin RUN_MYSQL_TESTS=1. Estas pruebas no certifican bloqueos ni concurrencia InnoDB.
- Bundle Dart y recursos Android ARM64 debug: compilación correcta, sin generar ni instalar APK.
- Compilación web V2 correcta y vista local en `http://localhost:5173/` mediante `tool/serve-finki-web.cjs`.
- Prueba específica adicional de filtros: los selectores envían `tipo=GASTO_OPERATIVO` y `estado=CONFIRMADO` en la consulta; resultado aprobado.
- Las capturas `build/tooling/redesign-*.png` provienen de widgets aislados; se revisaron inicio, fiados, vacíos completos, final del scroll, formularios e historial. Sus datos nunca se cargan en producción.

```powershell
.\tool\flutter-local.ps1 analyze --no-pub
.\tool\flutter-local.ps1 test --no-pub --concurrency=1 --dart-define=RUN_LIVE_API=true
.\tool\flutter-local.ps1 build bundle --debug --no-pub --target-platform=android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
Push-Location backend
node --test test/*.test.js
Pop-Location
```

Registros de esta entrega: `build/tooling/finki-v2-final-tests.log`, `finki-v2-backend-tests.log`, `finki-v2-android-bundle.log` y `finki-v2-web-build.log`.

## Actualizar el teléfono por USB

En esta revisión `adb devices -l` no detecta ningún dispositivo. La ejecución física de V2 sigue pendiente; el usuario indicó continuar sin teléfono. No se desinstaló, reinició ni borró la aplicación instalada.

Si vuelve a estar conectada una sesión Flutter activa, ejecutar primero pub get y usar **Flutter: Hot Restart** desde la paleta de VS Code, o `R` en la terminal de flutter run. La localización y configuración raíz se inicializan al reiniciar Dart; las posteriores correcciones de presentación pueden usar `r` (Hot Reload). Hot Restart reinicia el estado Dart, mientras la sesión guardada se vuelve a leer del almacenamiento seguro.

Si la sesión de depuración ya terminó, conectar y desbloquear el teléfono, aceptar la depuración USB y ejecutar desde PowerShell:

```powershell
Set-Location D:\HACKATHON2026\Hackathon2026-Pinguinos
& D:\Android\Sdk\platform-tools\adb.exe devices -l
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS reverse tcp:3000 tcp:3000
.\tool\flutter-local.ps1 pub get
.\tool\flutter-local.ps1 run --no-pub -d 10AD370TQF002ZS --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

`10AD370TQF002ZS` es el ID de la sesión anterior; debe aparecer como `device` al reconectarlo. Si ADB muestra otro ID, sustituirlo en ambos comandos. `flutter run` prepara la actualización debug de desarrollo cuando es necesaria. No se cambió el applicationId ni el espacio de almacenamiento de sesión; se mantiene exactamente el API_BASE_URL anterior. No ejecutar flutter clean, pm clear ni desinstalar para aplicar estos cambios.

Express debe continuar en `127.0.0.1:3000`; adb reverse redirige ese puerto por USB. MySQL conserva su configuración local.

## Límites pendientes

Falta comprobar V2 directamente en el teléfono y recorrer los formularios con la cuenta real. No se hicieron ensayos de escritura sobre Bodega Finki Demo. Voz, cámara/OCR, IA conversacional, PDF y sincronización offline completa siguen pendientes y se identifican como próximos.

Se preserva la rama actual `feat/backend-v1` y todos los cambios anteriores. Sin commits ni push.
