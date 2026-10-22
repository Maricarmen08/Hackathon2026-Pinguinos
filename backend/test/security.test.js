'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {randomBytes}=require('node:crypto');
const {once}=require('node:events');
const {createApp}=require('../src/app');
const {MemoryDatabase}=require('./memory');
test('HTTP: cabeceras, CORS, tamaño JSON y límite de autenticación',async t=>{
  const app=createApp({db:new MemoryDatabase(),config:{JWT_SECRET:randomBytes(48).toString('hex'),JWT_REFRESH_SECRET:randomBytes(48).toString('hex'),CORS_ORIGINS:'https://permitido.example.invalid'}});
  const server=app.listen(0,'127.0.0.1');await once(server,'listening');
  t.after(()=>new Promise(resolve=>server.close(resolve)));
  const base='http://127.0.0.1:'+server.address().port+'/api/v1';
  const live=await fetch(base+'/health/live');assert.equal(live.status,200);assert.equal(live.headers.get('x-powered-by'),null);assert.equal(live.headers.get('cache-control'),'no-store');
  assert.equal((await fetch(base+'/health/live',{headers:{Origin:'https://ajeno.example.invalid'}})).status,403);
  assert.equal((await fetch(base+'/auth/registro',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({nombre:'x'.repeat(70000)})})).status,413);
  for(let i=0;i<10;i++)assert.equal((await fetch(base+'/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'})).status,422);
  assert.equal((await fetch(base+'/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'})).status,429);
});
