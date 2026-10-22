'use strict';
const {writeFileSync}=require('node:fs');
const {randomBytes}=require('node:crypto');
const path=require('node:path');
const isTest=process.argv.includes('--test'),name=isTest?'.env.test':'.env';
const contents=[
'NODE_ENV='+(isTest?'test':'development'),'HOST=127.0.0.1','PORT=3000',
'DB_HOST=127.0.0.1','DB_PORT=3306','DB_NAME=hackathon_pinguinos_'+(isTest?'test':'dev'),
'DB_USER=pinguinos_'+(isTest?'test':'app'),'DB_PASSWORD=',
'JWT_SECRET='+randomBytes(48).toString('base64url'),
'JWT_REFRESH_SECRET='+randomBytes(48).toString('base64url'),
'CORS_ORIGINS=http://localhost:5173',...(isTest?['RUN_MYSQL_TESTS=0']:[])
].join('\n')+'\n';
try {
  writeFileSync(path.join(__dirname,'..',name),contents,{flag:'wx',mode:0o600});
  console.log(name+' creado sin mostrar secretos. Completar DB_USER y DB_PASSWORD localmente y revisar permisos de Windows.');
} catch(e) {
  if(e.code==='EEXIST')console.error(name+' ya existe; no se sobrescribe. Editarlo localmente.');
  else console.error('No se pudo crear el archivo privado');
  process.exitCode=1;
}
