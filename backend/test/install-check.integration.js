'use strict';
// Prueba funcional COMPLETA sobre la base temporal hackathon_pinguinos_install_check.
// La invoca scripts/verify-install.js; nunca se ejecuta con npm test (no termina en .test.js).
const test=require('node:test');
const {loadConfig}=require('../src/config');
const {Database}=require('../src/repositories/database');
const {scenario}=require('./scenarios');
const TARGET='hackathon_pinguinos_install_check';
test('Instalación nueva desde database/hackathon_pinguinos_dev.sql',{skip:process.env.FINKI_INSTALL_CHECK!=='1'},async t=>{
  const config=loadConfig({...process.env},'.env.install-check');
  if(config.DB_NAME!==TARGET)throw new Error('Solo '+TARGET+'; desarrollo y pruebas prohibidos');
  const db=new Database(config);
  if(process.env.FINKI_ALLOW_NON_84!=='1'){try{await db.ping();}catch(e){await db.close();throw e;}}
  await scenario(t,db,config);
});
