'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {answer}=require('../src/services/insights');
const {period,businessToday}=require('../src/services/insights-period');
const business={id:'time-business',nombre:'Fixture',inicio_historial:'2026-09-01',zona_horaria:'America/Lima'};
const dates=['2026-10-23','2026-10-22','2026-10-17','2026-10-03','2026-09-30'];
const ops=dates.map((date,i)=>({id:'s'+i,tipo:'VENTA',estado:'CONFIRMADO',fecha_operacion:date,total_minor:String((i+1)*10000)}));
const data=[ops,[],[],[],[]];
const ask=q=>answer(business,data,q,[],[],'2026-10-23');
for(const [q,total,from,to] of [
  ['Mis ventas del día','10000','2026-10-23','2026-10-23'],
  ['mis ventas del dia','10000','2026-10-23','2026-10-23'],
  ['¿Cuánto vendí hoy?','10000','2026-10-23','2026-10-23'],
  ['CUANTO VENDI HOY','10000','2026-10-23','2026-10-23'],
  ['Ventas de esta mañana','10000','2026-10-23','2026-10-23'],
  ['ventas hoy por la manana','10000','2026-10-23','2026-10-23'],
  ['Ventas de ayer','20000','2026-10-22','2026-10-22'],
  ['¿Ventas de esta semana?','30000','2026-10-19','2026-10-23'],
  ['Ventas de este mes','100000','2026-10-01','2026-10-23'],
  ['ventas del mes pasado','50000','2026-09-01','2026-09-30'],
  ['ventas de los últimos siete días','60000','2026-10-17','2026-10-23'],
  ['VENTAS ULTIMOS 7 DIAS','60000','2026-10-17','2026-10-23'],
  ['Ventas del 17/10/2026 al 22/10/2026','50000','2026-10-17','2026-10-22'],
  ['Ventas 2026-10-03 al 2026-10-22','90000','2026-10-03','2026-10-22'],
  ['Ventas del día 22/10/2026','20000','2026-10-22','2026-10-22'],
])test('periodo y cifras diferenciadas: '+q,()=>{const r=ask(q);assert.equal(r.desde,from);assert.equal(r.hasta,to);assert.equal(r.indicadores.ventas_minor,total);assert.match(r.respuesta,/^S\/ /);});
test('mañana requiere precisión honesta, no se usa como pronóstico',()=>{assert.match(ask('Ventas esta mañana').respuesta,/día completo/);assert.throws(()=>ask('Ventas de mañana'));});
test('sin duplicación de advertencias y deuda vacía breve',()=>{const r=answer({...business,inicio_historial:'2026-10-22'},[[],[],[],[],[]],'Quién me debe más',[],[],'2026-10-23');assert.equal(r.deudores.length,0);assert.equal(r.respuesta,'Nadie tiene una deuda pendiente registrada al 23/10/2026.');const sales=answer({...business,inicio_historial:'2026-10-22'},[[],[],[],[],[]],'ventas de este mes',[],[],'2026-10-23');assert.match(sales.respuesta,/Historial disponible desde 22\/10\/2026/);assert.doesNotMatch(sales.respuesta,/Sin movimientos/);});
test('saludo e identidad sin inventar información personal ni enviar a Gemini',()=>{for(const q of ['¿Quién eres?','quien eres','HOLA']){const r=ask(q);assert.match(r.respuesta,/Soy Finki/);assert.equal(r.fuente,'ORIENTACION');}assert.match(ask('quien soy').respuesta,/Puedes ver tus datos en Perfil/);});
test('zona del negocio cerca de medianoche UTC y cambio de mes',()=>{const instant=new Date('2026-11-01T02:30:00Z');assert.equal(businessToday(business,instant),'2026-10-31');assert.equal(businessToday({...business,zona_horaria:'Asia/Tokyo'},instant),'2026-11-01');assert.deepEqual(period('ventas del dia',businessToday(business,instant)),['2026-10-31','2026-10-31']);assert.deepEqual(period('ayer','2026-03-01'),['2026-02-28','2026-02-28']);assert.deepEqual(period('ultimos siete dias','2026-03-01'),['2026-02-23','2026-03-01']);assert.deepEqual(period('esta semana','2026-10-26'),['2026-10-26','2026-10-26']);});
test('fechas inválidas y periodos contradictorios no caen al mes por defecto',()=>{for(const q of ['ventas 31/02/2026','ventas hoy y ayer','ventas últimos diez días','ventas 24/10/2026'])assert.throws(()=>ask(q));});

