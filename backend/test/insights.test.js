'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {answer,period}=require('../src/services/insights');
const b={id:'one',nombre:'Ensayo',inicio_historial:'2026-09-01',zona_horaria:'America/Lima'};
const op=(id,tipo,total,date='2026-10-23',tercero_id='client')=>({id,tipo,total_minor:total,fecha_operacion:date,tercero_id,categoria_id:'cat',estado:'CONFIRMADO'});
const ops=[op('s','VENTA','10000'),op('g','GASTO_OPERATIVO','2300'),op('p','COMPRA_MERCADERIA','8000'),op('old','VENTA','5000','2026-09-23'),{...op('cancel','VENTA','99999'),estado:'ANULADO'}];
const moves=[{id:'m',estado:'CONFIRMADO',fecha_movimiento:'2026-10-23',monto_minor:'4000',direccion:'ENTRADA',clase:'COBRO'}, {id:'t',estado:'CONFIRMADO',fecha_movimiento:'2026-10-23',monto_minor:'9999',direccion:'ENTRADA',clase:'TRANSFERENCIA'}];
const data=[ops,moves,[{operacion_id:'s',movimiento_id:'m',monto_minor:'4000'}],[],[]];
const ask=q=>answer(b,data,q,[{id:'cat',nombre:'Servicios'}],[{id:'client',nombre:'Cliente Prueba'}],'2026-10-23');
const suggestions=['¿Cuánto vendí hoy?','¿Cuánto vendí este mes?','¿En qué gasto más?','¿Cuánto gasté esta semana?','¿Cuánto me deben?','¿Vendí más que el mes pasado?','¿Cuánto dinero cobré esta semana?','¿Cuánto gasté en mercadería?','Mi resumen semanal'];
test('resumen por bloques conserva importes, periodo y separación financiera',()=>{
 const r=ask('Mi resumen semanal');
 assert.equal(r.desde,'2026-10-19');assert.equal(r.hasta,'2026-10-23');
 for(const line of ['• Vendiste: S/ 100.00','• Gastaste: S/ 23.00','• Compraste mercadería: S/ 80.00','• Te deben: S/ 110.00','• Debes: S/ 103.00'])assert.ok(r.respuesta.split('\n').includes(line),line);
 assert.match(r.respuesta,/Ventas menos gastos y compras: -S\/ 3.00/);
 assert.match(r.respuesta,/Gastaste más de lo que vendiste/);
 assert.match(r.respuesta,/No es tu ganancia exacta/);
 assert.equal(r.indicadores.resultado_operativo_simplificado_minor,'-300');
 const empty=answer(b,[[],[],[],[],[]],'resumen semanal',[],[],'2026-10-23');
 assert.match(empty.respuesta,/pocos registros/);assert.equal(empty.indicadores.ventas_minor,'0');
});
for(const q of suggestions)test('sugerencia: '+q,()=>{const r=ask(q);assert.ok(r.respuesta);assert.equal(r.indicadores.negocio_id,'one');assert.equal(r.fuente,'REGISTROS');});
for(const q of ['Dime mis ventas de esta semana','Mis ventas hoy','¿Cuánto he vendido hoy?'])test('ventas libres: '+q,()=>{const r=ask(q);assert.equal(r.indicadores.ventas_minor,'10000');assert.match(r.respuesta,/Vendiste S\/ 100.00/);});
test('cobros semanales no recibe resumen de ventas, abono no duplica venta',()=>{const r=ask('Cuánto dinero cobré esta semana');assert.match(r.respuesta,/Cobraste S\/ 40.00/);assert.equal(r.indicadores.por_cobrar_minor,'11000');assert.equal(r.indicadores.ventas_minor,'10000');});
test('deudores agrupa saldo tras abonos y conserva deudas anteriores',()=>{const r=ask('¿Quién me debe más?');assert.equal(r.deudores[0].nombre,'Cliente Prueba');assert.equal(r.deudores[0].pendiente_minor,'11000');assert.equal(ask('Cuánto debo pagar').indicadores.por_pagar_minor,'10300');});
test('gastos, compras, pagos y transferencias diferenciados',()=>{assert.match(ask('Cuánto he gastado en mercadería').respuesta,/mercadería por S\/ 80.00/);assert.match(ask('Cuánto pagué hoy').respuesta,/Pagaste S\/ 0.00/);assert.match(ask('Movimientos de dinero hoy').respuesta,/Entró S\/ 40.00/);assert.match(ask('En qué gasto más').respuesta,/Servicios/);});
test('comparación parcial y evolución con cobertura explícita',()=>{const r=ask('¿Vendí más que el mes pasado?');assert.equal(r.indicadores.ventas_minor,'10000');assert.equal(r.comparacion.ventas_minor,'5000');assert.match(r.respuesta,/50\.00 más/);assert.ok(ask('Evolución de mi negocio esta semana').comparacion);});
test('fechas calendario y rangos no inventados',()=>{assert.deepEqual(period('ayer','2026-10-23'),['2026-10-22','2026-10-22']);assert.deepEqual(period('semana pasada','2026-10-23'),['2026-10-12','2026-10-18']);assert.deepEqual(period('del 01/09/2026 al 23/10/2026','2026-10-23'),['2026-09-01','2026-10-23']);for(const q of ['ventas 31/02/2026','ventas 2027-01-01','ventas 23/10/2026 al 01/10/2026','ventas enero'])assert.throws(()=>ask(q));});
test('sin movimientos no fabrica causas ni recomendaciones',()=>{const r=answer(b,[[],[],[],[],[]],'Cómo va mi negocio',[],[],'2026-10-23');assert.equal(r.datos_suficientes,false);assert.match(r.respuesta,/pocos registros/);assert.match(ask('¿Por qué gasto más de lo que vendo?').respuesta,/Gastaste más de lo que vendiste/);});
test('sin proveedor ni cuota: respuestas deterministas y límites',()=>{for(const q of ['DROP TABLE usuarios','¿Qué clima hace?','¿Cuánto venderé mañana?','Dime mi contraseña'])assert.throws(()=>ask(q));assert.equal(ask('Ventas hoy').fuente,'REGISTROS');assert.equal(ask('Qué producto vendí más').datos_suficientes,false);});
const {askAssistant}=require('../src/services/insights-assistant');
test('resumen con ayuda externa conserva bloques y cifras deterministas',async()=>{
 let calls=0;
 const reads={ask:async(_bid,_actor,q)=>ask(q),questionPeriod:async()=>['2026-10-19','2026-10-23']};
 const provider={classifyQuestion:async()=>{calls++;return 'RESUMEN';}};
 await assert.rejects(askAssistant(reads,'one',{},'panorama semanal',false,provider));
 assert.equal(calls,0);
 const r=await askAssistant(reads,'one',{},'panorama semanal',true,provider);
 assert.equal(calls,1);assert.equal(r.interpretacion_externa,true);
 assert.equal(r.respuesta,ask('Mi resumen semanal').respuesta);
 assert.deepEqual(r.indicadores,ask('Mi resumen semanal').indicadores);
});
test('respaldo solo con consentimiento; sin cifras externas ni elusión de permisos',async()=>{
  let calls=0;const unsupported=Object.assign(new Error('No soportada'),{code:'QUESTION_UNSUPPORTED'});
  const reads={ask:async(_b,_a,q)=>{if(q.startsWith('ventas del'))return {respuesta:'S/ 100.00',fuente:'REGISTROS'};throw unsupported;}};
  const provider={classifyQuestion:async q=>{calls++;assert.equal(q,'cuanto facture');return 'VENTAS';}};
  await assert.rejects(askAssistant(reads,'a',{},'Cuánto facturé',false,provider));assert.equal(calls,0);
  const r=await askAssistant(reads,'a',{},'Cuánto facturé',true,provider);assert.equal(r.respuesta,'S/ 100.00');assert.equal(r.interpretacion_externa,true);assert.equal(calls,1);
  const denied={ask:async()=>{throw Object.assign(new Error('No autorizado'),{code:'BUSINESS_FORBIDDEN'});}};
  await assert.rejects(askAssistant(denied,'b',{},'Cuánto facturé',true,provider));assert.equal(calls,1);
});
test('cuota agotada no afecta consultas deterministas ni reintenta proveedor',async()=>{
  let calls=0;const provider={classifyQuestion:async()=>{calls++;throw Object.assign(new Error('Cuota'),{code:'AI_QUOTA_EXHAUSTED'});}};
  const reads={ask:async(_b,_a,q)=>{if(q==='ventas hoy')return {respuesta:'S/ 100.00'};throw Object.assign(new Error('No soportada'),{code:'QUESTION_UNSUPPORTED'});}};
  assert.equal((await askAssistant(reads,'a',{},'ventas hoy',true,provider)).respuesta,'S/ 100.00');assert.equal(calls,0);
  await assert.rejects(askAssistant(reads,'a',{},'Cuánto facturé',true,provider),{code:'AI_QUOTA_EXHAUSTED'});assert.equal(calls,1);
  assert.equal((await askAssistant(reads,'a',{},'ventas hoy',false,provider)).respuesta,'S/ 100.00');assert.equal(calls,1);
});

