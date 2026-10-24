'use strict';
// ADAPTADOR SOLO DE PRUEBAS UNITARIAS. No emula MySQL, índices ni bloqueos InnoDB.
const {utc}=require('../src/services/auth');
const {fail}=require('../src/errors');
class MemorySession {
  constructor(data,db){this.data=data;this.db=db;}
  async list(t,eq={},opts={}) {
    let rows=[...this.data.get(t).values()].filter(row=>Object.entries(eq).every(([k,v])=>Array.isArray(v)?v.includes(row[k]):v===null?row[k]==null:row[k]===v));
    for(const [k,op,val]of opts.ranges||[])rows=rows.filter(r=>{
      const a=k==='seq'?BigInt(r[k]):r[k],b=k==='seq'?BigInt(val):val;
      return op==='>'?a>b:op==='>='?a>=b:op==='<'?a<b:a<=b;
    });
    if(opts.search)rows=rows.filter(r=>opts.search.columns.some(k=>(r[k]||'').toLowerCase().includes(opts.search.term.toLowerCase())));
    if(opts.order)rows.sort((a,b)=>{for(const [k,d]of opts.order){const av=k==='seq'?BigInt(a[k]):a[k],bv=k==='seq'?BigInt(b[k]):b[k];const cmp=av===bv?0:av>bv?1:-1;if(cmp)return d==='DESC'?-cmp:cmp;}return 0;});
    if(opts.limit)rows=rows.slice(opts.offset||0,(opts.offset||0)+opts.limit);
    return structuredClone(rows);
  }
  async get(t,eq){return (await this.list(t,eq,{limit:1}))[0]||null;}
  async insert(t,row) {
    if(this.db.failOnTable===t){this.db.failOnTable=null;throw new Error('Fallo tardío inyectado para comprobar rollback unitario');}
    const key=t==='cambios_sync'?row.negocio_id+':'+row.seq:row.id||row.negocio_id;
    if(this.data.get(t).has(key))throw Object.assign(new Error('duplicate'),{code:'ER_DUP_ENTRY'});
    if(t==='usuarios' && [...this.data.get(t).values()].some(r=>(row.telefono_normalizado && r.telefono_normalizado===row.telefono_normalizado) || (row.correo_normalizado && r.correo_normalizado===row.correo_normalizado)))throw Object.assign(new Error('duplicate'),{code:'ER_DUP_ENTRY'});
    if(t==='identidades_externas' && [...this.data.get(t).values()].some(r=>r.proveedor===row.proveedor&&(r.sujeto===row.sujeto||r.usuario_id===row.usuario_id)))throw Object.assign(new Error('duplicate'),{code:'ER_DUP_ENTRY'});
    const now=utc(new Date());
    this.data.get(t).set(key,{version:'1',creado_en:now,actualizado_en:now,estado:'CONFIRMADO',activa:1,activo:1,anulado_en:null,anulado_por:null,motivo_anulacion:null,revocado_en:null,vence_el:null,transferencia_id:null,...structuredClone(row)});
    return row;
  }
  async update(t,eq,changes) {
    const rows=await this.list(t,eq);
    if(t==='usuarios')for(const row of rows){const next={...row,...changes};if([...this.data.get(t).values()].some(r=>r.id!==row.id&&((next.telefono_normalizado && r.telefono_normalizado===next.telefono_normalizado)||(next.correo_normalizado&&r.correo_normalizado===next.correo_normalizado))))throw Object.assign(new Error('duplicate'),{code:'ER_DUP_ENTRY'});}
    for(const row of rows)this.data.get(t).set(t==='cambios_sync'?row.negocio_id+':'+row.seq:row.id||row.negocio_id,{...row,...structuredClone(changes)});
    return rows.length;
  }
}
class MemoryDatabase {
  constructor(){this.data=new Map(Object.keys(require('../src/repositories/tables')).map(t=>[t,new Map()]));this.queue=Promise.resolve();this.failOnTable=null;}
  async read(fn){return fn(new MemorySession(structuredClone(this.data),this));}
  async snapshot(fn){return this.read(fn);}
  async transaction(fn){
    const before=this.queue;let unlock;this.queue=new Promise(resolve=>{unlock=resolve;});await before;
    const working=structuredClone(this.data);
    try{const result=await fn(new MemorySession(working,this));this.data=working;return result;}
    finally{unlock();}
  }
  async ping(){return true;}
  async close(){}
}
module.exports={MemoryDatabase};
