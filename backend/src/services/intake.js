'use strict';
const {randomUUID,createHash}=require('node:crypto');
const path=require('node:path'),{mkdir,writeFile}=require('node:fs/promises');
const {fail}=require('../errors');
const {json,today,nextVersion}=require('../domain');
const {membership,requireSession,utc}=require('./auth');
const {mediaType}=require('./ai-provider');
const hash=b=>createHash('sha256').update(b).digest('hex');
async function saveProposal(s,business,actor,p,changed){
  const found=p.sha256&&(await s.get('comprobantes',{negocio_id:business.id,sha256:p.sha256}));
  if(found)fail(409,'DUPLICATE_EVIDENCE','Esta imagen o grabación ya fue analizada. Revisa tu historial.');
  if(p.evidence){await s.insert('comprobantes',p.evidence);changed.push({tabla:'comprobantes',registro:await s.get('comprobantes',{id:p.evidence.id,negocio_id:business.id})});}
  const row={id:p.id,negocio_id:business.id,comprobante_id:p.evidence?.id||null,tipo_entrada:p.kind,texto_entrada:p.text||null,texto_extraido:p.result.texto_visible,proveedor:p.provider||'OpenAI',modelo:p.model,version_esquema:'1.0.0',estado:'REQUIERE_REVISION',resultado:p.result,correccion_usuario:{consentimiento:{version:p.consentVersion||'legacy-v3',proveedor:p.provider||'OpenAI',aceptado_en:utc(new Date()),usuario_id:actor.sub}},creado_por:actor.sub};
  await s.insert('extracciones',row);changed.push({tabla:'extracciones',registro:await s.get('extracciones',{id:p.id,negocio_id:business.id})});
}
function intakeService(db,execute,provider){
  const running=new Map();
  return async(bid,actor,{bytes,text,consent,id,consentVersion})=>{
    if(consent!==true)fail(422,'CONSENT_REQUIRED','Autoriza enviar esta entrada al proveedor antes de continuar');
    provider.check();
    await db.read(async s=>{await requireSession(s,actor);await membership(s,bid,actor.sub,true);});
    const mime=bytes?mediaType(bytes):null,sha=bytes?hash(bytes):null,key=bid+':'+(sha||hash(text||''));
    if(running.has(key))fail(409,'ANALYSIS_RUNNING','Esta entrada ya se está analizando');
    running.set(key,true);
    try{
      const previous=await db.read(s=>s.get('extracciones',{id,negocio_id:bid}));
      if(previous){
        if(previous.estado!=='REQUIERE_REVISION')fail(409,'PROPOSAL_UNAVAILABLE','Esta propuesta ya se revisó. Consulta tus registros o crea otra entrada.');
        return {id:previous.id,resultado:json(previous.resultado),estado:previous.estado,transcripcion:previous.tipo_entrada==='AUDIO'?previous.texto_entrada:null};
      }
      if(sha&&await db.read(s=>s.get('comprobantes',{negocio_id:bid,sha256:sha})))fail(409,'DUPLICATE_EVIDENCE','Esta imagen o grabación ya fue analizada. Revisa tu historial.');
      let transcript=text||null;
      if(mime==='audio/wav')transcript=await provider.transcribe(bytes,mime);
      const result=await provider.extract({text:transcript,image:mime?.startsWith('image/')?bytes:null,mime,today:today()});
      let evidence;
      if(bytes){
        const dir=path.resolve(process.env.FINKI_PRIVATE_DIR||path.join(__dirname,'../../private'),'evidence',bid);await mkdir(dir,{recursive:true,mode:0o700});
        await writeFile(path.join(dir,sha),bytes,{flag:'wx',mode:0o600}).catch(e=>{if(e.code!=='EEXIST')throw e;});
        evidence={id:randomUUID(),negocio_id:bid,tipo:mime==='audio/wav'?'AUDIO':result.medio==='YAPE'?'YAPE':result.medio==='PLIN'?'PLIN':'OTRO',storage_key:path.posix.join('evidence',bid,sha),mime_type:mime,bytes:bytes.length,sha256:sha,estado_archivo:'DISPONIBLE',referencia_externa:result.referencia,total_minor:result.monto_minor,moneda:'PEN',creado_por:actor.sub};
      }
      await execute(bid,{command_id:randomUUID(),dispositivo_id:actor.did,tipo:'GUARDAR_PROPUESTA_INTERNA',payload:{id,sha256:sha,kind:mime==='audio/wav'?'AUDIO':bytes?'IMAGEN':'TEXTO',text:transcript,result,evidence,consentVersion,provider:provider.name,model:provider.model||provider.config.AI_EXTRACTION_MODEL}},actor);
      return {id,resultado:result,estado:'REQUIERE_REVISION',transcripcion:mime==='audio/wav'?transcript:null};
    }finally{running.delete(key);}
  };
}
async function confirmProposal(s,business,actor,p,changed,financial){
  const row=await s.get('extracciones',{id:p.extraccion_id,negocio_id:business.id},'update');
  if(!row||row.estado!=='REQUIERE_REVISION')fail(409,'PROPOSAL_UNAVAILABLE','Esta propuesta ya fue confirmada o no está disponible');
  const before=changed.length;
  const extracted=json(row.resultado);
  let targets;
  if(p.tipo==='VINCULAR_EVIDENCIA'){
    if(!row.comprobante_id)fail(422,'EVIDENCE_REQUIRED','Esta propuesta no tiene un archivo para vincular');
    const existing=await s.get(p.datos.tabla,{id:p.datos.id,negocio_id:business.id});
    if(!existing||existing.estado!=='CONFIRMADO')fail(404,'NOT_FOUND','Registro no disponible en tu negocio');
    if(extracted.monto_minor!==null&&String(existing.total_minor??existing.monto_minor)!==extracted.monto_minor)fail(422,'EVIDENCE_AMOUNT_MISMATCH','El importe no coincide con el registro seleccionado');
    targets=[{tabla:p.datos.tabla,registro:existing}];
  }else{
    const ref=extracted.referencia;
    if(ref){
      const prior=await s.get('movimientos',{negocio_id:business.id,referencia_externa:ref,estado:'CONFIRMADO'});
      if(prior)fail(409,'POSSIBLE_DUPLICATE','Ya existe un movimiento con esta referencia. Vincula el comprobante al registro existente.');
      if(p.datos.movimiento)p.datos.movimiento.referencia_externa=ref;
      for(const payment of p.datos.pagos_iniciales||[])payment.referencia_externa=ref;
    }
  if(p.tipo==='REGISTRAR_OPERACION')p.datos.operacion={...p.datos.operacion,origen:row.tipo_entrada==='AUDIO'?'VOZ':row.tipo_entrada==='IMAGEN'?'IMAGEN':'MANUAL',extraccion_id:row.id};
  await financial(s,business,actor,p.tipo,p.datos,changed);
    targets=changed.slice(before).filter(c=>['operaciones','movimientos'].includes(c.tabla));
  }
  if(row.comprobante_id){
    for(const ch of targets){
      const link={id:randomUUID(),negocio_id:business.id,comprobante_id:row.comprobante_id,operacion_id:ch.tabla==='operaciones'?ch.registro.id:null,movimiento_id:ch.tabla==='movimientos'?ch.registro.id:null,creado_por:actor.sub};
      await s.insert('vinculos_comprobante',link);changed.push({tabla:'vinculos_comprobante',registro:await s.get('vinculos_comprobante',{id:link.id,negocio_id:business.id})});
    }
  }
  const changes={estado:'CONFIRMADA',correccion_usuario:{...json(row.correccion_usuario),tipo:p.tipo,datos:p.datos},confirmada_por:actor.sub,confirmada_en:utc(new Date()),version:nextVersion(row),actualizado_en:utc(new Date())};
  await s.update('extracciones',{id:row.id,negocio_id:business.id},changes);
  changed.push({tabla:'extracciones',registro:{...row,...changes},version_anterior:String(row.version)});
}
async function discardProposal(s,business,actor,p,changed){
  const row=await s.get('extracciones',{id:p.extraccion_id,negocio_id:business.id},'update');
  if(!row||row.estado!=='REQUIERE_REVISION')fail(409,'PROPOSAL_UNAVAILABLE','La propuesta ya se revisó o no está disponible');
  if(String(row.version)!==p.expected_version)fail(409,'VERSION_CONFLICT','Actualiza la propuesta antes de descartarla');
  // Existing schema: FALLIDA + an explicit cancellation code, never DELETE.
  const changes={estado:'FALLIDA',codigo_error:'DESCARTADA_USUARIO',correccion_usuario:{...json(row.correccion_usuario),descartada_por:actor.sub,descartada_en:utc(new Date())},version:nextVersion(row),actualizado_en:utc(new Date())};
  await s.update('extracciones',{id:row.id,negocio_id:business.id},changes);
  changed.push({tabla:'extracciones',registro:{...row,...changes},version_anterior:String(row.version)});
}
module.exports={intakeService,saveProposal,confirmProposal,discardProposal};
