# Contrato REST V1

Base: /api/v1. JSON UTF-8; importes en céntimos como cadenas, UUID canónicos, fechas comerciales YYYY-MM-DD e instantes UTC.

## Autenticación

| Método | Ruta | Cuerpo / resultado |
|---|---|---|
| GET | /health/live | Público: {status:"ok",api:"v1"} |
| GET | /health/ready | Público: comprueba DB y migraciones; 200/503 |
| POST | /auth/registro | nombre, telefono, correo opcional/null, clave (12–128 caracteres), dispositivo {nombre,plataforma} |
| POST | /auth/login | usuario (teléfono/correo), clave, dispositivo {nombre,plataforma} |
| POST | /auth/refresh | {refresh_token}; rota tokens y sesión |
| POST | /auth/logout | Bearer access; revoca familia de sesión |
| GET | /auth/me | Bearer; usuario público y negocios autorizados |
| GET | /perfil | Alias de /auth/me |
| PATCH | /perfil | Bearer; expected_version y alguno de nombre,telefono,correo |

Registro devuelve 201; login/refresh/perfil/logout 200. Registro/login devuelven usuario público, access_token, refresh_token, token_type, expires_in=900 y dispositivo_id. Refresh devuelve tokens y dispositivo_id. Nunca password_hash/refresh_hash.

Plataformas ANDROID/IOS/WEB/OTRO. Teléfono sin + se normaliza con +; nueve dígitos peruanos comenzando por 9 se normalizan a +51. Correo se normaliza a minúsculas. No enviar claves por URL.

Resto de rutas requiere Authorization: Bearer <access_token>. Cada consulta comprueba usuario, dispositivo, sesión, membresía y negocio activo. Un lector no escribe; un operador no administra cuentas/categorías, perfil del negocio ni anulaciones.

## Rutas de negocio

| Método | Ruta | Parámetros / resultado |
|---|---|---|
| GET | /negocios | {items:[negocios con rol]} |
| POST | /negocios | Envelope de CREAR_NEGOCIO |
| GET | /negocios/:id | Perfil del negocio propio |
| PATCH | /negocios/:id | Envelope de ACTUALIZAR_NEGOCIO |
| POST | /negocios/:id/comandos | Envelope completo; todos los tipos soportados |
| GET / POST | /negocios/:id/categorias | Lista / CREAR_CATEGORIA |
| GET / POST | /negocios/:id/terceros | Lista / CREAR_TERCERO |
| GET / POST | /negocios/:id/cuentas | Cuentas con saldo / CREAR_CUENTA |
| GET / POST | /negocios/:id/operaciones | Historial / REGISTRAR_OPERACION |
| GET | /negocios/:id/operaciones/:operationId | Operación, aplicaciones, movimientos y pendiente |
| GET | /negocios/:id/historial | Alias de lista de operaciones |
| GET | /negocios/:id/movimientos | Lista de dinero por cuenta |
| POST | /negocios/:id/cobros | REGISTRAR_COBRO |
| POST | /negocios/:id/pagos | REGISTRAR_PAGO |
| POST | /negocios/:id/transferencias | REGISTRAR_TRANSFERENCIA |
| POST | /negocios/:id/movimientos-no-operativos | REGISTRAR_MOVIMIENTO_NO_OPERATIVO |
| GET | /negocios/:id/pendientes | Pendientes al corte, paginados |
| GET | /negocios/:id/indicadores | Indicadores sobre snapshot consistente |
| GET | /negocios/:id/reportes/actividad | Mismo reporte JSON, no PDF |
| GET | /negocios/:id/sync/snapshot | Entidades financieras/catálogos y cursor consistente |
| GET | /negocios/:id/sync/cambios | cursor entero >=0 (default 0), limit 1–100 (default 100) |

GET de listas: limit 1–100 (default 30), offset 0–10000, q para concepto/nombre. Historial admite desde,hasta,tipo,tercero_id,categoria_id,estado; movimientos admite desde,hasta,cuenta_id,estado. Se responden {items,next_offset}. No usar offset para sync.

Pendientes admite hasta (default hoy del negocio), direccion COBRAR/PAGAR, tercero_id,q,limit,offset. Indicadores/actividad admiten desde y hasta; por defecto inicio_historial y hoy. Las cuentas se calculan al corte actual. No se infiere utilidad contable ni aprobación crediticia.

