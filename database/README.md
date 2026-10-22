# Base de datos FINKI

## Instalación oficial: un solo archivo

**Para instalar FINKI importa únicamente `hackathon_pinguinos_dev.sql`.** Crea la base
`hackathon_pinguinos_dev` vacía con la estructura final: 23 tablas (21 de producto + 2 de
control), 5 vistas, 58 claves foráneas y 108 restricciones CHECK, y registra las
versiones 001 y 002 en `schema_migraciones`, que el backend comprueba al iniciar.
No contiene usuarios, contraseñas, sesiones, negocios ni datos financieros.
Guía paso a paso: [`docs/INSTALACION_EQUIPO_FINKI.md`](../docs/INSTALACION_EQUIPO_FINKI.md).

- Se generó copiando, sin cambios, el DDL de `migrations/001_initial_schema.sql` y
  `migrations/002_reporting_views.sql`, sin sus procedimientos instaladores
  (`dbv1_aplicar_001/002`), que Express no usa.
- `CREATE DATABASE` sin `IF NOT EXISTS`: si la base ya existe se detiene con el error
  1007 y no toca nada. No contiene DROP, DELETE ni TRUNCATE.
- Las sentencias son ASCII: el resultado no depende de la codificación del cliente.
- Validación reproducible: `.\tool\finki-verify-install.ps1` (o `npm run verify:install`
  en `backend/`) crea `hackathon_pinguinos_install_check`, compara su estructura con
  `hackathon_pinguinos_dev` solo lectura y ejecuta el recorrido real de la API.

### Qué hacer con los demás SQL

| Archivo | Estado | Motivo |
|---|---|---|
| `hackathon_pinguinos_dev.sql` | **Oficial de instalación** | Único archivo a importar |
| `migrations/001`, `002` | Conservados, históricos | Fuente del SQL único; `backend/test/setup-test-db.js` los lee para la base `_test`; base de futuras migraciones 003+. No editar. |
| `seeds/001_demo_data.sql` | Conservado, opcional | Datos ficticios; no forma parte de la instalación |
| `tests/*.sql`, `queries/*.sql` | Conservados | Mantenimiento e inspección de solo lectura |
| `schema.sql` | Conservado, **no importar** | V0.1 con `DROP TABLE`; candidato a mover a `database/legacy/` con autorización |

### Cambios futuros de estructura

1. Crear `migrations/003_<nombre>.sql` aditivo para las bases ya instaladas.
2. Regenerar `hackathon_pinguinos_dev.sql` para que incluya ese cambio y su fila en
   `schema_migraciones`.
3. Ejecutar `.\tool\finki-verify-install.ps1`: la comparación debe salir idéntica.

---

# Historial técnico V1 (instalación por migraciones)

## Estado y límites de esta entrega

Archivos preparados para MySQL **8.4.3**, InnoDB y HeidiSQL. El usuario confirmó instalación de 23 tablas, cinco vistas, migraciones 001/002 y demo, además de verificaciones de metadatos/demo/consistencia satisfactorias. Codex no ejecutó esos SQL. La suite de integridad V2 se entrega corregida y revisada estáticamente, **sin instalar ni ejecutar**; requiere autorización posterior. No se conoce ni se presupone ninguna contraseña local.

La V1 contiene **21 tablas de producto + 2 de control de instalación = 23 tablas**, cinco vistas y dos rutinas de instalación. Semillas y pruebas agregan su propia rutina solo si se importan.

**NO IMPORTAR `database/schema.sql`: es la V0.1 heredada y contiene DROP TABLE. Se conserva sin cambios para proteger el trabajo anterior.** La V1 no lo invoca.

## Árbol y orden

