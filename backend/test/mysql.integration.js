'use strict';
const test=require('node:test');
const {loadConfig}=require('../src/config');
const {Database}=require('../src/repositories/database');
const {scenario}=require('./scenarios');
require('dotenv').config({path:require('node:path').join(__dirname,'../.env.test'),quiet:true});
test('Integración REAL MySQL aislado', {skip:process.env.RUN_MYSQL_TESTS!=='1'},async t=>{
  const config=loadConfig(process.env,'.env.test');
  if(config.NODE_ENV!=='test'||config.DB_NAME!=='hackathon_pinguinos_test')throw new Error('Solo NODE_ENV=test y DB_NAME=hackathon_pinguinos_test; desarrollo prohibido');
  const db=new Database(config);
  try{await db.ping();}catch(e){await db.close();throw e;}
  await scenario(t,db,config);
});