Sync snapshot contiene negocio/catálogos/cuentas/operaciones/movimientos/aplicaciones/transferencias/cierres, sin sesiones/credenciales. Cambios devuelve {items,cursor}; cada item tiene seq y payload de entidades. Consumo de snapshot completo es alcance MVP; paginación de snapshots grandes pendiente.

## Envelope de escritura

```json
{
  "command_id": "<uuid-del-comando>",
  "dispositivo_id": "<uuid-del-login>",
  "tipo": "CREAR_TERCERO",
  "payload": {
    "id": "<uuid-del-tercero>",
    "nombre": "Cliente de ejemplo"
  }
}
```

En rutas específicas, tipo puede omitirse; si se incluye debe coincidir con la ruta. /comandos lo exige.

Respuesta 201 nueva / 200 reintento:

```json
{
  "command_id": "<uuid>",
  "sync_seq": "8",
  "entidades": [
    { "tabla": "terceros", "registro": { "id": "<uuid>", "negocio_id": "<uuid>", "nombre": "Cliente de ejemplo", "version": "1" } }
  ],
  "replayed": false
}
```

Registro es la fila canónica con metadatos de negocio; el ejemplo omite campos adicionales. Reutilizar exactamente command_id, dispositivo y contenido al reintentar. Cambiar un importe requiere nuevo comando, no reutilizarlo. Si hay refresh de sesión dentro del mismo dispositivo se conserva dispositivo_id.

## Payloads por tipo

Todos los objetos son estrictos: campos desconocidos producen 422. Dinero positivo <=100000000000000 céntimos; saldo inicial admite cero/negativos dentro del mismo límite. Los IDs referenciados deben pertenecer al negocio.

| Tipo | Payload |
|---|---|
| CREAR_NEGOCIO | id,nombre,rubro,inicio_historial,ciudad opcional/null |
| ACTUALIZAR_NEGOCIO | expected_version y alguno de nombre,rubro,ciudad |
| CREAR_CATEGORIA | id,nombre,tipo VENTA/COMPRA_MERCADERIA/GASTO_OPERATIVO,icono opcional/null |
| CREAR_TERCERO | id,nombre,telefono opcional/null,notas opcional/null |
| CREAR_CUENTA | id,nombre,tipo EFECTIVO/BANCO/YAPE/PLIN,fecha_apertura,saldo_inicial_minor opcional "0" |
| REGISTRAR_OPERACION | operacion y pagos_iniciales opcional [] |
| REGISTRAR_COBRO / REGISTRAR_PAGO | movimiento y aplicaciones (1–100) |
| REGISTRAR_TRANSFERENCIA | id,cuenta_origen_id,cuenta_destino_id,monto_minor,fecha,concepto,movimiento_salida_id,movimiento_entrada_id |
| REGISTRAR_MOVIMIENTO_NO_OPERATIVO | campos de movimiento y clase APORTE/RETIRO/PRESTAMO_RECIBIDO/AMORTIZACION/INVERSION |
| ANULAR_OPERACION / ANULAR_MOVIMIENTO / ANULAR_TRANSFERENCIA | id,expected_version,motivo |

CREAR_NEGOCIO solo se acepta mediante POST /negocios o comando con negocio ID idéntico; crea membresía propietario y contador atómicamente. Moneda PEN y zona America/Lima quedan fijas. No hay API de invitaciones, borrado o cambio de propietario en esta V1.

Operación:
- id,tipo,concepto,total_minor,fecha_operacion,condicion CONTADO/CREDITO.
- categoria_id y tercero_id opcionales/null.
- vence_el opcional/null; origen solo MANUAL (default).
- Tipos económicos VENTA/COMPRA_MERCADERIA/GASTO_OPERATIVO requieren categoría compatible.
- SALDO_CXC/SALDO_CXP requieren crédito, tercero, categoría null y propietario.
- Crédito requiere tercero; contado requiere pagos iniciales por todo el importe.
- Movimiento inicial exige fecha >= operación y dentro de la cuenta/historial.

Movimiento:
- id,cuenta_id,monto_minor,fecha_movimiento,canal,concepto,referencia_externa opcional/null.
- canal EFECTIVO/YAPE/PLIN/TRANSFERENCIA/OTRO.
- Dirección y clase COBRO/PAGO se derivan del comando, no del cliente.

