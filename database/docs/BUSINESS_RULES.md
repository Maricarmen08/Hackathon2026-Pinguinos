# Contrato financiero, seguridad e integración

## Semántica conservada

- Operación: venta, compra de mercadería o gasto ocurrido. SALDO_CXC/SALDO_CXP representa deuda anterior; no resultado del período.
- Movimiento: entrada/salida de dinero de una cuenta.
- Aplicación: parte de un movimiento destinada a liquidar una operación.
- Transferencia: dos piernas entre cuentas propias; no venta ni gasto.
- Cuenta pendiente: total menos aplicaciones válidas. No tabla duplicada ni columna de saldo editable.
- Solo PEN, dos decimales, en el contrato V1. Moneda de cuenta explícita y restringida a PEN.
- Saldos iniciales de cuentas pueden ser negativos para reflejar situación registrada; jamás son ventas.
- Los tipos de cuenta YAPE/PLIN solo se usan si se administra un saldo separado. Si corresponden a una cuenta bancaria ya registrada, usarla y marcar canal YAPE/PLIN.

## Garantías del esquema

PK UUID como CHAR(36) ascii_bin; claves UUID de padre/hijo del mismo tipo. Estructura básica (36 caracteres y guiones) en PK; validación hexadecimal, minúsculas y generación segura en backend/Flutter.

Dinero BIGINT firmado, sin FLOAT/DOUBLE, positivos 1..100000000000000 donde corresponde. Saldos iniciales tienen rango firmado. Nunca convertir a Number/double para sumas. Totales y SUM pueden exceder un importe individual; comprobar rango al persistir y serializar SUM exactos como cadenas.

Dominios CHECK con collation binaria de códigos. Anulación exige estado, fecha, miembro y motivo no vacío. Confirmados no admiten metadatos de anulación. CHECK no compara con otras filas ni con reloj actual.

Toda referencia de negocio, incluido autor/confirmador/anulador, usa FK compuesta negocio_id + ID. Autores apuntan a membresias(negocio_id,usuario_id). Membresía inicial referencia usuarios para evitar ciclo de bootstrap. No hay borrados en cascada; FK sin acciones explícitas conserva RESTRICT/NO ACTION de InnoDB.

UNIQUE protege correo/teléfono, categoría normalizada por tipo/negocio, documento de tercero informado, nombres de cuenta, par operación/movimiento, vínculos de evidencia, fecha de cierre, comando y secuencia.

Los índices por referencia/hash de comprobante NO son UNIQUE: una evidencia puede respaldar varias entidades y las referencias de distintos proveedores no son globalmente únicas.

## Invariantes OBLIGATORIAS del servicio transaccional

NO implementadas con triggers ni procedimientos financieros en esta etapa:

