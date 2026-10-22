# Suite de integridad MySQL V2 — ejecución controlada

## Estado

Release inmutable **pinguinos-integrity:2.0.0**. Archivos preparados y revisados estáticamente; Codex NO ha ejecutado SQL, instalado la rutina ni accedido a MySQL para validarla.

El usuario confirmó previamente MySQL 8.4.3, 23 tablas, cinco vistas, migraciones 001/002, demo importada y verificaciones de metadatos/demo/consistencia satisfactorias. Es evidencia comunicada por el usuario; no es resultado de esta suite V2.

## Archivos y orden

| Archivo | Acción | Frecuencia |
|---|---|---|
| 00_preflight_integrity_v2.sql | Inspección de contexto, esquema y colisiones | Antes de instalar/ejecutar |
| 01_install_integrity_suite_v2.sql | CREATE de UNA rutina versionada; NO CALL | Una vez, tras autorización |
| 02_run_integrity_suite_v2.sql | Un único CALL; sin DDL ni COMMIT | Cada ejecución autorizada |
| integrity_tests.sql | Aviso de obsolescencia, sin pruebas ni escrituras | No utilizar como runner |
| metadata_validation.sql | Inspección de esquema | Según necesidad |
| demo_verification.sql | Revisión de resultados demo | Antes/después del ensayo |
| consistency_checks.sql | Detectores de invariantes consolidadas | Antes/después del ensayo |

No reinstalar migraciones, semillas, tablas ni vistas.

## Objeto persistente y protección de versión

Instalará únicamente:
`hackathon_pinguinos_dev.dbv1_test_integridad_v2_0_0`.

La rutina tiene SQL SECURITY INVOKER, tres parámetros y COMMENT `pinguinos-integrity:2.0.0`. El runner usa ese nombre y ese token explícitos. No llama a la antigua `dbv1_test_integridad`, que se deja intacta si existe.

CREATE no tiene OR REPLACE, DROP ni IF NOT EXISTS. Si ya existe V2, detenerse: no se sustituye ni se ejecuta automáticamente. Inspeccionar:

```sql
SHOW CREATE PROCEDURE hackathon_pinguinos_dev.dbv1_test_integridad_v2_0_0;
```

Comparar con el archivo aprobado y las huellas de database/CHECKSUMS.sha256. Nombre, comentario y token previenen la confusión accidental con V1; no son una firma criptográfica del código instalado. Una modificación futura de la suite requiere nueva versión, nombre y token, no editar silenciosamente una rutina publicada.

La instalación no modifica filas. El CREATE sí permanece y provoca commit implícito; el ROLLBACK del ensayo no lo elimina.

## Pasos exactos en HeidiSQL (solo después de autorización de ejecución)

1. Abrir una **conexión nueva y exclusiva** a la instancia local confirmada, con cuenta de pruebas/administración que pueda leer metadatos, tablas y vistas y ejecutar las escrituras de ensayo. La instalación requiere CREATE ROUTINE; ejecución requiere EXECUTE, SELECT, INSERT y UPDATE pertinentes. Para inspeccionar ausencia de triggers, usar una cuenta con visibilidad TRIGGER sobre las tablas (information_schema puede ocultarlos por privilegios).
2. Seleccionar manualmente `hackathon_pinguinos_dev` en el árbol. Los scripts de ejecución no hacen USE para ocultar una selección equivocada.
3. No tener transacciones pendientes, tareas de edición ni otra suite concurrente. Autocommit debe estar ya activo. **No activar autocommit sobre trabajo pendiente**, porque lo confirmaría; abrir otra conexión.
4. En esa conexión, configurar solo parámetros de sesión:
```sql
SET SESSION time_zone = '+00:00';
SET SESSION sql_mode = 'STRICT_ALL_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
```
5. Cargar completo `00_preflight_integrity_v2.sql` por Archivo → Cargar archivo SQL. Detenerse al primer error. Todas las banderas deben ser 1 y colisiones 0. Antes de instalar, que no aparezca la rutina V2 es normal. Si la conexión ya tiene una transacción, SET TRANSACTION sin SESSION falla con 1568 sin confirmarla.
6. Si V2 no está instalada y hay autorización, cargar completo `01_install_integrity_suite_v2.sql`, incluyendo DELIMITER. Ejecutar solo este archivo. No continuar si aparece un error. No seleccionar fragmentos ni usar importación CSV.
7. El instalador establece un modo estricto antes de CREATE y restaura el modo previo al terminar. Si falla y se detiene antes de restaurarlo, cerrar la conexión dedicada; no hay obligación de reutilizarla.
8. Revisar SHOW CREATE PROCEDURE y comentario. No aceptar simplemente una rutina de igual nombre procedente de otra fuente.
9. Preferiblemente abrir otra conexión nueva para ejecutar, repetir pasos 2–5 y cargar completo `02_run_integrity_suite_v2.sql`.
10. Debe aparecer **un resultado PASS de release 2.0.0**, únicamente después de verificar limpieza. Un error o aviso del archivo obsoleto no es PASS.
11. Ejecutar demo_verification.sql y consistency_checks.sql para comprobar que los resultados de demostración siguen iguales.

