'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {GeminiProvider}=require('../src/services/gemini-provider');
const {ProviderCircuit}=require('../src/services/provider-circuit');
test('429 persiste, bloquea nuevas llamadas y permite una petición controlada tras Retry-After',async()=>{
  const dir=fs.mkdtempSync(path.join(os.tmpdir(),'finki-circuit-'));let now=Date.parse('2026-10-22T00:00Z'),calls=0;
  const filename=path.join(dir,'quota.json'),config={AI_ENABLED:true,GEMINI_API_KEY:'mock-only'},budget={reserve(){}};
  const transport=async()=>{calls++;return new Response('',{status:429,headers:{'retry-after':'120'}});};
  try{
    const create=()=>new GeminiProvider(config,transport,budget,new ProviderCircuit(filename,()=>now));
    await assert.rejects(create().extract({text:'ensayo',today:'2026-10-22'}),e=>e.code==='AI_QUOTA_EXHAUSTED');
    assert.equal(create().availability().disponible,false);
    for(let n=0;n<4;n++)await assert.rejects(create().extract({text:'ensayo'}),e=>e.code==='AI_QUOTA_EXHAUSTED');
    assert.equal(calls,1);now+=120001;
    assert.equal(create().availability().disponible,true);
    await assert.rejects(create().extract({text:'ensayo'}),e=>e.code==='AI_QUOTA_EXHAUSTED');assert.equal(calls,2);
    fs.writeFileSync(filename,'broken');assert.throws(()=>create().availability(),e=>e.code==='AI_BUDGET_UNAVAILABLE');
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
