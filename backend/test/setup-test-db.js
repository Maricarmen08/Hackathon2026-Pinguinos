'use strict';
// Preparación EXPLÍCITA de una base VACÍA de pruebas. Nunca invocado por npm test.
// No altera los archivos aprobados ni ejecuta su instalador calificado a _dev.
const {readFileSync}=require('node:fs'),path=require('node:path');
const {loadConfig}=require('../src/config');
const {Database}=require('../src/repositories/database');
async function setup() {
  require('dotenv').config({path:path.join(__dirname,'../.env.test'),quiet:true});
  const c=loadConfig(process.env,'.env.test');
  if(c.NODE_ENV!=='test'||c.DB_NAME!=='hackathon_pinguinos_test'||process.env.ALLOW_TEST_SCHEMA_SETUP!=='YES')throw new Error('Solo base hackathon_pinguinos_test VACIA y ALLOW_TEST_SCHEMA_SETUP=YES');
  const db=new Database(c);let connection;
  try {
    connection=await db.connection();
    const [[server]]=await connection.query('SELECT VERSION() AS version,DATABASE() AS db,CURRENT_USER() AS account');
    if(!server.version.startsWith('8.4.')||server.db!=='hackathon_pinguinos_test'||server.account.split('@')[0].toLowerCase()==='root')throw new Error('Servidor/cuenta/destino no autorizados para preparación aislada');
    const [[count]]=await connection.execute('SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema=?',[c.DB_NAME]);
    if(Number(count.n)!==0)throw new Error('La base de pruebas no está vacía: no se modifica ni reinicializa');
    const schema=readFileSync(path.join(__dirname,'../../database/migrations/001_initial_schema.sql'),'utf8');
    const views=readFileSync(path.join(__dirname,'../../database/migrations/002_reporting_views.sql'),'utf8');
    const tables=[...schema.matchAll(/CREATE TABLE [a-z_]+ \([\s\S]*?\) ENGINE=InnoDB[^;]*;/g)].map(m=>m[0]);
    const viewStatements=[...views.matchAll(/CREATE SQL SECURITY INVOKER VIEW [\s\S]*?;/g)].map(m=>m[0]);
    if(tables.length!==23||viewStatements.length!==5)throw new Error('Formato/versión de migraciones no esperado');
    for(const statement of [...tables,...viewStatements])await connection.query(statement);
    await connection.execute("INSERT INTO schema_migraciones(version,nombre,contrato_version) VALUES(1,'001_initial_schema.sql','1.0.0'),(2,'002_reporting_views.sql','1.0.0')");
    console.log('Esquema de pruebas preparado desde DDL aprobado, sin demo ni cambios en desarrollo.');
  } finally {if(connection)connection.release();await db.close();}
}
if(require.main===module)setup().catch(()=>{console.error('Preparación de pruebas abortada. Revisar destino, permisos y estado parcial: DDL no es reversible. No borrar automáticamente.');process.exitCode=1;});
module.exports={setup};