Equivalente exacto del runner:
```sql
CALL hackathon_pinguinos_dev.dbv1_test_integridad_v2_0_0(
  'pinguinos-integrity:2.0.0',
  DATABASE(),
  @@SESSION.sql_mode
);
```

No omitir parámetros, no llamar V1 y no ejecutar directamente los INSERT del instalador fuera de la rutina.

## Precondiciones automáticas antes del primer INSERT

- Token correcto y base del caller exactamente hackathon_pinguinos_dev. Se pasa DATABASE() como argumento porque dentro de una rutina calificada refleja el esquema de la rutina.
- Servidor versión 8.4.
- autocommit, foreign_key_checks y unique_checks ya en 1; no se cambian automáticamente.
- Sin transacción previa: SET TRANSACTION READ WRITE sin SESSION actúa como guard.
- Modo estricto tanto del caller como de la rutina almacenada.
- time_zone de la sesión +00:00.
- Nombre, comentario y seguridad INVOKER de la release coincidentes.
- Bloqueo nombrado exclusivo de la suite.
- Las 23 tablas esperadas existen y son InnoDB.
- Migraciones 001 y 002 registradas con sus nombres.
- Cinco vistas esperadas visibles.
- Los 108 CHECK esperados están presentes y ENFORCED=YES. MySQL 8.4 no usa la variable MariaDB check_constraint_checks.
- Sin triggers visibles no previstos.
- Cero colisiones de UUID en todas las tablas afectadas y del teléfono marcador del fixture.

Los metadatos exigen permisos de visibilidad adecuados. Las precondiciones no reemplazan verificar la identidad del servidor y usar una base de desarrollo: no distinguen una copia de producción renombrada maliciosamente.

## Fixtures y garantía de reversión

Prefijo completo UUID: `00000000-0000-4000-8000-`; sufijos de doce dígitos documentados abajo. El SQL contiene siempre UUID completos, nunca rangos ni LIKE para limpiar.

| Tabla | Sufijos decimales |
|---|---|
| usuarios | 900 |
| dispositivos | 901 |
| negocios | 910, 911 |
| membresias | 912, 913 |
| categorias | 920, 921 |
| terceros | 940 |
| cuentas | 930, 931, 932 |
| operaciones | 950, 951 |
| movimientos | 951, 960, 961, 964, 967, 968, 969 |
| aplicaciones | 962, 963, 965, 983 |
| transferencias | 966 |
| sync_contadores | negocio 910 |
| comandos_procesados | 970, 972 |
| auditoria | 971 |
| comprobantes | 980 |
| vinculos_comprobante | 981, 982, 983 |

Se comprueba ausencia por tabla ANTES de empezar y DESPUÉS del ROLLBACK normal. Incluye IDs de inserts rechazados: si alguna restricción dejara pasar una fila, tampoco se permite que quede persistida.

