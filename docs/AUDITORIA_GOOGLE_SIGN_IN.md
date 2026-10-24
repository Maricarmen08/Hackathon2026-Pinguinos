# Auditoría final de Google Sign-In — 24/10/2026

## Resultado y alcance

Implementación local en la rama `danny`. El usuario confirmó manualmente Android
y Web: registro sin teléfono/contraseña, creación de negocio, perfil, salida y
regreso con la misma cuenta al negocio existente. Esta evidencia manual pertenece
al entorno local; no demuestra que Render esté desplegado o validado.

No se ejecutaron migraciones, autenticaciones de ensayo ni escrituras en la base
habitual durante esta auditoría. Las pruebas usan memoria y respuestas HTTP
ficticias. No se modifican los servicios financieros ni `backend/web_build`.

## Correcciones finales

- Perfil muestra `Acceso con Google` cuando la respuesta autenticada indica
  `tiene_clave=false`. La página informa cómo entrar y no ofrece formulario de
  contraseña. El indicador actual del perfil prevalece sobre el caché de sesión.
- Express rechaza explícitamente cambiar/establecer contraseña cuando no existe
  hash previo (`PASSWORD_NOT_AVAILABLE`). No hay flujo de alta de contraseña por
  Google ni se simula una contraseña anterior.
- Se mantiene el cambio de contraseña tradicional, incluido para cuentas con
  Google vinculado que sí tienen contraseña.
- La validación de `iat` exige entero positivo y mantiene su límite futuro.
- Se conserva el nonce nuevo por intento Android, con una instancia nueva del
  adaptador oficial inicializada una sola vez; no se reinicializa el singleton.

## Controles comprobados

- Biblioteca oficial verifica firma, audiencia configurada, emisor y expiración;
  se comprueban nonce, email verificado, sub e iat. Prueba RSA con claves efímeras.
- Watermark persistente bajo bloqueo rechaza emisión igual/anterior. No se
  guardan tokens Google. La comparación estricta puede rechazar intentos en el
  mismo segundo; el siguiente intento obtiene otro nonce.
- Identidad por `(GOOGLE, sub)`, sin fusionar por correo. Uniques y transacciones
  protegen de duplicados/usuarios huérfanos y concurrencia.
- Vincular exige sesión FINKI, contraseña actual y token Google verificado;
  se prueban contraseña incorrecta, correo coincidente e identidades de otra
  cuenta. No existe endpoint/UI para desvincular o eliminar el único acceso.
- Registro tradicional, teléfono/correo, credenciales inválidas, refresh rotativo,
  logout y revocación siguen cubiertos. Recuperar sesión significa renovar la
  sesión existente; no se ha añadido recuperación de contraseña por correo.
- Android usa el ID Web como serverClientId y la asociación paquete/SHA-1 del
  cliente Android. Web solo recibe GOOGLE_WEB_CLIENT_ID: no pasar serverClientId
  Android al SDK Web. Usar el botón Web oficial.
- Configuración privada distinta para Android y Web; nunca publicar los archivos
  locales ni generar una versión de producción con API localhost.

## Validación automática

- Backend: 129 pruebas aprobadas.
- Flutter: 214 pruebas aprobadas; 2 omitidas preexistentes.
- Flutter analyze: sin observaciones.
- Revisión de secretos en archivos candidatos y de correo/sub reales de Google:
  sin coincidencias. Es una revisión acotada a cambios actuales, no una auditoría
  forense de todo el historial Git.
- Base local consultada en modo lectura: migraciones 001/002/003, 24 tablas,
  5 vistas, cero identidades huérfanas. No se repite la migración 003.

En la preparación de publicación se repitieron y aprobaron las compilaciones
debug Android/Web con los fuentes finales, después de los ajustes de Perfil.
No se reinstaló Android ni se afirma haber probado manualmente esas etiquetas
nuevas. Las pruebas reales anteriores de Google fueron confirmadas por el usuario.

## Exclusiones obligatorias

Mantener ignorados `.env`, `.env.test`, `.env.google.local`, `private/` (JSON OAuth,
lanzadores y perfil Chrome), `backend/private/`, `build/`, `output/`, PDFs,
fotografías, capturas, dumps y bases locales. Las plantillas `.env.example` son
publicables, sin valores reales. Client IDs son públicos, pero se suministran
desde configuración de despliegue; no son Client Secrets. No se necesitan claves
de servicio ni Firebase para esta integración.

Los backups y verificaciones con datos reales se conservan fuera del repositorio.
Logs y capturas de desarrollo permanecen en rutas ignoradas. No habilitar logs
de cuerpo HTTP, Authorization, ID tokens ni refresh tokens.

## Pendientes previos de producción

1. npm audit mantiene dos alertas altas preexistentes: body-parser 1.20.8 y zod
   3.25.76. La solución propuesta para Zod es un cambio mayor. No se ejecutó
   npm audit fix ni actualizaciones fuera del alcance de Google.
2. La conexión MySQL remota ya utilizaba `ssl.rejectUnauthorized=false` en HEAD.
   Antes del despliegue, coordinar validación de certificado/CA con el proveedor
   y probarla en staging. No se ha cambiado TLS de producción ni sus secretos.

Google funciona localmente y está preparado para revisión e integración; estos
pendientes impiden declarar una aprobación de seguridad completa para producción.