- `migrations/001_initial_schema.sql`: tablas, claves, checks y registro de migración.
- `migrations/002_reporting_views.sql`: cinco vistas de consulta y registro de migración.
- `seeds/001_demo_data.sql`: datos sintéticos opcionales, separados del esquema.
- `tests/metadata_validation.sql`: consultas de metadatos, solo lectura.
- `tests/demo_verification.sql`: consultas de la demo, solo lectura.
- `tests/consistency_checks.sql`: detectores de invariantes, solo lectura.
- `tests/README.md`: guía de la suite V2 y permisos/precondiciones.
- `tests/00_preflight_integrity_v2.sql`: inspección previa, sin escrituras de tablas.
- `tests/01_install_integrity_suite_v2.sql`: instalación de una rutina versionada; sin ejecutar pruebas.
- `tests/02_run_integrity_suite_v2.sql`: ejecución sin DDL; datos de ensayo con ROLLBACK verificado.
- `tests/integrity_tests.sql`: aviso obsoleto, no instala ni ejecuta pruebas.
- `queries/financial_reports.sql`: ejemplos de indicadores, pendientes al corte y promedio de meses completos; solo lectura de tablas.
- `docs/DATA_DICTIONARY.md`: columnas, relaciones, restricciones e índices.
- `docs/BUSINESS_RULES.md`: obligaciones del backend, idempotencia y sincronización.
- `docs/REPORTING.md`: fórmulas e indicadores.
- `docs/TEST_PLAN.md`: cobertura real y pruebas pendientes.
- `CHECKSUMS.sha256`: huellas de los scripts SQL entregados.
- `schema.sql`: legado, excluido de la instalación V1.

## Antes de importar: Laragon y HeidiSQL

Estos son pasos para una ejecución POSTERIOR autorizada, no un reporte de acciones ya realizadas.

1. Abrir Laragon desde `D:\laragon\laragon`. Revisar que use MySQL 8.4.3 y el puerto configurado.
2. Si MySQL está detenido, iniciarlo desde Laragon cuando se autorice. No es necesario iniciar Apache/Nginx.
3. Abrir HeidiSQL desde Laragon (menú de base de datos) o desde su instalación.
4. Crear una sesión MySQL TCP/IP con host `127.0.0.1`, puerto observado (previsto 3306) y usuario/contraseña que el equipo conozca. No asumir contraseña vacía ni reutilizar credenciales en Git.
5. Conectarse y ejecutar únicamente esta inspección:

```sql
SELECT VERSION(), @@port, CURRENT_USER(), DATABASE();
SHOW DATABASES LIKE 'hackathon_pinguinos_dev';
```

La versión debe comenzar por `8.4.`. El cliente instalado no demuestra la versión del servidor conectado.

Si la base existe, inspeccionar antes de cualquier escritura:

```sql
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema='hackathon_pinguinos_dev';
SELECT routine_name
FROM information_schema.routines
WHERE routine_schema='hackathon_pinguinos_dev';
```

**Si hay tablas, no aplicar 001 sobre ellas. No borrar, renombrar ni recrear datos automáticamente.** La conversión de V0.1 requiere una migración de datos aparte y autorización.

## Crear la base nueva

Solo tras comprobar que no existe y contar con autorización:

```sql
CREATE DATABASE hackathon_pinguinos_dev
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
```

No se usa IF NOT EXISTS para evitar confundir una base preexistente con una instalación nueva. El error 1007 exige detenerse e inspeccionar.

En HeidiSQL, actualizar el árbol y seleccionar la base nueva.

## Importar estructura y vistas, exactamente en este orden

1. Abrir `migrations/001_initial_schema.sql` mediante **Archivo → Cargar archivo SQL** (el nombre puede variar según versión).
2. Revisar que aparece `USE hackathon_pinguinos_dev`.
3. Ejecutar **el archivo completo**, incluyendo DELIMITER, CREATE PROCEDURE y CALL. No ejecutar solo el fragmento seleccionado ni importar en modo CSV.
4. Configurar/dar la orden de detenerse al primer error. **No continuar ni ignorar errores.**
5. Verificar `SELECT * FROM hackathon_pinguinos_dev.schema_migraciones;`: debe existir versión 1.
6. Cargar y ejecutar completo `migrations/002_reporting_views.sql`.
7. Verificar versiones 1 y 2 y abrir `tests/metadata_validation.sql`.
8. Esperar **23 BASE TABLE**, **5 VIEW**, 58 claves foráneas y 108 CHECK en la entrega actual. Los índices secundarios declarados son 48; MySQL puede añadir otros para soportar FK.

Las rutinas se califican con el nombre de la base: si USE falla, no pueden crearse accidentalmente en otra base. No contienen SQL dinámico ni nombres de base recibidos del usuario. Solo el operador de instalación necesita CREATE ROUTINE/EXECUTE/CREATE VIEW y permisos DDL.

### Repeticiones, fallos y migraciones futuras

