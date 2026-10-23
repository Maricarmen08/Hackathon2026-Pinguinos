'use strict';
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {once}=require('node:events');
const {mkdtemp,rm}=require('node:fs/promises');
const path=require('node:path'),os=require('node:os');
const {deflateSync}=require('node:zlib');
const {createApp}=require('../src/app');
function png(red=20){
  const chunk=(type,data)=>{
    const b=Buffer.alloc(data.length+12);b.writeUInt32BE(data.length);b.write(type,4);data.copy(b,8);
    let crc=0xffffffff;for(const byte of b.subarray(4,-4)){crc^=byte;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}
    b.writeUInt32BE((crc^0xffffffff)>>>0,b.length-4);return b;
  };
  const hdr=Buffer.alloc(13);hdr.writeUInt32BE(1);hdr.writeUInt32BE(1,4);hdr[8]=8;hdr[9]=6;
  return Buffer.concat([Buffer.from('89504e470d0a1a0a','hex'),chunk('IHDR',hdr),chunk('IDAT',deflateSync(Buffer.from([0,red,30,40,255]))),chunk('IEND',Buffer.alloc(0))]);
}
async function accountScenario(t,db,config){
  const root=await mkdtemp(path.join(os.tmpdir(),'finki-account-test-'));
  const server=createApp({db,config:{...config,profilePhotoRoot:root}}).listen(0,'127.0.0.1');await once(server,'listening');
  t.after(async()=>{
    await new Promise(r=>server.close(r));
    if(path.dirname(path.resolve(root))!==path.resolve(os.tmpdir())||!path.basename(root).startsWith('finki-account-test-'))throw new Error('Directorio temporal inesperado; no se elimina');
    await rm(root,{recursive:true,force:true});
  });
  const base='http://127.0.0.1:'+server.address().port+'/api/v1';
  const req=async(method,url,body,token,raw=false)=>{
    const r=await fetch(base+url,{method,headers:{...(body?{'Content-Type':raw?'application/octet-stream':'application/json'}:{}),...(token?{Authorization:'Bearer '+token}:{})},...(body?{body:raw?body:JSON.stringify(body)}:{})});
    return {status:r.status,body:await r.json()};
  };
  const suffix=randomUUID().replaceAll('-','');
  const input={nombre:'PRUEBA PERFIL '+suffix,telefono:'+999'+String(BigInt('0x'+suffix.slice(0,8))).padStart(10,'0'),correo:suffix+'@example.invalid',clave:'Prueba-Clave-2026!',dispositivo:{nombre:'Aislado',plataforma:'ANDROID'}};
  const a=await req('POST','/auth/registro',input);assert.equal(a.status,201);
  const b=await req('POST','/auth/registro',{...input,telefono:'+998'+input.telefono.slice(4),correo:'otro'+input.correo});assert.equal(b.status,201);
  const token=a.body.access_token,uid=a.body.usuario.id;
  const login=(usuario,clave=input.clave)=>req('POST','/auth/login',{usuario,clave,dispositivo:input.dispositivo});
  let second;
  await t.test('teléfono y correo normalizado acceden a la misma cuenta; credenciales inválidas rechazadas',async()=>{
    assert.equal((await login(input.telefono)).body.usuario.id,uid);
    second=await login(input.correo.toUpperCase());assert.equal(second.body.usuario.id,uid);
    assert.equal((await login(input.telefono,'incorrecta')).status,401);
    assert.equal((await login('inexistente'+input.correo)).status,401);
  });
  await t.test('perfil valida, persiste y rechaza identificadores duplicados sin perder datos',async()=>{
    assert.equal((await req('PATCH','/perfil',{expected_version:'1',nombre:''},token)).status,422);
    assert.equal((await req('PATCH','/perfil',{expected_version:'1',telefono:'123'},token)).status,422);
    assert.equal((await req('PATCH','/perfil',{expected_version:'1',correo:'invalido'},token)).status,422);
    const name='PRUEBA NOMBRE '+suffix,phone='+997'+input.telefono.slice(4),email='nuevo'+input.correo;
    assert.equal((await req('PATCH','/perfil',{expected_version:'1',nombre:name,telefono:phone,correo:email.toUpperCase()},token)).status,200);
    assert.equal((await login(email)).body.usuario.nombre,name);
    assert.equal((await req('PATCH','/perfil',{expected_version:'2',correo:b.body.usuario.correo},token)).status,409);
    assert.equal((await req('PATCH','/perfil',{expected_version:'2',telefono:b.body.usuario.telefono},token)).status,409);
    const saved=(await req('GET','/perfil',undefined,token)).body.usuario;
    assert.equal(saved.nombre,name);assert.equal(saved.telefono,phone);assert.equal(saved.correo,email);
    input.telefono=phone;input.correo=email;
  });
  await t.test('foto privada: guardar, reemplazar, persistir, aislamiento, eliminar y archivos inválidos',async()=>{
    assert.equal((await req('GET','/perfil/foto')).status,401);
    assert.equal((await req('PUT','/perfil/foto',png(),token,true)).status,200);
    assert.equal((await req('GET','/perfil/foto',undefined,token)).body.imagen_base64,png().toString('base64'));
    assert.equal((await req('GET','/perfil/foto',undefined,second.body.access_token)).body.imagen_base64,png().toString('base64'));
    const relogin=await require('../src/services/auth').authService(db,config).login({usuario:input.correo,clave:input.clave,dispositivo:input.dispositivo});
    assert.equal((await req('GET','/perfil/foto',undefined,relogin.access_token)).body.imagen_base64,png().toString('base64'));
    assert.equal((await require('../src/services/profile-photo').profilePhotoService({profilePhotoRoot:root}).get({sub:uid})).imagen_base64,png().toString('base64'));
    assert.equal((await req('GET','/perfil/foto?usuario_id='+uid,undefined,b.body.access_token)).body.imagen_base64,null);
    assert.equal((await req('GET','/perfil/foto',undefined,b.body.access_token)).body.imagen_base64,null);
    assert.equal((await req('PUT','/perfil/foto',png(100),token,true)).status,200);
    assert.equal((await req('PUT','/perfil/foto',Buffer.from('no es una imagen'),token,true)).status,422);
    const corrupt=png();corrupt[corrupt.length-1]^=1;
    assert.equal((await req('PUT','/perfil/foto',corrupt,token,true)).status,422);
    assert.equal((await req('PUT','/perfil/foto',Buffer.alloc(524289),token,true)).status,413);
    assert.equal((await req('GET','/perfil/foto',undefined,token)).body.imagen_base64,png(100).toString('base64'));
    assert.equal((await req('DELETE','/perfil/foto',undefined,token)).status,200);
    assert.equal((await req('GET','/perfil/foto',undefined,token)).body.imagen_base64,null);
  });
  await t.test('cambio seguro de contraseña, revocación de otras sesiones y límites de intentos',async()=>{
    const newPassword='Otra-Clave-Segura-2026!';
    const change=(actual,nueva,confirmacion=nueva)=>req('POST','/perfil/contrasena',{actual,nueva,confirmacion},token);
    assert.equal((await change('incorrecta',newPassword)).body.error.code,'WRONG_PASSWORD');
    assert.equal((await change(input.clave,'corta')).status,422);
    assert.equal((await change(input.clave,newPassword,'No-coincide-2026!')).status,422);
    assert.equal((await change(input.clave,newPassword)).status,200);
    assert.equal((await req('GET','/auth/me',undefined,token)).status,200);
    assert.equal((await req('GET','/auth/me',undefined,second.body.access_token)).status,401);
    assert.equal((await req('POST','/auth/refresh',{refresh_token:second.body.refresh_token})).status,401);
    assert.equal((await login(input.telefono)).status,401);
    assert.equal((await login(input.telefono,newPassword)).body.usuario.id,uid);
    const row=await db.read(s=>s.get('usuarios',{id:uid}));assert.ok(row.password_hash.startsWith('$scrypt$'));assert.ok(!row.password_hash.includes(newPassword));
    await change('incorrecta',newPassword);
    assert.equal((await change('incorrecta',newPassword)).status,429);
  });
}
module.exports={accountScenario,png};
