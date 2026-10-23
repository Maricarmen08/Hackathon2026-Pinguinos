'use strict';
const { randomUUID } = require('node:crypto');
const { fail } = require('../errors');
const { hash,canonical,json,dateWithin,nextVersion,today } = require('../domain');
const { requireSession,membership,utc } = require('./auth');
const { financialService } = require('./financial');
const {createCertificate}=require('./certificate');
const {saveProposal,confirmProposal,discardProposal}=require('./intake');
const {saveEvidence,confirmLocal}=require('./local-intake');
function commandService(db) {
  const financial=financialService();
  return async function execute(bid,c,actor) {
    if(c.dispositivo_id!==actor.did)fail(403,'DEVICE_MISMATCH','Dispositivo incompatible con sesión');
    if(c.tipo==='CREAR_NEGOCIO' && c.payload.id!==bid)fail(422,'BUSINESS_ID_MISMATCH','ID del negocio incompatible');
    const digest=hash(canonical({tipo:c.tipo,payload:c.payload,dispositivo_id:c.dispositivo_id}));
    return db.transaction(async s=>{
      // Bloqueo raíz: todas las escrituras de un negocio siguen este orden.
      let counter=await s.get('sync_contadores',{negocio_id:bid},'update');
      await requireSession(s,actor,'share');
      let context,created=false;
      if(!counter) {
        if(c.tipo!=='CREAR_NEGOCIO')fail(403,'BUSINESS_FORBIDDEN','No tienes acceso al negocio');
        if(await s.get('negocios',{id:bid}))fail(409,'BUSINESS_INCONSISTENT','Negocio requiere revisión de configuración');
        if(c.payload.inicio_historial>today())fail(422,'INVALID_DATE','Inicio de historial futuro');
        await s.insert('negocios',{...c.payload,zona_horaria:'America/Lima',moneda:'PEN',estado:'ACTIVO'});
        await s.insert('membresias',{id:randomUUID(),negocio_id:bid,usuario_id:actor.sub,rol:'PROPIETARIO',estado:'ACTIVA',creado_por:actor.sub});
        await s.insert('sync_contadores',{negocio_id:bid,ultimo_seq:'0'});
        counter={ultimo_seq:'0'};created=true;
      }
      context=await membership(s,bid,actor.sub,true);
      if(c.tipo==='CONFIRMAR_PROPUESTA_LOCAL'&&c.command_id!==c.payload.entrada.id_local)fail(422,'LOCAL_ID_MISMATCH','Conserva la identidad del borrador al confirmar o reintentar.');
      const prior=await s.get('comandos_procesados',{id:c.command_id});
      if(prior) {
        if(prior.negocio_id!==bid || prior.usuario_id!==actor.sub || prior.dispositivo_id!==actor.did || prior.request_hash!==digest)fail(409,'IDEMPOTENCY_CONFLICT','command_id ya utilizado con otro contenido o actor');
        return {...json(prior.respuesta),replayed:true};
      }
      const {business,member}=context,changed=[];
      const ownerOnly=['ACTUALIZAR_NEGOCIO','CREAR_CATEGORIA','CREAR_CUENTA','REGISTRAR_MOVIMIENTO_NO_OPERATIVO','ANULAR_OPERACION','ANULAR_MOVIMIENTO','ANULAR_TRANSFERENCIA'];
      if((ownerOnly.includes(c.tipo)||['SALDO_CXC','SALDO_CXP'].includes(c.payload.operacion?.tipo)||['CONFIRMAR_PROPUESTA','CONFIRMAR_PROPUESTA_LOCAL'].includes(c.tipo)&&(c.payload.tipo==='REGISTRAR_TRANSFERENCIA'||['SALDO_CXC','SALDO_CXP'].includes(c.payload.datos?.operacion?.tipo))) && member.rol!=='PROPIETARIO')fail(403,'OWNER_REQUIRED','Acción reservada al propietario');
      if(c.tipo==='CREAR_NEGOCIO') {
        if(!created)fail(409,'BUSINESS_EXISTS','El negocio ya existe; usar su command_id original');
        changed.push({tabla:'negocios',registro:business});
        changed.push({tabla:'membresias',registro:context.member});
        const cashId=randomUUID();
        await s.insert('cuentas',{id:cashId,negocio_id:bid,nombre:'Efectivo',tipo:'EFECTIVO',moneda:'PEN',saldo_inicial_minor:'0',fecha_apertura:business.inicio_historial,creado_por:actor.sub});
        changed.push({tabla:'cuentas',registro:await s.get('cuentas',{id:cashId,negocio_id:bid})});
      } else if(c.tipo==='GUARDAR_PROPUESTA_INTERNA') {
        await saveProposal(s,business,actor,c.payload,changed);
      } else if(c.tipo==='GUARDAR_EVIDENCIA_LOCAL_INTERNA') {
        await saveEvidence(s,business,actor,c.payload,changed);
      } else if(c.tipo==='CONFIRMAR_PROPUESTA_LOCAL') {
        await confirmLocal(s,business,actor,c.payload,changed,financial);
      } else if(c.tipo==='CONFIRMAR_PROPUESTA') {
        await confirmProposal(s,business,actor,c.payload,changed,financial);
      } else if(c.tipo==='DESCARTAR_PROPUESTA') {
        await discardProposal(s,business,actor,c.payload,changed);
      } else if(c.tipo==='GENERAR_CONSTANCIA') {
        changed.push({tabla:'reportes',registro:await createCertificate(s,business,actor,c.payload,counter)});
      } else if(c.tipo.startsWith('CREAR_')) {
        const table={CREAR_CATEGORIA:'categorias',CREAR_TERCERO:'terceros',CREAR_CUENTA:'cuentas'}[c.tipo];
        if(!table)fail(422,'UNKNOWN_COMMAND','Comando no implementado');
        const row={...c.payload,negocio_id:bid,creado_por:actor.sub};
        if(table==='categorias')row.nombre_normalizado=row.nombre.normalize('NFKC').toLowerCase().replace(/\s+/g,' ');
        if(table==='cuentas') {dateWithin(row.fecha_apertura,business);row.moneda='PEN';}
        await s.insert(table,row);changed.push({tabla:table,registro:await s.get(table,{id:row.id,negocio_id:bid})});
      } else if(c.tipo==='ACTUALIZAR_NEGOCIO') {
        const {expected_version,...data}=c.payload;
        if(String(business.version)!==expected_version)fail(409,'VERSION_CONFLICT','Versión desactualizada');
        await s.update('negocios',{id:bid},{...data,version:nextVersion(business),actualizado_en:utc(new Date())});
        changed.push({tabla:'negocios',registro:await s.get('negocios',{id:bid}),version_anterior:String(business.version)});
      } else await financial(s,business,actor,c.tipo,c.payload,changed);

      const seq=(BigInt(counter.ultimo_seq)+1n).toString();
      const response={command_id:c.command_id,sync_seq:seq,entidades:changed.map(({tabla,registro})=>({tabla,registro})),replayed:false};
      await s.insert('comandos_procesados',{id:c.command_id,negocio_id:bid,dispositivo_id:actor.did,usuario_id:actor.sub,tipo:c.tipo,request_hash:digest,respuesta:response,sync_seq:seq,creado_por:actor.sub});
      for(const ch of changed)await s.insert('auditoria',{
        id:randomUUID(),negocio_id:bid,usuario_id:actor.sub,dispositivo_id:actor.did,command_id:c.command_id,
        accion:c.tipo,entidad:ch.tabla,entidad_id:ch.registro.id,version_anterior:ch.version_anterior||null,
        version_nueva:String(ch.registro.version),detalle:{estado:ch.registro.estado||null,motivo:c.payload.motivo||null},creado_por:actor.sub
      });
      await s.insert('cambios_sync',{negocio_id:bid,seq,command_id:c.command_id,tipo:c.tipo,payload:response.entidades});
      await s.update('sync_contadores',{negocio_id:bid},{ultimo_seq:seq});
      return response;
    });
  };
}
module.exports={commandService};