- `schema_migraciones` registra una versión únicamente al completar su migración.
- La 001 requiere base sin tablas/vistas. La 002 requiere versión 1 y ausencia de versión 2 o posterior.
- Un bloqueo nombrado serializa estas migraciones.
- Los procedimientos permanecen instalados. Reimportar el mismo archivo falla en CREATE PROCEDURE; detenerse. Si alguien continúa, los guards de CALL también impiden reaplicar.
- Si se creó la rutina pero no se ejecutó CALL, un operador puede revisar y ejecutar el CALL correspondiente. Si hubo DDL parcial, **no hacerlo a ciegas**.
- DDL MySQL hace commit implícito. El instalador completo no es una transacción reversible: un error puede dejar tablas/vistas parciales aunque falte la fila de versión.
- Ante fallo parcial, conservar la base, capturar el error, revisar information_schema y preparar reparación aditiva revisada. No ejecutar DROP ni editar la migración aplicada.
- Futuros cambios: 003, 004, etc., guard de versión previa exacta, comprobaciones de precondiciones, SQL aditivo y versión registrada al final. Nunca cambiar 001/002 ya aplicadas.
- `CHECKSUMS.sha256` permite comparar archivos aprobados. No sustituye un runner de migraciones ni valida por sí solo el estado de la base. El runner con verificación de hash queda para integración.
- Las tablas de control son metadatos de instalación, no datos que sincroniza Flutter.

