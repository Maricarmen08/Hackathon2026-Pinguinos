'use strict';
// Explicit opt-in; creates two uniquely named LOCAL databases and never drops them.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {randomBytes,randomUUID}=require('node:crypto');
const mysql=require('mysql2/promise');
const {loadConfig}=require('../src/config');
const {Database}=require('../src/repositories/database');
const {authService}=require('../src/services/auth');
const {googleAuthService}=require('../src/services/google-auth');
test('003: instalación limpia y migración existente solo en bases nuevas aisladas',{skip:process.env.FINKI_GOOGLE_SCHEMA_TEST!=='YES'},async()=>{
 const local=loadConfig();assert.ok(['localhost','127.0.0.1','::1'].includes(local.DB_HOST),'Remote database forbidden');assert.equal(local.NODE_ENV,'development');
 const root=path.join(__dirname,'../../database'),suffix=randomBytes(5).toString('hex');
 const fresh='hackathon_pinguinos_google_f_'+suffix,upgrade='hackathon_pinguinos_google_u_'+suffix;
 const conn=await mysql.createConnection({host:local.DB_HOST,port:local.DB_PORT,user:local.DB_USER,password:local.DB_PASSWORD,multipleStatements:true,charset:'utf8mb4'});
 try{
  const sql=fs.readFileSync(path.join(root,'hackathon_pinguinos_dev.sql'),'utf8');
  await conn.query(sql.split('hackathon_pinguinos_dev').join(fresh));
  await conn.query('CREATE DATABASE `'+upgrade+'` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci');await conn.query('USE `'+upgrade+'`');
  const old=fs.readFileSync(path.join(root,'migrations/001_initial_schema.sql'),'utf8');
  const views=fs.readFileSync(path.join(root,'migrations/002_reporting_views.sql'),'utf8');
  for(const match of old.matchAll(/CREATE TABLE [a-z_]+ \([\s\S]*?\) ENGINE=InnoDB[^;]*;/g))await conn.query(match[0]);
  for(const match of views.matchAll(/CREATE SQL SECURITY INVOKER VIEW [\s\S]*?;/g))await conn.query(match[0]);
  await conn.query("INSERT INTO schema_migraciones(version,nombre,contrato_version) VALUES(1,'001_initial_schema.sql','1.0.0'),(2,'002_reporting_views.sql','1.0.0')");
  const id=randomUUID(),hash=await require('../src/security').hashPassword('Ficticia-Migracion-2026!');
  await conn.execute("INSERT INTO usuarios(id,nombre,telefono_normalizado,correo_normalizado,password_hash) VALUES(?,?,?,?,?)",[id,'Ensayo anterior','+51900000002','old@example.invalid',hash]);
  const migration=fs.readFileSync(path.join(root,'migrations/003_google_identity.sql'),'utf8');
  await conn.query(migration.match(/CREATE PROCEDURE[\s\S]*?END\$\$/)[0].replace(/\$\$$/,''));
  await conn.query('CALL finki_aplicar_003()');
  const [[preserved]]=await conn.execute('SELECT id,password_hash,telefono_normalizado,acceso_google FROM usuarios WHERE id=?',[id]);
  assert.equal(preserved.password_hash,hash);assert.equal(preserved.telefono_normalizado,'+51900000002');assert.equal(preserved.acceso_google,0);
  await assert.rejects(conn.query('CALL finki_aplicar_003()'));
  const columns=async schema=>(await conn.execute('SELECT table_name,column_name,column_type,is_nullable,column_default,character_set_name,collation_name FROM information_schema.columns WHERE table_schema=? ORDER BY table_name,ordinal_position',[schema]))[0];
  assert.deepEqual(await columns(fresh),await columns(upgrade));
  for(const dbName of [fresh,upgrade]){
   const [[n]]=await conn.execute("SELECT (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=? AND table_type='BASE TABLE') AS t,(SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_schema=? AND constraint_type='CHECK') AS c",[dbName,dbName]);
   assert.equal(Number(n.t),24);assert.equal(Number(n.c),114);
   const cfg={...local,DB_NAME:dbName,GOOGLE_AUTH_ENABLED:true,JWT_SECRET:randomBytes(48).toString('hex'),JWT_REFRESH_SECRET:randomBytes(48).toString('hex')};
   const db=new Database(cfg);try{
    await db.ping();let iat=100;
    const auth=authService(db,cfg),p={sub:'fixture-'+dbName,email:'fixture-'+dbName+'@example.invalid',name:'Ensayo Google'};
    if(dbName===upgrade)assert.ok((await auth.login({usuario:'old@example.invalid',clave:'Ficticia-Migracion-2026!',dispositivo:{nombre:'Migracion',plataforma:'ANDROID'}})).access_token);
    const g=googleAuthService(db,auth,async()=>({...p,iat}));
    const input={id_token:'fiction-only',nonce:'n'.repeat(36),dispositivo:{nombre:'Ensayo',plataforma:'WEB'}};
    const attempts=await Promise.allSettled([g.login(input),g.login(input)]);assert.equal(attempts.filter(a=>a.status==='fulfilled').length,1);
    const a=attempts.find(a=>a.status==='fulfilled').value;assert.equal(a.usuario.telefono,null);assert.equal(a.usuario.tiene_clave,false);assert.equal(a.usuario.version,'1');
    iat++;assert.equal((await g.login(input)).usuario.id,a.usuario.id);
    const other=googleAuthService(db,auth,async()=>({...p,sub:'another',email:'another-'+dbName+'@example.invalid',iat}));
    assert.equal((await other.login(input)).usuario.telefono,null);
    // MySQL CHECK blocks active traditional rows without credentials.
    await assert.rejects(db.transaction(s=>s.insert('usuarios',{id:randomUUID(),nombre:'Invalid',estado:'ACTIVO',telefono_normalizado:null,password_hash:null,acceso_google:0})));
   }finally{await db.close();}
  }
  console.log('PASS: '+fresh+' y '+upgrade+'; 24 tablas / 114 CHECK; fila anterior preservada; NULL, concurrencia y sesiones comprobados. Ninguna escritura en bases habituales.');
 }finally{await conn.end();}
});