Aplicación:
- id,operacion_id,monto_minor.
- Suman exactamente el movimiento; no se excede ningún pendiente; misma contraparte.
- pagos_iniciales usa objetos de movimiento más aplicacion_id, máximo 20.

## Ejemplo: fiado S/100 y abono S/40

Payload REGISTRAR_OPERACION:

```json
{
  "operacion": {
    "id": "<uuid-venta>",
    "tipo": "VENTA",
    "categoria_id": "<uuid-categoria-venta>",
    "tercero_id": "<uuid-cliente>",
    "concepto": "Venta fiada de abarrotes",
    "total_minor": "10000",
    "fecha_operacion": "2026-10-22",
    "condicion": "CREDITO"
  },
  "pagos_iniciales": []
}
```

Payload REGISTRAR_COBRO:

```json
{
  "movimiento": {
    "id": "<uuid-cobro>",
    "cuenta_id": "<uuid-cuenta>",
    "monto_minor": "4000",
    "fecha_movimiento": "2026-10-22",
    "canal": "YAPE",
    "concepto": "Abono de cliente"
  },
  "aplicaciones": [
    { "id": "<uuid-aplicacion>", "operacion_id": "<uuid-venta>", "monto_minor": "4000" }
  ]
}
```

Cambiar placeholders por UUID reales y fecha por una válida. Envolver cada payload con su propio command_id y dispositivo_id. Resultado: ventas 10000, cobros 4000, pendiente 6000. Liquidar luego 6000 con IDs nuevos; ventas siguen 10000.

Para contado, poner condicion CONTADO y pagos_iniciales con un movimiento por el total más aplicacion_id. Para compras/gastos se usa el mismo REGISTRAR_OPERACION; genera PAGO en lugar de COBRO.

## Anulaciones

Propietario únicamente, con versión y motivo. No hay borrado físico.
- Contado: ANULAR_OPERACION anula también sus movimientos exclusivos. Si comparten otras operaciones, rechaza por corrección conjunta pendiente.
- ANULAR_MOVIMIENTO no puede dejar un contado confirmado sin liquidar.
- Crédito con cobros vivos rechaza ANULAR_OPERACION; anular primero cobros.
- Transferencia: anular cabecera y ambas piernas juntas.
- No usar anulaciones para devoluciones reales; ese flujo compensatorio no está implementado.

## Indicadores y errores

Reporte: ventas_minor,compras_minor,gastos_minor,resultado_operativo_simplificado_minor,cobros_ventas_minor,pagos_operativos_minor,flujo_operativo_minor,por_cobrar_minor,por_pagar_minor,cuentas,pendientes,meses_completos,promedio_mensual_ventas_minor,ventas_mensuales,meses_historial,dias_con_ventas,dias_con_cierre,advertencias,corte_sync_seq.

Promedio sobre meses completos, incluidos meses sin ventas; null si insuficiente. Pendientes consideran pagos hasta hasta, no pagos futuros. Anulaciones corrigen el historial actual; todavía no se persisten PDFs/snapshots de reporte emitido.

Error:
```json
{"error":{"code":"EXCEEDS_OUTSTANDING","message":"El abono supera el pendiente"},"request_id":"<uuid>"}
```

401 TOKEN_REQUIRED/INVALID_TOKEN/INVALID_SESSION/INVALID_CREDENTIALS/INVALID_REFRESH.
403 BUSINESS_FORBIDDEN/ROLE_FORBIDDEN/OWNER_REQUIRED/DEVICE_MISMATCH/CORS_FORBIDDEN.
404 ENTITY_NOT_FOUND/NOT_FOUND.
409 IDEMPOTENCY_CONFLICT/DUPLICATE/EXCEEDS_OUTSTANDING/VERSION_CONFLICT/LIVE_PAYMENTS/CASH_AGGREGATE_REQUIRED/SHARED_PAYMENT/TRANSFER_ATOMIC.
422 VALIDATION_ERROR (field_errors), INVALID_AMOUNT/INVALID_DATE/INVALID_PERIOD/INVALID_CATEGORY/ALLOCATION_MISMATCH/INCOMPATIBLE_OPERATION.
413 REQUEST_TOO_LARGE. 429 AUTH_RATE_LIMIT. 503 DATABASE_UNAVAILABLE/AUTH_BUSY o servicio temporalmente no disponible.