## Despliegue coordinado de Render y MySQL (NO ejecutado)

1. La responsable confirma host/esquema de producción, MySQL 8.4, versiones 001 y
   002 y ausencia de 003/aplicación parcial. No reutilizar una conexión local ni
   asumir que la base de las compañeras coincide. Revisar los pendientes previos.
   Debe ser cero antes de migrar (solo lectura):

```sql
SELECT COUNT(*) AS incompatibles
FROM usuarios
WHERE estado <> 'BLOQUEADO'
  AND (telefono_normalizado IS NULL OR password_hash IS NULL);
```

Si no es cero, detenerse y revisar con la responsable; no inventar credenciales.
2. Acordar mantenimiento y detener escrituras de todos los backends que usen ese
   esquema. Mantener Google desactivado. Obtener respaldo completo privado con
   mysqldump (tablas, datos, vistas, rutinas, triggers y eventos) y comprobar su
   restauración en una base nueva aislada. Usar TLS verificado donde corresponda.
3. Instalar el backend compatible con Google aún desactivado
   (`GOOGLE_AUTH_ENABLED=0`); conservar JWT, permisos, datos y configuración real.
4. Desde la raíz del checkout revisado, ejecutar UNA vez con cliente MySQL conectado
   explícitamente al esquema correcto:

```powershell
mysql.exe --host=HOST_CONFIRMADO --user=USUARIO_AUTORIZADO --password `
  --database=BASE_CONFIRMADA `
  --execute="SOURCE database/migrations/003_google_identity.sql"
```

No usar `--force`, no reimportar el SQL único, no repetir tras error. DDL confirma
implícitamente: detenerse e inspeccionar el estado parcial. No prometer rollback
del archivo. El respaldo se restaura primero en otra base, nunca sobre datos
originales sin un procedimiento expresamente aprobado.

5. Verificar versiones 1/2/3, 24 tablas/5 vistas, columnas/constraints de usuarios,
   identidades vacías inicialmente, ausencia de huérfanos y conservación de filas
   anteriores. Comprobar registro/acceso tradicionales con datos de ensayo en
   staging; no insertar pruebas en negocios ajenos.
6. Render: configurar `GOOGLE_CLIENT_IDS` con las audiencias Web autorizadas y
   solo entonces `GOOGLE_AUTH_ENABLED=1`. Mantener los secretos existentes. Usar
   `npm ci` y Node compatible con engines. Verificar health y migración al arrancar.
7. Google Cloud: origen HTTPS real del frontend, CORS restringido al frontend y
   clientes Android por paquete/certificado real de distribución. No asumir que
   el certificado debug equivale al futuro de Play App Signing.
8. Compilar el cliente Web con ID público y URL HTTPS de producción; NO usar
   los JSON privados locales ni GOOGLE_SERVER_CLIENT_ID en Web:

```powershell
flutter build web --release `
  --dart-define=GOOGLE_WEB_CLIENT_ID=ID_WEB_PUBLICO `
  --dart-define=API_BASE_URL=https://hackathon2026-pinguinos.onrender.com/api/v1
```

Publicar el artefacto en `backend/web_build` únicamente mediante el procedimiento
autorizado del equipo. La auditoría no lo reemplaza ni despliega. Android usa
GOOGLE_SERVER_CLIENT_ID=ID_WEB_PUBLICO y la URL HTTPS productiva. Probar Google
nuevo/existente, logout/regreso, vinculación y acceso tradicional en staging antes
de abrir a usuarios. No retirar Google ni volver a un backend incompatible si ya
existen cuentas sin contraseña: requiere plan de compatibilidad, no borrar cuentas.

## Inventario publicable

Se adjunta al final el inventario exacto de candidatos actual. No ejecutar git add,
commit, push o merge hasta que el usuario revise y autorice.

Total: 36 archivos candidatos (sin staging ni publicación).

- `backend/.env.example`
- `backend/package-lock.json`
- `backend/package.json`
- `backend/scripts/verify-install.js`
- `backend/src/app.js`
- `backend/src/config.js`
- `backend/src/errors.js`
- `backend/src/repositories/database.js`
- `backend/src/repositories/tables.js`
- `backend/src/services/auth.js`
- `backend/src/services/google-auth.js`
- `backend/src/validators.js`
- `backend/test/google-auth.test.js`
- `backend/test/google-schema.integration.js`
- `backend/test/memory.js`
- `backend/test/setup-test-db.js`
- `database/CHECKSUMS.sha256`
- `database/README.md`
- `database/hackathon_pinguinos_dev.sql`
- `database/migrations/003_google_identity.sql`
- `docs/AUDITORIA_GOOGLE_SIGN_IN.md`
- `docs/GOOGLE_SIGN_IN_FINKI.md`
- `docs/INSTALACION_EQUIPO_FINKI.md`
- `lib/v1/account_security_page.dart`
- `lib/v1/api_client.dart`
- `lib/v1/app.dart`
- `lib/v1/google_access.dart`
- `lib/v1/google_android_access.dart`
- `lib/v1/google_button_stub.dart`
- `lib/v1/google_button_web.dart`
- `lib/v1/profile_edit_page.dart`
- `pubspec.lock`
- `pubspec.yaml`
- `test/account_security_test.dart`
- `test/google_access_test.dart`
- `test/google_android_access_test.dart`
