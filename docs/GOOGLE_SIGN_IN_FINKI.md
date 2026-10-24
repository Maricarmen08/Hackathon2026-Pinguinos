# Google Sign-In en FINKI: preparación local y despliegue coordinado

Estado: Android y Web validados manualmente por el usuario el 24/10/2026, incluido
logout y regreso al negocio existente. NO habilitado en producción.
Ver el cierre de auditoría en [AUDITORIA_GOOGLE_SIGN_IN.md](AUDITORIA_GOOGLE_SIGN_IN.md).
No existen Client IDs de
ensayo inventados en la configuración. Las pruebas usan verificadores dobles e
identidades ficticias. La selección real de cuentas Google requiere configurar
Google Cloud y validar Android/Web. No se necesita Firebase.

## 1. Flujo y conservación de cuentas

- Registro e inicio tradicionales conservan teléfono/contraseña y validadores.
- Google nuevo: token verificado -> usuario sin teléfono ni contraseña -> sesión
  FINKI -> `BusinessHome` detecta cero negocios -> formulario existente de negocio.
- Google existente: `(GOOGLE, sub)` recupera el mismo UUID y sus membresías.
- Correo coincidente no vinculado: no se crea ni fusiona. Ingresar con FINKI,
  abrir Perfil > Cambiar contraseña / Seguridad, pulsar Vincular Google y comprobar
  la contraseña anterior. Debe haber sesión activa y ambas identidades verificadas.
- No hay endpoint para quitar una identidad o desactivar el único acceso.
- Cuenta Google sin contraseña: Seguridad informa que se accede con Google;
  no se simula contraseña ni se exige teléfono para editar el nombre.
- Cambiar el correo de contacto no cambia `sub` ni vincula una nueva identidad.
- No se descarga ni reemplaza la fotografía del usuario desde Google.

## 2. Esquema 003

Archivo incremental: `database/migrations/003_google_identity.sql`.

`identidades_externas`: id/usuario_id CHAR(36) ascii_bin; proveedor VARCHAR(16)
ascii_bin; sujeto VARCHAR(255) ascii_bin; correo_proveedor VARCHAR(254) nullable;
correo_verificado BOOLEAN; ultimo_token_iat BIGINT; creado_en y ultimo_acceso_en
DATETIME(6). FK a usuarios; UNIQUE(proveedor,sujeto) y UNIQUE(usuario_id,proveedor).
CHECK para UUID, proveedor GOOGLE, sujeto no vacío, correo verificado e iat positivo.

Usuarios: teléfono nullable; `acceso_google BOOLEAN NOT NULL DEFAULT FALSE`;
password_hash sigue nullable y valida el formato cuando existe. CHECK de método:
usuario activo exige teléfono+hash tradicional o acceso_google=1. Usuarios
tradicionales existentes reciben acceso_google=0 y conservan todos sus valores.
MySQL permite varios NULL en UNIQUE de teléfono, pero no teléfonos no nulos repetidos.

La presencia de identidad válida para acceso_google=1 es un invariante del backend:
solo se asigna tras verificación Google y dentro de la misma transacción que
inserta la identidad. MySQL no permite CHECK con consulta a otra tabla. No otorgar
al cliente capacidad de escribir ese indicador; PATCH /perfil no lo admite.
No crear usuarios manualmente saltándose este servicio.

Instalación limpia: importar únicamente el SQL único actualizado, 24 tablas,
5 vistas, 59 FK, 114 CHECK y migraciones 1/2/3. No ejecutar luego 003 sobre ella.
Las migraciones 001 y 002 históricas no se modifican. El verificador y la
preparación de pruebas ya contemplan la tercera versión.

## 3. Aplicación por la responsable de MySQL (NO ejecutado en producción)

1. Validar primero sobre una copia aislada. Confirmar host, esquema, MySQL 8.4,
   versiones 001/002 y ausencia de una aplicación parcial de 003.
2. Programar una ventana sin escrituras, mantener GOOGLE_AUTH_ENABLED=0 y guardar
   respaldo fuera de Git, con acceso restringido. Comprobar restauración en otra
   base nueva antes de continuar. Los ejemplos contienen marcadores que hay que
   reemplazar localmente; no son credenciales.

```powershell
mysqldump.exe --host=HOST_MYSQL --user=USUARIO_RESPALDO --password `
  --single-transaction --routines --triggers --no-tablespaces `
  --result-file="RUTA_PRIVADA_RESPALDO.sql" BASE_ACTUAL
```