Validaciones adicionales pueden devolver códigos específicos del mismo grupo; no reintentar errores 422 cambiando silenciosamente el comando. Reintentar fallos transitorios con la misma identidad.
# Extensiones V3 — 22/10/2026

Conservan autenticación Bearer, autorización por negocio y contratos financieros V1. Documentación de continuidad: `../../docs/FINKI_V3_PROGRESS.md`.

- `POST /negocios/:id/comandos`, tipo `GENERAR_CONSTANCIA`: payload `{id, desde, hasta}`. Emite snapshot y PDF privados dentro del protocolo idempotente. Requiere rol de escritura.
- `GET /negocios/:id/constancias?limit=20&offset=0`: metadatos de constancias del negocio.
- `GET /negocios/:id/constancias/:reportId`: `{id, sha256, pdf_base64, indicadores}`; autoriza y verifica el hash, sin recalcular cifras.
- `GET /negocios/:id/ia/estado`: configuración disponible, sin claves.
- `GET /negocios/:id/ia/propuestas`: últimas 20 propuestas pendientes para un miembro con escritura.
- `POST /negocios/:id/ia/analizar?id=UUID`, con `X-Finki-Consent: 1`: JSON `{texto}` hasta 6000 caracteres o cuerpo `application/octet-stream` JPEG/PNG/WAV hasta 7 MiB. Valida MIME por contenido y dimensiones; limita seis solicitudes por minuto/usuario. Proveedor desactivado responde 503 AI_NOT_CONFIGURED; no genera respuesta simulada. La entrada se envía al proveedor solo con consentimiento, configuración habilitada y pertenencia válida.
- `POST /negocios/:id/comandos`, tipo `CONFIRMAR_PROPUESTA`: payload `{extraccion_id, tipo, datos}`. Tipos internos permitidos: REGISTRAR_OPERACION/COBRO/PAGO/TRANSFERENCIA con sus payloads financieros, o VINCULAR_EVIDENCIA con `{tabla: operaciones|movimientos, id}`. Vincular comprueba pertenencia, estado e importe y no mueve dinero. La confirmación consume la propuesta una sola vez, conserva corrección humana y publica el conjunto atómicamente. Mismo command_id conserva idempotencia.
- `POST /negocios/:id/consultas`, JSON `{pregunta}` hasta 300 caracteres: consultas predefinidas sobre cifras reales. No acepta SQL ni instrucciones de ejecución del modelo.

Categoría null en operaciones regulares se resuelve a General del mismo tipo dentro de la transacción; no se relajó el CHECK SQL. Cuenta null solo tiene resolución automática para cobros/pagos EFECTIVO: cuenta de efectivo activa o creación segura por propietario con saldo cero. Para otros canales se exige elegir cuenta. Los negocios nuevos incluyen Efectivo. No son movimientos de ingreso ni inventan dinero.

Voz y OCR permanecen desactivados en el entorno del usuario (`AI_ENABLED=0`). No habilitar llamadas de pago sin nueva autorización. Los archivos privados no tienen URL pública; respaldar archivos y MySQL conjuntamente. Un fallo SQL posterior a escribir un archivo puede dejar un huérfano privado sin publicar; no se borra automáticamente.

# Gemini V3 (22/10/2026)

`GET /negocios/:id/ia/estado` conserva autenticación/membresía y devuelve
`proveedor: "Gemini"` o `"OpenAI"`, `configurado` y `requiere_consentimiento`.
Configurado significa habilitado con clave presente, no que Google haya validado
credenciales/cuota. Configuración e instrucciones: [GEMINI_SETUP](../../docs/GEMINI_SETUP.md).
`/ia/analizar` mantiene su contrato; genera propuesta y exige confirmación posterior.
Gemini responde `503 AI_QUOTA_EXHAUSTED`, `AI_BUSY` o `AI_BUDGET_UNAVAILABLE`
con mensaje para continuar manualmente. No se envían detalles privados del proveedor.
Los errores de interpretación mantienen `422 AI_UNCLEAR` / `AI_INVALID_PROPOSAL`.
