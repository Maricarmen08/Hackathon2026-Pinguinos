# Perfil, fotografía privada y seguridad de cuenta

## Alcance de esta entrega

Se conserva la rama `danny`, la sesión Android, el negocio y sus datos. No se
modifica el PDF, el cálculo financiero, las propuestas, OCR ni la voz offline.
No hay cambios de esquema, migraciones, dependencias, secretos o `.env`.

### Identidad visual

El encabezado utilizaba `assets/branding/finki_robot.png`: el propio archivo
contiene una vista recortada del robot. No era un fallo de `Clip` ni de `BoxFit`.
`FinkiMascot` compacto usa ahora el recurso completo existente
`finki_logo_display.png`, dentro del tamaño anterior y con `BoxFit.contain`.
`FinkiBrandHeader` comparte esta corrección entre las pestañas y pantallas
secundarias que ya lo utilizan. Se mantienen FINKI, subtítulo y acciones.

### Perfil

Se conservan editar datos, selección de negocio, roles, edición/creación del
negocio, sincronización, privacidad, ayuda y cierre de sesión. Se añaden foto,
seguridad, identificadores de acceso y versión 1.0.0 (compilación 1, igual que
`pubspec.yaml`). La ayuda tiene su propia sección. Los cambios personales
confirmados recargan los datos y muestran un mensaje de éxito; los errores
conservan el formulario. El teléfono acepta los formatos existentes del backend,
incluyendo nueve dígitos peruanos, normalizados allí a +51.

### Fotografía

- `image_picker`, ya instalado: cámara o galería, hasta 1024 × 1024 y calidad 85.
- Previsualización, encuadre cuadrado horizontal/vertical cuando corresponde,
  confirmación explícita y opción de eliminar con confirmación.
- Flutter vuelve a codificar la selección como PNG de 256 × 256. No conserva
  EXIF, localización ni el nombre/ruta del archivo original. No llama a IA.
- `GET /perfil/foto`, `PUT /perfil/foto`, `DELETE /perfil/foto` requieren sesión
  válida. No aceptan un identificador de otro usuario como destino.
- Backend limita cuerpo a 512 KiB y dimensiones a 512 × 512. Valida firma PNG,
  estructura, CRC de cada bloque, formato RGB/RGBA de 8 bits, descompresión
  limitada, longitud y filtros de filas. Rechaza archivos truncados, corruptos,
  formatos inesperados y contenido comprimido excesivo.
- Almacenamiento: directorio privado existente (`FINKI_PRIVATE_DIR` si está
  configurado, de lo contrario `backend/private`), subdirectorio
  `profile-photos/<DB_NAME>/<usuario_uuid>.png`. No es una URL pública ni una
  columna BLOB en MySQL. Escritura temporal y reemplazo atómico; el cliente no
  controla rutas. Los archivos privados deben incluirse en las copias de
  seguridad del despliegue, junto con las demás evidencias privadas.
- La copia persiste en servidor al salir y volver a entrar. Android reutiliza
  la caché cifrada del `ApiClient`, separada por URL del servidor y usuario.
  Después de guardar/eliminar se actualiza esa caché. Sin conexión se avisa que
  se está mostrando la última copia y se deshabilitan cambios. Sin copia se
  muestra el avatar predeterminado.

### Acceso con teléfono o correo

Ya existía antes de esta entrega: `auth.login` busca el teléfono normalizado o
el correo normalizado y comprueba la misma contraseña scrypt. No crea otro
usuario. MySQL exige unicidad de ambos identificadores. Se conserva este
contrato y se cambia la etiqueta a «Teléfono o correo electrónico».

**Limitación real:** no hay infraestructura de envío/verificación de correo.
Un correo asociado sirve como identificador con contraseña, pero no acredita
titularidad del buzón. La UI lo indica expresamente; no se muestra como
«verificado» ni se implementa recuperación por correo/teléfono. Incorporar
verificación o recuperación requiere un flujo independiente de tokens de un
solo uso, caducidad y entrega real. No se simula esa infraestructura.

### Cambio de contraseña

`POST /perfil/contrasena`: contraseña actual, nueva y confirmación. Política
existente de 12 a 128 caracteres; la nueva debe ser distinta y coincidir con
su confirmación. El formulario permite mostrar/ocultar cada campo.

Se comprueba la clave actual en backend y se usa el scrypt existente. Una
transacción vuelve a comprobar que el hash no cambió concurrentemente, actualiza
el hash y la versión del usuario, y revoca todas las sesiones distintas de la
actual, incluidos sus tokens de renovación. La sesión desde la que se cambió
continúa abierta. No hay contraseñas en respuestas, logs ni almacenamiento local.
Límite por usuario: cinco intentos cada quince minutos, en el proceso Express
local actual. No es un flujo de «olvidé mi contraseña».

