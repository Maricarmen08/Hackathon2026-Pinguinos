'use strict';
// Explicit, one-time local provisioning. Never resets an existing database/user.
const mysql=require('mysql2/promise'),fs=require('node:fs'),path=require('node:path');
const {randomBytes}=require('node:crypto');
async function main(){
  if(process.argv[2]!=='--authorized-isolated-setup')throw new Error('Requiere autorización explícita');
  const filename=path.join(__dirname,'../.env.test');
  if(fs.existsSync(filename))throw new Error('.env.test ya existe; revisar sin sobrescribir');
  const admin=require('dotenv').parse(fs.readFileSync(path.join(__dirname,'../.env')));
  if(admin.NODE_ENV!=='development'||admin.HOST!=='127.0.0.1'||!['localhost','127.0.0.1'].includes(admin.DB_HOST))throw new Error('Solo administrador MySQL local de desarrollo');
  const c=await mysql.createConnection({host:admin.DB_HOST,port:Number(admin.DB_PORT||3306),user:admin.DB_USER,password:admin.DB_PASSWORD,multipleStatements:false});
  const secret=randomBytes(32).toString('hex');
  try{
    const [[version]]=await c.query('SELECT VERSION() AS v');if(!version.v.startsWith('8.4.'))throw new Error('MySQL 8.4 requerido');
    const [dbs]=await c.execute('SELECT SCHEMA_NAME FROM information_schema.schemata WHERE SCHEMA_NAME=?',['hackathon_pinguinos_test']);
    const [users]=await c.execute('SELECT User FROM mysql.user WHERE User=?',['finki_integration']);
    if(dbs.length||users.length)throw new Error('Base o usuario ya existen: no se reemplazan');
    await c.query('CREATE DATABASE hackathon_pinguinos_test CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci');
    await c.query("CREATE USER 'finki_integration'@'127.0.0.1' IDENTIFIED BY ?",[secret]);
    await c.query("GRANT CREATE, CREATE VIEW, REFERENCES, SELECT, INSERT, UPDATE ON hackathon_pinguinos_test.* TO 'finki_integration'@'127.0.0.1'");
    fs.writeFileSync(filename,[ 'NODE_ENV=test','HOST=127.0.0.1','PORT=0',`DB_HOST=${admin.DB_HOST}`,`DB_PORT=${admin.DB_PORT||3306}`,'DB_NAME=hackathon_pinguinos_test','DB_USER=finki_integration',`DB_PASSWORD=${secret}`,`JWT_SECRET=${randomBytes(48).toString('hex')}`,`JWT_REFRESH_SECRET=${randomBytes(48).toString('hex')}`,'CORS_ORIGINS=','RUN_MYSQL_TESTS=0',''].join('\n'),{flag:'wx',mode:0o600});
    console.log('Base y credenciales aisladas preparadas. Desarrollo no modificado.');
  }finally{await c.end();}
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
