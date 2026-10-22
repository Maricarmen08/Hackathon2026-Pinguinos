# Backend Express V1 — Pinguinos

## Estado de la entrega

Implementación real sobre el contrato físico de `database/migrations/001_initial_schema.sql`, sin modificar esa estructura. Runtime probado con Node **26.2.0** y npm **11.13.0**; requiere Node >=22.

- Servicios, validadores, repositorio MySQL y servidor HTTP implementados.
- Pruebas unitarias y HTTP usan servicios reales con un adaptador en memoria claramente separado.
- Integración MySQL preparada exclusivamente para `hackathon_pinguinos_test`; no se ejecuta desde npm test.
- Conexión real a MySQL 8.4 verificada con check:db; lecturas de 23 tablas, 5 vistas, paginación y reporte verificadas en transacción READ ONLY.
- La integración de escritura con InnoDB queda pendiente exclusivamente en la base aislada de pruebas; las pruebas HTTP usan un adaptador en memoria.
- No se escribieron datos de demostración ni se ejecutaron migraciones de desarrollo.
- IA, OCR, PDF y Flutter no implementados en esta etapa. El reporte de actividad es JSON, no un PDF.
- La V0.1 original se conserva en legacy/server-v0.1.cjs y public/. No se ejecuta ni se sirve desde V1: su autenticación/esquema son incompatibles e inseguros para esta base.

## Instalación y configuración local

Desde PowerShell:

```powershell
Set-Location 'D:\HACKATHON2026\Hackathon2026-Pinguinos\backend'
npm.cmd ci --ignore-scripts
npm.cmd run configure
```

configure crea backend/.env mediante escritura exclusiva (no sobrescribe archivos existentes), genera dos secretos independientes y no los imprime. Completar DB_USER/DB_PASSWORD localmente. La configuración Laragon autorizada usa root sin contraseña bajo la excepción local descrita abajo. Revisar permisos del archivo en Windows; no enviarlo por chat.

Variables: NODE_ENV, HOST, PORT, DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, JWT_SECRET, JWT_REFRESH_SECRET, CORS_ORIGINS. Ver .env.example.

- DB_NAME=hackathon_pinguinos_dev.
- Root o contraseña vacía solo se aceptan con NODE_ENV=development, HOST=127.0.0.1 y DB_HOST igual a 127.0.0.1, localhost o ::1. Se valida también la cuenta efectiva MySQL. Producción, test, conexiones remotas y escucha en otras interfaces los rechazan. Sin NODE_ENV explícito se asume production.
- JWT_SECRET y JWT_REFRESH_SECRET independientes, aleatorios, mínimo 43 caracteres; configure genera 48 bytes cada uno.
- CORS_ORIGINS: lista separada por comas de orígenes exactos. Flutter móvil no envía Origin y puede autenticarse. No admite comodín.
- HOST=127.0.0.1. La configuración root local no permite exposición LAN. Android Emulator puede usar http://10.0.2.2:3000/api/v1; para Android físico por USB usar adb reverse tcp:3000 tcp:3000 y http://127.0.0.1:3000/api/v1.
- Se lee SOLO backend/.env, no el .env raíz compartido con Flutter.
- No copiar secretos del backend a assets móviles.

## Usuario MySQL para despliegues posteriores (opcional ahora)

1. Conectar a la instancia Laragon con una cuenta administrativa conocida; comprobar VERSION(), @@port y la base.
2. Herramientas → Administrador de usuarios (nombre puede variar). Crear `pinguinos_app` para host `127.0.0.1`, contraseña nueva y fuerte, sin permisos globales.
3. Dar SELECT sobre `hackathon_pinguinos_dev`.
4. Dar INSERT solo en: usuarios, dispositivos, sesiones, negocios, membresias, sync_contadores, categorias, terceros, cuentas, operaciones, movimientos, aplicaciones, transferencias, comandos_procesados, cambios_sync, auditoria.
5. Dar UPDATE solo en: usuarios, dispositivos, sesiones, negocios, sync_contadores, operaciones, movimientos, transferencias.
6. No otorgar DELETE, DROP, ALTER, CREATE, CREATE ROUTINE, GRANT OPTION ni permisos sobre otras bases.
7. Guardar permisos, completar backend/.env y ejecutar check:db.

