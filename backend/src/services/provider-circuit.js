'use strict';
const fs=require('node:fs'),path=require('node:path');
const {ApiError,fail}=require('../errors');
class ProviderCircuit {
  constructor(filename,clock=Date.now){this.filename=filename;this.clock=clock;}
  read(){
    try{
      if(!fs.existsSync(this.filename))return {until:0,failures:0};
      if(fs.statSync(this.filename).size>4096)throw Error('state');
      const state=JSON.parse(fs.readFileSync(this.filename,'utf8'));
      if(!Number.isSafeInteger(state.until)||!Number.isSafeInteger(state.failures)||state.failures<0)throw Error('state');
      return state;
    }catch{fail(503,'AI_BUDGET_UNAVAILABLE','No se pudo comprobar la disponibilidad. Usa el registro local.');}
  }
  write(state){
    try{fs.mkdirSync(path.dirname(this.filename),{recursive:true,mode:0o700});const tmp=this.filename+'.tmp';fs.writeFileSync(tmp,JSON.stringify(state),{mode:0o600});fs.renameSync(tmp,this.filename);}
    catch{fail(503,'AI_BUDGET_UNAVAILABLE','No se pudo conservar el estado. Usa el registro local.');}
  }
  availability(){const s=this.read();return {disponible:s.until<=this.clock(),reintentar_en:s.until>this.clock()?new Date(s.until).toISOString():null,motivo:s.until>this.clock()?s.reason:null};}
  check(){
    const s=this.read();if(s.until<=this.clock())return;
    const e=new ApiError(503,s.reason==='QUOTA'?'AI_QUOTA_EXHAUSTED':'AI_PROVIDER_UNAVAILABLE','La ayuda externa está temporalmente pausada. Puedes continuar localmente.');
    e.retryAt=new Date(s.until).toISOString();throw e;
  }
  block(reason,retryAfter){
    const old=this.read(),failures=Math.min(old.failures+1,8);
    let seconds=reason==='QUOTA'?Math.min(900*2**(failures-1),86400):60;
    if(retryAfter){const n=Number(retryAfter);const delay=Number.isFinite(n)?n:(Date.parse(retryAfter)-this.clock())/1000;if(Number.isFinite(delay))seconds=Math.max(60,Math.min(Math.ceil(delay),86400));}
    this.write({reason,failures,until:this.clock()+seconds*1000});
  }
  success(){if(this.read().failures)this.write({until:0,failures:0});}
}
module.exports={ProviderCircuit};
