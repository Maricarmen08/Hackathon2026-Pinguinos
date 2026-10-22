'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {randomBytes,randomUUID}=require('node:crypto');
const {money,canonical,hash}=require('../src/domain');
const {buildReport}=require('../src/services/queries');
const {tokens}=require('../src/security');
const v=require('../src/validators');
const {Session}=require('../src/repositories/database');
test('dinero exacto, formato canónico y límite',()=>{
  assert.equal(money('99999999999999')+money('1'),100000000000000n);
  for(const bad of [1,'0','-1','1.00','01','1e3','100000000000001','9'.repeat(10000)])assert.throws(()=>money(bad));
  assert.equal(money('0',true),0n);assert.throws(()=>money('-0',true));
  assert.equal(hash(canonical({b:2,a:1})),hash(canonical({a:1,b:2})));
});
test('validación de fechas, normalización de teléfono y campos desconocidos',()=>{
  assert.throws(()=>v.date.parse('2026-02-30'));assert.equal(v.date.parse('2024-02-29'),'2024-02-29');
  assert.equal(v.login.parse({usuario:'987654321',clave:'x',dispositivo:{nombre:'X',plataforma:'ANDROID'}}).usuario,'+51987654321');
  assert.throws(()=>v.command({command_id:randomUUID(),dispositivo_id:randomUUID(),tipo:'CREAR_TERCERO',payload:{id:randomUUID(),nombre:'X',admin:true}}));
});
test('JWT rechaza manipulación y confusión de access/refresh',()=>{
  const jwt=tokens({JWT_SECRET:randomBytes(48).toString('hex'),JWT_REFRESH_SECRET:randomBytes(48).toString('hex')});
  const t=jwt.issue(randomUUID(),randomUUID(),randomUUID(),randomUUID());
  assert.equal(jwt.verify(t.access_token,'access').typ,'access');
  assert.throws(()=>jwt.verify(t.refresh_token,'access'));
  assert.throws(()=>jwt.verify(t.access_token.slice(0,-10)+'aaaaaaaaaa','access'));
});
test('repositorio usa parámetros y allowlist para SQL, incluyendo búsqueda literal',async()=>{
  const calls=[],s=new Session({execute:async(sql,params)=>{calls.push({sql,params});return [[],[]];}});
  const attack="' OR 1=1 --";
  await s.get('terceros',{nombre:attack});
  assert.equal(calls[0].sql.includes(attack),false);assert.ok(calls[0].params.includes(attack));
  await s.list('terceros',{negocio_id:randomUUID()},{search:{columns:['nombre'],term:'%_'},limit:10});
  assert.ok(calls[1].params.includes('%=%=_%'));
  await assert.rejects(s.get('usuarios; DROP TABLE usuarios',{}));
  await assert.rejects(s.update('terceros',{},{}));
});
test('promedio incluye meses cero y pendientes al corte excluyen cobros futuros',()=>{
  const b={id:'b',inicio_historial:'2026-01-01'},o={id:'sale',tipo:'VENTA',estado:'CONFIRMADO',total_minor:'10000',fecha_operacion:'2026-01-10'};
  const m={id:'cash',estado:'CONFIRMADO',monto_minor:'4000',fecha_movimiento:'2026-04-01',direccion:'ENTRADA',clase:'COBRO'};
  const a={operacion_id:'sale',movimiento_id:'cash',monto_minor:'4000'};
  const r=buildReport(b,[o],[m],[a],[],[],'2026-01-01','2026-03-31');
  assert.equal(r.meses_completos,3);assert.equal(r.promedio_mensual_ventas_minor,'3333');assert.equal(r.por_cobrar_minor,'10000');assert.equal(r.cobros_ventas_minor,'0');
  const partial=buildReport(b,[],[],[],[],[],'2026-01-02','2026-01-22');assert.equal(partial.promedio_mensual_ventas_minor,null);
});