1. Autorizar miembro ACTIVO y rol en cada lectura/escritura; usuario activo, dispositivo no revocado y sesión válida. Las FK no verifican estados ni roles.
2. Mantener al menos un propietario activo; alta usuario/negocio/membresía/contador atómica.
3. Normalizar teléfono/correo/categoría; validar UUID completo, zona horaria IANA, documento y texto no vacío. Restringir actualizaciones a campos permitidos.
4. Inmutabilidad de moneda, zona horaria e inicio observado una vez usados, salvo proceso de corrección controlado.
5. Categoría de operación igual al tipo de categoría y activa al registrar. Terceros y cuentas deben estar activos al registrar, sin impedir consultas históricas.
6. Cuenta, operaciones y aplicaciones del mismo negocio; mismas fechas/moneda según contrato.
7. No operar antes de apertura de cuenta/inicio de historial, ni fechas futuras en el MVP. Para deudas previas, registrar SALDO_CXC/CXP a la fecha de apertura del historial y conservar antecedente en concepto/evidencia.
8. Una venta/gasto/compra de CONTADO se liquida completamente en el mismo comando. Una operación CREDITO requiere tercero.
9. COBRO aplica solo a VENTA/SALDO_CXC. PAGO solo a COMPRA_MERCADERIA/GASTO_OPERATIVO/SALDO_CXP.
10. Suma aplicada válida a operación <= total. Recalcular con bloqueos; no confiar en pendiente enviado por móvil.
11. Todo COBRO/PAGO se distribuye por su importe completo; las demás clases no llevan aplicaciones.
12. No mezclar contrapartes distintas en un mismo cobro/pago. Anticipos y pagos sin aplicar quedan fuera de V1.
13. Cada transferencia tiene exactamente dos movimientos del mismo importe/fecha/estado, salida en origen y entrada en destino. SQL impide cuentas idénticas y piernas duplicadas, pero no garantiza que existan ambas.
14. No interpretar aportes/préstamos como venta ni retiros/capital de deuda como gasto. Intereses son un gasto aparte. Inversión no es gasto operativo.
15. Aplicaciones y finanzas confirmadas son inmutables; no corregirlas con UPDATE arbitrario.
16. Para anular operación, no puede quedar dinero confirmado aplicado. Anular cobro/pago invalida sus aplicaciones por estado y reabre pendientes. Transferencia se anula completa. Corrección: anular y reemplazar conjunto consistente atómicamente, con IDs nuevos.
17. Devoluciones reales NO son anulaciones de errores. Requieren futuros hechos compensatorios/nota de crédito; no simular borrando ventas.
18. Escribir auditoría en la MISMA transacción; conservar valores/motivos suficientes para trazabilidad sin copiar secretos.
19. Incrementar version y actualizado_en explícitamente en cada actualización; los DEFAULT no hacen esto automáticamente. creado_en es hora del servidor UTC; fecha_operacion es fecha comercial.
20. Validar hash real, MIME por contenido, tamaño <=25 MiB, pertenencia, ruta privada no proporcionada por cliente y existencia del archivo antes de marcar DISPONIBLE. La semilla usa metadatos ficticios y PENDIENTE.
21. IA solo propone: no registrar finanzas hasta confirmación humana. Validar el JSON contra version_esquema. Un fallo o importe ausente nunca se rellena con valores inventados.
22. Confirmar extracción, crear finanzas/vínculos y evento en un comando idempotente; cada entidad tiene UUID. Audio/transcripción se retienen solo según política acordada.
23. Un comprobante puede respaldar venta y cobro mediante dos vínculos, sin crear otra venta.
24. Una captura Yape/Plin puede cobrar un fiado, aportar capital o transferir fondos; exigir clasificación y sugerir coincidencias, no asumir ingreso por venta.
25. Reportes: instantánea consistente y corte_seq. No modificar JSON histórico de un PDF emitido; generar otro reporte.
26. No aplicar stock, impuestos o contabilidad formal inexistentes a los resultados simplificados.

## Comando, idempotencia y bloqueo

Pseudoalgoritmo de una única conexión mysql2:

1. Validar token, forma del comando, límites y UUID; resolver negocio autorizado.
2. BEGIN.
3. Bloquear sync_contadores del negocio con SELECT ... FOR UPDATE. TODAS las escrituras de negocio deben tomar este bloqueo antes de cualquier otra escritura de ese negocio.
4. Comprobar nuevamente membresía, usuario y dispositivo; impedir revocaciones concurrentes mediante la misma disciplina de bloqueo.
5. Consultar comandos_procesados por command_id. Si pertenece al actor/negocio y hash canónico idéntico, ROLLBACK de lectura y devolver respuesta persistida. Otro contenido/actor: conflicto, sin revelar datos ajenos.
6. Bloquear operaciones/cuentas afectadas en orden estable y validar expected_version.
7. Recalcular pendientes y validar invariantes anteriores; rechazar sobreabono.
8. Insertar/actualizar todas las entidades y auditoría; asignar siguiente seq.
9. Insertar comandos_procesados con respuesta canónica y SHA-256 del request normalizado; insertar cambios_sync con MISMA seq y command_id; actualizar contador.
10. COMMIT; solo entonces responder aceptado.
11. Ante error: ROLLBACK y respuesta tipificada. Deadlock/transitorio: reintento acotado con el mismo command_id.

