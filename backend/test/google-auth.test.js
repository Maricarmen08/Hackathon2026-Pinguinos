'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {googleAuthService,googleVerifier}=require('../src/services/google-auth');
const {authService}=require('../src/services/auth');
const {MemoryDatabase}=require('./memory');
const config={JWT_SECRET:'a'.repeat(64),JWT_REFRESH_SECRET:'b'.repeat(64)};
const input={id_token:'fictitious-token-for-tests-only',nonce:'n'.repeat(36),dispositivo:{nombre:'Ensayo',plataforma:'ANDROID'}};
const identity={sub:'fiction-sub',email:'google@example.invalid',name:'Ensayo Google',iat:100};

test('Google exclusivo no permite crear contraseña ni altera la identidad o sesión',async()=>{
 const db=new MemoryDatabase(),auth=authService(db,config);
 const a=await googleAuthService(db,auth,async()=>({...identity})).login(input);
 const actor=auth.jwt.verify(a.access_token,'access');
 await assert.rejects(auth.changePassword(actor,{actual:'inexistente',nueva:'Ficticia-Segura-2026!'}),{code:'PASSWORD_NOT_AVAILABLE'});
 assert.equal((await db.read(s=>s.get('usuarios',{id:actor.sub}))).password_hash,null);
 assert.equal((await auth.me(actor)).usuario.google_vinculado,true);
 assert.equal((await db.read(s=>s.list('identidades_externas'))).length,1);
});

test('tradicional: registro, teléfono/correo, refresh y logout conservan contratos',async()=>{
 const db=new MemoryDatabase(),auth=authService(db,config);
 const a=await auth.register({nombre:'Cuenta ficticia',telefono:'+51900000004',correo:'trad@example.invalid',clave:'Ficticia-Segura-2026!',dispositivo:input.dispositivo});
 for(const usuario of ['+51900000004','trad@example.invalid'])assert.equal((await auth.login({usuario,clave:'Ficticia-Segura-2026!',dispositivo:input.dispositivo})).usuario.id,a.usuario.id);
 await assert.rejects(auth.login({usuario:'trad@example.invalid',clave:'incorrecta',dispositivo:input.dispositivo}),{code:'INVALID_CREDENTIALS'});
 const refreshed=await auth.refresh(a.refresh_token),actor=auth.jwt.verify(refreshed.access_token,'access');
 assert.equal((await auth.me(actor)).usuario.id,a.usuario.id);
 await auth.logout(actor);
 await assert.rejects(auth.me(actor),{code:'INVALID_SESSION'});
 await assert.rejects(auth.refresh(refreshed.refresh_token),{code:'INVALID_REFRESH'});
});

