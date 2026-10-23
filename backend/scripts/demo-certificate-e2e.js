'use strict';
// Explicitly authorized demo E2E only; no automatic cleanup or credential output.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{randomUUID,createHash}=require('node:crypto');
const {loadConfig}=require('../src/config'),{Database}=require('../src/repositories/database'),{tokens}=require('../src/security'),{today,canonical}=require('../src/domain');
async function main(){
 if(process.env.FINKI_DEMO_E2E!=='AUTORIZADO')throw Error('Requiere autorización explícita FINKI_DEMO_E2E=AUTORIZADO');
 const config=loadConfig();if(config.NODE_ENV!=='development'||config.DB_NAME!=='hackathon_pinguinos_dev'||config.HOST!=='127.0.0.1'||!['127.0.0.1','localhost'].includes(config.DB_HOST))throw Error('Solo desarrollo local demo');
 const db=new Database(config),manifestPath=path.resolve(__dirname,'../../build/tooling/certificate-demo-e2e.json');
 try{
  const context=await db.snapshot(async s=>{
   const rows=await s.list('negocios',{nombre:'Bodega Finki Demo',estado:'ACTIVO'});assert.equal(rows.length,1,'Negocio demo ambiguo');const business=rows[0];
   const owners=await s.list('membresias',{negocio_id:business.id,rol:'PROPIETARIO',estado:'ACTIVA'});assert.equal(owners.length,1,'Responsable demo ambiguo');const owner=owners[0];
   const devices=await s.list('dispositivos',{usuario_id:owner.usuario_id,plataforma:'ANDROID'});
   for(const d of devices.filter(d=>!d.revocado_en)){
    const sessions=await s.list('sesiones',{dispositivo_id:d.id});const active=sessions.find(x=>!x.revocado_en&&Date.parse(x.expira_en.replace(' ','T')+'Z')>Date.now());
    if(active)return {business,owner,d,active};
   }throw Error('No hay sesión Android vigente; no se escribe');
  });
  // Temporary access token bound to the EXISTING authorized session. Never saved,
  // logged or refreshed; no changes to the phone session or server secrets.
  const token=tokens(config).issue(context.owner.usuario_id,context.d.id,context.active.id,context.active.familia_id).access_token;
  const root='/negocios/'+context.business.id,base='http://127.0.0.1:3000/api/v1';
  const request=async(method,p,body)=>{const res=await fetch(base+p,{method,headers:{Authorization:'Bearer '+token,...(body?{'Content-Type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{})});const r=await res.json();if(!res.ok)throw Error(`${res.status}: ${r.error?.code||'HTTP'}`);return r;};
  const hashRows=rows=>Object.fromEntries(rows.map(r=>[r.id,createHash('sha256').update(canonical(r)).digest('hex')]));
  let m;
  if(fs.existsSync(manifestPath)){m=JSON.parse(fs.readFileSync(manifestPath));assert.equal(m.business,context.business.id);}
  else{
   const date=today(context.business.zona_horaria),ids=Object.fromEntries(['account','client','provider','saleCat','expenseCat','purchaseCat','sale','expense','purchase','credit','report'].map(k=>[k,randomUUID()]));
   const label='PRUEBA FINKI '+date+' '+ids.account.slice(0,6);
   const op=(id,type,amount,concept,mode='CONTADO',person=null)=>({id,tipo:type,categoria_id:ids[type==='VENTA'?'saleCat':type==='GASTO_OPERATIVO'?'expenseCat':'purchaseCat'],tercero_id:person,total_minor:amount,condicion:mode,fecha_operacion:date,concepto:label+' '+concept,origen:'MANUAL'});
   const move=(amount,concept)=>({id:randomUUID(),cuenta_id:ids.account,monto_minor:amount,fecha_movimiento:date,canal:'EFECTIVO',concepto:label+' '+concept});
   const steps=[];const add=(type,payload)=>steps.push({command_id:randomUUID(),dispositivo_id:context.d.id,tipo:type,payload});
   add('CREAR_CUENTA',{id:ids.account,nombre:label+' Caja',tipo:'EFECTIVO',fecha_apertura:date,saldo_inicial_minor:'0'});
   for(const [id,name]of [[ids.client,'Cliente'],[ids.provider,'Proveedor']])add('CREAR_TERCERO',{id,nombre:label+' '+name,notas:'Prueba end-to-end autorizada. No representa actividad comercial real.'});
   for(const [id,tipo]of [[ids.saleCat,'VENTA'],[ids.expenseCat,'GASTO_OPERATIVO'],[ids.purchaseCat,'COMPRA_MERCADERIA']])add('CREAR_CATEGORIA',{id,nombre:label+' '+tipo,tipo});
   add('REGISTRAR_OPERACION',{operacion:op(ids.sale,'VENTA','5000','Venta arroz'),pagos_iniciales:[{...move('5000','Cobro venta arroz'),aplicacion_id:randomUUID()}]});
   add('REGISTRAR_OPERACION',{operacion:op(ids.expense,'GASTO_OPERATIVO','1200','Gasto bolsas'),pagos_iniciales:[{...move('1200','Pago bolsas'),aplicacion_id:randomUUID()}]});
   add('REGISTRAR_OPERACION',{operacion:op(ids.purchase,'COMPRA_MERCADERIA','8000','Compra mercadería','CREDITO',ids.provider)});
   add('REGISTRAR_OPERACION',{operacion:op(ids.credit,'VENTA','2000','Venta fiada','CREDITO',ids.client)});
   add('REGISTRAR_COBRO',{movimiento:move('1000','Abono fiado'),aplicaciones:[{id:randomUUID(),operacion_id:ids.credit,monto_minor:'1000'}]});
   add('REGISTRAR_PAGO',{movimiento:move('3000','Pago parcial proveedor'),aplicaciones:[{id:randomUUID(),operacion_id:ids.purchase,monto_minor:'3000'}]});
   const before=await request('GET',root+'/indicadores?desde='+date+'&hasta='+date);
   const original=await db.snapshot(async s=>({operations:hashRows(await s.list('operaciones',{negocio_id:context.business.id})),movements:hashRows(await s.list('movimientos',{negocio_id:context.business.id}))}));
   m={business:context.business.id,date,ids,label,steps,before,original,completed:[]};fs.writeFileSync(manifestPath,JSON.stringify(m,null,2),{flag:'wx'});
  }
  for(const step of m.steps){const r=await request('POST',root+'/comandos',step);if(!m.completed.includes(step.command_id))m.completed.push(step.command_id);fs.writeFileSync(manifestPath,JSON.stringify(m,null,2));}
  const after=await request('GET',root+'/indicadores?desde='+m.date+'&hasta='+m.date);
  assert.equal(after.cuentas.find(a=>a.id===m.ids.account).saldo_registrado_minor,'1800');
  const expected={ventas_minor:7000n,cobros_ventas_minor:6000n,gastos_minor:1200n,compras_minor:8000n,por_cobrar_minor:1000n,por_pagar_minor:5000n,pagos_operativos_minor:4200n,resultado_operativo_simplificado_minor:-2200n};
  for(const [k,n]of Object.entries(expected))assert.equal(BigInt(after[k])-BigInt(m.before[k]),n,k);
  assert.equal((await request('GET',root+'/operaciones/'+m.ids.credit)).pendiente_minor,'1000');
  assert.equal((await request('GET',root+'/operaciones/'+m.ids.purchase)).pendiente_minor,'5000');
  const history=await request('GET',root+'/operaciones?q='+encodeURIComponent(m.label)+'&limit=100');assert.equal(history.items.length,4);
  const activity=await request('GET',root+'/reportes/actividad?desde='+m.date+'&hasta='+m.date);for(const k of Object.keys(expected))assert.equal(activity[k],after[k]);
  for(const [direction,id]of [['COBRAR',m.ids.credit],['PAGAR',m.ids.purchase]])assert.ok((await request('GET',root+'/pendientes?direccion='+direction+'&limit=100')).items.some(o=>o.id===id));
  const current=await db.snapshot(async s=>({operations:hashRows(await s.list('operaciones',{negocio_id:m.business})),movements:hashRows(await s.list('movimientos',{negocio_id:m.business}))}));
  for(const group of ['operations','movements'])for(const [id,hash]of Object.entries(m.original[group]))assert.equal(current[group][id],hash,'Registro previo alterado');
  const queries=[];for(const pregunta of ['Mis ventas del día','Cuánto cobré hoy','Cuánto gasté hoy','Cuánto gasté en mercadería hoy','Quién me debe más','Cuánto debo pagar'])queries.push(await request('POST',root+'/consultas',{pregunta}));
  if(!m.reportCommand)m.reportCommand={command_id:randomUUID(),dispositivo_id:context.d.id,tipo:'GENERAR_CONSTANCIA',payload:{id:m.ids.report,desde:m.date,hasta:m.date}};
  fs.writeFileSync(manifestPath,JSON.stringify(m,null,2));await request('POST',root+'/comandos',m.reportCommand);
  const file=await request('GET',root+'/constancias/'+m.ids.report);for(const k of Object.keys(expected))assert.equal(file.indicadores[k],after[k]);
  const out=path.resolve(__dirname,'../../output/pdf');fs.mkdirSync(out,{recursive:true});const pdf=path.join(out,'FINKI-constancia-PRUEBA-FINKI.pdf');fs.writeFileSync(pdf,Buffer.from(file.pdf_base64,'base64'));assert.equal(createHash('sha256').update(fs.readFileSync(pdf)).digest('hex'),file.sha256);
  const recent=await request('GET',root+'/constancias?limit=100');assert.equal(recent.items.filter(r=>r.id===m.ids.report).length,1);
  m.after=after;m.queries=queries;m.pdf=pdf;m.verified=true;fs.writeFileSync(manifestPath,JSON.stringify(m,null,2));
  console.log(JSON.stringify({business:'Bodega Finki Demo',steps:m.steps.length,operations:4,report:m.ids.report,totals:Object.fromEntries(Object.keys(expected).map(k=>[k,after[k]])),prior_records_unchanged:true,pdf},null,2));
 }finally{await db.close();}
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});


