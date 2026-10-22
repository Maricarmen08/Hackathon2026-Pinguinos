# FINKI en Chrome, ejecución local

Dirección: http://localhost:5173/
API: http://127.0.0.1:3000/api/v1

El servidor Flutter queda escuchando solo en localhost y Express en 127.0.0.1:3000. backend/.env ya permite exactamente CORS_ORIGINS=http://localhost:5173; no se ampliaron permisos ni se cambiaron secretos. MySQL sigue accediéndose únicamente desde Express.

Para volver a iniciar desde la raíz, si el servidor web ya está detenido:

```powershell
.\tool\flutter-local.ps1 run -d chrome --web-hostname=localhost --web-port=5173 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1
```

No iniciar otra copia si el puerto 5173 está ocupado. Mantener Laragon y Express activos. flutter run abre un perfil Chrome de desarrollo; utilizar la misma ventana para conservar su sesión local. El almacenamiento web existente utiliza WebCrypto en localhost; no se guarda la contraseña.

La plataforma web fue generada con flutter create --platforms=web --no-pub. Android y las migraciones conservaron sus hashes. Se ajustaron el título visible y metadatos a FINKI, y el dispositivo de autenticación usa plataforma WEB en el navegador. No se añadieron dependencias. El logo y robot oficiales están integrados desde assets/branding/finki_logo.png, conservando exactamente el PNG proporcionado y su transparencia.

Verificación: compilación de depuración web correcta, pantalla de login renderizada e inspeccionada en Chrome y petición health/ready desde el navegador con respuesta 200 {status:ready}. Contexto seguro localhost y WebCrypto disponibles. No se enviaron formularios de autenticación ni comandos financieros durante esta preparación.

Para crear TU primera cuenta, pulsa «Soy nuevo · Registrarme» y completa tus propios datos y una contraseña de al menos 12 caracteres. Después podrás crear tu negocio y acceder a las pantallas privadas. Ese envío manual sí crea tu cuenta real en el backend. No hay acceso anónimo a datos privados ni usuarios de prueba creados automáticamente.

Logs de esta ejecución: build/tooling/finki-web.stdout.log y finki-web.stderr.log. No se utilizó emulador ni se generó otro APK. Sin commits ni push.


## Identidad visual FINKI

Logo en login, registro, encabezados, menú del negocio y dashboard. Tema azul #185FC9, azul marino #102F5C, celeste #09AFDC y fondos claros. Diseño de dos columnas en escritorio y una columna en móvil, con campos y botones redondeados. Favicon y metadatos web actualizados. No se cambiaron servicios, reglas financieras, autenticación ni datos.

Archivos visuales: lib/core/theme/app_theme.dart, lib/ui/widgets/finki_brand.dart, lib/v1/app.dart, lib/v1/forms.dart, pubspec.yaml, assets/branding/finki_logo.png, web/index.html, web/manifest.json y web/favicon.png.