UPDATE sobre dispositivos permite el bloqueo FOR UPDATE usado para serializar rotación de sesiones. Catálogos se leen FOR SHARE, evitando conceder UPDATE innecesario. [Privilegios de locking reads MySQL](https://dev.mysql.com/doc/refman/8.4/en/innodb-locking-reads.html).

No se crea automáticamente otro usuario. Para Laragon local se autorizó expresamente root con contraseña vacía, sin cambiar la autenticación de comerciantes. El usuario bloqueado demo permanece bloqueado: registrar un comerciante nuevo por la API.

## Arranque

```powershell
npm.cmd run check:db
node scripts/check-readonly.js
npm.cmd start
# Desarrollo con recarga:
npm.cmd run dev
```

check:db solo cambia parámetros de sesión y consulta versión/cuenta/migraciones, sin DML de negocio. start valida conexión antes de escuchar. Si falla, no publica un servidor aparentemente conectado.

Salud: GET /api/v1/health/live y /api/v1/health/ready. No exponen nombres de usuario, claves ni versión del motor.

## Arquitectura

```text
server.js                 configuración, verificación DB y ciclo de vida
src/app.js                middleware HTTP y rutas /api/v1
src/config.js             variables locales validadas
src/validators.js         contratos Zod estrictos
src/domain.js             dinero, fechas, canonicalización
src/security.js           scrypt y JWT
src/errors.js             errores seguros y request_id
src/repositories/          allowlist física y pool mysql2/promise
src/services/auth.js       usuarios, dispositivos, sesiones y permisos
src/services/commands.js   transacción, recibo, secuencia, auditoría
src/services/financial.js  operaciones, cobros/pagos, transferencias y anulaciones
src/services/queries.js    historial, saldos, indicadores y snapshot
test/                     unitarias/HTTP e integración MySQL separada
scripts/                  configuración y diagnóstico local
legacy/ y public/         referencia V0.1 conservada, no expuesta por V1
```

Controladores HTTP pequeños viven en app.js; reglas de negocio en servicios. No se añadieron capas vacías.

## Finanzas, precisión e idempotencia

Ver docs/API.md para cuerpos exactos.

- Todos los importes JSON son cadenas de céntimos; no números ni decimales. Ejemplo: "10000" = S/100.
- BIGINT/DECIMAL del driver se mantienen como cadenas. Cálculos con BigInt, incluido promedio redondeado.
- UUID generados también por cliente offline. No inferir negocio/usuario/dispositivo por defaults.
- Fecha comercial YYYY-MM-DD; instantes de respuesta ISO UTC. La sesión MySQL usa +00:00.
- Cada comando bloquea el contador del negocio FOR UPDATE antes de escribir y revalida sesión/membresía.
- Verifica pendientes con operaciones y movimientos bloqueados. Abonos no crean ventas.
- Contado exige liquidación completa; crédito requiere tercero.
- Categoría, cuenta, tercero, fechas y pertenencia se validan además de los CHECK/FK.
- Cobro/pago distribuye todo su importe, sin exceder pendientes ni mezclar contrapartes.
- Transferencias crean cabecera y dos piernas en una transacción.
- Aportes/préstamos no son ventas; retiros/capital/inversión no son gastos operativos.
- La misma transacción guarda recibo command_id+hash, auditoría, evento y contador. Si falla, todo revierte.
- Reintento idéntico devuelve respuesta guardada (replayed=true). Otro contenido/actor produce 409.
- Se reintentan como máximo dos veces deadlocks/timeouts con la misma identidad de comando.
- La sesión limita la espera de bloqueos InnoDB a cinco segundos por intento.
- Una colisión concurrente en alta de negocio puede responder 409; reintentar el mismo command_id permite recuperar el recibo si el alta fue aceptada.
- No hay DELETE financiero. Anulación de contado revierte el conjunto de operación y movimientos exclusivamente vinculados; movimiento compartido requiere corrección conjunta. Crédito pagado exige anular primero cobros/pagos. Transferencia se anula completa.
- Anulación corrige errores de registro; no equivale a devolución real. Notas de crédito/devoluciones/anticipos quedan pendientes.
- Saldos negativos registrados no se ocultan ni se convierten en ventas.

## Autenticación y seguridad

Scrypt nativo, N=131072,r=8,p=1, sal aleatoria de 16 bytes, clave derivada de 64 bytes y comparación constante. Máximo dos derivaciones concurrentes por proceso. Formato definido:
`$scrypt$N=131072,r=8,p=1$<sal_hex>$<derivado_hex>`.
Compatible con el CHECK aprobado. No admite hashes Argon2 ya existentes sin añadir su verificador. [Parámetros recomendados por OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html).

JWT HS256 con issuer/audience/type verificados; access 15 minutos y refresh 30 días, secretos separados. Hash SHA256 del refresh en sesiones. Rotación revoca sesión anterior; reuso revoca su familia y exige login. Tokens revocados se comprueban contra MySQL en cada request; no esperar solo a expiración JWT.

Roles: PROPIETARIO puede administrar catálogos/cuentas/perfil y anular; OPERADOR registra terceros y actividad operativa; LECTOR solo consulta. Creación de membresía propietario implementada; invitaciones/cambios de roles no se exponen todavía.

Helmet, tamaño JSON 64 KiB, schemas strict, SQL parametrizado/allowlist, CORS exacto y rate limit de auth 10/minuto/IP. trust proxy=false: no confiar en X-Forwarded-For enviado por cliente. Ajustar solo al desplegar tras proxy confiable. Logs sin cuerpos, contraseñas, tokens o error SQL crudo.

Producción exige HTTPS, política de retención/backups y rate limiter compartido si hay varios procesos; el store en memoria del limitador no coordina réplicas.

## Pruebas

```powershell
npm.cmd test
npm.cmd run test:mysql
```

npm test no lee .env ni conecta MySQL: crea HTTP real en loopback con servicios reales y MemoryDatabase de test. Sus verificaciones de concurrencia/rollback NO certifican InnoDB. El INTERNAL_ERROR registrado durante el escenario de fallo tardío es intencional; se comprueba que el cliente no recibe detalles y no queda escritura.

test:mysql se omite por defecto y solo acepta NODE_ENV=test, DB_NAME=hackathon_pinguinos_test y RUN_MYSQL_TESTS=1. Nunca cae a la base de desarrollo. Ver docs/TESTING.md para preparación aislada.

## Indicadores y límites

Reporte JSON sobre snapshot consistente: ventas, compras, gastos, cobros/pagos, flujo, pendientes al corte, saldos y promedio de meses completos incluyendo ceros. No unir ventas con abonos para sumar ingresos.

Sin inventario, el resultado simplificado no es utilidad contable. Regularidad disponible como días con ventas y cobertura declarada, sin inferir estabilidad crediticia. Los datos pendientes en Flutter no se incluyen hasta sincronizar.

La implementación V1 carga el historial del negocio en memoria para agregación/snapshot; limitar ventanas (máximo 120 meses) y migrar agregaciones a SQL/paginación de snapshot antes de grandes volúmenes. Listados de historial sí tienen paginación. No es un motor analítico para millones de filas.

## Errores frecuentes

- Configuración incompleta: ejecutar configure y completar archivo privado; no copiar claves aquí.
- ECONNREFUSED/ETIMEDOUT: revisar MySQL Laragon/puerto/red.
- ER_ACCESS_DENIED_ERROR: revisar usuario específico, contraseña y host de cuenta.
- ER_DBACCESS_DENIED_ERROR: permisos de base.
- Migraciones ausentes: seleccionar la base V1 correcta; no ejecutar schema.sql legado.
- 401: token inválido, expirado, sesión revocada o usuario bloqueado.
- 403: negocio/rol/origen no permitido.
- 409: duplicado, versión obsoleta, sobreabono o conflicto idempotente.
- 422: contrato/importe/fecha/categoría inválidos.
- 429: límite de autenticación.
- 503: DB o recursos de autenticación temporalmente no disponibles; mismo command_id al reintentar.

## Flutter posterior

Guardar tokens en almacenamiento seguro, usar UUID de cliente y céntimos como cadenas. Obtener dispositivo_id del login y enviarlo en cada comando. Tratar 201 aceptado/200 replay como confirmación, conservar conflictos 409 y errores offline. Snapshot inicial + cambios por seq; no descargar sesiones/usuarios/secretos. El cliente local y Drift permanecen pendientes.
