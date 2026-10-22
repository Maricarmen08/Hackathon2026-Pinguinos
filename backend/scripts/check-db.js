'use strict';
const {loadConfig}=require('../src/config');
const {Database}=require('../src/repositories/database');
(async()=>{
  let db;
  try {
    const config=loadConfig();db=new Database(config);await db.ping();
    console.log('PASS: conexión MySQL 8.4 con configuración autorizada y migraciones 001/002.');
  } catch(e) {
    const safeCodes=new Set(['ECONNREFUSED','ETIMEDOUT','ER_ACCESS_DENIED_ERROR','ER_DBACCESS_DENIED_ERROR','ER_BAD_DB_ERROR']);
    console.error(e.message.startsWith('Configuración')?e.message:'Conexión no verificada: '+(safeCodes.has(e.code)?e.code:'verificar servidor, permisos y migraciones')+'. No se escribieron datos.');
    process.exitCode=1;
  } finally {if(db)await db.close();}
})();
