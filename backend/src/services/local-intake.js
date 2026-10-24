'use strict';
const {randomUUID,createHash}=require('node:crypto');
const path=require('node:path'),{mkdir,writeFile}=require('node:fs/promises');
const {fail}=require('../errors');
const {membership,requireSession}=require('./auth');
const {mediaType}=require('./ai-provider');
const {saveProposal,confirmProposal}=require('./intake');

async function saveEvidence(s,business,actor,p,changed){
  const existing=await s.get('comprobantes',{id:p.id,negocio_id:business.id});
  if(existing){if(existing.sha256!==p.sha256)fail(409,'IDEMPOTENCY_CONFLICT','La imagen cambió. Revisa el registro.');return;}
  if(await s.get('comprobantes',{negocio_id:business.id,sha256:p.sha256}))fail(409,'DUPLICATE_EVIDENCE','Esta imagen ya está guardada. Revisa el registro existente.');
  await s.insert('comprobantes',{...p,creado_por:actor.sub,negocio_id:business.id});
  changed.push({tabla:'comprobantes',registro:await s.get('comprobantes',{id:p.id,negocio_id:business.id})});
}

function localEvidenceService(db,execute){
  return async(bid,actor,id,bytes)=>{
    await db.read(async s=>{await requireSession(s,actor);await membership(s,bid,actor.sub,true);});
    const mime=mediaType(bytes);if(!mime.startsWith('image/'))fail(422,'UNSUPPORTED_MEDIA','Usa una imagen PNG o JPEG');
    const sha=createHash('sha256').update(bytes).digest('hex');
    const previous=await db.read(s=>s.get('comprobantes',{id,negocio_id:bid}));
    if(previous){if(previous.sha256!==sha)fail(409,'IDEMPOTENCY_CONFLICT','La imagen cambió. Revisa el registro.');return {id,sha256:sha};}
    const dir=path.resolve(process.env.FINKI_PRIVATE_DIR||path.join(__dirname,'../../private'),'evidence',bid);
    await mkdir(dir,{recursive:true,mode:0o700});
    await writeFile(path.join(dir,sha),bytes,{flag:'wx',mode:0o600}).catch(e=>{if(e.code!=='EEXIST')throw e;});
    await execute(bid,{command_id:randomUUID(),dispositivo_id:actor.did,tipo:'GUARDAR_EVIDENCIA_LOCAL_INTERNA',payload:{id,sha256:sha,mime_type:mime,bytes:bytes.length,tipo:'OTRO',estado_archivo:'DISPONIBLE',storage_key:path.posix.join('evidence',bid,sha),moneda:null}},actor);
    return {id,sha256:sha};
  };
}

async function confirmLocal(s,business,actor,p,changed,financial){
  if(p.entrada.tipo==='IMAGEN'&&!p.comprobante_id)fail(422,'EVIDENCE_REQUIRED','Conserva la imagen antes de confirmar');
  if(p.comprobante_id){
    const image=await s.get('comprobantes',{id:p.comprobante_id,negocio_id:business.id});
    if(!image||image.estado_archivo!=='DISPONIBLE')fail(404,'NOT_FOUND','Imagen no disponible en tu negocio');
    if(await s.get('extracciones',{negocio_id:business.id,comprobante_id:p.comprobante_id}))fail(409,'DUPLICATE_EVIDENCE','Esta imagen ya tiene una propuesta. Revisa el registro existente.');
  }
  const id=randomUUID(); // Server extraction identity, created atomically after human confirmation.
  await saveProposal(s,business,actor,{id,kind:p.comprobante_id?'IMAGEN':'TEXTO',text:p.entrada.texto,result:p.entrada.propuesta,provider:'LOCAL',model:'reglas-1.0.0',localSource:p.entrada.tipo,comprobanteId:p.comprobante_id},changed);
  await confirmProposal(s,business,actor,{extraccion_id:id,tipo:p.tipo,datos:p.datos},changed,financial);
}
module.exports={localEvidenceService,saveEvidence,confirmLocal};
