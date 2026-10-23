'use strict';

const {mkdir,writeFile,readFile}=require('node:fs/promises');
const path=require('node:path');
const {createHash}=require('node:crypto');
const {buildReport}=require('./queries');
const {today,json}=require('../domain');
const {utc}=require('./auth');
const {fail}=require('../errors');
const digest=b=>createHash('sha256').update(b).digest('hex');
const storage=()=>path.resolve(process.env.FINKI_PRIVATE_DIR||path.join(__dirname,'../../private'));
function soles(value){if(value==null)return 'Sin meses completos';const n=BigInt(value),a=n<0n?-n:n;return `${n<0n?'-':''}S/ ${a/100n}.${String(a%100n).padStart(2,'0')}`;}
function renderCertificate(r,id,generated) { return require('./certificate-renderer')(r,id,generated,soles); }
async function createCertificate(s,business,actor,payload,counter){
  if(payload.desde>payload.hasta||payload.hasta>today(business.zona_horaria)||Number(payload.hasta.slice(0,4))-Number(payload.desde.slice(0,4))>10)fail(422,'INVALID_PERIOD','Elige un periodo válido de hasta diez años, sin fechas futuras');
  const data=await Promise.all(['operaciones','movimientos','aplicaciones','cuentas','cierres_diarios'].map(t=>s.list(t,{negocio_id:business.id})));
  const owners=await s.list('membresias',{negocio_id:business.id,rol:'PROPIETARIO',estado:'ACTIVA'});
  const owner=owners[0]?await s.get('usuarios',{id:owners[0].usuario_id}):null;
  const r={...buildReport(business,...data,payload.desde,payload.hasta),corte_sync_seq:String(counter.ultimo_seq),titular_nombre:owner?.nombre||null,zona_horaria:business.zona_horaria,version_documento:'2.0'};
  // Do not persist private operational rows in report summaries or sync payloads.
  delete r.cuentas;delete r.pendientes;
  const generated=utc(new Date()),bytes=await renderCertificate(r,payload.id,generated),sha=digest(bytes);
  const dir=path.join(storage(),'reports',business.id);await mkdir(dir,{recursive:true,mode:0o700});
  const key=path.posix.join('reports',business.id,`${sha}.pdf`);
  await writeFile(path.join(storage(),key),bytes,{flag:'wx',mode:0o600}).catch(e=>{if(e.code!=='EEXIST')throw e;});
  // A SQL rollback can leave an unreferenced private file; never a published report.
  await s.insert('reportes',{id:payload.id,negocio_id:business.id,desde:payload.desde,hasta:payload.hasta,zona_horaria:business.zona_horaria,moneda:'PEN',version_formula:r.version_formula,corte_sync_seq:r.corte_sync_seq,estado:'LISTO',parametros:{desde:payload.desde,hasta:payload.hasta},indicadores:r,storage_key:key,sha256:sha,generado_en:generated,creado_por:actor.sub});
  return s.get('reportes',{id:payload.id,negocio_id:business.id});
}
async function certificateFile(row){
  if(row.estado!=='LISTO'||!row.sha256||!/^reports\/[a-f0-9-]{36}\/[a-f0-9]{64}\.pdf$/.test(row.storage_key||''))fail(409,'REPORT_NOT_READY','La constancia no está disponible');
  let bytes;try{bytes=await readFile(path.join(storage(),row.storage_key));}catch{fail(503,'REPORT_FILE_MISSING','No se encuentra el archivo de la constancia');}
  if(digest(bytes)!==row.sha256)fail(503,'REPORT_INTEGRITY','El archivo requiere revisión de integridad');
  return {id:row.id,sha256:row.sha256,pdf_base64:bytes.toString('base64'),indicadores:json(row.indicadores)};
}
module.exports={renderCertificate,createCertificate,certificateFile,soles};