Un comando=un evento de sync con un payload que incluye varias entidades relacionadas. La serialización del contador antes de escribir evita que el cliente avance sobre una secuencia confirmada fuera de orden. Otros procesos (IA, catálogos, reportes y cambios del perfil) también deben publicar cambios mediante este protocolo si modifican entidades sincronizadas.

La PK y UNIQUE de comandos no impiden por sí solas repetir las escrituras si se insertan antes fuera de transacción. El protocolo es obligatorio. Conservar recibos aceptados; no caducarlos de modo que un reintento viejo pueda ejecutarse de nuevo. Request_hash es JSON canónico, no JSON.stringify con orden arbitrario.

No escribir versiones, sesiones ni hashes desde el teléfono. Un UUID del cliente no demuestra pertenencia ni permiso.

## Sincronización móvil prevista (no implementada)

SQLite/Drift: réplicas de negocio + outbox + sync_estado + archivos_locales + borradores. Una transacción local guarda finanzas y outbox; UI distingue LOCAL_PENDIENTE, ACEPTADO, RECHAZADO y CONFLICTO.

Snapshot inicial con lectura consistente y cursor del contador. Descarga incremental ordenada por seq; aplicar página y cursor atómicamente. Cambios autoritativos con pending local se conservan aparte y requieren rebase/revisión, nunca sobrescritura silenciosa.

Dos teléfonos pueden cobrar offline la misma deuda: el segundo sobreabono sincronizado se rechaza y queda visible para revisión. El teléfono no puede prometer aceptación definitiva antes del servidor.

Reintentos con backoff; dependencias tercero/cuenta/categoría antes de operación. Archivos en cola separada. Desconexión, cierre de app y respuesta perdida no duplican comandos. Al revocar acceso no se puede borrar remotamente al instante un dispositivo offline: bloquear sync al reconectar y proteger datos locales.

Registro/login inicial y PDF consolidado requieren conexión. Captura offline posible; IA remota queda pendiente. Background no se garantiza con app cerrada.

## Endpoints a implementar posteriormente

/api/v1/auth/{registro,login,refresh,logout}, /auth/me.
/api/v1/negocios/:id/{comandos,operaciones,movimientos,pendientes,cuentas,categorias,terceros}.
/api/v1/negocios/:id/{comprobantes,extracciones,indicadores,consultas,reportes}.
/api/v1/negocios/:id/sync/{snapshot,cambios}.

Mismo servicio de comandos para online y outbox; no doble implementación. Dinero JSON "1850"; fechas YYYY-MM-DD e instantes UTC; paginación por cursor; errores 401,403,409 conflicto/idempotencia/sobreabono,422 validación.

IA para preguntas traduce a métrica/período/filtros autorizados. Consultas predefinidas calculan resultados exactos; no SQL libre generado por el modelo.

## Seguridad y alcance

Sin RLS automática en MySQL: permisos de API y filtros por negocio obligatorios. Vistas con SQL SECURITY INVOKER no aíslan negocios. No exponerlas directamente al móvil.

Argon2id para nuevas credenciales; prefijo scrypt previsto para compatibilidad si se define formalmente. La excepción hash NULL solo permite usuario BLOQUEADO. No existe un servicio de login V1 aún.

Refresh rotativo con hash; revocar familia ante reutilización; verificar dispositivo. Tokens en almacenamiento seguro móvil, no tablas locales. Uploads privados con permisos, límites y expiración; no URL pública persistente. No información personal real en seeds/logs.

Documentar retención y cifrado antes de datos reales; no se implementa infraestructura de cifrado con tablas.

## Diferencias justificadas respecto al diseño

- Dos tablas técnicas schema_migraciones/schema_semillas: control reproducible.
- password_hash nullable EXCLUSIVAMENTE para usuario bloqueado sin credencial; evita inventar claves/hashes en demo.
- Unificación a anulado_en/anulado_por para las tres entidades financieras.
- Moneda explícita también en cuentas, restringida a PEN.
- FK de actores contra membresía; bootstrap de membresía contra usuario para evitar ciclo.
- Sin FK al seq que cierre un ciclo comandos/cambios: coincidencia y atomicidad verificadas por servicio y detector SQL.
- DDL no se promete reversible; fallos parciales exigen reparación revisada.
