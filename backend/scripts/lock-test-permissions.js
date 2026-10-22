'use strict';
const fs=require('node:fs'),path=require('node:path'),mysql=require('mysql2/promise');
async function main(){
  const c=require('dotenv').parse(fs.readFileSync(path.join(__dirname,'../.env')));
  if(c.NODE_ENV!=='development'||c.HOST!=='127.0.0.1'||!['127.0.0.1','localhost'].includes(c.DB_HOST))throw new Error('Solo MySQL local');
  const db=await mysql.createConnection({host:c.DB_HOST,port:Number(c.DB_PORT||3306),user:c.DB_USER,password:c.DB_PASSWORD});
  try{await db.query("REVOKE CREATE, CREATE VIEW, REFERENCES ON hackathon_pinguinos_test.* FROM 'finki_integration'@'127.0.0.1'");console.log('Retirados permisos de instalación. Usuario de pruebas limitado a SELECT, INSERT y UPDATE en _test.');}finally{await db.end();}
}
main().catch(()=>{console.error('No se pudieron retirar permisos de preparación de pruebas; revisar localmente.');process.exitCode=1;});
