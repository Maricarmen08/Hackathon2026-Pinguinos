'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {GeminiProvider,DailyBudget,MODEL}=require('../src/services/gemini-provider');
const {createProvider,OpenAIProvider}=require('../src/services/ai-provider');
const config={AI_PROVIDER:'gemini',AI_ENABLED:true,GEMINI_API_KEY:'mock-not-a-real-key',GEMINI_MODEL:MODEL};
const p={intencion:'VENTA',monto_minor:'4500',concepto:'gaseosas',fecha:'2026-10-22',persona:null,referencia:null,medio:'EFECTIVO',fiado:false,es_pago:false,pregunta:null,texto_visible:'Vendí 45 soles de gaseosas'};
const reply=(value,reason='STOP')=>new Response(JSON.stringify({candidates:[{finishReason:reason,content:{parts:[{text:JSON.stringify(value)}]}}]}));
const budget=()=>({reserve(){}});
const circuit=()=>({check(){},block(){},success(){},availability(){return {disponible:true};}});
test('selección explícita Gemini/OpenAI y proveedor desconocido',()=>{
  assert.ok(createProvider(config) instanceof GeminiProvider);
  assert.ok(createProvider({...config,AI_PROVIDER:'openai'}) instanceof OpenAIProvider);
  assert.throws(()=>createProvider({...config,AI_PROVIDER:'unknown'}));
});
test('apagado o sin clave bloquea toda llamada',async()=>{
  for(const c of [{AI_ENABLED:false},{GEMINI_API_KEY:''},{GEMINI_MODEL:'paid-model'}]){
    const g=new GeminiProvider({...config,...c},()=>{throw new Error('NETWORK MUST NOT RUN');},budget(),circuit());
    await assert.rejects(g.extract({text:'venta',today:p.fecha}),e=>e.code==='AI_NOT_CONFIGURED');
  }
});
test('REST oficial, clave solo cabecera, esquema y propuesta editable; imagen y transcripción',async()=>{
  let calls=0;
  const g=new GeminiProvider(config,async(url,opts)=>{
    calls++;assert.equal(url,`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`);
    assert.ok(!url.includes(config.GEMINI_API_KEY));assert.equal(opts.headers['x-goog-api-key'],config.GEMINI_API_KEY);
    const b=JSON.parse(opts.body);assert.equal(b.generationConfig.maxOutputTokens,1800);assert.equal(b.generationConfig.responseFormat.text.mimeType,'APPLICATION_JSON');assert.equal(b.tools,undefined);
    if(calls===2){assert.equal(b.contents[0].parts[1].inlineData.mimeType,'image/png');return reply({...p,es_pago:false,medio:'YAPE'});}
    return reply(calls===3?{text:'Hoy vendí 45 soles en gaseosas'}:p);
  },budget(),circuit());
  assert.deepEqual(await g.extract({text:'Hoy vendí 45 soles en gaseosas',today:p.fecha}),p);
  const image=await g.extract({image:Buffer.from('mock image'),mime:'image/png',today:p.fecha});assert.equal(image.intencion,'DESCONOCIDO');assert.match(image.pregunta,/abono/);
  assert.equal(await g.transcribe(Buffer.alloc(50),'audio/wav'),'Hoy vendí 45 soles en gaseosas');
});
test('errores, cuota, JSON, campos extra, truncamiento y bloqueo: nunca acepta datos inválidos',async()=>{
  for(const [transport,code] of [
    [async()=>new Response('',{status:429}),'AI_QUOTA_EXHAUSTED'],
    [async()=>new Response('private details',{status:403}),'AI_PROVIDER_UNAVAILABLE'],
    [async()=>{throw Error('network secret');},'AI_PROVIDER_UNAVAILABLE'],
    [async()=>new Response('invalid'),'AI_INVALID_PROPOSAL'],
    [async()=>reply({...p,monto_minor:'-1'}),'AI_INVALID_PROPOSAL'],
    [async()=>reply({...p,sql:'DELETE'}),'AI_INVALID_PROPOSAL'],
    [async()=>reply(p,'MAX_TOKENS'),'AI_UNCLEAR'],
    [async()=>new Response(JSON.stringify({promptFeedback:{blockReason:'SAFETY'}})),'AI_UNCLEAR'],
    [async()=>new Response('x'.repeat(140000)),'AI_INVALID_PROPOSAL']
  ])await assert.rejects(new GeminiProvider(config,transport,budget(),circuit()).extract({text:'venta',today:p.fecha}),e=>e.code===code&&!e.message.includes('private'));
});
test('límites de entrada y concurrencia impiden solicitudes adicionales',async()=>{
  let resolve,calls=0;const g=new GeminiProvider(config,()=>{calls++;return new Promise(r=>resolve=r);},budget(),circuit());
  await assert.rejects(g.extract({text:'x'.repeat(6001)}),e=>e.status===413);
  await assert.rejects(g.transcribe(Buffer.alloc(1500001),'audio/wav'),e=>e.code==='INVALID_AUDIO');
  const pending=g.extract({text:'venta',today:p.fecha});
  await assert.rejects(g.extract({text:'venta',today:p.fecha}),e=>e.code==='AI_BUSY');resolve(reply(p));await pending;assert.equal(calls,1);
});
test('presupuesto persiste entre instancias, falla cerrado y limita frecuencia',()=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'finki-gemini-')),file=path.join(dir,'budget.json');let now=Date.parse('2026-10-22T00:00Z');
  try{
    const b=new DailyBudget(file,3,()=>now);b.reserve();b.reserve();assert.throws(()=>b.reserve(),e=>e.code==='AI_QUOTA_EXHAUSTED');
    now+=60001;b.reserve();assert.throws(()=>new DailyBudget(file,3,()=>now).reserve(),e=>e.code==='AI_QUOTA_EXHAUSTED');
    now+=86400000;new DailyBudget(file,3,()=>now).reserve();
    fs.writeFileSync(file,'broken');assert.throws(()=>b.reserve(),e=>e.code==='AI_BUDGET_UNAVAILABLE');
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
