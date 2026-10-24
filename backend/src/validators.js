'use strict';
const { z } = require('zod');
const { money } = require('./domain');
const uuid = z.string().uuid().transform(v => v.toLowerCase());
const text = max => z.string().trim().min(1).max(max);
const nullable = schema => schema.nullish().transform(v => v ?? null);
const amount = z.string().superRefine((v, c) => { try { money(v); } catch { c.addIssue({ code: 'custom', message: 'Céntimos positivos como cadena entera, máximo 100000000000000' }); } });
const signed = z.string().superRefine((v, c) => { try { money(v, true); } catch { c.addIssue({ code: 'custom', message: 'Céntimos enteros dentro de rango' }); } });
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(v => { const d = new Date(v + 'T00:00:00Z'); return v>='1000-01-01' && Number.isFinite(+d) && d.toISOString().slice(0, 10) === v; }, 'Fecha inexistente o fuera del rango MySQL');
const normalizePhone = v => /^9[0-9]{8}$/.test(v)?'+51'+v:v.startsWith('+')?v:'+'+v;
const phone = z.string().trim().regex(/^\+?[1-9][0-9]{7,14}$/).transform(normalizePhone);
const email = z.string().trim().email().max(254).transform(v => v.toLowerCase());
const password = z.string().min(12).max(128);
const changePassword = z.object({actual:z.string().min(1).max(128),nueva:password,confirmacion:password}).strict().refine(v=>v.nueva===v.confirmacion,'Las contraseñas no coinciden').refine(v=>v.nueva!==v.actual,'Elige una contraseña diferente');
const device = z.object({ nombre: text(100), plataforma: z.enum(['ANDROID','IOS','WEB','OTRO']) }).strict();
const register = z.object({ nombre: text(120), telefono: phone, correo: nullable(email), clave: password, dispositivo: device }).strict();
const login = z.object({ usuario: text(254).transform(v => /^[+]?[1-9][0-9]{7,14}$/.test(v)?normalizePhone(v):v.toLowerCase()), clave: z.string().min(1).max(128), dispositivo: device }).strict();
const refresh = z.object({ refresh_token: z.string().min(20).max(4096) }).strict();
const business = z.object({ id: uuid, nombre: text(120), rubro: text(80), inicio_historial: date, ciudad: nullable(text(80)) }).strict();
const channel = z.enum(['EFECTIVO','YAPE','PLIN','TRANSFERENCIA','OTRO']);
const movement = z.object({ id: uuid, cuenta_id: nullable(uuid), monto_minor: amount, fecha_movimiento: date, canal: channel, concepto: text(240), referencia_externa: nullable(text(120)) }).strict();
const allocation = z.object({ id: uuid, operacion_id: uuid, monto_minor: amount }).strict();
const operation = z.object({
  id: uuid, tipo: z.enum(['VENTA','COMPRA_MERCADERIA','GASTO_OPERATIVO','SALDO_CXC','SALDO_CXP']),
  tercero_id: nullable(uuid), categoria_id: nullable(uuid), concepto: text(240), total_minor: amount,
  fecha_operacion: date, condicion: z.enum(['CONTADO','CREDITO']), vence_el: nullable(date), origen: z.literal('MANUAL').default('MANUAL')
}).strict();
const initial = movement.extend({ aplicacion_id: uuid });
const version = z.string().regex(/^[1-9][0-9]{0,18}$/);
const profile = z.object({ expected_version: version, nombre: text(120).optional(), telefono: phone.optional(), correo: nullable(email).optional() }).strict().refine(v => ['nombre','telefono','correo'].some(k => k in v), 'Incluir un campo de perfil');
const voidPayload = z.object({ id: uuid, expected_version: version, motivo: text(300) }).strict();
const payloads = {
  CONFIRMAR_PROPUESTA_LOCAL: z.object({entrada:z.object({id_local:uuid,tipo:z.enum(['TEXTO','VOZ','IMAGEN']),texto:text(6000),propuesta:z.unknown().transform(value=>require('./services/ai-provider').validateProposal(value))}).strict(),comprobante_id:nullable(uuid),tipo:z.enum(['REGISTRAR_OPERACION','REGISTRAR_COBRO','REGISTRAR_PAGO','REGISTRAR_TRANSFERENCIA','VINCULAR_EVIDENCIA']),datos:z.unknown()}).strict().transform(p=>({...p,datos:p.tipo==='VINCULAR_EVIDENCIA'?z.object({tabla:z.enum(['operaciones','movimientos']),id:uuid}).strict().parse(p.datos):payloads[p.tipo].parse(p.datos)})),
  CONFIRMAR_PROPUESTA: z.object({extraccion_id:uuid,tipo:z.enum(['REGISTRAR_OPERACION','REGISTRAR_COBRO','REGISTRAR_PAGO','REGISTRAR_TRANSFERENCIA','VINCULAR_EVIDENCIA']),datos:z.unknown()}).strict().transform(p=>({...p,datos:p.tipo==='VINCULAR_EVIDENCIA'?z.object({tabla:z.enum(['operaciones','movimientos']),id:uuid}).strict().parse(p.datos):payloads[p.tipo].parse(p.datos)})),
  GENERAR_CONSTANCIA: z.object({id:uuid,desde:date,hasta:date}).strict(),
  CREAR_NEGOCIO: business,
  CREAR_CATEGORIA: z.object({ id: uuid, nombre: text(80), tipo: z.enum(['VENTA','COMPRA_MERCADERIA','GASTO_OPERATIVO']), icono: nullable(text(40)) }).strict(),
  CREAR_TERCERO: z.object({ id: uuid, nombre: text(120), telefono: nullable(phone), notas: nullable(text(500)) }).strict(),
  CREAR_CUENTA: z.object({ id: uuid, nombre: text(80), tipo: z.enum(['EFECTIVO','BANCO','YAPE','PLIN']), fecha_apertura: date, saldo_inicial_minor: signed.default('0') }).strict(),
  ACTUALIZAR_NEGOCIO: z.object({ expected_version: version, nombre: text(120).optional(), rubro: text(80).optional(), ciudad: nullable(text(80)).optional() }).strict().refine(v => ['nombre','rubro','ciudad'].some(k => k in v), 'Incluir un campo de perfil'),
  REGISTRAR_OPERACION: z.object({ operacion: operation, pagos_iniciales: z.array(initial).max(20).default([]) }).strict(),
  REGISTRAR_COBRO: z.object({ movimiento: movement, aplicaciones: z.array(allocation).min(1).max(100) }).strict(),
  REGISTRAR_PAGO: z.object({ movimiento: movement, aplicaciones: z.array(allocation).min(1).max(100) }).strict(),
  REGISTRAR_TRANSFERENCIA: z.object({ id: uuid, cuenta_origen_id: uuid, cuenta_destino_id: uuid, monto_minor: amount, fecha: date, concepto: text(240), movimiento_salida_id: uuid, movimiento_entrada_id: uuid }).strict(),
  REGISTRAR_MOVIMIENTO_NO_OPERATIVO: movement.extend({ clase: z.enum(['APORTE','RETIRO','PRESTAMO_RECIBIDO','AMORTIZACION','INVERSION']) }),
  DESCARTAR_PROPUESTA: z.object({extraccion_id:uuid,expected_version:version}).strict(),
  ANULAR_OPERACION: voidPayload, ANULAR_MOVIMIENTO: voidPayload, ANULAR_TRANSFERENCIA: voidPayload
};
const envelope = z.object({ command_id: uuid, dispositivo_id: uuid, tipo: z.enum(Object.keys(payloads)), payload: z.unknown() }).strict();
function command(input) { const c = envelope.parse(input); c.payload = payloads[c.tipo].parse(c.payload); return c; }
const filters = z.object({
  desde: date.optional(), hasta: date.optional(), tipo: z.enum(['VENTA','COMPRA_MERCADERIA','GASTO_OPERATIVO','SALDO_CXC','SALDO_CXP']).optional(), tercero_id: uuid.optional(),
  categoria_id: uuid.optional(), cuenta_id: uuid.optional(), q: text(100).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(30),
  offset: z.coerce.number().int().min(0).max(10000).default(0),
  direccion: z.enum(['COBRAR','PAGAR']).optional(), estado: z.enum(['CONFIRMADO','ANULADO']).optional()
}).strict().refine(v => !v.desde || !v.hasta || v.desde <= v.hasta, 'Período invertido');
module.exports = { device, uuid, register, login, refresh, business, command, filters, date, profile, changePassword };
