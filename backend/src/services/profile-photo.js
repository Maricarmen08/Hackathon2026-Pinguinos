'use strict';
const fs=require('node:fs/promises'),path=require('node:path');
const {randomUUID}=require('node:crypto');
const {inflateSync}=require('node:zlib');
const {fail}=require('../errors');

function crc32(bytes) {
  let crc=0xffffffff;
  for(const byte of bytes){crc^=byte;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}
  return (crc^0xffffffff)>>>0;
}
// Accept only the bounded, non-interlaced 8-bit RGB/RGBA PNG produced by the app.
// Validate chunks, CRCs and decompressed scanlines rather than trusting MIME/extension.
function validatePhoto(bytes) {
  const invalid=()=>fail(422,'INVALID_PHOTO','Usa una fotografía válida; vuelve a elegirla desde la app');
  if(!Buffer.isBuffer(bytes)||bytes.length<45||bytes.length>512*1024||!bytes.subarray(0,8).equals(Buffer.from('89504e470d0a1a0a','hex')))invalid();
  let offset=8,width,height,channels,ended=false,dataStarted=false,dataEnded=false;
  const parts=[];
  while(offset<bytes.length){
    if(offset+12>bytes.length)invalid();
    const length=bytes.readUInt32BE(offset),end=offset+12+length;
    if(end>bytes.length)invalid();
    const type=bytes.toString('ascii',offset+4,offset+8),data=bytes.subarray(offset+8,end-4);
    if(crc32(bytes.subarray(offset+4,end-4))!==bytes.readUInt32BE(end-4))invalid();
    if(offset===8&&type!=='IHDR')invalid();
    if(type==='IHDR'){
      if(width!==undefined||length!==13)invalid();
      width=data.readUInt32BE(0);height=data.readUInt32BE(4);channels=data[9]===6?4:data[9]===2?3:0;
      if(!width||!height||width>512||height>512||data[8]!==8||!channels||data[10]||data[11]||data[12])invalid();
    }else if(type==='IDAT'){
      if(dataEnded)invalid();dataStarted=true;parts.push(data);
    }else if(type==='IEND'){
      if(length||end!==bytes.length)invalid();ended=true;
    }else{
      if(dataStarted)dataEnded=true;
      if(!['sRGB','gAMA','cHRM','pHYs','sBIT'].includes(type))invalid();
    }
    offset=end;
  }
  if(!ended||!parts.length)invalid();
  const stride=width*channels+1,expected=stride*height;
  let decoded;
  try{decoded=inflateSync(Buffer.concat(parts),{maxOutputLength:expected});}catch{invalid();}
  if(decoded.length!==expected)invalid();
  for(let y=0;y<height;y++)if(decoded[y*stride]>4)invalid();
  return bytes;
}
function profilePhotoService(config) {
  const root=path.resolve(config.profilePhotoRoot||path.join(process.env.FINKI_PRIVATE_DIR||path.join(__dirname,'../../private'),'profile-photos',config.DB_NAME||'test'));
  const filename=actor=>{
    if(!/^[0-9a-f-]{36}$/i.test(actor.sub))fail(401,'INVALID_SESSION','Sesión no válida');
    return path.join(root,actor.sub+'.png');
  };
  return {
    async get(actor){
      try{return {imagen_base64:(await fs.readFile(filename(actor))).toString('base64'),mime:'image/png'};}
      catch(e){if(e.code==='ENOENT')return {imagen_base64:null};throw e;}
    },
    async put(actor,bytes){
      validatePhoto(bytes);
      await fs.mkdir(root,{recursive:true,mode:0o700});
      const target=filename(actor),temp=target+'.'+randomUUID()+'.tmp';
      try{await fs.writeFile(temp,bytes,{flag:'wx',mode:0o600});await fs.rename(temp,target);}
      finally{await fs.unlink(temp).catch(e=>{if(e.code!=='ENOENT')throw e;});}
      return {ok:true};
    },
    async remove(actor){await fs.unlink(filename(actor)).catch(e=>{if(e.code!=='ENOENT')throw e;});return {ok:true};}
  };
}
module.exports={profilePhotoService,validatePhoto};
