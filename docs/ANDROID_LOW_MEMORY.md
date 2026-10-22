# Android físico: compilación con memoria limitada

## Causa comprobada el 22/10/2026

`android/hs_err_pid27692.log`: fallo nativo `malloc` de 32752 bytes en
`C2 CompilerThread0`, no un error Dart ni un límite de heap Java alcanzado.
Al fallar: RAM libre 169 MB y margen de memoria comprometida de Windows 9 MB
(`TotalPageFile 20490M`, `AvailPageFile 9M`). El nombre de este campo de la JVM
incluye el límite de compromiso, no solo el espacio usado en pagefile.sys.

Al diagnosticar: Windows tenía 7.37 GiB utilizables, ~98 MB libres y ~666 MB
de margen de compromiso. Dos Gradle de VS Code sumaban ~2350 MiB privados,
además de los analizadores y las demás aplicaciones. No era necesario cambiar
Java 25: Gradle 9.3.1 lo admite; AGP 9.1 usa Gradle 9.3.1.

Fuentes oficiales:
https://docs.gradle.org/current/userguide/compatibility.html
https://developer.android.com/build/releases/about-agp

## Ajustes locales

- `android/gradle.properties`: heap 512 MiB, metaspace 384 MiB, caché de código
  64 MiB, SerialGC, dos procesadores y `TieredStopAtLevel=1` para evitar C2.
- Se conserva un worker, sin paralelismo ni daemon persistente y Kotlin in-process.
  Gradle puede crear un daemon de un solo uso aunque `org.gradle.daemon=false`.
- La primera compilación con memoria limitada dejó de fallar en la JVM y detectó
  además `Could not close incremental caches` en `image_picker_android`.
  `kotlin.incremental=false` evita ese mecanismo sin borrar cachés. El mensaje
  disponible no permite atribuirlo con certeza a corrupción o rutas entre unidades.
- `tool/flutter-local.ps1`: no inyecta un segundo `-Xmx`; limita JIT también
  en el lanzador. Archivo abierto con acceso exclusivo impide dos ejecuciones
  del script. No impide procesos iniciados directamente por VS Code/Android Studio.
- No se cambiaron Java, AGP, Gradle ni dependencias; no se borraron cachés,
  no hubo `flutter clean` ni cambios en backend, base de datos o secretos Gemini.

Cerrar VS Code antes de compilar en este equipo: sus importadores Java/Gradle
pueden volver a consumir memoria aunque no se ejecute Flutter desde el editor.
Mantener Laragon, backend y chat abiertos. No iniciar otro build en paralelo.

## Compilar y actualizar sin borrar almacenamiento

Desde la raíz del repositorio, con el teléfono desbloqueado y autorizado:

```powershell
.\tool\flutter-local.ps1 build apk --debug --no-pub --target-platform android-arm64 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS reverse tcp:3000 tcp:3000
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS install -r build\app\outputs\flutter-apk\app-debug.apk
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS shell am start -W -n pe.pinguinos.hackathon_pinguinos_mvp/.MainActivity
```

Ejecutar instalación solo si la compilación terminó con éxito. `install -r`
conserva los datos de aplicación; no desinstalar ni limpiar almacenamiento.
`adb reverse` debe repetirse tras reconectar USB. Backend escucha solo en
127.0.0.1:3000 y MySQL permanece local.

Para desarrollar después:

```powershell
.\tool\flutter-local.ps1 run --no-pub -d 10AD370TQF002ZS --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

Si existe `JAVA_TOOL_OPTIONS` personalizado en la terminal, el script lo respeta.
No añadir otro heap global; revisar las opciones efectivas en el log Gradle.

Si vuelve a agotarse el compromiso de Windows, liberar aplicaciones antes de
reintentar. La alternativa es ampliar la paginación de Windows (requiere espacio
en disco y posiblemente reinicio); no se cambia automáticamente desde este script.
Reducir indefinidamente el heap puede producir `Java heap space` y no soluciona
la falta de memoria del sistema.

## Resultado verificado

El segundo intento, con `kotlin.incremental=false`, terminó correctamente en 279 s
(4 min 39 s). No se ejecutaron compilaciones simultáneas. El bloqueo exclusivo del
script se comprobó mientras compilaba.

Instalación `adb install -r`: `Success`. Inicio de `.MainActivity`: `Status: ok`,
`LaunchState: COLD`. Android informa `lastUpdateTime=2026-10-22 14:19:07`,
versionCode 1/versionName 1.0.0. Se conserva el applicationId.

Se inspeccionó captura del Android físico: dashboard de Bodega Finki Demo con
sesión de Danny conservada, logo FINKI y navegación visibles. No se registraron
ventas, gastos ni otros datos ficticios. No hubo excepciones Flutter en los
últimos 350 registros consultados del proceso. Se observó una advertencia del
renderizador OpenGL sobre swap behavior que no impidió mostrar el dashboard.

`adb reverse --list` confirma tcp:3000. Chrome del teléfono mostró
`{"status":"ready"}` en `http://127.0.0.1:3000/api/v1/health/ready`, verificado
en su jerarquía UI. También se comprobó ready desde Windows después de instalar.
Al cerrar VS Code se había cerrado la terminal de Express: se reinició Node
como proceso independiente, solo en 127.0.0.1:3000.

Evidencia local ignorada por Git: `build/tooling/finki-v3-android-verified.png`
y `build/tooling/finki-health-check.xml`. La APK actual está en
`build/app/outputs/flutter-apk/app-debug.apk`.

Archivos fuente/configuración de esta corrección: `android/gradle.properties`,
`tool/flutter-local.ps1`, este documento y la nota de progreso V3. No se tocó
`backend/.env`, ninguna clave, código financiero ni archivos de base de datos.
Sin commits ni push.
