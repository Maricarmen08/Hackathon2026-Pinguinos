'use strict';
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {once}=require('node:events');
const {createApp}=require('../src/app');
const {today}=require('../src/domain');
async function scenario(t,db,config,{faultInjection=false}={}) {
  const server=createApp({db,config}).listen(0,'127.0.0.1');await once(server,'listening');
  t.after(async()=>{await new Promise(resolve=>server.close(resolve));await db.close();});
  const base='http://127.0.0.1:'+server.address().port+'/api/v1';
  const request=async(method,path,body,token,extraHeaders={})=>{
    const res=await fetch(base+path,{method,headers:{...(body?{'Content-Type':'application/json'}:{}),...(token?{Authorization:'Bearer '+token}:{}),...extraHeaders},...(body?{body:JSON.stringify(body)}:{})});
    return {status:res.status,body:await res.json(),headers:res.headers};
  };
  const suffix=randomUUID().replaceAll('-',''),phone=()=>'+999'+String(BigInt('0x'+randomUUID().slice(0,8))).padStart(10,'0');
  const userInput=(name)=>({nombre:'Ensayo '+name,telefono:phone(),correo:name+suffix+'@example.invalid',clave:'Ensayo-Seguro-2026!',dispositivo:{nombre:'Test',plataforma:'ANDROID'}});
  const a=userInput('alice'),b=userInput('bob');let alice,bob;
  await t.test('registro y login real del servicio; nunca devuelve hash',async()=>{
    alice=await request('POST','/auth/registro',a);assert.equal(alice.status,201);assert.ok(alice.body.access_token);
    assert.equal(JSON.stringify(alice.body).includes('password_hash'),false);
    bob=await request('POST','/auth/registro',b);assert.equal(bob.status,201);
    const bad=await request('POST','/auth/login',{usuario:a.telefono,clave:'incorrecta',dispositivo:a.dispositivo});assert.equal(bad.status,401);
    const ok=await request('POST','/auth/login',{usuario:a.telefono,clave:a.clave,dispositivo:a.dispositivo});assert.equal(ok.status,200);
    const blocked=await db.transaction(async s=>{
      const row=await s.get('usuarios',{id:bob.body.usuario.id});await s.update('usuarios',{id:row.id},{estado:'BLOQUEADO'});return row;
    });
    assert.equal((await request('POST','/auth/login',{usuario:b.telefono,clave:b.clave,dispositivo:b.dispositivo})).status,401);
    await db.transaction(s=>s.update('usuarios',{id:blocked.id},{estado:'ACTIVO'}));
  });
  const token=()=>alice.body.access_token,bid=randomUUID(),date=today(),start=date.slice(0,7)+'-01',path='/negocios/'+bid;
  const envelope=(tipo,payload,id=randomUUID())=>({command_id:id,dispositivo_id:alice.body.dispositivo_id,tipo,payload});
  const cmd=async(tipo,payload,id)=>request('POST',path+'/comandos',envelope(tipo,payload,id??(tipo==='CONFIRMAR_PROPUESTA_LOCAL'?payload.entrada.id_local:undefined)),token());
  const ids={saleCat:randomUUID(),purchaseCat:randomUUID(),expenseCat:randomUUID(),cash:randomUUID(),wallet:randomUUID(),client:randomUUID(),provider:randomUUID(),credit:randomUUID(),purchase:randomUUID()};
  await t.test('negocio propio, acceso ajeno y contratos estrictos',async()=>{
    const created=await request('POST','/negocios',envelope('CREAR_NEGOCIO',{id:bid,nombre:'Negocio de ensayo '+suffix,rubro:'Pruebas',inicio_historial:start,ciudad:null}),token());assert.equal(created.status,201,JSON.stringify(created.body));
    assert.equal((await request('GET',path,undefined,token())).status,200);
    assert.equal((await request('GET',path,undefined,bob.body.access_token)).status,403);
    assert.equal((await request('GET',path+'/indicadores?q=ignorado',undefined,token())).status,422);
    assert.equal((await request('GET',path)).status,401);
    assert.equal((await cmd('CREAR_TERCERO',{id:randomUUID(),nombre:'X',usuario_id:randomUUID()})).status,422);
  });
  await t.test('edición de negocio por comando conserva ID, controla versión y reintentos',async()=>{
    const before=await request('GET',path,undefined,token());
    const id=randomUUID(),payload={expected_version:String(before.body.version),nombre:'Negocio actualizado de ensayo',rubro:'Bodega'};
    assert.equal((await cmd('ACTUALIZAR_NEGOCIO',payload,id)).status,201);
    const repeated=await cmd('ACTUALIZAR_NEGOCIO',payload,id);
    assert.equal(repeated.status,200);assert.equal(repeated.body.replayed,true);
    assert.equal((await cmd('ACTUALIZAR_NEGOCIO',payload)).status,409);
    const after=await request('GET',path,undefined,token());
    assert.equal(after.body.id,bid);assert.equal(after.body.nombre,payload.nombre);
    assert.equal(BigInt(after.body.version),BigInt(before.body.version)+1n);
  });
  await t.test('catálogos y terceros persistidos',async()=>{
    for(const [id,tipo]of [[ids.saleCat,'VENTA'],[ids.purchaseCat,'COMPRA_MERCADERIA'],[ids.expenseCat,'GASTO_OPERATIVO']])assert.equal((await cmd('CREAR_CATEGORIA',{id,nombre:tipo,tipo})).status,201);
    for(const [id,tipo]of [[ids.cash,'EFECTIVO'],[ids.wallet,'YAPE']])assert.equal((await cmd('CREAR_CUENTA',{id,nombre:'Caja ensayo '+tipo,tipo,fecha_apertura:start,saldo_inicial_minor:'0'})).status,201);
    for(const [id,nombre]of [[ids.client,'Cliente ensayo'],[ids.provider,'Proveedor ensayo']])assert.equal((await cmd('CREAR_TERCERO',{id,nombre})).status,201);
  });
  const op=(id,tipo,cat,total,condicion,tercero)=>({id,tipo,categoria_id:cat,total_minor:total,condicion,tercero_id:tercero,concepto:'Operación ensayo',fecha_operacion:date,origen:'MANUAL'});
  const mov=(amount,account=ids.cash)=>({id:randomUUID(),cuenta_id:account,monto_minor:amount,fecha_movimiento:date,canal:'EFECTIVO',concepto:'Movimiento ensayo'});
  const settle=(operation,amount,type='REGISTRAR_COBRO')=>cmd(type,{movimiento:mov(amount),aplicaciones:[{id:randomUUID(),operacion_id:operation,monto_minor:amount}]});
  let initialCommand;
  await t.test('fiado 100, reintento idempotente y hash incompatible',async()=>{
    initialCommand=randomUUID();const payload={operacion:op(ids.credit,'VENTA',ids.saleCat,'10000','CREDITO',ids.client)};
    assert.equal((await cmd('REGISTRAR_OPERACION',payload,initialCommand)).status,201);
    const repeat=await cmd('REGISTRAR_OPERACION',payload,initialCommand);assert.equal(repeat.status,200);assert.equal(repeat.body.replayed,true);
    assert.equal((await cmd('REGISTRAR_OPERACION',{operacion:{...payload.operacion,total_minor:'9999'}},initialCommand)).status,409);
    const detail=await request('GET',path+'/operaciones/'+ids.credit,undefined,token());assert.equal(detail.body.pendiente_minor,'10000');
  });
  await t.test('abono 40, sobreabono rechazado y liquidación 60',async()=>{
    assert.equal((await settle(ids.credit,'4000')).status,201);
    assert.equal((await request('GET',path+'/operaciones/'+ids.credit,undefined,token())).body.pendiente_minor,'6000');
    const over=await settle(ids.credit,'6001');assert.equal(over.status,409);assert.equal(over.body.error.code,'EXCEEDS_OUTSTANDING');
    assert.equal((await settle(ids.credit,'6000')).status,201);
    const report=await request('GET',path+'/indicadores',undefined,token());
    assert.equal(report.body.ventas_minor,'10000');assert.equal(report.body.cobros_ventas_minor,'10000');assert.equal(report.body.por_cobrar_minor,'0');
  });
  await t.test('venta contado, compra pendiente, pago parcial y gasto pagado',async()=>{
    const cashSale=randomUUID(),salePayment={...mov('5000'),aplicacion_id:randomUUID()};
    assert.equal((await cmd('REGISTRAR_OPERACION',{operacion:op(cashSale,'VENTA',ids.saleCat,'5000','CONTADO',null),pagos_iniciales:[salePayment]})).status,201);
    assert.equal((await cmd('REGISTRAR_OPERACION',{operacion:op(randomUUID(),'VENTA',ids.saleCat,'5000','CONTADO',null)})).status,422);
    assert.equal((await cmd('REGISTRAR_OPERACION',{operacion:op(ids.purchase,'COMPRA_MERCADERIA',ids.purchaseCat,'8000','CREDITO',ids.provider)})).status,201);
    assert.equal((await settle(ids.purchase,'3000','REGISTRAR_PAGO')).status,201);
    assert.equal((await cmd('REGISTRAR_OPERACION',{operacion:op(randomUUID(),'GASTO_OPERATIVO',ids.expenseCat,'2000','CONTADO',null),pagos_iniciales:[{...mov('2000'),aplicacion_id:randomUUID()}]})).status,201);
    const report=(await request('GET',path+'/reportes/actividad',undefined,token())).body;
    assert.equal(report.ventas_minor,'15000');assert.equal(report.compras_minor,'8000');assert.equal(report.gastos_minor,'2000');
    assert.equal(report.resultado_operativo_simplificado_minor,'5000');assert.equal(report.flujo_operativo_minor,'10000');assert.equal(report.por_pagar_minor,'5000');
  });
  await t.test('transferencia interna, aporte y retiro no son ventas/gastos',async()=>{
    assert.equal((await cmd('REGISTRAR_TRANSFERENCIA',{id:randomUUID(),cuenta_origen_id:ids.cash,cuenta_destino_id:ids.wallet,monto_minor:'1000',fecha:date,concepto:'Transferencia',movimiento_salida_id:randomUUID(),movimiento_entrada_id:randomUUID()})).status,201);
    for(const clase of ['APORTE','RETIRO'])assert.equal((await cmd('REGISTRAR_MOVIMIENTO_NO_OPERATIVO',{...mov('100'),clase})).status,201);
    const r=(await request('GET',path+'/indicadores',undefined,token())).body;
    assert.equal(r.ventas_minor,'15000');assert.equal(r.gastos_minor,'2000');assert.equal(r.resultado_operativo_simplificado_minor,'5000');
    assert.equal(r.cuentas.reduce((n,c)=>n+BigInt(c.saldo_registrado_minor),0n),10000n);
  });
  await t.test('roles de lector, aislamiento de referencias y rollback de fallo intermedio',async()=>{
    const otherAccount=randomUUID();
    const otherBusiness=randomUUID();
    const asBob=(tipo,payload)=>({command_id:randomUUID(),dispositivo_id:bob.body.dispositivo_id,tipo,payload});
    assert.equal((await request('POST','/negocios',asBob('CREAR_NEGOCIO',{id:otherBusiness,nombre:'Negocio B ensayo',rubro:'Pruebas',inicio_historial:start}),bob.body.access_token)).status,201);
    assert.equal((await request('POST','/negocios/'+otherBusiness+'/comandos',asBob('CREAR_CUENTA',{id:otherAccount,nombre:'Caja ajena',tipo:'EFECTIVO',fecha_apertura:start}),bob.body.access_token)).status,201);
    assert.equal((await request('GET','/negocios/'+otherBusiness,undefined,token())).status,403);
    assert.equal((await request('POST','/negocios/'+otherBusiness+'/consultas',{pregunta:'¿Quién me debe más?'},token())).status,403);
    await db.transaction(async s=>{
      // Fixture aislado: no existe API de invitación en V1.
      await s.insert('membresias',{id:randomUUID(),negocio_id:bid,usuario_id:bob.body.usuario.id,rol:'LECTOR',estado:'ACTIVA',creado_por:alice.body.usuario.id});
    });
    const denied=await request('POST',path+'/comandos',{command_id:randomUUID(),dispositivo_id:bob.body.dispositivo_id,tipo:'CREAR_TERCERO',payload:{id:randomUUID(),nombre:'Prohibido'}},bob.body.access_token);assert.equal(denied.status,403);
    const badOp=randomUUID();
    assert.equal((await cmd('REGISTRAR_OPERACION',{operacion:op(badOp,'VENTA',ids.saleCat,'200','CONTADO',null),pagos_iniciales:[{...mov('200',otherAccount),aplicacion_id:randomUUID()}]})).status,404);
    assert.equal((await request('GET',path+'/operaciones/'+badOp,undefined,token())).status,404);
    if(faultInjection) {
      const before=await db.read(s=>s.get('sync_contadores',{negocio_id:bid}));
      db.failOnTable='auditoria';const id=randomUUID(),commandId=randomUUID();
      assert.equal((await cmd('CREAR_TERCERO',{id,nombre:'Revertir'},commandId)).status,500);
      assert.equal(await db.read(s=>s.get('terceros',{id})),null);assert.equal(await db.read(s=>s.get('comandos_procesados',{id:commandId})),null);
      assert.equal((await db.read(s=>s.get('sync_contadores',{negocio_id:bid}))).ultimo_seq,before.ultimo_seq);
    }
  });
  await t.test('concurrencia: dos cobros por el mismo pendiente',async()=>{
    const id=randomUUID();assert.equal((await cmd('REGISTRAR_OPERACION',{operacion:op(id,'VENTA',ids.saleCat,'100','CREDITO',ids.client)})).status,201);
    const results=await Promise.all([settle(id,'100'),settle(id,'100')]);assert.deepEqual(results.map(r=>r.status).sort(),[201,409]);
  });
  await t.test('anulaciones conservan conjuntos de contado y trazabilidad',async()=>{
    const cashId=randomUUID(),payment={...mov('100'),aplicacion_id:randomUUID()};
    assert.equal((await cmd('REGISTRAR_OPERACION',{operacion:op(cashId,'VENTA',ids.saleCat,'100','CONTADO',null),pagos_iniciales:[payment]})).status,201);
    assert.equal((await cmd('ANULAR_MOVIMIENTO',{id:payment.id,expected_version:'1',motivo:'Ensayo'})).status,409);
    assert.equal((await cmd('ANULAR_OPERACION',{id:cashId,expected_version:'1',motivo:'Error de registro de ensayo'})).status,201);
    const canceled=(await request('GET',path+'/operaciones/'+cashId,undefined,token())).body;
    assert.equal(canceled.estado,'ANULADO');assert.equal(canceled.pendiente_minor,'0');assert.equal(canceled.movimientos[0].estado,'ANULADO');
    const credit=randomUUID(),p={...mov('40'),aplicacion_id:randomUUID()};
    assert.equal((await cmd('REGISTRAR_OPERACION',{operacion:op(credit,'VENTA',ids.saleCat,'100','CREDITO',ids.client),pagos_iniciales:[p]})).status,201);
    assert.equal((await cmd('ANULAR_OPERACION',{id:credit,expected_version:'1',motivo:'Ensayo'})).status,409);
    assert.equal((await cmd('ANULAR_MOVIMIENTO',{id:p.id,expected_version:'1',motivo:'Cobro registrado por error'})).status,201);
    assert.equal((await request('GET',path+'/operaciones/'+credit,undefined,token())).body.pendiente_minor,'100');
    assert.equal((await cmd('ANULAR_OPERACION',{id:credit,expected_version:'1',motivo:'Venta registrada por error'})).status,201);
    const audits=await db.read(s=>s.list('auditoria',{negocio_id:bid,entidad_id:credit}));
    assert.ok(audits.some(a=>a.accion==='ANULAR_OPERACION'));
    const snapshot=await request('GET',path+'/sync/snapshot',undefined,token());assert.equal(snapshot.status,200);assert.ok(snapshot.body.cursor);
    const changes=await request('GET',path+'/sync/cambios?cursor=0',undefined,token());assert.equal(changes.status,200);
    assert.equal(new Set(changes.body.items.map(x=>x.seq)).size,changes.body.items.length);
    assert.equal((await request('PATCH','/perfil',{expected_version:'1',nombre:'Nombre actualizado de ensayo'},token())).status,200);
    assert.equal((await request('PATCH','/perfil',{expected_version:'1',nombre:'Versión vieja'},token())).status,409);
  });
  await t.test('constancia PDF real, snapshot MySQL, acceso e idempotencia',async()=>{
    const id=randomUUID(),commandId=randomUUID(),payload={id,desde:start,hasta:date};
    const before=(await request('GET',path+'/indicadores',undefined,token())).body;
    const created=await cmd('GENERAR_CONSTANCIA',payload,commandId);assert.equal(created.status,201,JSON.stringify(created.body));
    assert.equal((await cmd('GENERAR_CONSTANCIA',payload,commandId)).body.replayed,true);
    const file=await request('GET',path+'/constancias/'+id,undefined,token());assert.equal(file.status,200);
    const bytes=Buffer.from(file.body.pdf_base64,'base64');assert.ok(bytes.length>2000);assert.equal(bytes.subarray(0,5).toString(),'%PDF-');
    assert.equal(require('node:crypto').createHash('sha256').update(bytes).digest('hex'),file.body.sha256);
    assert.equal(file.body.indicadores.ventas_minor,before.ventas_minor);assert.equal(file.body.indicadores.cobros_ventas_minor,before.cobros_ventas_minor);
    assert.equal(file.body.indicadores.por_cobrar_minor,before.por_cobrar_minor);
    const saved=await db.read(s=>s.get('reportes',{id,negocio_id:bid}));assert.equal(saved.estado,'LISTO');
    assert.ok((await request('GET',path+'/constancias',undefined,token())).body.items.some(r=>r.id===id));
    // Report fixtures only; never user's development data.
    const dir=require('node:path').join(__dirname,'../../build/tooling');require('node:fs').mkdirSync(dir,{recursive:true});require('node:fs').writeFileSync(require('node:path').join(dir,'finki-v3-certificate-test.pdf'),bytes);
    assert.equal((await request('GET',path+'/constancias/'+id)).status,401);
    const another=await cmd('GENERAR_CONSTANCIA',{id:randomUUID(),desde:date,hasta:'2099-01-01'});assert.equal(another.status,422);
    assert.equal((await request('GET',path+'/constancias/'+randomUUID(),undefined,token())).status,404);
  });
  await t.test('venta simple sin categoría usa General atómicamente',async()=>{
    const id=randomUUID();const result=await cmd('REGISTRAR_OPERACION',{operacion:op(id,'VENTA',null,'100','CONTADO',null),pagos_iniciales:[{...mov('100'),cuenta_id:null,aplicacion_id:randomUUID()}]});assert.equal(result.status,201,JSON.stringify(result.body));
    const row=(await request('GET',path+'/operaciones/'+id,undefined,token())).body;assert.ok(row.categoria_id);assert.equal(row.pendiente_minor,'0');
  });
  await t.test('consultas autorizadas usan cifras reales y rechazan preguntas arbitrarias',async()=>{
    for(const pregunta of ['¿Cuánto vendí hoy?','¿Cuánto vendí este mes?','¿En qué gasto más?','¿Cuánto me deben?','¿Vendí más que el mes pasado?','¿Cuánto dinero cobré esta semana?','¿Cuánto gasté en mercadería?','Mi resumen semanal','¿Cuánto gasté esta semana?','¿Qué producto vendí más?']){
      const r=await request('POST',path+'/consultas',{pregunta},token());assert.equal(r.status,200,JSON.stringify(r.body));assert.ok(r.body.respuesta);assert.equal(r.body.indicadores.negocio_id,bid);
    }
    assert.equal((await request('POST',path+'/consultas',{pregunta:'DROP TABLE usuarios'},token())).status,422);
    assert.equal((await request('POST',path+'/consultas',{pregunta:'ventas hoy'})).status,401);
    assert.equal((await request('POST',path+'/consultas',{pregunta:'¿Quién me debe más?'},bob.body.access_token)).status,200); // LECTOR autorizado para consultar.
    for(const pregunta of ['Dime mis ventas de esta semana','¿Quién me debe más?','¿Cuánto debo pagar?','¿Cómo va mi negocio?','¿Por qué gasto más de lo que vendo?','¿Cuánto pagué hoy?']){
      const r=await request('POST',path+'/consultas',{pregunta},token());assert.equal(r.status,200,JSON.stringify(r.body));assert.equal(r.body.indicadores.negocio_id,bid);assert.equal(r.body.fuente,'REGISTROS');
    }
  });
  await t.test('periodos diarios y mensuales con ventas distintas en negocio aislado',async()=>{
    const temporalBid=randomUUID(),customer=randomUUID(),category=randomUUID(),p='/negocios/'+temporalBid;
    const shiftDate=(n)=>new Date(Date.parse(date+'T00:00:00Z')+n*86400000).toISOString().slice(0,10);
    const command=(tipo,payload)=>request('POST',p+'/comandos',envelope(tipo,payload),token());
    assert.equal((await request('POST','/negocios',envelope('CREAR_NEGOCIO',{id:temporalBid,nombre:'Ensayo temporal aislado',rubro:'Pruebas',inicio_historial:shiftDate(-40)}),token())).status,201);
    assert.equal((await command('CREAR_TERCERO',{id:customer,nombre:'Cliente temporal'})).status,201);
    assert.equal((await command('CREAR_CATEGORIA',{id:category,nombre:'Ventas temporales',tipo:'VENTA'})).status,201);
    for(const [offset,total] of [[0,'10000'],[-1,'20000'],[-8,'30000']]){
      const result=await command('REGISTRAR_OPERACION',{operacion:{...op(randomUUID(),'VENTA',category,total,'CREDITO',customer),fecha_operacion:shiftDate(offset)}});assert.equal(result.status,201,JSON.stringify(result.body));
    }
    for(const pregunta of ['Mis ventas del día','mis ventas del dia','¿Cuánto vendí hoy?','Ventas esta mañana']){
      const r=await request('POST',p+'/consultas',{pregunta},token());assert.equal(r.status,200,JSON.stringify(r.body));assert.equal(r.body.desde,date);assert.equal(r.body.hasta,date);assert.equal(r.body.indicadores.ventas_minor,'10000');assert.equal(r.body.indicadores.cobros_ventas_minor,'0');
    }
    const yesterday=await request('POST',p+'/consultas',{pregunta:'Ventas de ayer'},token());assert.equal(yesterday.body.indicadores.ventas_minor,'20000');
    const daily=await request('GET',p+'/ventas/hoy',undefined,token());assert.equal(daily.status,200);assert.equal(daily.body.negocio_id,temporalBid);assert.equal(daily.body.ventas_minor,'10000');assert.equal(daily.body.desde,date);assert.equal(daily.body.hasta,date);
    const reportToday=await request('GET',p+'/indicadores?desde='+date+'&hasta='+date,undefined,token());assert.equal(reportToday.body.ventas_minor,daily.body.ventas_minor);
    assert.equal((await request('GET',p+'/ventas/hoy')).status,401);
    assert.equal((await request('GET',p+'/ventas/hoy',undefined,bob.body.access_token)).status,403);
    const monthly=await request('POST',p+'/consultas',{pregunta:'Ventas de este mes'},token());
    const expected=[[0,10000n],[-1,20000n],[-8,30000n]].filter(([offset])=>shiftDate(offset)>=date.slice(0,7)+'-01').reduce((n,[,amount])=>n+amount,0n);
    assert.equal(monthly.body.indicadores.ventas_minor,expected.toString());
    assert.equal((await request('POST',p+'/consultas',{pregunta:'ventas hoy'},bob.body.access_token)).status,403);
  });
  await t.test('propuesta requiere confirmación, abona sin nueva venta y no se confirma dos veces',async()=>{
    const operationId=randomUUID();assert.equal((await cmd('REGISTRAR_OPERACION',{operacion:op(operationId,'VENTA',null,'10000','CREDITO',ids.client)})).status,201);
    const extraction=randomUUID(),actor=require('../src/security').tokens(config).verify(token(),'access');
    const result={intencion:'COBRO',monto_minor:'4000',concepto:'Abono de ensayo',fecha:date,persona:null,referencia:null,medio:'EFECTIVO',fiado:false,es_pago:false,pregunta:null,texto_visible:'Cliente pagó 40 soles'};
    await require('../src/services/commands').commandService(db)(bid,{command_id:randomUUID(),dispositivo_id:actor.did,tipo:'GUARDAR_PROPUESTA_INTERNA',payload:{id:extraction,kind:'TEXTO',text:'Cliente pagó 40 soles',result,model:'fixture explícito sin proveedor'}},actor);
    const before=(await request('GET',path+'/indicadores',undefined,token())).body;
    assert.equal((await request('GET',path+'/operaciones/'+operationId,undefined,token())).body.pendiente_minor,'10000');
    const payload={extraccion_id:extraction,tipo:'REGISTRAR_COBRO',datos:{movimiento:mov('4000'),aplicaciones:[{id:randomUUID(),operacion_id:operationId,monto_minor:'4000'}]}};
    const id=randomUUID();assert.equal((await cmd('CONFIRMAR_PROPUESTA',payload,id)).status,201);
    assert.equal((await cmd('CONFIRMAR_PROPUESTA',payload,id)).body.replayed,true);
    assert.equal((await cmd('CONFIRMAR_PROPUESTA',payload)).status,409);
    const after=(await request('GET',path+'/indicadores',undefined,token())).body;assert.equal(after.ventas_minor,before.ventas_minor);assert.equal(BigInt(after.cobros_ventas_minor)-BigInt(before.cobros_ventas_minor),4000n);
    assert.equal((await request('GET',path+'/operaciones/'+operationId,undefined,token())).body.pendiente_minor,'6000');
    assert.equal((await db.read(s=>s.get('extracciones',{id:extraction,negocio_id:bid}))).estado,'CONFIRMADA');
  });
  await t.test('imagen real con proveedor DOBLE: archivo privado, duplicados y vínculo sin doble venta',async()=>{
    const fs=require('node:fs'),pathModule=require('node:path');
    const bytes=fs.readFileSync(pathModule.join(__dirname,'../../assets/branding/finki_robot.png'));
    let calls=0;const actor=require('../src/security').tokens(config).verify(token(),'access');
    const provider=new (require('../src/services/gemini-provider').GeminiProvider)({AI_ENABLED:true,GEMINI_API_KEY:'mock-not-a-real-key'},async()=>{calls++;return new Response(JSON.stringify({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify({intencion:'DESCONOCIDO',monto_minor:'10000',concepto:'Ensayo de comprobante',fecha:date,persona:null,referencia:'fixture-'+randomUUID(),medio:'YAPE',fiado:false,es_pago:true,pregunta:'¿Qué representa?',texto_visible:'Fixture sin proveedor real'})}]}}]}));},{reserve(){}},{check(){},block(){},success(){},availability(){return {disponible:true};}});
    const intake=require('../src/services/intake').intakeService(db,require('../src/services/commands').commandService(db),provider),id=randomUUID();
    const indicatorsBefore=(await request('GET',path+'/indicadores',undefined,token())).body;
    const first=await intake(bid,actor,{bytes,id,consent:true});assert.equal(first.estado,'REQUIERE_REVISION');
    const saved=await db.read(s=>s.get('extracciones',{id,negocio_id:bid}));assert.equal(saved.proveedor,'Gemini');assert.equal(saved.modelo,'gemini-3.5-flash-lite');
    const indicatorsAfter=(await request('GET',path+'/indicadores',undefined,token())).body;assert.equal(indicatorsAfter.ventas_minor,indicatorsBefore.ventas_minor);assert.equal(indicatorsAfter.cobros_ventas_minor,indicatorsBefore.cobros_ventas_minor);
    await assert.rejects(intake(bid,require('../src/security').tokens(config).verify(bob.body.access_token,'access'),{bytes,id:randomUUID(),consent:true}),e=>e.status===403);assert.equal(calls,1);
    assert.ok((await request('GET',path+'/ia/propuestas',undefined,token())).body.items.some(r=>r.id===id));
    assert.equal((await request('GET',path+'/ia/propuestas',undefined,bob.body.access_token)).status,403);
    assert.equal((await intake(bid,actor,{bytes,id,consent:true})).id,id);assert.equal(calls,1);
    await assert.rejects(intake(bid,actor,{bytes,id:randomUUID(),consent:true}),e=>e.code==='DUPLICATE_EVIDENCE');assert.equal(calls,1);
    const movement=mov('10000'),oid=randomUUID();assert.equal((await cmd('REGISTRAR_OPERACION',{operacion:op(oid,'VENTA',null,'10000','CONTADO',null),pagos_iniciales:[{...movement,aplicacion_id:randomUUID()}]})).status,201);
    const before=(await request('GET',path+'/indicadores',undefined,token())).body;
    assert.equal((await cmd('CONFIRMAR_PROPUESTA',{extraccion_id:id,tipo:'VINCULAR_EVIDENCIA',datos:{tabla:'movimientos',id:movement.id}})).status,201);
    const after=(await request('GET',path+'/indicadores',undefined,token())).body;assert.equal(after.ventas_minor,before.ventas_minor);assert.equal(after.cobros_ventas_minor,before.cobros_ventas_minor);
    const extraction=await db.read(s=>s.get('extracciones',{id,negocio_id:bid}));assert.equal(extraction.estado,'CONFIRMADA');
    assert.equal((await db.read(s=>s.list('vinculos_comprobante',{negocio_id:bid,comprobante_id:extraction.comprobante_id}))).length,1);
  });
  await t.test('descarte auditado: versión, aislamiento, idempotencia y protección de confirmadas',async()=>{
    const actor=require('../src/security').tokens(config).verify(token(),'access'),id=randomUUID();
    const p={intencion:'VENTA',monto_minor:'5000',concepto:'Arroz de ensayo',fecha:date,persona:null,referencia:null,medio:null,fiado:false,es_pago:false,pregunta:null,texto_visible:'Ensayo sin finanzas'};
    const execute=require('../src/services/commands').commandService(db);
    await execute(bid,{command_id:randomUUID(),dispositivo_id:actor.did,tipo:'GUARDAR_PROPUESTA_INTERNA',payload:{id,kind:'TEXTO',text:'Vendí 50 soles de arroz',result:p,model:'fixture',provider:'Gemini',consentVersion:'finki-v4-2026-10-22'}},actor);
    const before=(await request('GET',path+'/indicadores',undefined,token())).body;
    const payload={extraccion_id:id,expected_version:'1'};
    assert.equal((await request('POST',path+'/comandos',{...envelope('DESCARTAR_PROPUESTA',payload),dispositivo_id:bob.body.dispositivo_id},bob.body.access_token)).status,403);
    assert.equal((await cmd('DESCARTAR_PROPUESTA',{...payload,expected_version:'2'})).status,409);
    const commandId=randomUUID();assert.equal((await cmd('DESCARTAR_PROPUESTA',payload,commandId)).status,201);
    assert.equal((await cmd('DESCARTAR_PROPUESTA',payload,commandId)).body.replayed,true);
    assert.equal((await cmd('DESCARTAR_PROPUESTA',payload)).status,409);
    const row=await db.read(s=>s.get('extracciones',{id,negocio_id:bid}));
    assert.equal(row.estado,'FALLIDA');assert.equal(row.codigo_error,'DESCARTADA_USUARIO');
    const correction=require('../src/domain').json(row.correccion_usuario);
    assert.equal(correction.consentimiento.version,'finki-v4-2026-10-22');assert.equal(correction.consentimiento.proveedor,'Gemini');assert.equal(correction.descartada_por,actor.sub);
    const list=await request('GET',path+'/ia/propuestas',undefined,token());assert.ok(!list.body.items.some(r=>r.id===id));
    const confirmed=(await db.read(s=>s.list('extracciones',{negocio_id:bid,estado:'CONFIRMADA'})))[0];
    assert.equal((await cmd('DESCARTAR_PROPUESTA',{extraccion_id:confirmed.id,expected_version:String(confirmed.version)})).status,409);
    const after=(await request('GET',path+'/indicadores',undefined,token())).body;
    assert.equal(after.ventas_minor,before.ventas_minor);assert.equal(after.cobros_ventas_minor,before.cobros_ventas_minor);
    const events=await db.read(s=>s.list('auditoria',{negocio_id:bid,command_id:commandId}));assert.equal(events.length,1);assert.equal(events[0].accion,'DESCARTAR_PROPUESTA');
  });
  await t.test('propuestas locales: fiado, abono, imagen original, aislamiento y reintento sin duplicados',async()=>{
    const proposed={intencion:'VENTA',monto_minor:'10000',concepto:'Ensayo local',fecha:date,persona:'Cliente',referencia:null,medio:null,fiado:true,es_pago:false,pregunta:null,texto_visible:'Le fié cien soles'};
    const wrapLocal=(tipo,datos,extra={})=>({entrada:{id_local:randomUUID(),tipo:'VOZ',texto:'Le fié cien soles',propuesta:proposed},comprobante_id:null,tipo,datos,...extra});
    const operationId=randomUUID(),id=randomUUID(),payload=wrapLocal('REGISTRAR_OPERACION',{operacion:op(operationId,'VENTA',null,'10000','CREDITO',ids.client)});
    payload.entrada.id_local=id;
    assert.equal((await request('POST',path+'/comandos',{...envelope('CONFIRMAR_PROPUESTA_LOCAL',payload),dispositivo_id:bob.body.dispositivo_id},bob.body.access_token)).status,403);
    const before=(await request('GET',path+'/indicadores',undefined,token())).body;
    const created=await cmd('CONFIRMAR_PROPUESTA_LOCAL',payload,id);assert.equal(created.status,201,JSON.stringify(created.body));
    assert.equal((await cmd('CONFIRMAR_PROPUESTA_LOCAL',payload,id)).body.replayed,true);
    const operation=(await request('GET',path+'/operaciones/'+operationId,undefined,token())).body;assert.equal(operation.origen,'VOZ');assert.ok(operation.extraccion_id);assert.equal(operation.pendiente_minor,'10000');
    const extraction=await db.read(s=>s.get('extracciones',{id:operation.extraccion_id,negocio_id:bid}));assert.equal(extraction.proveedor,'LOCAL');assert.equal(extraction.estado,'CONFIRMADA');
    const pay=wrapLocal('REGISTRAR_COBRO',{movimiento:mov('4000'),aplicaciones:[{id:randomUUID(),operacion_id:operationId,monto_minor:'4000'}]});
    const paid=await cmd('CONFIRMAR_PROPUESTA_LOCAL',pay);assert.equal(paid.status,201,JSON.stringify(paid.body));assert.equal((await request('GET',path+'/operaciones/'+operationId,undefined,token())).body.pendiente_minor,'6000');
    const after=(await request('GET',path+'/indicadores',undefined,token())).body;assert.equal(BigInt(after.ventas_minor)-BigInt(before.ventas_minor),10000n);
    const bytes=Buffer.concat([require('node:fs').readFileSync(require('node:path').join(__dirname,'../../assets/branding/finki_robot.png')),Buffer.from(randomUUID())]),imageId=randomUUID();
    const upload=async(image,data=bytes,auth=token())=>{const r=await fetch(base+path+'/ia/evidencia-local?id='+image,{method:'POST',headers:{Authorization:'Bearer '+auth,'Content-Type':'application/octet-stream'},body:data});return {status:r.status,body:await r.json()};};
    assert.equal((await upload(imageId,bytes,bob.body.access_token)).status,403);
    assert.equal((await upload(imageId)).status,201);assert.equal((await upload(imageId)).body.id,imageId);
    assert.equal((await upload(randomUUID())).status,409);
    const localImage=wrapLocal('REGISTRAR_COBRO',{movimiento:mov('2000'),aplicaciones:[{id:randomUUID(),operacion_id:operationId,monto_minor:'2000'}]}, {comprobante_id:imageId,entrada:{id_local:randomUUID(),tipo:'IMAGEN',texto:'Yape de ensayo por 20 soles',propuesta:{...proposed,intencion:'DESCONOCIDO',monto_minor:'2000',medio:'YAPE',es_pago:true,referencia:'local-'+randomUUID()}}});
    const imageCommand=localImage.entrada.id_local;const imageResult=await cmd('CONFIRMAR_PROPUESTA_LOCAL',localImage,imageCommand);assert.equal(imageResult.status,201,JSON.stringify(imageResult.body));
    assert.equal((await cmd('CONFIRMAR_PROPUESTA_LOCAL',localImage,imageCommand)).body.replayed,true);
    assert.equal((await cmd('CONFIRMAR_PROPUESTA_LOCAL',{...localImage,entrada:{...localImage.entrada,id_local:randomUUID()}})).status,409);
    assert.equal((await cmd('CONFIRMAR_PROPUESTA_LOCAL',payload,randomUUID())).body.error.code,'LOCAL_ID_MISMATCH');
    assert.equal((await cmd('CONFIRMAR_PROPUESTA_LOCAL',{...payload,datos:{...payload.datos,operacion:{...payload.datos.operacion,id:randomUUID()}}})).body.error.code,'IDEMPOTENCY_CONFLICT');
    assert.equal((await request('GET',path+'/operaciones/'+operationId,undefined,token())).body.pendiente_minor,'4000');
    const evidence=await db.read(s=>s.get('comprobantes',{id:imageId,negocio_id:bid}));assert.equal(evidence.sha256,require('node:crypto').createHash('sha256').update(bytes).digest('hex'));
    const original=require('node:fs').readFileSync(require('node:path').resolve(process.env.FINKI_PRIVATE_DIR||require('node:path').join(__dirname,'../private'),evidence.storage_key));assert.ok(original.equals(bytes));
    const invalid=wrapLocal('REGISTRAR_OPERACION',{operacion:op(randomUUID(),'VENTA',null,'100','CONTADO',null),pagos_iniciales:[{...mov('100'),cuenta_id:randomUUID(),aplicacion_id:randomUUID()}]});
    const count=(await db.read(s=>s.list('extracciones',{negocio_id:bid}))).length;assert.equal((await cmd('CONFIRMAR_PROPUESTA_LOCAL',invalid)).status,404);assert.equal((await db.read(s=>s.list('extracciones',{negocio_id:bid}))).length,count);
  });
  await t.test('IA desactivada bloquea proveedor y exige consentimiento sin cargos',async()=>{
    assert.equal((await request('GET',path+'/ia/estado',undefined,token())).body.configurado,false);
    assert.equal((await request('POST',path+'/ia/analizar?id='+randomUUID(),{texto:'Vendí 35 soles'},token())).status,422);
    const blocked=await request('POST',path+'/ia/analizar?id='+randomUUID(),{texto:'Vendí 35 soles'},token(),{'X-Finki-Consent':'1'});assert.equal(blocked.status,503);assert.equal(blocked.body.error.code,'AI_NOT_CONFIGURED');
  });
  await t.test('refresh rotativo, detección de reuso y logout',async()=>{
    const renewed=await request('POST','/auth/refresh',{refresh_token:alice.body.refresh_token});assert.equal(renewed.status,200);
    assert.equal((await request('GET','/auth/me',undefined,token())).status,401);
    assert.equal((await request('GET','/auth/me',undefined,renewed.body.access_token)).status,200);
    assert.equal((await request('POST','/auth/refresh',{refresh_token:alice.body.refresh_token})).status,401);
    assert.equal((await request('GET','/auth/me',undefined,renewed.body.access_token)).status,401);
    assert.equal((await request('POST','/auth/logout',{},bob.body.access_token)).status,200);
    assert.equal((await request('GET','/auth/me',undefined,bob.body.access_token)).status,401);
  });
}
module.exports={scenario};
