'use strict';
const test=require('node:test');
const {randomBytes}=require('node:crypto');
const {MemoryDatabase}=require('./memory');
const {scenario}=require('./scenarios');
test('HTTP y servicios reales con repositorio EN MEMORIA (no certifica MySQL)',async t=>{
  await scenario(t,new MemoryDatabase(),{NODE_ENV:'test',JWT_SECRET:randomBytes(48).toString('hex'),JWT_REFRESH_SECRET:randomBytes(48).toString('hex'),CORS_ORIGINS:''},{faultInjection:true});
});
