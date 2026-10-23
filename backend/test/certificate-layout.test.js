'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {renderCertificate}=require('../src/services/certificate'),{buildReport}=require('../src/services/queries');
const {period}=require('../src/services/certificate-renderer');
test('PDF periodo diario no es rango y rango conserva extremos',()=>{assert.equal(period('2026-10-23','2026-10-23'),'23/10/2026');assert.equal(period('2026-10-17','2026-10-23'),'17/10/2026 al 23/10/2026');});
test('PDF formal: fecha diaria, importes negativos, titular y anexo extenso',async()=>{
 const dir=path.resolve(__dirname,'../../build/tooling');fs.mkdirSync(dir,{recursive:true});
 for(const [name,from,to,businessName]of [['daily','2026-10-23','2026-10-23','Bodega de prueba'],['long','2025-01-01','2026-10-23','Negocio '.repeat(15)]]){
  const business={id:'fixture',nombre:businessName,inicio_historial:'2025-01-01'};
  const ops=[{id:'s',estado:'CONFIRMADO',tipo:'VENTA',fecha_operacion:to,total_minor:'7000'},{id:'p',estado:'CONFIRMADO',tipo:'COMPRA_MERCADERIA',fecha_operacion:to,total_minor:'8000'},{id:'g',estado:'CONFIRMADO',tipo:'GASTO_OPERATIVO',fecha_operacion:to,total_minor:'1200'}];
  const r={...buildReport(business,ops,[],[],[],[],from,to),titular_nombre:'Persona de prueba '.repeat(5),zona_horaria:'America/Lima',corte_sync_seq:'123'};
  assert.equal(r.resultado_operativo_simplificado_minor,'-2200');
  const bytes=await renderCertificate(r,'00000000-0000-4000-8000-000000000001','2026-10-23 15:00:00.000');assert.equal(bytes.subarray(0,5).toString(),'%PDF-');fs.writeFileSync(path.join(dir,`certificate-fixture-${name}.pdf`),bytes);
 }
});
