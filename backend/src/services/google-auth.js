'use strict';
const {OAuth2Client}=require('google-auth-library');
const {randomUUID}=require('node:crypto');
const {fail}=require('../errors');
const {verifyPassword}=require('../security');
const {requireSession,publicUser,utc}=require('./auth');
function googleVerifier(config,client=new OAuth2Client()) {
  const audiences=(config.GOOGLE_CLIENT_IDS||'').split(',').map(x=>x.trim()).filter(Boolean);
  return async(token,nonce)=>{
    if(!config.GOOGLE_AUTH_ENABLED||!audiences.length)fail(503,'GOOGLE_NOT_CONFIGURED','Google todavía no está configurado. Puedes usar tu acceso habitual.');
    let p;
    try {p=(await client.verifyIdToken({idToken:token,audience:audiences})).getPayload();}
    catch(e) {if(['ENOTFOUND','ETIMEDOUT','ECONNRESET','EAI_AGAIN'].includes(e.code||e.cause?.code))fail(503,'GOOGLE_UNAVAILABLE','No se pudo conectar con Google. Inténtalo más tarde.');fail(401,'INVALID_GOOGLE_TOKEN','Google no pudo verificar el acceso. Inténtalo nuevamente.');}
    const now=Math.floor(Date.now()/1000);
    if(!p||!['accounts.google.com','https://accounts.google.com'].includes(p.iss)||!audiences.includes(p.aud)||typeof p.sub!=='string'||!p.sub||p.sub.length>255||!p.exp||p.exp<=now||!Number.isSafeInteger(p.iat)||p.iat<=0||p.iat>now+60||p.nonce!==nonce||p.email_verified!==true||typeof p.email!=='string'||!p.email)fail(401,'INVALID_GOOGLE_TOKEN','La credencial Google no es válida para este acceso.');
    return {sub:p.sub,email:p.email.toLowerCase(),name:typeof p.name==='string'?p.name.slice(0,120).trim()||'Usuario Google':'Usuario Google',iat:p.iat};
  };
}
function googleAuthService(db,auth,verify){
  async function exchange(input,actor){
    const p=await verify(input.id_token,input.nonce);
    try {return await db.transaction(async s=>{
      let user,identity=await s.get('identidades_externas',{proveedor:'GOOGLE',sujeto:p.sub},'update');
      if(actor){
        user=(await requireSession(s,actor,'update')).user;
        const emailOwner=await s.get('usuarios',{correo_normalizado:p.email},'update');
        if(emailOwner&&emailOwner.id!==user.id)fail(409,'GOOGLE_LINK_REQUIRED','Ese correo pertenece a otra cuenta FINKI. Comprueba primero el acceso a esa cuenta.');
        if(!user.password_hash||!await verifyPassword(input.clave_actual,user.password_hash))fail(401,'GOOGLE_LINK_PROOF','Comprueba la contraseña actual para vincular Google.');
        if(identity&&identity.usuario_id!==user.id)fail(409,'GOOGLE_ALREADY_LINKED','Esa cuenta Google ya está vinculada a otra cuenta FINKI.');
        const other=await s.get('identidades_externas',{usuario_id:user.id,proveedor:'GOOGLE'},'update');
        if(other&&other.sujeto!==p.sub)fail(409,'GOOGLE_ALREADY_LINKED','Tu cuenta ya tiene otra identidad Google.');
      }else if(identity){user=await s.get('usuarios',{id:identity.usuario_id},'update');}
      else {
        if(await s.get('usuarios',{correo_normalizado:p.email},'update'))fail(409,'GOOGLE_LINK_REQUIRED','Este correo ya tiene una cuenta FINKI. Ingresa con tu acceso habitual y vincula Google desde Seguridad.');
        user={id:randomUUID(),nombre:p.name,telefono_normalizado:null,correo_normalizado:p.email,password_hash:null,acceso_google:1,estado:'ACTIVO'};
        await s.insert('usuarios',user);
      }
      if(!user||user.estado!=='ACTIVO')fail(401,'ACCOUNT_BLOCKED','Esta cuenta no está disponible.');
      // Monotonic issuance watermark, under lock: the same or older Google
      // credential cannot issue another FINKI session. No Google token is stored.
      if(identity&&p.iat<=Number(identity.ultimo_token_iat))fail(401,'GOOGLE_REPLAY','No se pudo completar el acceso. Inténtalo otra vez.');
      if(identity)await s.update('identidades_externas',{id:identity.id},{ultimo_token_iat:p.iat,ultimo_acceso_en:utc(new Date())});
      else await s.insert('identidades_externas',{id:randomUUID(),usuario_id:user.id,proveedor:'GOOGLE',sujeto:p.sub,correo_proveedor:p.email,correo_verificado:1,ultimo_token_iat:p.iat});
      if(!user.acceso_google)await s.update('usuarios',{id:user.id},{acceso_google:1});
      if(actor)return {ok:true};
      const did=randomUUID();await s.insert('dispositivos',{id:did,usuario_id:user.id,...input.dispositivo});
      return {usuario:publicUser(await s.get('usuarios',{id:user.id})),...await auth.newSession(s,user.id,did)};
    });}catch(e){if(e.code==='ER_DUP_ENTRY')fail(409,'GOOGLE_CONFLICT','Otro acceso ya creó o vinculó esta cuenta. Reintenta sin crear otra cuenta.');throw e;}
  }
  return {login:input=>exchange(input),link:(actor,input)=>exchange(input,actor)};
}
module.exports={googleVerifier,googleAuthService};