3. Con cuenta autorizada para ALTER, CREATE TABLE/ROUTINE e INSERT de migraciones,
   y conectado explícitamente al esquema correcto:

```powershell
mysql.exe --host=HOST_MYSQL --user=USUARIO_MIGRACION --password `
  --database=BASE_ACTUAL `
  --execute="SOURCE database/migrations/003_google_identity.sql"
```

4. Verificar schema_migraciones incluye 003; revisar SHOW CREATE TABLE usuarios e
   identidades_externas, conteos y accesos tradicionales. El usuario normal de la
   app conserva SELECT/INSERT/UPDATE sobre el esquema, incluida la nueva tabla.
5. Desplegar backend compatible con Google todavía apagado. Solo tras aprobar
   pruebas y configurar OAuth habilitar Google. Finalmente publicar clientes.

DDL hace commit implícito: no se promete rollback transaccional del archivo.
Si falla, detenerse, guardar error y consultar metadata. No volver a ejecutar a
ciegas, no borrar tablas/rutinas para insistir y no importar el SQL limpio encima.
La rutina se conserva para inspección y rechaza versión aplicada/parcial.
Recuperación: mantener Google apagado, revisar qué DDL terminó y completar bajo
revisión o restaurar el respaldo en un esquema NUEVO. Verificarlo antes de cambiar
la conexión mediante el procedimiento autorizado del equipo. No borrar la base
original. Después de crear usuarios Google no volver al backend anterior sin un
plan: esas cuentas no tienen contraseña tradicional.

## 4. Google Cloud: configuración personal del equipo

1. Crear/seleccionar proyecto y configurar Google Auth Platform: branding FINKI,
   soporte, audiencia y cuentas de ensayo cuando corresponda. Pedir solo identidad
   básica (openid/email/profile), no Drive, contactos, People API ni Gmail.
2. Crear cliente Web. Orígenes: http://localhost y http://localhost:5173 para
   desarrollo; origen HTTPS real del frontend desplegado, sin /api/v1 ni rutas.
   Express puede servir `backend/web_build`; si ese es el frontend desplegado, el
   origen es https://hackathon2026-pinguinos.onrender.com. Confirmarlo con el equipo.
   Con callback JavaScript no se inventa una URL redirect. Si se elige redirect
   en el futuro, registrarlo y añadir las protecciones de ese flujo.
3. Crear clientes Android: paquete `pe.pinguinos.hackathon_pinguinos_mvp`, SHA-1
   del certificado de cada variante. Obtener SHA-256 para configuraciones que la
   requieran. Cada PC puede tener su propia firma debug; Play App Signing tendrá
   otra firma. El release actual aún firma con debug: no asumir firma productiva.
4. Mantener mismo proyecto para la relación de clientes Android/Web. El Client ID
   Web se usa como serverClientId de Android. Nunca usar aquí el ID Android.
5. Client IDs son públicos. No hace falta copiar un client secret al teléfono o
   navegador, ni crear claves de servicio. Conservar cualquier secreto fuera de Git.

Documentación oficial:
- https://pub.dev/packages/google_sign_in_android
- https://pub.dev/packages/google_sign_in_web
- https://developers.google.com/identity/gsi/web/guides/verify-google-id-token
- https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid

Para consultar las huellas de las variantes locales (sin compartir el keystore):
```powershell
Set-Location android
.\gradlew.bat signingReport
Set-Location ..
```
Usar el JDK compatible que informa flutter doctor -v. No ejecutar signingReport
mientras otra compilación esté activa. Copiar SHA-1/SHA-256 del certificado de la
variante correcta, no de otra PC. No subir el keystore ni sus contraseñas.

## 5. Configuración (no se modifica .env existente)

Backend: GOOGLE_AUTH_ENABLED=0 por defecto. Tras aplicar 003 y preparar pruebas,
usar GOOGLE_AUTH_ENABLED=1 y GOOGLE_CLIENT_IDS con la lista explícita separada
por comas de audiencias Web permitidas. Sin IDs no se realizan verificaciones
externas. Al habilitar Google, `Database.ping` exige migración 003.

Flutter: GOOGLE_WEB_CLIENT_ID para Web; GOOGLE_SERVER_CLIENT_ID para Android.
Los valores reales se pasan mediante --dart-define. Sin ellos el botón se muestra
deshabilitado con explicación y siguen disponibles los accesos anteriores.

Para probar sin invalidar la sesión del backend habitual, usar una base nueva
con 003 y un backend en el puerto 3001, con usuario MySQL autorizado solo para
ensayo y secretos JWT propios. Configurar esas variables únicamente en la
terminal del proceso de ensayo; no editar el .env habitual ni Render. La URL
3001 tiene su propio namespace de almacenamiento de sesión en Flutter. No usar
las mismas cuentas o base de producción.