## Validación

Las pruebas de identidad escriben solo en repositorio en memoria y en
`hackathon_pinguinos_test` con guardia `NODE_ENV=test`. La foto de ensayo usa un
directorio temporal independiente que se elimina al terminar. Nunca se cambian
el nombre, teléfono, correo, clave o foto reales de Danny.

- Backend: regresión HTTP/financiera; acceso por teléfono y correo normalizado,
  rechazo de credenciales inválidas, edición válida, validaciones y duplicados,
  persistencia, foto privada y separación de usuarios, reemplazo y eliminación,
  corrupción/tamaño, contraseña actual incorrecta, nueva inválida, confirmación
  distinta, cambio correcto, clave anterior inválida, nueva válida, revocación
  de otras sesiones y limitación de intentos.
- MySQL aislado: mismos escenarios con índices, transacciones y sesiones reales.
- Flutter: cabecera completa proporcional en 320 y 714 píxeles, validación del
  formulario, errores que conservan datos, visibilidad de claves, cámara/galería
  simuladas con previsualización y confirmación, normalización 256 × 256,
  caché offline y aislamiento entre usuarios; regresión de las demás pantallas.
- El PNG realmente producido por Flutter también se pasó al validador backend.

La comprobación física de cámara/galería y guardado de una foto personal, así
como el cambio de contraseña real, requieren intervención del titular. Abrir
formularios y cancelar selectores en Android no modifica esas credenciales.

## Archivos de esta mejora

UI: `lib/ui/widgets/finki_brand.dart`, `lib/v1/app.dart`,
`lib/v1/profile_edit_page.dart`, `lib/v1/profile_photo_page.dart`,
`lib/v1/account_security_page.dart`.

Backend: `backend/src/app.js`, `backend/src/validators.js`,
`backend/src/services/auth.js`, `backend/src/services/profile-photo.js`.

Pruebas: `backend/test/account-scenarios.js`, `backend/test/api.test.js`,
`backend/test/mysql.integration.js`, `backend/test/memory.js`,
`test/account_security_test.dart`, `test/redesign_test.dart`.

## Resultado final del 23/10/2026

| Verificación | Resultado |
| --- | --- |
| Flutter analyze del código final | Sin incidencias |
| Flutter test completo | 173 aprobadas; 2 pruebas específicas de dispositivo omitidas |
| Backend npm test | 95 aprobadas |
| MySQL aislado | 26 aprobadas |
| PNG generado por Flutter → validador backend | Válido |
| APK debug arm64 | Compilada correctamente en 260,3 s |
| Android `install -r` | Success; inicio Status ok |
| Android versión | 1.0.0, compilación 1; actualización 23/10/2026 12:52:11 |
| Comparación READ ONLY de identidades y datos financieros | Hashes idénticos antes y después de la revisión física |
| Rama | danny; sin commit, push ni merge |

Se inspeccionaron las capturas físicas de Inicio, Historial, Fiados, Reportes y
Perfil: el logo aparece completo. También se abrieron Mi constancia, Hablar con
Finki y Mis preguntas, que comparten la cabecera. Se revisaron información
personal, formulario de contraseña, fotografía, negocio activo, sincronización,
privacidad, ayuda, versión y cierre de sesión sin pulsar acciones de guardado.
La galería y la cámara reales se abrieron y cancelaron correctamente.

La sesión continúa siendo Danny / Bodega Finki Demo, con el avatar predeterminado
y los mismos identificadores. Inicio sigue mostrando ventas de hoy S/ 70.00;
Reportes conserva gastos S/ 12.00, compras S/ 80.00 y resultado -S/ 22.00; Fiados
mantiene S/ 10.00 pendiente. No se registraron movimientos nuevos ni se generó
otra constancia. No aparecieron excepciones no controladas ni desbordamientos
en los últimos 600 registros del proceso Android consultados.

Evidencias locales: `build/tooling/certificate-profile-*-final.png`,
`certificate-profile-gallery-picker.png`, `certificate-profile-camera-picker.png`,
`profile-flutter-tests.log`, `profile-backend-tests.log`,
`profile-mysql-tests.log` y comparación hash `profile-data-before.json`.

### Comprobaciones personales pendientes

El titular puede guardar su foto desde cámara/galería, ajustar el encuadre,
volver a entrar para comprobarla, probar la copia offline y eliminarla cuando
quiera. Puede cambiar su contraseña voluntariamente y comprobar el nuevo acceso.
Esas escrituras se probaron con identidades ficticias, y no se ejecutaron sobre
su cuenta durante la revisión física. La titularidad del correo sigue sin
verificación; no se ofrece recuperación de contraseña.
