# Ajustes visuales finales FINKI V2 — 22/10/2026

Cambios limitados a `lib/ui/widgets/finki_components.dart`, `lib/v1/app.dart` y pruebas nuevas en `test/visual_polish_test.dart`.

- FinkiMoneyCard: parejas con IntrinsicHeight, Row estirado y espacio flexible antes del importe. Altura compartida según contenido, sin altura fija; en espacios estrechos se apilan.
- FinkiSelect: ButtonTheme(alignedDropdown: true) elimina la expansión lateral de 16/24 px del anclaje nativo. Popup alineado al campo, radio 16, elevación 3 y marca de selección. Conserva validación, opciones, navegación y callbacks. La altura usa el área visible de Flutter View, incluido el teclado incluso cuando Scaffold ya retiró sus insets del MediaQuery.
- Alcance: dashboard y pares de indicadores en reportes; selectores comunes de Historial y formularios V1 (operaciones, abonos, cuentas, categorías, contactos y negocios donde usan FinkiSelect).

Validación real: analyze sin observaciones; suite general 60 aprobadas y una prueba opcional omitida. Esa prueba de API real se ejecutó después con RUN_LIVE_API=true y pasó: health/live, health/ready y rechazo 401 de acceso anónimo. Las 18 pruebas visuales específicas pasaron también por separado, con capturas: 320, 360, 390, 412, 768 y horizontal 844x390; teclado simulado, SafeArea, selección, textos largos e importes grandes. No son pruebas físicas de todos esos dispositivos.

En Android V2206 se conservó la sesión y se aplicó la actualización por attach/hot reload, sin reinstalar ni generar un APK. Se verificaron tarjetas iguales, importes alineados, menús de Historial y pago de venta con márgenes y robot completo. Se abrió el formulario de venta y se cerró sin guardar. Capturas locales en build/tooling/finki-polish-cards-final.png, finki-polish-menu-final.png, finki-polish-payment-menu.png y finki-polish-restored.png. El fallo temporal de conexión tras el cierre de ADB se resolvió restableciendo adb reverse.

Para actualizar de nuevo desde PowerShell en la raíz del proyecto, con Laragon y Express activos y el teléfono conectado:

```powershell
& D:\Android\Sdk\platform-tools\adb.exe devices
& D:\Android\Sdk\platform-tools\adb.exe -s 10AD370TQF002ZS reverse tcp:3000 tcp:3000
.\tool\flutter-local.ps1 run --no-pub -d 10AD370TQF002ZS --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

Si ya hay una sesión Flutter conectada, usar `r` para hot reload. No desinstalar ni borrar almacenamiento. Mantener el mismo applicationId. El puerto USB permite usar Express en loopback; MySQL no se expone.

No se modificaron backend, migraciones ni base de datos en esta tarea. No se guardaron operaciones, negocios ni usuarios de prueba en desarrollo. Se preservaron cambios anteriores, sin commits ni push. Las pruebas de widgets usan datos locales de prueba sin HTTP. No se reconstruyó la versión web en esta revisión enfocada en Android. El teclado y la orientación se validaron automáticamente; no se afirma una revisión manual exhaustiva de cada formulario o dispositivo.