test('regresión: Google -> registrar negocio -> logout -> mismo sub vuelve al negocio sin duplicados',async()=>{
 const {randomUUID}=require('node:crypto');
 const db=new MemoryDatabase(),auth=authService(db,config);
 let credential={...identity};
 const service=googleAuthService(db,auth,async()=>credential);
 const first=await service.login(input),actor=auth.jwt.verify(first.access_token,'access');
 assert.equal((await auth.me(actor)).negocios.length,0);
 const bid=randomUUID();
 await require('../src/services/commands').commandService(db)(bid,{
  command_id:randomUUID(),dispositivo_id:actor.did,tipo:'CREAR_NEGOCIO',
  payload:{id:bid,nombre:'NEGOCIO FICTICIO REGRESION',rubro:'Bodega',inicio_historial:'2026-01-01',ciudad:null}
 },actor);
 await auth.logout(actor);
 await assert.rejects(auth.me(actor),{code:'INVALID_SESSION'});
 // Cached/old credentials remain rejected even after a legitimate logout.
 await assert.rejects(service.login(input),{code:'GOOGLE_REPLAY'});
 credential={...identity,iat:101};
 const second=await service.login({...input,nonce:'fresh-attempt-nonce'.padEnd(36,'n')});
 assert.equal(second.usuario.id,first.usuario.id);
 const me=await auth.me(auth.jwt.verify(second.access_token,'access'));
 assert.equal(me.negocios.length,1);assert.equal(me.negocios[0].id,bid);
 for(const table of ['usuarios','negocios','identidades_externas','membresias'])assert.equal((await db.read(s=>s.list(table))).length,1);
 assert.equal((await db.read(s=>s.list('operaciones'))).length,0);
});
test('Google nuevo sin teléfono/clave, regreso, sesión y aislamiento',async()=>{
 const db=new MemoryDatabase(),auth=authService(db,config);let p={...identity};
 const service=googleAuthService(db,auth,async()=>p);
 const a=await service.login(input);assert.equal(a.usuario.telefono,null);assert.equal(a.usuario.tiene_clave,false);assert.equal(a.usuario.google_vinculado,true);
 const actor=auth.jwt.verify(a.access_token,'access');assert.equal((await auth.me(actor)).negocios.length,0);
 assert.equal((await db.read(s=>s.get('usuarios',{id:actor.sub}))).password_hash,null);
 await assert.rejects(service.login(input),{code:'GOOGLE_REPLAY'});
 p={...p,iat:101};const again=await service.login(input);assert.equal(again.usuario.id,a.usuario.id);
 await db.transaction(async s=>{await s.insert('negocios',{id:'b',estado:'ACTIVO',nombre:'Ensayo'});await s.insert('membresias',{id:'m',usuario_id:actor.sub,negocio_id:'b',estado:'ACTIVA',rol:'PROPIETARIO'});});
 p={...p,iat:102};const existing=await service.login(input);assert.equal((await auth.me(auth.jwt.verify(existing.access_token,'access'))).negocios.length,1);
 assert.equal((await db.read(s=>s.list('usuarios'))).length,1);
 const other=googleAuthService(db,auth,async()=>({...identity,sub:'other',email:'other@example.invalid'}));
 const o=await other.login(input);assert.equal((await auth.me(auth.jwt.verify(o.access_token,'access'))).negocios.length,0);
 await db.transaction(s=>s.update('usuarios',{id:actor.sub},{estado:'BLOQUEADO'}));p={...p,iat:103};await assert.rejects(service.login(input),{code:'ACCOUNT_BLOCKED'});
});
test('correo coincidente no fusiona; vincular exige sesión y clave anterior',async()=>{
 const db=new MemoryDatabase(),auth=authService(db,config);
 const a=await auth.register({nombre:'Tradicional',telefono:'+51900000001',correo:identity.email,clave:'Ficticia-Segura-2026!',dispositivo:input.dispositivo});
 const service=googleAuthService(db,auth,async()=>({...identity}));
 await assert.rejects(service.login(input),{code:'GOOGLE_LINK_REQUIRED'});
 const actor=auth.jwt.verify(a.access_token,'access');
 await assert.rejects(service.link(actor,{...input,clave_actual:'incorrecta'}),{code:'GOOGLE_LINK_PROOF'});
 assert.equal((await db.read(s=>s.list('identidades_externas'))).length,0);
 await service.link(actor,{...input,clave_actual:'Ficticia-Segura-2026!'});
 const outsider=await auth.register({nombre:'Otra cuenta ficticia',telefono:'+51900000005',correo:'outsider@example.invalid',clave:'Ficticia-Segura-2026!',dispositivo:input.dispositivo});
 await assert.rejects(service.link(auth.jwt.verify(outsider.access_token,'access'),{...input,clave_actual:'Ficticia-Segura-2026!'}),{code:'GOOGLE_LINK_REQUIRED'});
 const differentIdentity=googleAuthService(db,auth,async()=>({...identity,sub:'different-sub',email:'different@example.invalid',iat:101}));
 await assert.rejects(differentIdentity.link(actor,{...input,clave_actual:'Ficticia-Segura-2026!'}),{code:'GOOGLE_ALREADY_LINKED'});
 assert.equal((await db.read(s=>s.list('identidades_externas'))).length,1);
 const returning=googleAuthService(db,auth,async()=>({...identity,iat:101}));assert.equal((await returning.login(input)).usuario.id,a.usuario.id);
 assert.ok((await auth.login({usuario:identity.email,clave:'Ficticia-Segura-2026!',dispositivo:input.dispositivo})).access_token);
});
test('concurrencia y rollback no crean dos identidades ni cuentas huérfanas',async()=>{
 const db=new MemoryDatabase(),auth=authService(db,config),service=googleAuthService(db,auth,async()=>({...identity}));
 const results=await Promise.allSettled([service.login(input),service.login(input)]);assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 assert.equal((await db.read(s=>s.list('usuarios'))).length,1);assert.equal((await db.read(s=>s.list('identidades_externas'))).length,1);
 const broken=new MemoryDatabase();broken.failOnTable='identidades_externas';
 await assert.rejects(googleAuthService(broken,authService(broken,config),async()=>({...identity})).login(input));
 assert.equal((await broken.read(s=>s.list('usuarios'))).length,0);
});
test('verificación oficial: firma/audiencia, vencimiento, emisor y nonce; apagado seguro',async()=>{
 const audience='test-client.apps.googleusercontent.com',now=Math.floor(Date.now()/1000);
 const p={sub:'fixture',email:'fixture@example.invalid',email_verified:true,nonce:input.nonce,aud:audience,iss:'https://accounts.google.com',iat:now,exp:now+3600};
 const c={GOOGLE_AUTH_ENABLED:true,GOOGLE_CLIENT_IDS:audience};
 const client=payload=>({verifyIdToken:async args=>{assert.equal(args.audience[0],audience);return {getPayload:()=>payload};}});
 assert.equal((await googleVerifier(c,client(p))(input.id_token,input.nonce)).sub,'fixture');
 for(const overrides of [{exp:now-1},{aud:'wrong'},{iss:'attacker'},{nonce:'wrong'},{email_verified:false},{iat:0},{iat:now+120}])await assert.rejects(googleVerifier(c,client({...p,...overrides}))(input.id_token,input.nonce),{code:'INVALID_GOOGLE_TOKEN'});
 await assert.rejects(googleVerifier(c,{verifyIdToken:async()=>{throw new Error('Invalid signature');}})(input.id_token,input.nonce),{code:'INVALID_GOOGLE_TOKEN'});
 await assert.rejects(googleVerifier(c,{verifyIdToken:async()=>{throw Object.assign(new Error('Network'),{code:'ENOTFOUND'});}})(input.id_token,input.nonce),{code:'GOOGLE_UNAVAILABLE'});
 await assert.rejects(googleVerifier({GOOGLE_AUTH_ENABLED:false})(input.id_token,input.nonce),{code:'GOOGLE_NOT_CONFIGURED'});
});
test('biblioteca oficial verifica RSA real con claves efímeras de ensayo, sin red',async()=>{
 const {generateKeyPairSync}=require('node:crypto'),jwt=require('jsonwebtoken'),{OAuth2Client}=require('google-auth-library');
 const pair=generateKeyPairSync('rsa',{modulusLength:2048,publicKeyEncoding:{type:'spki',format:'pem'},privateKeyEncoding:{type:'pkcs8',format:'pem'}});
 const client=new OAuth2Client();client.getFederatedSignonCertsAsync=async()=>({certs:{'unit-key':pair.publicKey},format:'PEM'});
 const aud='audience-fixture-only',now=Math.floor(Date.now()/1000);
 const payload={sub:'fiction-sub',email:'rsa@example.invalid',email_verified:true,iss:'https://accounts.google.com',aud,iat:now,exp:now+3600,nonce:input.nonce};
 const sign=p=>jwt.sign(p,pair.privateKey,{algorithm:'RS256',keyid:'unit-key'});
 const verify=googleVerifier({GOOGLE_AUTH_ENABLED:true,GOOGLE_CLIENT_IDS:aud},client);
 assert.equal((await verify(sign(payload),input.nonce)).sub,'fiction-sub');
 for(const changes of [{exp:now-600},{aud:'not-allowed'},{iss:'https://attacker.invalid'},{nonce:'wrong'}])await assert.rejects(verify(sign({...payload,...changes}),input.nonce),{code:'INVALID_GOOGLE_TOKEN'});
 const parts=sign(payload).split('.');parts[2]=(parts[2][0]==='A'?'B':'A')+parts[2].slice(1);
 await assert.rejects(verify(parts.join('.'),input.nonce),{code:'INVALID_GOOGLE_TOKEN'});
});
