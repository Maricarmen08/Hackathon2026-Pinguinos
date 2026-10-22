'use strict';
const PDFDocument=require('pdfkit');
const {mkdir,writeFile,readFile}=require('node:fs/promises');
const path=require('node:path');
const {createHash}=require('node:crypto');
const {buildReport}=require('./queries');
const {today,json}=require('../domain');
const {utc}=require('./auth');
const {fail}=require('../errors');
const digest=b=>createHash('sha256').update(b).digest('hex');
const storage=()=>path.resolve(process.env.FINKI_PRIVATE_DIR||path.join(__dirname,'../../private'));
function soles(value){if(value==null)return 'Sin meses completos';const n=BigInt(value),a=n<0n?-n:n;return `${n<0n?'-':''}S/ ${a/100n}.${String(a%100n).padStart(2,'0')}`;}
function renderCertificate(r,id,generated) {
  return new Promise((resolve,reject)=>{
    const doc=new PDFDocument({size:'A4',margin:44,bufferPages:true,info:{Title:'FINKI - Constancia de actividad registrada',Author:'FINKI'}}),chunks=[];
    doc.on('data',b=>chunks.push(b));doc.on('end',()=>resolve(Buffer.concat(chunks)));doc.on('error',reject);
    const text=(s,size=10,color='#18365B')=>doc.fillColor(color).fontSize(size).text(s,{lineGap:3});
    const heading=s=>{if(doc.y>710)doc.addPage();doc.moveDown(.7);text(s,15);doc.moveDown(.3);};
    const line=(label,value)=>{if(doc.y>738)doc.addPage();text(`${label}: ${value}`,10);};
    doc.image(path.join(__dirname,'../../../assets/branding/finki_robot.png'),470,25,{fit:[60,50]});
    text('FINKI',30,'#1263CF');text('Mi constancia de actividad económica registrada',17);doc.moveDown();
    text(r.negocio_nombre,18);line('Periodo',`${r.desde} al ${r.hasta}`);line('Moneda','PEN - soles');line('Generado (UTC)',generated);line('Código',id);line('Corte de registros',r.corte_sync_seq);
    heading('Tu actividad y tu dinero');
    for(const [label,key]of [['Ventas registradas','ventas_minor'],['Cobros recibidos de ventas','cobros_ventas_minor'],['Gastos operativos registrados','gastos_minor'],['Compras de mercadería registradas','compras_minor'],['Pagos de compras y gastos','pagos_operativos_minor'],['Cobros de deudas anteriores al historial','cobros_deudas_iniciales_minor'],['Pagos de deudas anteriores al historial','pagos_deudas_iniciales_minor'],['Me deben al cierre','por_cobrar_minor'],['Debo pagar al cierre','por_pagar_minor'],['Resultado simplificado registrado','resultado_operativo_simplificado_minor']])line(label,soles(r[key]));
    heading('Promedio y cobertura del historial');
    line('Promedio mensual de VENTAS registradas',soles(r.promedio_mensual_ventas_minor));
    line('Meses calendario completos incluidos',r.meses_completos);line('Meses con operaciones en el periodo',r.meses_con_informacion);
    line('Meses incluidos en el promedio',r.ventas_mensuales.map(m=>m.mes).join(', ')||'Ninguno; el periodo no cubre un mes completo');
    line('Inicio declarado del historial',r.inicio_historial_declarado);line('Primer registro disponible',r.primer_registro||'No hay registros');line('Último registro disponible',r.ultimo_registro||'No hay registros');line('Meses transcurridos desde inicio declarado',r.meses_historial);
    line('Frecuencia registrada',`${r.dias_con_ventas} días con ventas / ${r.dias_observados} días calendario observables`);
    line('Porcentaje de días con ventas',r.regularidad_base_puntos==null?'Sin días observables':`${(Number(r.regularidad_base_puntos)/100).toFixed(2)}%`);
    doc.addPage();text('FINKI | Evolución mensual',21,'#1263CF');doc.moveDown();
    text('Ventas, cobros recibidos y pagos efectuados. Misma escala para todos los meses; importes exactos debajo.',10);
    const colors=['#1263CF','#00A9BB','#64748B'];
    const maximum=r.serie_mensual.flatMap(m=>[m.ventas_minor,m.cobros_minor,m.pagos_minor]).reduce((a,b)=>BigInt(b)>a?BigInt(b):a,1n);
    for(const m of r.serie_mensual){
      if(doc.y>640)doc.addPage();doc.moveDown(.5);text(`${m.mes}${m.parcial?' (periodo parcial)':''}`,12);
      const vals=[m.ventas_minor,m.cobros_minor,m.pagos_minor];
      for(let i=0;i<3;i++){const y=doc.y;doc.rect(44,y,Number(BigInt(vals[i])*440n/maximum),6).fill(colors[i]);doc.y=y+9;text(`${['Ventas','Cobros','Pagos'][i]}: ${soles(vals[i])}`,9);}
      text(`Gastos registrados: ${soles(m.gastos_minor)} | Compras: ${soles(m.compras_minor)}`,9);
    }
    heading('Cómo se calculó');
    text('Ventas, compras y gastos se suman por la fecha de la operación confirmada. Cobros y pagos se suman por la fecha del dinero recibido o pagado y sus aplicaciones válidas. Un abono no crea otra venta. Transferencias propias no son ventas ni gastos. Las anulaciones se excluyen según el estado vigente al emitir este documento.');doc.moveDown(.5);
    text('Promedio = ventas de meses calendario completos / número de esos meses, incluyendo meses sin registros con cero y excluyendo los meses parciales. Se redondea al céntimo, mitad hacia arriba. Un mes sin filas tiene cobertura desconocida: no prueba ausencia de actividad. Sin meses completos no se calcula promedio.');doc.moveDown(.5);
    text('Frecuencia = días distintos con ventas / días calendario desde el mayor entre inicio declarado y comienzo del periodo hasta el cierre, inclusive. Mide registros; no certifica estabilidad. Meses con información cuenta meses con operaciones confirmadas.');doc.moveDown(.5);
    text('Resultado simplificado = ventas - compras de mercadería - gastos operativos registrados. Las compras no equivalen necesariamente al costo de lo vendido. No incluye inventario valorizado, depreciación ni todos los posibles costos o impuestos; no es utilidad neta.');
    heading('Información y límites');
    text('Información aportada por el usuario, sin auditoría independiente. Este documento no es certificación oficial ni de SUNAT, no equivale a una declaración tributaria, no evalúa solvencia y no garantiza aprobación de crédito. No incluye registros pendientes en otros celulares. Los saldos al cierre se reconstruyen con operaciones y cobros/pagos válidos hasta esa fecha.');
    text(`Fórmula ${r.version_formula}. El archivo y su resumen se conservan como una instantánea; un reporte posterior puede reflejar correcciones.`,9);
    const range=doc.bufferedPageRange();for(let p=range.start;p<range.start+range.count;p++){doc.switchToPage(p);doc.fontSize(8).fillColor('#64748B').text(`FINKI | ${id} | ${p+1}/${range.count}`,44,795,{lineBreak:false});}
    doc.end();
  });
}
async function createCertificate(s,business,actor,payload,counter){
  if(payload.desde>payload.hasta||payload.hasta>today(business.zona_horaria)||Number(payload.hasta.slice(0,4))-Number(payload.desde.slice(0,4))>10)fail(422,'INVALID_PERIOD','Elige un periodo válido de hasta diez años, sin fechas futuras');
  const data=await Promise.all(['operaciones','movimientos','aplicaciones','cuentas','cierres_diarios'].map(t=>s.list(t,{negocio_id:business.id})));
  const r={...buildReport(business,...data,payload.desde,payload.hasta),corte_sync_seq:String(counter.ultimo_seq)};
  // Do not persist private operational rows in report summaries or sync payloads.
  delete r.cuentas;delete r.pendientes;
  const generated=utc(new Date()),bytes=await renderCertificate(r,payload.id,generated),sha=digest(bytes);
  const dir=path.join(storage(),'reports',business.id);await mkdir(dir,{recursive:true,mode:0o700});
  const key=path.posix.join('reports',business.id,`${sha}.pdf`);
  await writeFile(path.join(storage(),key),bytes,{flag:'wx',mode:0o600}).catch(e=>{if(e.code!=='EEXIST')throw e;});
  // A SQL rollback can leave an unreferenced private file; never a published report.
  await s.insert('reportes',{id:payload.id,negocio_id:business.id,desde:payload.desde,hasta:payload.hasta,zona_horaria:business.zona_horaria,moneda:'PEN',version_formula:r.version_formula,corte_sync_seq:r.corte_sync_seq,estado:'LISTO',parametros:{desde:payload.desde,hasta:payload.hasta},indicadores:r,storage_key:key,sha256:sha,generado_en:generated,creado_por:actor.sub});
  return s.get('reportes',{id:payload.id,negocio_id:business.id});
}
async function certificateFile(row){
  if(row.estado!=='LISTO'||!row.sha256||!/^reports\/[a-f0-9-]{36}\/[a-f0-9]{64}\.pdf$/.test(row.storage_key||''))fail(409,'REPORT_NOT_READY','La constancia no está disponible');
  let bytes;try{bytes=await readFile(path.join(storage(),row.storage_key));}catch{fail(503,'REPORT_FILE_MISSING','No se encuentra el archivo de la constancia');}
  if(digest(bytes)!==row.sha256)fail(503,'REPORT_INTEGRITY','El archivo requiere revisión de integridad');
  return {id:row.id,sha256:row.sha256,pdf_base64:bytes.toString('base64'),indicadores:json(row.indicadores)};
}
module.exports={renderCertificate,createCertificate,certificateFile,soles};
