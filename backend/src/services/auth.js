'use strict';
const { randomUUID } = require('node:crypto');
const { hashPassword, verifyPassword, tokens } = require('../security');
const { hash, nextVersion } = require('../domain');
const { fail } = require('../errors');
const utc = date => date.toISOString().replace('T',' ').replace('Z','');
const publicUser = u => ({ id:u.id,nombre:u.nombre,telefono:u.telefono_normalizado,correo:u.correo_normalizado,version:String(u.version) });
async function requireSession(s,claims,lock) {
  const u=await s.get('usuarios',{id:claims.sub},lock);
  const d=await s.get('dispositivos',{id:claims.did,usuario_id:claims.sub},lock);
  const session=await s.get('sesiones',{id:claims.sid,dispositivo_id:claims.did},lock);
  if (!u || u.estado!=='ACTIVO' || !d || d.revocado_en || !session || session.revocado_en ||
      Date.parse(session.expira_en.replace(' ','T')+'Z')<=Date.now()) fail(401,'INVALID_SESSION','Sesión no válida o revocada');
  return {user:u,device:d,session};
}
async function membership(s,businessId,userId,write=false) {
  const m=await s.get('membresias',{negocio_id:businessId,usuario_id:userId,estado:'ACTIVA'},write?'share':undefined);
  const b= m && await s.get('negocios',{id:businessId,estado:'ACTIVO'},write?'share':undefined);
  if (!m || !b) fail(403,'BUSINESS_FORBIDDEN','No tienes acceso al negocio');
  if (write && m.rol==='LECTOR') fail(403,'ROLE_FORBIDDEN','Tu rol no permite escribir');
  return {member:m,business:b};
}
function authService(db,config) {
  const jwt=tokens(config);
  async function newSession(s,userId,deviceId,family=randomUUID()) {
    const sid=randomUUID(),issued=jwt.issue(userId,deviceId,sid,family);
    await s.insert('sesiones',{id:sid,dispositivo_id:deviceId,refresh_hash:hash(issued.refresh_token),familia_id:family,expira_en:utc(new Date(Date.now()+30*86400000))});
    return {...issued,dispositivo_id:deviceId};
  }
  return {
    jwt,
    async register(input) {
      const encoded=await hashPassword(input.clave),uid=randomUUID(),did=randomUUID();
      return db.transaction(async s=>{
        await s.insert('usuarios',{id:uid,nombre:input.nombre,telefono_normalizado:input.telefono,correo_normalizado:input.correo,password_hash:encoded,estado:'ACTIVO'});
        await s.insert('dispositivos',{id:did,usuario_id:uid,...input.dispositivo});
        const session=await newSession(s,uid,did);
        return {usuario:publicUser(await s.get('usuarios',{id:uid})),...session};
      });
    },
    async login(input) {
      const user=await db.read(async s=> (await s.get('usuarios',{telefono_normalizado:input.usuario})) || (await s.get('usuarios',{correo_normalizado:input.usuario})));
      // Igualar el coste para usuarios inexistentes/bloqueados sin habilitar cuentas demo.
      if (!user || user.estado!=='ACTIVO' || !user.password_hash) {
        await hashPassword(input.clave);
        fail(401,'INVALID_CREDENTIALS','Usuario o contraseña incorrectos');
      }
      if (!await verifyPassword(input.clave,user.password_hash)) fail(401,'INVALID_CREDENTIALS','Usuario o contraseña incorrectos');
      return db.transaction(async s=>{
        const current=await s.get('usuarios',{id:user.id},'share');
        if (!current || current.estado!=='ACTIVO' || current.password_hash!==user.password_hash) fail(401,'INVALID_CREDENTIALS','Usuario o contraseña incorrectos');
        const did=randomUUID(); await s.insert('dispositivos',{id:did,usuario_id:user.id,...input.dispositivo});
        return {usuario:publicUser(current),...await newSession(s,user.id,did)};
      });
    },
    async refresh(raw) {
      const c=jwt.verify(raw,'refresh');
      const result=await db.transaction(async s=>{
        const device=await s.get('dispositivos',{id:c.did,usuario_id:c.sub},'update');
        const user=await s.get('usuarios',{id:c.sub});
        const session=await s.get('sesiones',{id:c.sid,dispositivo_id:c.did},'update');
        if (!device || device.revocado_en || !user || user.estado!=='ACTIVO' || !session ||
            session.refresh_hash!==hash(raw) || session.familia_id!==c.fid) return {invalid:true};
        if (session.revocado_en) {
          const family=await s.list('sesiones',{familia_id:session.familia_id});
          for (const row of family) await s.update('sesiones',{id:row.id},{revocado_en:utc(new Date())});
          return {invalid:true}; // COMMIT de revocación antes de devolver error.
        }
        if (Date.parse(session.expira_en.replace(' ','T')+'Z')<=Date.now()) return {invalid:true};
        await s.update('sesiones',{id:session.id},{revocado_en:utc(new Date())});
        return newSession(s,c.sub,c.did,session.familia_id);
      });
      if (result.invalid) fail(401,'INVALID_REFRESH','Renovación inválida; inicia sesión nuevamente');
      return result;
    },
    async logout(claims) {
      return db.transaction(async s=>{
        const {session}=await requireSession(s,claims,'update');
        await s.update('sesiones',{familia_id:session.familia_id},{revocado_en:utc(new Date())});
        return {ok:true};
      });
    },
    async updateProfile(claims,input) {
      return db.transaction(async s=>{
        const {user}=await requireSession(s,claims,'update');
        if(String(user.version)!==input.expected_version)fail(409,'VERSION_CONFLICT','Versión desactualizada');
        const row={version:nextVersion(user),actualizado_en:utc(new Date())};
        if(input.nombre!==undefined)row.nombre=input.nombre;
        if(input.telefono!==undefined)row.telefono_normalizado=input.telefono;
        if(input.correo!==undefined)row.correo_normalizado=input.correo;
        await s.update('usuarios',{id:claims.sub},row);
        return {usuario:publicUser({...user,...row})};
      });
    },
    async me(claims) {
      return db.read(async s=>{
        const {user}=await requireSession(s,claims);
        const ms=await s.list('membresias',{usuario_id:claims.sub,estado:'ACTIVA'});
        const businesses=[];
        for (const m of ms) { const b=await s.get('negocios',{id:m.negocio_id,estado:'ACTIVO'}); if(b)businesses.push({...b,rol:m.rol}); }
        return {usuario:publicUser(user),negocios:businesses};
      });
    }
  };
}
module.exports={ authService,requireSession,membership,publicUser,utc };
