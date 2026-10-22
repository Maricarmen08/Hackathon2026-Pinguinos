# Pruebas backend V1

## Actualización V3 — 22/10/2026

La sección V1 siguiente conserva el historial de entrega. Estado actual: `npm test` 33 aprobadas y MySQL aislado 19 aprobadas, cero fallos. Se prepararon `_test` y su usuario exclusivo con autorización; ya se retiraron permisos DDL. No repetir el bootstrap sobre esa base existente. Se añadieron constancia PDF real/snapshot/hash, categoría opcional, efectivo predeterminado, consultas autorizadas, consentimiento/bloqueo del proveedor, confirmación de propuestas, imagen privada y duplicados/vínculo sin repetir ventas. Los ensayos de proveedor son dobles explícitos; OpenAI permanece desactivado por decisión del usuario. Ver `../../docs/FINKI_V3_PROGRESS.md` para límites físicos y comandos actuales.

## Ejecutadas durante esta entrega

- node --check: archivos JavaScript de runtime/scripts/tests.
- npm test: servidor HTTP real en 127.0.0.1, servicios reales, repositorio exclusivamente en memoria.
- Última ejecución completa: **18 pruebas aprobadas, cero fallos**; incluye prueba HTTP y sus subcasos más pruebas puras/middleware.
- npm audit --omit=dev: cero vulnerabilidades informadas en ese momento; no garantía permanente.
- Intento de arranque normal y check:db: rechazados por configuración DB/JWT incompleta.
- test:mysql: SKIP, no una prueba aprobada.
- Puerto 3306 local: conexión TCP disponible, sin autenticar ni ejecutar SQL.

Las pruebas HTTP iniciales necesitaron permiso de loopback del entorno; EACCES de sandbox no se trató como fallo de MySQL. Se repitieron con acceso local autorizado.

## Qué prueba npm test

Registro/login correcto e incorrecto, usuario bloqueado, hashes no expuestos, sesión, refresh rotativo/reuso/logout, negocio propio/ajeno, roles de lector, catálogos, fiado 100→abono40→saldo60→liquidación, contado, compras/gastos/pagos, transferencia/aporte/retiro, conflicto idempotente, rollback de escritura intermedia y fallo tardío de auditoría, dos cobros concurrentes, anulaciones, snapshot y cambios, versión de perfil.

Pruebas puras: exactitud monetaria, fechas/normalización, rechazo de campos desconocidos, canonicalización, JWT manipulado, SQL parametrizado y allowlist, promedio con meses cero y corte histórico.

Middleware HTTP: cabeceras, CORS, 64KiB y 429 de autenticación.

MemoryDatabase NO emula FK/CHECK, driver, privilegios, aislamiento ni bloqueos MySQL. Su cola transaccional solo permite comprobar lógica/atomicidad del servicio con un doble de repositorio. El resultado no certifica InnoDB ni rendimiento.

El log INTERNAL_ERROR del ensayo de fallo tardío es deliberado: respuesta segura y ausencia de escrituras tras rollback.

## Integración real aislada: preparación posterior, explícita

No usar hackathon_pinguinos_dev ni importar semillas. Los escenarios crean datos de ensayo que quedan SOLO en hackathon_pinguinos_test para inspección. No se borran automáticamente; el repositorio de pruebas no contiene DELETE/DROP.

1. En HeidiSQL con un administrador, crear una base NUEVA vacía:
```sql
CREATE DATABASE hackathon_pinguinos_test CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
```
Si existe, inspeccionarla; no reemplazarla. El bootstrap rechaza cualquier base no vacía.

2. Crear usuario no root exclusivo para esa base. Para preparar el esquema necesitará temporalmente CREATE, CREATE VIEW, REFERENCES, SELECT, INSERT y UPDATE sobre esa base únicamente. Después retirar permisos DDL y dejar DML necesarios para el ensayo. No dar acceso a desarrollo.

3. Generar archivo privado separado:
```powershell
npm.cmd run configure -- --test
```
Completar DB_USER/DB_PASSWORD en backend/.env.test. Mantener NODE_ENV=test y DB_NAME=hackathon_pinguinos_test.

4. Solo tras autorización para ESCRIBIR en la base aislada:
```powershell
$env:ALLOW_TEST_SCHEMA_SETUP='YES'
node test/setup-test-db.js
Remove-Item Env:ALLOW_TEST_SCHEMA_SETUP
```

Este bootstrap lee los DDL CREATE TABLE/VIEW de las migraciones aprobadas sin modificarlas y los aplica a la conexión de pruebas. No ejecuta sus procedimientos calificados a desarrollo. Verifica 23 tablas y cinco vistas esperadas; registra versiones 001/002 sin demo. DDL hace commit implícito: si falla parcialmente, detenerse y revisar; no reintentar ni borrar automáticamente.

5. Activar expresamente la integración:
```powershell
$env:RUN_MYSQL_TESTS='1'
npm.cmd run test:mysql
Remove-Item Env:RUN_MYSQL_TESTS
```

El test exige nombre exacto y modo test antes de crear Database. También verifica versión/migraciones. Cada ejecución usa UUID/nombres/teléfonos sintéticos nuevos; repetir no reinicializa tablas.

Esta suite usa el MISMO contrato de escenarios HTTP con repositorio MySQL real. Prueba concurrencia desde dos requests, rechazo de sobreabono, rollback de una operación insertada cuyo pago falla, transacciones e indicadores. El fallo tardío artificial de auditoría es solo unitario.

En .env.test, RUN_MYSQL_TESTS=0 por defecto. Si variable del shell es 1, prima sobre el archivo. No ejecutar integración desde la cuenta de producción.

## Pendiente

Credenciales específicas, preparación aislada y ejecución MySQL. Hasta entonces no afirmar que SQL/privilegios/pool estén verificados en una instancia real. Mantener el PASS de la suite SQL V2 anterior como evidencia de base de datos proporcionada por el usuario, no como resultado de estos servicios nuevos.