Ejemplo de terminal Backend de ensayo (todos los marcadores se reemplazan):
```powershell
$env:DB_NAME='BASE_AISLADA_CON_003'
$env:DB_USER='USUARIO_LOCAL_ENSAYO'
$env:DB_HOST='127.0.0.1'
$env:DB_PASSWORD=[System.Net.NetworkCredential]::new('',(Read-Host 'Clave local de ensayo' -AsSecureString)).Password
$env:PORT='3001'
$env:GOOGLE_AUTH_ENABLED='1'
$env:GOOGLE_CLIENT_IDS='ID_WEB_REAL'
$env:JWT_SECRET=node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
$env:JWT_REFRESH_SECRET=node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
Set-Location backend
npm.cmd start
```
Cerrar esa terminal al terminar. No copiar ni publicar su entorno.

Ejemplo Android de ensayo (sustituir ID_WEB_REAL; API local elegida explícitamente):
```powershell
adb -s ID_TELEFONO reverse tcp:3001 tcp:3001
.\tool\flutter-local.ps1 run -d ID_TELEFONO `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=ID_WEB_REAL `
  --dart-define=API_BASE_URL=http://127.0.0.1:3001/api/v1
```
Web de ensayo (no usa backend/web_build):
```powershell
.\tool\flutter-local.ps1 run -d chrome --web-hostname=localhost --web-port=5173 `
  --dart-define=GOOGLE_WEB_CLIENT_ID=ID_WEB_REAL `
  --dart-define=API_BASE_URL=http://127.0.0.1:3001/api/v1
```
Web utiliza renderButton oficial y authenticationEvents; nunca invoca authenticate
en Web. Allí el SDK se inicializa una sola vez por runtime. Solo el botón Google tiene
sus requisitos de marca: no se cambia robot, logo, navegación ni paleta FINKI.
No se ha reconstruido, sobrescrito ni publicado `backend/web_build`.

## 6. Seguridad y límites

### Preparar la Web para el servicio Express ya existente en Render

Desde la raíz del proyecto, en Windows con Flutter instalado:

```powershell
.\tool\build-web-release.ps1 -GoogleWebClientId 'CLIENT_ID_WEB_PUBLICO' -PrepareBackend
```

Sustituir el marcador por el Client ID Web real, no por un Client Secret. El script
compila release con `GOOGLE_WEB_CLIENT_ID` y la API HTTPS
`https://hackathon2026-pinguinos.onrender.com/api/v1`, verifica ambos valores en el
JavaScript generado y copia el resultado a `backend/web_build`, que es la carpeta
que Express sirve. Se puede indicar otra API HTTPS con `-ApiBaseUrl`. Sin
`-PrepareBackend` solo genera `build/web`, sin sustituir la carpeta publicable.
No utiliza los JSON de pruebas con localhost ni pasa serverClientId a Web.

Revisar y subir después los fuentes y `backend/web_build` regenerado con la
autorización correspondiente. La compañera actualiza su servicio existente desde
ese commit; no necesita crear otro despliegue ni ejecutar otra migración. Su
backend debe tener Google habilitado y aceptar el mismo ID Web en
`GOOGLE_CLIENT_IDS`; Google Cloud debe autorizar el origen HTTPS de la página.
Cambiar únicamente variables de Express no modifica un Flutter Web ya compilado.
El script no accede a Render ni a MySQL y no realiza commit, push o despliegue.

El backend usa google-auth-library verifyIdToken con audiencias explícitas,
firma, emisor y expiración; además exige sub, email_verified, iat y nonce. No
acepta identidades o correos libres proporcionados por Flutter.

En Android el nonce aleatorio se renueva en cada intento interactivo mediante una
instancia nueva del adaptador oficial GoogleSignInAndroid, inicializada una sola
vez. No se reinicializa el singleton GoogleSignIn. Web conserva la inicialización
única y su botón oficial. El nonce enviado debe coincidir con el ID token.
La app no recibe sesiones por cookies ni redirects externos: envía JSON y
guarda solo la respuesta de su petición. CORS valida origen Web; no se cambia la
política para aceptar cualquier dominio. Google se intercambia vía HTTPS en
producción (HTTP localhost únicamente para ensayo controlado).