Referencia: [commit implícito MySQL](https://dev.mysql.com/doc/refman/8.4/en/implicit-commit.html).

## Importar datos ficticios

Opcional, después de 002, en esta base nueva sin usuarios/negocios:

1. Cargar completo `seeds/001_demo_data.sql`.
2. Ejecutar y revisar que no hubo errores; sus DML van en una transacción.
3. Verificar `schema_semillas`, versión 1.
4. Ejecutar `tests/demo_verification.sql`.

Los UUID son fijos para revisión; no usar estos datos en producción. El correo usa el dominio reservado `example.invalid` y los teléfonos son marcadores deliberadamente no reales.

**No hay contraseña demo.** El usuario está BLOQUEADO con hash NULL y no puede iniciar sesión. Es una excepción controlada al diseño previo: permite importar fixtures sin fabricar hashes ni añadir una biblioteca. Antes de habilitarlo, el futuro servicio deberá generar Argon2id (o scrypt con formato acordado), verificar el hash y activar al usuario en una acción explícita. No sustituir NULL por texto plano. Los CHECK reconocen el prefijo de hash; no prueban su validez criptográfica.

La evidencia demo está PENDIENTE: no se incluye una imagen real; bytes/hash son metadatos sintéticos señalados y no se deben marcar DISPONIBLE.

### Resultados esperados (no resultados ejecutados)

| Indicador | Céntimos | Soles |
|---|---:|---:|
| Ventas (50 contado + 100 fiado) | 15000 | 150 |
| Cobros (50 + abono 40) | 9000 | 90 |
| Compra proveedor | 8000 | 80 |
| Gasto operativo | 2000 | 20 |
| Pagos (20 servicio + 30 proveedor) | 5000 | 50 |
| Resultado simplificado | 5000 | 50 |
| Flujo operativo | 4000 | 40 |
| Por cobrar | 6000 | 60 |
| Por pagar | 5000 | 50 |
| Efectivo tras transferencia de 10 | 2000 | 20 |
| Billetera tras transferencia | 2000 | 20 |

La transferencia cambia la distribución de saldos; no ventas ni resultado.

## Consultar tablas, relaciones e índices

```sql
SHOW FULL TABLES FROM hackathon_pinguinos_dev;
SHOW CREATE TABLE hackathon_pinguinos_dev.operaciones;
SHOW INDEX FROM hackathon_pinguinos_dev.operaciones;
SELECT * FROM hackathon_pinguinos_dev.v_operaciones_saldos;
SELECT * FROM hackathon_pinguinos_dev.v_cuentas_saldos;
```

En HeidiSQL: seleccionar tabla → pestañas de columnas/índices/claves foráneas (según versión). Las relaciones de negocio llevan negocio_id y apuntan a una clave UNIQUE completa del padre. No desactivar FOREIGN_KEY_CHECKS.

## Pruebas

La guía vigente es [tests/README.md](tests/README.md). No usar el CALL antiguo de V1.

1. En conexión dedicada nueva, seleccionar manualmente la base de desarrollo y configurar UTC/modo estricto según la guía.
2. Revisar `00_preflight_integrity_v2.sql`; detenerse ante error, bandera 0 o colisiones.
3. Instalar una vez `01_install_integrity_suite_v2.sql` SOLO con autorización. CREATE PROCEDURE hace commit implícito y deja una rutina persistente. No reemplaza V1 ni una V2 existente.
4. Revisar la definición instalada y ejecutar `02_run_integrity_suite_v2.sql` SOLO con autorización. El runner no contiene DDL ni COMMIT y no llama V1.
5. PASS exige aserciones null-safe y ausencia de los UUID exactos en las 16 tablas afectadas después del ROLLBACK. Errores inesperados/advertencias abortan; no hay DELETE de limpieza.
6. Verificar demo y consistencia después. El rechazo de sobreabonos concurrentes y la idempotencia del servicio siguen pendientes del backend.

`integrity_tests.sql` ahora solo muestra un aviso de obsolescencia para impedir ejecutar accidentalmente su versión anterior. Ver `docs/TEST_PLAN.md` para cobertura y límites.

## Errores frecuentes

| Error | Acción |
|---|---|
| 2003 / conexión rechazada | Revisar Laragon, host, puerto y escucha; no crear otra instancia por defecto |
| 1045 / acceso denegado | Revisar credenciales/permisos sin publicarlos |
| 1049 / base inexistente | Revisar creación autorizada y nombre exacto |
| 1007 / base ya existe | Detenerse e inspeccionar; no borrar |
| 1304 / rutina ya existe | No reimportar; revisar versiones y ejecución previa |
| 1050 / tabla existe | Posible instalación parcial o destino incorrecto; detenerse |
| 1452 / FK | Padre inexistente o negocio distinto; revisar datos y orden |
| 1062 / duplicado | ID, comando o clave natural repetida; no usar INSERT IGNORE como solución |
| 3819 / CHECK | Revisar importe, estado, motivo o campos requeridos |
| 3780 / FK incompatible | Posible esquema divergente: comparar tipos y collation |
| 1064 / sintaxis | Confirmar MySQL 8.4 y ejecución completa con DELIMITER |
| 1142 / permisos | Usar cuenta de instalación autorizada, no ampliar permisos globalmente |
| 45000 / guard | Leer el mensaje; no quitar la protección |

## Usuario MySQL para Express (etapa posterior)

Preparar mediante el administrador de usuarios de HeidiSQL una cuenta exclusiva, por ejemplo `pinguinos_app`@`127.0.0.1`, con contraseña nueva y fuerte guardada solo en configuración privada del backend.

Permisos orientativos por tabla:
- SELECT/INSERT/UPDATE para identidad y catálogos según casos de uso.
- SELECT/INSERT para aplicaciones, comandos, cambios y auditoría; sin UPDATE/DELETE si son inmutables.
- SELECT/INSERT/UPDATE para operaciones/movimientos/transferencias, con anulaciones controladas.
- SELECT para vistas y schema_migraciones.
- SELECT/UPDATE para sync_contadores; INSERT únicamente para alta de negocio si lo necesita.
- Sin DROP, ALTER, CREATE, GRANT, DELETE ni EXECUTE de instaladores/pruebas.

El usuario de migraciones es distinto. No conceder permisos globales ni usar root desde Express. MySQL no aísla filas de negocios automáticamente: la API debe filtrar y autorizar; las FK compuestas evitan enlaces cruzados pero no consultas indebidas.

## Integración posterior

La V0.1 NO es compatible directamente con estas tablas: no apuntar server.js a esta base antes de migrar sus servicios. No ejecutar schema.sql para resolver errores de nombres.

- Separar DB_HOST/DB_PORT/DB_DATABASE/DB_USERNAME/DB_PASSWORD de configuración móvil pública.
- mysql2: `supportBigNumbers: true`, `bigNumberStrings: true`, fechas sin conversión ambigua y sesión UTC. JSON con dinero como cadena.
- UUID canónicos generados offline; backend valida formato hexadecimal y normaliza minúsculas. SQL comprueba estructura básica de UUID en PK, no versión/entropía.
- Sesiones, roles y hashes mediante servicios reales; nunca SELECT * de usuario hacia cliente.
- Un mismo servicio de comandos para escritura online y sincronización.
- Reemplazar TransactionModel por Operacion, Movimiento, Aplicacion y Cuenta.
- Reemplazar DatabaseService por repositorios local/remoto sin fallback ficticio.
- Implementar SQLite/Drift, outbox y archivos locales en otra etapa.
- Implementar reportes, IA y uploads; las tablas no ejecutan esas funcionalidades.
- Los endpoints actuales /transacciones, /login y /negocio deben evolucionar al contrato /api/v1 autenticado documentado en BUSINESS_RULES.
