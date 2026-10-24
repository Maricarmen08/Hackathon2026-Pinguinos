'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {analyze,percent,ratio}=require('../src/services/certificate-analysis');
const {buildReport}=require('../src/services/queries'),{renderCertificate}=require('../src/services/certificate');

test('porcentajes y razones con redondeo y sin denominador',()=>{
  assert.equal(percent('2500','10000'),'25.0%');assert.equal(percent('-2200','7000'),'-31.4%');assert.equal(percent('1','0'),null);assert.equal(percent('0','100'),'0.0%');
  assert.equal(ratio('500','100'),'5.00');assert.equal(ratio('500','0'),null);
});
const business={id:'b',nombre:'Bodega Central',inicio_historial:'2026-01-01',moneda:'COP'};
const op=(id,tipo,fecha,total,extra={})=>({id,estado:'CONFIRMADO',tipo,fecha_operacion:fecha,total_minor:String(total),...extra});
function fixture(){
  const ops=[];let n=0;
  for(const [m,sales] of [['01',200000],['02',250000],['03',300000],['04',350000],['05',400000],['06',450000]]){
    ops.push(op('v'+(n++),'VENTA',`2026-${m}-10`,sales,{tercero_id:'t'+(n%4)}));
    ops.push(op('c'+(n++),'COMPRA_MERCADERIA',`2026-${m}-12`,sales*0.5));
    ops.push(op('g'+(n++),'GASTO_OPERATIVO',`2026-${m}-15`,sales*0.1,{categoria_id:n%2?'cat1':'cat2'}));
  }
  const moves=[{id:'m1',estado:'CONFIRMADO',cuenta_id:'a1',direccion:'ENTRADA',monto_minor:'900000',fecha_movimiento:'2026-06-20',clase:'COBRO'}];
  const apps=[{operacion_id:'v0',movimiento_id:'m1',monto_minor:'150000'}];
  const accounts=[{id:'a1',fecha_apertura:'2026-01-01',saldo_inicial_minor:'100000'}];
  return buildReport(business,ops,moves,apps,accounts,[],'2026-01-01','2026-06-30');
}
test('el reporte trae antigüedad, concentración, gastos por categoría y saldo en cuentas',()=>{
  const r=fixture();
  assert.equal(r.ventas_cantidad,6);assert.equal(r.saldo_cuentas_minor,'1000000');
  assert.equal(r.antiguedad_por_cobrar_minor.length,4);
  assert.equal(r.antiguedad_por_cobrar_minor.reduce((a,b)=>a+BigInt(b),0n).toString(),r.por_cobrar_minor);
  assert.ok(r.gastos_por_categoria.length>=1);assert.equal(JSON.stringify(r).includes('Cliente'),false);
  const a=analyze(r);assert.equal(a.margen_bruto,'50.0%');assert.equal(a.margen_operativo,'40.0%');assert.equal(a.tendencia,'Creciente');assert.equal(a.meses_completos,6);
  assert.ok(a.lectura.length>=1&&a.lectura.length<=5);
});
test('sin ventas ni cuentas el análisis no inventa cifras',()=>{
  const r=buildReport(business,[],[],[],[],[],'2026-06-01','2026-06-10'),a=analyze(r);
  assert.equal(a.margen_operativo,null);assert.equal(a.cobranza,null);assert.equal(a.tendencia,undefined);assert.match(a.lectura.join(' '),/No hay ventas/);
});
test('PDF con análisis completo se genera con el símbolo de la moneda',async()=>{
  const r={...fixture(),titular_nombre:'Persona de prueba',zona_horaria:'America/Bogota',corte_sync_seq:'1',version_documento:'3.0'};
  r.gastos_por_categoria=r.gastos_por_categoria.map((c,i)=>({...c,nombre:['Arriendo','Transporte'][i]||'Otros'}));
  const bytes=await renderCertificate(r,'00000000-0000-4000-8000-000000000002','2026-06-30 15:00:00.000');
  assert.equal(bytes.subarray(0,5).toString(),'%PDF-');
  const dir=path.resolve(__dirname,'../../build/tooling');fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'certificate-analysis-fixture.pdf'),bytes);
});
