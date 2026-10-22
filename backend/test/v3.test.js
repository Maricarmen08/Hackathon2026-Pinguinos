'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {buildReport}=require('../src/services/queries');
const {renderCertificate}=require('../src/services/certificate');
const {validateProposal,mediaType,OpenAIProvider}=require('../src/services/ai-provider');
const business={id:'test',nombre:'FINKI ensayo',inicio_historial:'2025-01-15',zona_horaria:'America/Lima'};
const ops=[{id:'sale',estado:'CONFIRMADO',tipo:'VENTA',fecha_operacion:'2025-01-20',total_minor:'10000'}, {id:'sale2',estado:'CONFIRMADO',tipo:'VENTA',fecha_operacion:'2025-03-05',total_minor:'5000'}];
const moves=[{id:'m1',estado:'CONFIRMADO',fecha_movimiento:'2025-02-02',monto_minor:'4000',direccion:'ENTRADA',clase:'COBRO'},{id:'m2',estado:'CONFIRMADO',fecha_movimiento:'2025-04-02',monto_minor:'6000',direccion:'ENTRADA',clase:'COBRO'}];
const apps=[{operacion_id:'sale',movimiento_id:'m1',monto_minor:'4000'},{operacion_id:'sale',movimiento_id:'m2',monto_minor:'6000'}];
test('constancia: meses cero, inicial/final parciales, fiado y abonos exactos',()=>{
  const r=buildReport(business,ops,moves,apps,[],[],'2025-01-15','2025-04-10');
  assert.equal(r.ventas_minor,'15000');assert.equal(r.cobros_ventas_minor,'10000');assert.equal(r.por_cobrar_minor,'5000');
  assert.equal(r.meses_completos,2);assert.equal(r.promedio_mensual_ventas_minor,'2500');assert.deepEqual(r.ventas_mensuales.map(m=>m.ventas_minor),['0','5000']);
  assert.deepEqual(r.serie_mensual.map(m=>m.parcial),[true,false,false,true]);
  const cut=buildReport(business,ops,moves,apps,[],[],'2025-01-15','2025-02-28');assert.equal(cut.por_cobrar_minor,'6000');assert.equal(cut.cobros_ventas_minor,'4000');
});
test('sin actividad ni mes completo no inventa promedio',()=>{
  const r=buildReport(business,[],[],[],[],[],'2025-01-15','2025-01-20');assert.equal(r.ventas_minor,'0');assert.equal(r.promedio_mensual_ventas_minor,null);assert.equal(r.primer_registro,null);assert.equal(r.meses_con_informacion,0);
});
test('PDF real con cifras grandes, nombres extensos y periodo vacío',async()=>{
  const r=buildReport({...business,nombre:'Negocio '.repeat(24)},[{...ops[0],total_minor:'100000000000000'}],[],[],[],[],'2025-01-15','2025-04-10');
  const pdf=await renderCertificate({...r,corte_sync_seq:'123'},'00000000-0000-4000-8000-000000000001','2026-10-22 12:00:00');assert.equal(pdf.subarray(0,5).toString(),'%PDF-');assert.ok(pdf.length>3000);
});
const proposal={intencion:'VENTA',monto_minor:'3500',concepto:'Pago',fecha:null,persona:null,referencia:null,medio:'YAPE',fiado:false,es_pago:true,pregunta:null,texto_visible:'Pago recibido'};
test('OCR: captura de pago exige clasificación y rechaza importe inventado/inválido',()=>{
  const p=validateProposal(proposal);assert.equal(p.intencion,'DESCONOCIDO');assert.ok(p.pregunta.includes('abono'));
  for(const monto_minor of ['0','-1','1.5','100000000000001'])assert.throws(()=>validateProposal({...proposal,monto_minor}));
  assert.throws(()=>validateProposal({...proposal,fecha:'2025-02-30'}));
});
test('proveedor desactivado no llama la red; validación MIME por firma',async()=>{
  let called=false;const provider=new OpenAIProvider({AI_ENABLED:false,OPENAI_API_KEY:''},()=>{called=true;});
  await assert.rejects(provider.transcribe(Buffer.alloc(50),'audio/wav'),e=>e.code==='AI_NOT_CONFIGURED');assert.equal(called,false);
  assert.throws(()=>mediaType(Buffer.from('fake.jpg')),e=>e.code==='UNSUPPORTED_MEDIA');
});
test('adaptador transcripción y extracción usa contratos HTTP (doble explícito, no prueba proveedor real)',async()=>{
  const endpoints=[];const provider=new OpenAIProvider({AI_ENABLED:true,OPENAI_API_KEY:'test-only',AI_TRANSCRIPTION_MODEL:'test',AI_EXTRACTION_MODEL:'test'},async(url,opts)=>{endpoints.push(url);assert.match(opts.headers.Authorization,/Bearer/);return {ok:true,json:async()=>url.endsWith('transcriptions')?{text:'Vendí 35 soles'}:{choices:[{message:{content:JSON.stringify({...proposal,es_pago:false,medio:'EFECTIVO'})}}]}};});
  assert.equal(await provider.transcribe(Buffer.alloc(50),'audio/wav'),'Vendí 35 soles');
  const p=await provider.extract({text:'Vendí 35 soles',today:'2026-10-22'});assert.equal(p.monto_minor,'3500');assert.equal(endpoints.length,2);
});