La transacción se marca como propia solo después de START TRANSACTION. El handler exterior revierte exclusivamente esa transacción. No hace ROLLBACK del caller si falla una precondición. Tras error durante ensayo también comprueba ausencia antes de propagar el error original; fallos de reversión/limpieza generan error crítico. No existe DELETE de limpieza.

El sobreabono de un céntimo usa SAVEPOINT; se comprueba ausencia de sus dos filas y pendiente cero tras ROLLBACK TO SAVEPOINT. Luego el ROLLBACK final revierte el resto.

PASS exige todas las aserciones y cero fixtures en las 16 tablas. No se afirma probar reversión solo porque exista una sentencia ROLLBACK.

Límites:
- Se basa en InnoDB, ausencia de efectos secundarios y sin cambios concurrentes de esquema ni escrituras externas sobre fixtures reservados.
- El bloqueo nombrado solo coordina ejecuciones que usen el mismo lock.
- Si se corta la conexión, InnoDB revierte la transacción pendiente; la verificación posterior no llega a ejecutarse y no habrá PASS. El lock se libera al cerrar conexión.
- Si falla una precondición por colisión, los datos encontrados se conservan; no se borran.
- La instalación DDL no es reversible por el ensayo.
- Variables/parámetros de sesión y la rutina persistente no son filas de negocio.
- Ante error crítico, cerrar conexión dedicada y revisar; no borrar registros automáticamente.

## Cobertura y errores negativos

- Fiado 10000 céntimos, abono 4000, pendiente 6000, liquidación 6000 y pendiente cero.
- Una sola venta: los abonos no aumentan ventas.
- Transferencia 1000 entre efectivo y banco: dos cuentas visibles, saldo agregado y resultado iguales.
- CHECK de monto cero/negativo: 3819 y nombre ck_operaciones_total_minor.
- FK de categoría/cuenta/aplicación cruzada: 1452 y constraint esperado.
- Pierna duplicada: 1062 y uq_movimientos_pierna.
- command_id repetido: 1062 PRIMARY, con secuencia distinta para aislar el caso.
- Secuencia repetida: 1062 uq_comandos_seq, con UUID nuevo para aislar el caso.
- Anulación inválida: 3819 ck_movimientos_anulacion.
- Anulación válida: una fila modificada, version=2, actualizado_en UTC, pendiente reabierto y auditoría explícita.
- Evidencia con dos destinos: 3819 ck_vinculos_destino. Dos vínculos válidos no crean otra venta.
- Sobreabono directo: se documenta y revierte el límite multifila del esquema, sin presentarlo como rechazo implementado.

Handlers locales capturan solo códigos esperados. Además inspeccionan MESSAGE_TEXT por nombre de constraint/índice; si no coincide hacen RESIGNAL. Errores inesperados y advertencias salen por el handler exterior, sin PASS. Si una versión/idioma del servidor presenta mensajes distintos, se revisa el diagnóstico; no se relaja el handler para aceptar cualquier error.

Todas las aserciones de importes/contadores usan <=>. Una fila ausente devuelve NULL y debe fallar; se comprueban cardinalidades explícitas donde corresponden. No se usa COALESCE para convertir una liquidación ausente en cero.

## Lo que NO garantiza esta suite SQL

Sobreabonos concurrentes, distribución completa de cobros/pagos, compatibilidad económica de categoría y contraparte, exactamente dos piernas atómicas, corrección/anulación de conjuntos, idempotencia real, permisos por usuario, sincronización y auditoría automática son obligaciones del futuro backend Express.

La rutina solo prueba rechazo estructural de comandos repetidos; no implementa procesador de comandos. La auditoría del ensayo se inserta explícitamente. No se modifica Express ni Flutter.

## Referencias

- [Commit implícito y transacciones](https://dev.mysql.com/doc/refman/8.4/en/implicit-commit.html).
- [SET TRANSACTION y alcance](https://dev.mysql.com/doc/refman/8.4/en/set-transaction.html).
- [CHECK ENFORCED en TABLE_CONSTRAINTS](https://dev.mysql.com/doc/refman/8.4/en/information-schema-table-constraints-table.html).
- [Comparación null-safe](https://dev.mysql.com/doc/refman/8.4/en/comparison-operators.html).
