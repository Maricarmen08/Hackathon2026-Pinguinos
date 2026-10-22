'use strict';
const {loadConfig}=require('./src/config');
const {Database}=require('./src/repositories/database');
const {createApp}=require('./src/app');
async function start() {
  const config=loadConfig(),db=new Database(config);
  // Fallar antes de escuchar si credenciales, versión o migraciones no son válidas.
  try { await db.ping(); }
  catch(e) { await db.close();throw e; }
  const server=createApp({db,config}).listen(config.PORT,config.HOST,()=>{
    console.log(JSON.stringify({event:'listening',host:config.HOST,port:server.address().port,api:'/api/v1'}));
  });
  server.headersTimeout=10000;server.requestTimeout=15000;
  const shutdown=()=>{server.close(()=>db.close().finally(()=>process.exit(0)));setTimeout(()=>process.exit(1),10000).unref();};
  process.once('SIGINT',shutdown);process.once('SIGTERM',shutdown);
  server.on('error',async()=>{console.error('No se pudo abrir el puerto HTTP configurado');await db.close();process.exitCode=1;});
  return {server,db};
}
if(require.main===module)start().catch(e=>{
  // No imprimir objetos de configuración, cadenas de conexión o error SQL completo.
  console.error(e.message.startsWith('Configuración')?e.message:'No se pudo iniciar: verificar MySQL 8.4, migraciones y credenciales del usuario de aplicación.');
  process.exitCode=1;
});
module.exports={start};