ultimo_token_iat es un watermark persistente bajo bloqueo: impide reutilizar el
mismo token o uno anterior para emitir otra sesión. Dos accesos legítimos en el
mismo segundo pueden requerir obtener un token nuevo después; no se guardan tokens
Google. Android cierra la selección anterior antes de autenticar para evitar un
token en caché. Esta política prioriza rechazar replay sobre aceptar reintentos.
Un nonce fijo durante toda la ejecución permitía que Android devolviera una
credencial en caché después de cerrar sesión: signOut no garantiza renovar su
fecha de emisión. La regresión comprueba nonce distinto por intento y el flujo
Google -> crear negocio ficticio -> logout -> regresar al mismo negocio, sin
duplicar usuario/identidad/membresía. El watermark sigue rechazando tokens usados.
Una credencial robada antes de su primer uso sigue siendo un bearer token: nunca
registrarla en logs, URLs, analytics o excepciones. Los tests inyectan verificadores
dobles; no prueban una cuenta Google real.

Se reutilizan JWT FINKI, refresh rotativo, dispositivo por acceso y membresías.
El cliente no asigna roles ni crea negocios automáticamente.

## 7. Pruebas y activación pendiente

```powershell
cd backend
npm.cmd test
# Solo con MySQL LOCAL y permiso CREATE DATABASE para bases nuevas de ensayo:
$env:FINKI_GOOGLE_SCHEMA_TEST='YES'
node --test test/google-schema.integration.js
```
Ese test rechaza hosts remotos, crea dos bases con sufijos aleatorios, nunca
actualiza el esquema habitual y no borra las bases de ensayo. Usa datos ficticios.
Comprueba instalación limpia, fila tradicional previa, rechazo de reaplicación,
NULL/UNIQUE, CHECK, concurrencia y sesiones reales sobre MySQL aislado.

Antes de desplegar: cuentas Google reales de ensayo en Android y Web, cancelación,
email coincidente, vinculación, usuario bloqueado, cuenta con/sin negocio, errores
de red, logout/reintento y permisos entre negocios. Revisar CORS/COOP/FedCM en el
hosting Web. No declarar E2E aprobado hasta disponer de Client IDs y SHA reales.

## 8. Inventario de archivos de esta implementación

- Modificado: `backend/.env.example`
- Modificado: `backend/package-lock.json`
- Modificado: `backend/package.json`
- Modificado: `backend/scripts/verify-install.js`
- Modificado: `backend/src/app.js`
- Modificado: `backend/src/config.js`
- Modificado: `backend/src/errors.js`
- Modificado: `backend/src/repositories/database.js`
- Modificado: `backend/src/repositories/tables.js`
- Modificado: `backend/src/services/auth.js`
- Modificado: `backend/src/validators.js`
- Modificado: `backend/test/memory.js`
- Modificado: `backend/test/setup-test-db.js`
- Modificado: `database/CHECKSUMS.sha256`
- Modificado: `database/README.md`
- Modificado: `database/hackathon_pinguinos_dev.sql`
- Modificado: `docs/INSTALACION_EQUIPO_FINKI.md`
- Modificado: `lib/v1/account_security_page.dart`
- Modificado: `lib/v1/api_client.dart`
- Modificado: `lib/v1/app.dart`
- Modificado: `lib/v1/profile_edit_page.dart`
- Modificado: `pubspec.lock`
- Modificado: `pubspec.yaml`
- Nuevo: `backend/src/services/google-auth.js`
- Nuevo: `backend/test/google-auth.test.js`
- Nuevo: `backend/test/google-schema.integration.js`
- Nuevo: `database/migrations/003_google_identity.sql`
- Nuevo: `docs/GOOGLE_SIGN_IN_FINKI.md`
- Nuevo: `lib/v1/google_access.dart`
- Nuevo: `lib/v1/google_button_stub.dart`
- Nuevo: `lib/v1/google_button_web.dart`
- Nuevo: `test/google_access_test.dart`
- Nuevo: `lib/v1/google_android_access.dart`
- Nuevo: `test/google_android_access_test.dart`
- Modificado: `test/account_security_test.dart`
- Nuevo: `docs/AUDITORIA_GOOGLE_SIGN_IN.md`

## 9. Avisos de dependencias previos

La auditoría npm detecta dos avisos altos ya presentes en HEAD antes de esta
implementación: body-parser 1.20.8 y zod 3.25.76. No proceden de la biblioteca
Google añadida. No se ejecutó npm audit fix ni una actualización mayor de Zod;
deben revisarse y resolverse por separado antes de considerar el despliegue
listo para producción. Los IDs locales se conservan en archivos privados; la
regresión real de salida y regreso fue confirmada por el usuario en Android y Web.
