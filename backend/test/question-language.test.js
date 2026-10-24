'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {answer}=require('../src/services/insights');
const {askAssistant}=require('../src/services/insights-assistant');
const {externalQuestion}=require('../src/services/question-language');
const b={id:'b',inicio_historial:'2026-09-01',zona_horaria:'America/Lima'};
const op=(id,tipo,total,date='2026-10-23')=>({id,tipo,total_minor:total,fecha_operacion:date,estado:'CONFIRMADO',categoria_id:'cat',tercero_id:'person',concepto:'Ensayo '+id});
const data=[[op('s','VENTA','10000'),op('old','VENTA','5000','2026-10-22'),op('light','GASTO_OPERATIVO','1200'),op('bags','GASTO_OPERATIVO','800'),op('buy','COMPRA_MERCADERIA','7000')],
 [{id:'m',estado:'CONFIRMADO',fecha_movimiento:'2026-10-23',monto_minor:'5000',direccion:'ENTRADA',clase:'COBRO'}],
 [{operacion_id:'s',movimiento_id:'m',monto_minor:'5000'}],[],[]];
const ask=q=>answer(b,data,q,[],[{id:'person',nombre:'Persona ficticia'}],'2026-10-23');
for(const q of ['Hola','qué tal','QUE TAL!!!','Buenos días','buenas Finki','¿Cómo estás?'])test('saludo sin leer cifras: '+q,()=>{
 const r=answer(b,null,q);assert.equal(r.fuente,'ORIENTACION');assert.match(r.respuesta,/Soy Finki/);assert.equal(r.indicadores,undefined);
});
for(const q of ['Ventas de hoy','Quiero que me des mis ventas de hoy','Oye Finki, cuánto vendí hoy','Por favor dime mis BENTAS de OY','quiero saber cuanto venddi hoy'])test('ventas equivalentes: '+q,()=>{
 const r=ask(q);assert.equal(r.indicadores.ventas_minor,'10000');assert.equal(r.desde,'2026-10-23');assert.equal(r.hasta,r.desde);
});
for(const q of ['Dime cuánto he gastado esta semana','cuanto gastee esta semana','quiero saber mis GASTOZ esta semana'])test('gastos equivalentes: '+q,()=>{
 const r=ask(q);assert.equal(r.indicadores.gastos_minor,'2000');assert.match(r.respuesta,/Gastaste/);assert.equal(r.desde,'2026-10-19');
});
test('lenguaje peruano separa deudas, cobros, compras y resumen',()=>{
 assert.equal(ask('Quién me debe plata').deudores[0].pendiente_minor,'10000');
 assert.match(ask('Cuánto debo a mis proveedores').respuesta,/Debes pagar S\/ 90.00/);
 assert.match(ask('Cuánto he cobrado este mes').respuesta,/Cobraste S\/ 50.00/);
 assert.match(ask('Cuánto compré en mercadería').respuesta,/mercadería por S\/ 70.00/);
 const summary=ask('Qué tal me fue esta semana');assert.match(summary.respuesta,/Así va tu negocio/);assert.equal(summary.indicadores.ventas_minor,'15000');
 const largest=ask('Cuál fue mi gasto más grande');assert.equal(largest.gasto_mayor.id,'light');assert.match(largest.respuesta,/S\/ 12.00/);
});
for(const q of ['¿Cuánta plata hice hoy?','A ver cuánto hice ayer','Muéstrame mis cuentas del mes'])test('aclaración sin inventar ni consultar proveedor: '+q,async()=>{
 let calls=0;const r=await askAssistant({ask:async(_b,_a,text)=>ask(text)},'b',{},q,true,{classifyQuestion:async()=>{calls++;return 'VENTAS';}});
 assert.equal(r.fuente,'ACLARACION');assert.equal(r.indicadores,undefined);assert.ok(r.opciones.length>=2);assert.equal(calls,0);
 const selected=ask(r.opciones[0].pregunta);assert.equal(selected.desde,r.desde);assert.equal(selected.hasta,r.hasta);
 if(q.includes('ayer'))assert.equal(selected.indicadores.ventas_minor,'5000');
});
test('ganancia no se presenta como utilidad real; información no registrada y periodos inválidos',()=>{
 assert.match(ask('Cuál es mi ganancia hoy').respuesta,/No es tu ganancia exacta/);
 assert.equal(ask('Qué producto vendí más').datos_suficientes,false);
 for(const q of ['Qué clima hace','ventas hoy y ayer','ventas 31/02/2026','cuánta plata hice mañana'])assert.throws(()=>ask(q));
});
test('Gemini recibe solo vocabulario genérico después de consentimiento',async()=>{
 const question='Cuánto facturé a Persona Ficticia, correo persona@example.invalid, teléfono +51900000000, referencia 87654321, saldo S/ 123.45 hoy';
 let calls=0,sent;
 const unsupported=Object.assign(new Error('No soportada'),{code:'QUESTION_UNSUPPORTED'});
 const reads={ask:async(_b,_a,q)=>{if(q===question)throw unsupported;return ask(q);},questionPeriod:async()=>['2026-10-23','2026-10-23']};
 const provider={classifyQuestion:async q=>{calls++;sent=q;return 'VENTAS';}};
 await assert.rejects(askAssistant(reads,'b',{},question,false,provider));assert.equal(calls,0);
 const r=await askAssistant(reads,'b',{},question,true,provider);assert.equal(calls,1);assert.equal(r.indicadores.ventas_minor,'10000');
 assert.doesNotMatch(sent,/Persona|ficticia|example|900000000|87654321|123|saldo|@/i);assert.match(sent,/facture/);
 assert.throws(()=>externalQuestion('Persona Ficticia +51900000000'),{code:'QUESTION_PRIVATE'});
});
test('saludos y consultas reconocidas funcionan con Gemini indisponible',async()=>{
 let calls=0;const provider={classifyQuestion:async()=>{calls++;throw new Error('No disponible');}};
 for(const q of ['qué tal','oye Finki cuánto vendí hoy','quién me debe plata'])assert.ok((await askAssistant({ask:async(_b,_a,text)=>ask(text)},'b',{},q,true,provider)).respuesta);
 assert.equal(calls,0);
});
test('saludos y aclaraciones autorizados no cargan tablas financieras',async()=>{
 const reads=require('../src/services/queries').readService({snapshot:async fn=>fn({
   get:async table=>({usuarios:{estado:'ACTIVO'},dispositivos:{},sesiones:{expira_en:'2099-01-01 00:00:00'},membresias:{},negocios:b})[table],
   list:async()=>{throw new Error('No debe consultar movimientos ni terceros');}
 })});
 for(const q of ['qué tal','cuánta plata hice hoy'])assert.ok((await reads.ask('b',{sub:'user',did:'d',sid:'s'},q)).respuesta);
 const denied=require('../src/services/queries').readService({snapshot:async fn=>fn({get:async()=>null})});
 await assert.rejects(denied.ask('b',{sub:'other'},'qué tal'),{code:'INVALID_SESSION'});
});
test('fuera de alcance no llama Gemini aunque haya consentimiento',async()=>{
 let calls=0;
 await assert.rejects(askAssistant({ask:async(_b,_a,q)=>ask(q)},'b',{},'qué clima hace',true,{classifyQuestion:async()=>{calls++;}}),{code:'QUESTION_OUT_OF_SCOPE'});
 assert.equal(calls,0);
});
