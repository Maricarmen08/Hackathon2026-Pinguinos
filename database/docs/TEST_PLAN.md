# Plan de pruebas y evidencia

## Estado real de esta entrega

El usuario confirmó ejecución satisfactoria de migraciones 001/002, demo, metadatos, consultas financieras y comprobaciones de consistencia sobre MySQL 8.4.3. Es evidencia proporcionada por el usuario.

La suite V2 **no ha sido instalada ni ejecutada por Codex**. Se corrigieron y revisaron estáticamente solo pruebas y documentación. La validación estática no equivale a compilar SQL con MySQL ni a obtener PASS de ejecución.

Revisión estática de V2: bloques BEGIN/END e IF/END IF y paréntesis balanceados; runner con un único CALL y sin DDL/DML directo; ausencia de COMMIT/DELETE/DROP en el instalador; manifiesto de 34 identidades por tabla (algunos UUID se reutilizan en tablas distintas) distribuido en 16 tablas, coincidente entre INSERT, prevuelo, colisiones y verificaciones de limpieza normal/error; 108 nombres CHECK contrastados con la migración; 10 handlers negativos. Tres mutaciones solo en memoria fueron detectadas: omitir una tabla en limpieza final, volver a una comparación vulnerable a NULL y llamar a V1. No se ejecutó SQL para estas comprobaciones.

Instalación: `tests/01_install_integrity_suite_v2.sql`. Ejecución: `tests/02_run_integrity_suite_v2.sql`. Prevuelo y pasos HeidiSQL: `tests/README.md`. `integrity_tests.sql` quedó como aviso obsoleto sin DML/DDL/CALL.

## Pruebas SQL preparadas (pendientes de ejecución autorizada)

| Caso | Evidencia preparada | Límite |
|---|---|---|
| Estructura | metadata_validation.sql: 23 tablas, 5 vistas, FKs/checks/índices | Requiere 001/002 |
| Venta fiada 100 | Suite V2: pendiente 10000 | Fixture temporal |
| Abono 40 | Pendiente 6000 y ventas siguen 10000 | Prueba cálculo SQL, no servicio |
| Liquidación 60 | Pendiente cero | Sin concurrencia |
| Cero/negativo | Handler específico de error 3819 | No valida el formulario |
| Aislamiento | Categoría/cuenta/aplicación de otro negocio: 1452 | No prueba autorización de lecturas |
| Transferencia | Saldo conjunto y resultado no cambian; pierna repetida 1062 | No garantiza existencia de ambas sin backend |
| Comando y secuencia repetidos | 1062 PRIMARY y uq_comandos_seq por separado | No prueba reejecución idempotente de servicio |
| Anulación | Sin metadatos falla; con motivo conserva fila y reabre deuda | Auditoría insertada explícitamente, no automática |
| Evidencia | Vínculos separados sin crear otra venta; dos destinos 3819 | No prueba upload ni OCR |
| Sobreabono | SAVEPOINT demuestra que DML directo puede producir pendiente -1; lo revierte | Documenta límite, NO afirma protección implementada |
| Demo | demo_verification.sql: importes esperados | Datos sintéticos, usuario bloqueado |
| Consistencia | consistency_checks.sql: cero anomalías esperadas | Detecta, no previene ni repara |

V2 usa comparaciones <=>, cardinalidades explícitas, comprobaciones de fixtures antes/después y handler de errores/advertencias que revierte solo la transacción propia. Comprueba 23 tablas InnoDB, 108 CHECK ENFORCED, migraciones/vistas, flags y SQL mode; rechaza triggers visibles y colisiones. GET STACKED DIAGNOSTICS verifica código y nombre esperado de constraint.

La instalación DDL y el runner están separados. Solo queda instalada dbv1_test_integridad_v2_0_0; la rutina V1, si existe, no se llama ni elimina. El token/nombre de release y revisión de SHOW CREATE evitan usar una rutina antigua por accidente. No se vuelve a instalar para repetir.

La reversión esperada depende de InnoDB, permisos de metadatos y ausencia de alteraciones concurrentes/efectos secundarios. Ver tests/README.md. Ante un fallo crítico de limpieza no se emite PASS ni se borran filas manualmente.

## Pruebas del futuro backend (no implementadas aquí)

1. Alta usuario/negocio/membresía/contador atómica; hash válido, respuesta sin credenciales.
2. Login, rotación, revocación y reuso de refresh.
3. Miembro de negocio A no puede listar, editar, subir archivos ni consultar PDF de B.
4. Crear venta contado: operación/cobro/aplicación/evento/auditoría juntos o ninguno.
5. Fiado 100 → abono 40 → abono 60, ventas únicas 100.
6. Con pendiente 60, comando por 61 debe 409 EXCEEDS_OUTSTANDING; cero escrituras consolidadas.
7. Dos conexiones concurrentes con abonos por el mismo pendiente: solo importe admisible aceptado, sin saldo negativo.
8. Mismo command_id/payload tras pérdida de respuesta: mismo resultado, una sola escritura y seq.
9. Mismo command_id/otro payload: 409; el recibo original no cambia.
10. Versión antigua: 409 sin last-write-wins financiero.
11. Categoría incompatible, cuentas inactivas, fecha anterior a apertura, moneda distinta: rechazo.
12. Transferencia: inyectar fallo tras primera pierna y comprobar ROLLBACK completo.
13. Anular venta con cobro vivo debe fallar; anular cobro reabre deuda; anular transferencia completa.
14. No borrar aplicaciones/auditoría ni actualizar importes confirmados.
15. Verificar respuesta del evento, recibo y contador ante crash/deadlock.
16. IA sin monto, OCR repetido, captura de un cobro existente y JSON no válido: nunca inventar venta.
17. UUID mal formado/hash no criptográfico rechazados aunque pasen checks básicos de representación.
18. Perfil: no perder último propietario; revocación concurrente con escritura.
19. Fechas/meses/UTC: abono posterior al corte no reduce pendiente histórico.
20. PDF: snapshot y corte coherentes pese a nuevas escrituras durante generación.

## Integración móvil posterior

- Persistir comando local, cerrar proceso, abrir y recuperar.
- Sin internet, crear cliente/fiado/abono; sincronizar por dependencias.
- Reintentar tras respuesta perdida; no duplicar.
- Dos dispositivos offline: conflicto de sobreabono visible y datos locales conservados.
- Descarga paginada, cambios simultáneos y cursor: cero omisiones/duplicados efectivos.
- Usuario cambia sesión con outbox pendiente: sin pérdida ni mezcla entre negocios.
- Foto pendiente/fallida no pierde operación manual.
- Dashboard local provisional vs consolidado del PDF: diferencias señaladas.
- Migraciones SQLite entre versiones sin perder outbox.

## Criterio para declarar validada la instalación

Ejecutar 001/002 en la instancia de desarrollo autorizada; revisar metadatos; importar demo opcional; ejecutar verificaciones, prevuelo V2 e instalar/ejecutar separadamente la rutina con ROLLBACK verificado; guardar resultados reales y versión. La validación transaccional de producto solo se declarará cuando exista y se pruebe el backend.