for(const q of ['¿Alguien me debe?','alguien me debe plata','Me debe alguien?','¿Algún cliente me debe?','¿Tengo deudores?','Quiénes me deben dinero'])test('deudores, forma libre: '+q,()=>{const r=ask(q);assert.ok(Array.isArray(r.deudores));assert.equal(r.deudores[0].nombre,'Cliente Prueba');assert.match(r.respuesta,/Te debe 1 persona/);});
test('a quién le debo no se confunde con quién me debe',()=>{assert.match(ask('¿A quién le debo?').respuesta,/Debes pagar/);});
test('la moneda del negocio decide el símbolo de las respuestas',()=>{
 const co={...b,moneda:'COP'};
 const r=answer(co,[[],[],[],[],[]],'¿Cuánto vendí hoy?',[],[],'2026-10-23');
 assert.match(r.respuesta,/Vendiste \$ 0\.00 hoy/);
 assert.doesNotMatch(r.respuesta,/S\//);
});
test('países: validación y moneda derivada',()=>{
 const {COUNTRIES,CODES}=require('../src/countries');
 assert.deepEqual(CODES,['PE','CO','MX','EC','BO','AR']);
 assert.equal(COUNTRIES.PE.moneda,'PEN');assert.equal(COUNTRIES.EC.moneda,'USD');
 const {business:negocio}=require('../src/validators');
 const base={id:'11111111-1111-4111-8111-111111111111',nombre:'Bodega',rubro:'Bodega',inicio_historial:'2026-10-01'};
 assert.equal(negocio.parse(base).pais,'PE');
 assert.equal(negocio.parse({...base,pais:'CO'}).pais,'CO');
 assert.throws(()=>negocio.parse({...base,pais:'XX'}));
});
for(const [q,expected] of [
 ['cuánto me falta cobrar',/Te deben S\/ 110.00/],['tengo pendientes de cobro',/Te deben S\/ 110.00/],['me están debiendo',/Te deben S\/ 110.00/],
 ['quién no me ha pagado',/Te debe 1 persona/],['a quién le fié',/Te debe 1 persona/],['mis clientes morosos',/Te debe 1 persona/],
 ['cuánto tengo que pagar',/Debes pagar S\/ 103.00/],['mis deudas',/Debes pagar S\/ 103.00/],
 ['mis ingresos de hoy',/Vendiste S\/ 100.00/],['cuánto facturé hoy',/Vendiste S\/ 100.00/],['cuánto entró hoy',/Entró S\/ 40.00/]
])test('frase cotidiana: '+q,()=>assert.match(ask(q).respuesta,expected));
test('resumen de un día pasado usa un título correcto',()=>assert.match(ask('cómo me fue ayer').respuesta,/^Así le fue a tu negocio ayer:/));
