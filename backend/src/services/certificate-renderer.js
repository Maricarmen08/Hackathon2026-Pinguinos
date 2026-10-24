'use strict';
const PDFDocument=require('pdfkit'),path=require('node:path');
const {analyze}=require('./certificate-analysis');
const navy='#12335D',blue='#1762C4',muted='#52657C',line='#DCE5F0',pale='#F1F6FC',warn='#9A5B00',warnBg='#FFF5E0';
const date=d=>d.split('-').reverse().join('/');
const period=(a,b)=>a===b?date(a):`${date(a)} al ${date(b)}`;
module.exports=function render(r,id,generated,soles){return new Promise((resolve,reject)=>{
 const A=analyze(r),symbol=require('../countries').symbolFor(r.moneda);
 const doc=new PDFDocument({size:'A4',margin:42,bufferPages:true,info:{Title:'FINKI - Constancia de actividad del negocio',Author:'FINKI',Subject:'Resumen de registros del usuario; no certificación oficial',FinkiFormula:String(r.version_formula),FinkiCorte:String(r.corte_sync_seq??'-'),FinkiDocumento:String(r.version_documento||'3.0')}}),chunks=[];
 doc.on('data',b=>chunks.push(b));doc.on('end',()=>resolve(Buffer.concat(chunks)));doc.on('error',reject);
 const left=42,width=511,limit=752;
 const text=(s,x,y,w=width,size=10,bold=false,color=navy)=>{doc.font(bold?'Helvetica-Bold':'Helvetica').fontSize(size).fillColor(color).text(String(s??'No consignado'),x,y,{width:w,lineGap:2});return doc.y;};
 const box=(x,y,w,h,color=pale)=>doc.roundedRect(x,y,w,h,9).fill(color);
 const rule=y=>doc.moveTo(left,y).lineTo(left+width,y).strokeColor(line).lineWidth(.6).stroke();
 const section=(title,y)=>{text(title,left,y,width,11,true,blue);return y+23;};
 const field=(label,value,x,y,w)=>{text(label.toUpperCase(),x,y,w,7.5,true,muted);return text(value,x,y+14,w,10,true);};
 const ensure=(y,h)=>{if(y+h>limit){doc.addPage();return 50;}return y;};
 const na='No disponible';
 // Tabla de dos columnas: concepto / importe. 'strong' resalta la fila.
 const table=(rows,y)=>{
  box(left,y,width,24,navy);text('CONCEPTO',left+14,y+8,340,8,true,'#FFFFFF');text(`IMPORTE (${symbol})`,left+366,y+8,129,8,true,'#FFFFFF');y+=28;
  rows.forEach(([label,value,strong],i)=>{
   y=ensure(y,26);
   if(strong)box(left,y,width,25,pale);else if(i%2===0)doc.rect(left,y,width,25).fill('#F8FAFD');
   text(label,left+14,y+8,342,9.5,!!strong);
   doc.font(strong?'Helvetica-Bold':'Helvetica').fontSize(10.5).fillColor(strong?blue:navy).text(value,left+356,y+7,{width:140,align:'right'});y+=26;
  });
  return y+8;
 };
 // Cabecera
 box(left,38,width,100);
 doc.image(path.join(__dirname,'../../../assets/branding/finki_logo_display.png'),52,46,{fit:[100,84],align:'center',valign:'center'});
 text('CONSTANCIA DE ACTIVIDAD\nDEL NEGOCIO',169,52,366,19,true);
 text('Resumen de movimientos registrados en FINKI',169,102,366,9,false,muted);
 let y=156;
 doc.font('Helvetica-Bold').fontSize(18);const nameHeight=doc.heightOfString(r.negocio_nombre,{width});
 text(r.negocio_nombre,left,y,width,18,true);y+=nameHeight+12;
 const metaY=y;
 const holderEnd=field('Titular / responsable',r.titular_nombre||'No consignado',left,y,245);
 const issuerTime=new Date(generated.replace(' ','T')+'Z');
 const zone=r.zona_horaria||'America/Lima';
 const issued=Number.isFinite(issuerTime.getTime())?new Intl.DateTimeFormat('es-PE',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'numeric',minute:'2-digit'}).format(issuerTime):generated;
 field('Fecha de emisión',issued,309,y,244);
 y=Math.max(holderEnd,metaY+40)+8;
 const periodEnd=field('Periodo evaluado',period(r.desde,r.hasta),left,y,245);
 field('Moneda',require('../countries').currencyName(r.moneda),309,y,244);
 y=Math.max(periodEnd,y+39)+12;

 // Resumen ejecutivo: cuatro cifras y lectura rápida
 y=ensure(y,200);y=section('RESUMEN EJECUTIVO',y);
 const tiles=[
  ['Ventas del periodo',soles(r.ventas_minor),`${r.ventas_cantidad??0} ventas registradas`],
  ['Resultado operativo',soles(r.resultado_operativo_simplificado_minor),A.margen_operativo?`Margen ${A.margen_operativo}`:'Sin ventas para medir margen'],
  ['Cobranza de ventas',A.cobranza||na,'Cobros ÷ ventas del periodo'],
  ['Capital de trabajo',soles(A.capital_trabajo_minor),A.liquidez?`Liquidez ${A.liquidez}`:'Sin cuentas por pagar']
 ];
 const tw=(width-27)/4;
 tiles.forEach(([label,value,note],i)=>{const x=left+i*(tw+9);box(x,y,tw,66);text(label.toUpperCase(),x+8,y+9,tw-16,6.8,true,muted);
  doc.font('Helvetica-Bold').fontSize(value.length>13?9.5:11.5);text(value,x+8,y+24,tw-16,value.length>13?9.5:11.5,true,i===1&&BigInt(r.resultado_operativo_simplificado_minor)<0n?warn:navy);text(note,x+8,y+46,tw-16,7,false,muted);});
 y+=78;
 if(A.lectura.length){
  doc.font('Helvetica').fontSize(8.5);
  const h=A.lectura.reduce((n,s)=>n+doc.heightOfString('• '+s,{width:width-24,lineGap:2})+3,0)+30;
  y=ensure(y,h);box(left,y,width,h);text('Lo más importante',left+12,y+9,width-24,9,true,blue);
  let ly=y+24;A.lectura.forEach(s=>{ly=text('• '+s,left+12,ly,width-24,8.5,false,navy)+3;});
  y+=h+12;
 }

 // 01 Estado de resultados
 y=ensure(y,230);y=section('01  ESTADO DE RESULTADOS SIMPLIFICADO',y);
 y=table([
  ['Ventas registradas',soles(r.ventas_minor)],
  ['(-) Compras de mercadería',soles(r.compras_minor)],
  [`Utilidad bruta aproximada${A.margen_bruto?` (${A.margen_bruto})`:''}`,soles(A.utilidad_bruta_minor)],
  [`(-) Gastos operativos${A.peso_gastos?` (${A.peso_gastos} de las ventas)`:''}`,soles(r.gastos_minor)],
  [`Resultado operativo simplificado${A.margen_operativo?` (${A.margen_operativo})`:''}`,soles(r.resultado_operativo_simplificado_minor),true]
 ],y);

 // 02 Flujo y posición al cierre
 y=ensure(y,300);y=section('02  FLUJO DE CAJA Y POSICIÓN AL CIERRE',y);
 y=table([
  ['Cobros de ventas recibidos en el periodo',soles(r.cobros_ventas_minor)],
  ['(-) Pagos de compras y gastos realizados',soles(r.pagos_operativos_minor)],
  ['Flujo operativo del periodo',soles(r.flujo_operativo_minor),true],
  ['Saldo registrado en cuentas al cierre',soles(r.saldo_cuentas_minor)],
  ['(+) Cuentas por cobrar al cierre',soles(r.por_cobrar_minor)],
  ['(-) Cuentas por pagar al cierre',soles(r.por_pagar_minor)],
  [`Capital de trabajo simplificado${A.liquidez?` · liquidez ${A.liquidez}`:''}`,soles(A.capital_trabajo_minor),true]
 ],y);

 // 03 Cuentas por cobrar
 y=ensure(y,190);y=section('03  CUENTAS POR COBRAR POR ANTIGÜEDAD',y);
 if(BigInt(r.por_cobrar_minor)===0n){y=text('No hay cuentas por cobrar al cierre del periodo.',left,y,width,9,false,muted)+14;}
 else{
  const cols=[['Antigüedad desde la venta',250],['Importe',140],['% del total',121]];
  box(left,y,width,24,navy);let x=left;cols.forEach(([l,w])=>{text(l.toUpperCase(),x+14,y+8,w-20,8,true,'#FFFFFF');x+=w;});y+=28;
  A.antiguedad.forEach((a,i)=>{if(i%2===0)doc.rect(left,y,width,24).fill('#F8FAFD');text(a.label,left+14,y+7,230,9.5);text(soles(a.minor),left+264,y+7,126,9.5);text(a.porcentaje||'-',left+404,y+7,100,9.5);y+=25;});
  y+=6;
  const lines=[];
  if(A.concentracion_top3)lines.push(`Las tres personas que más deben concentran ${A.concentracion_top3} del total.`);
  lines.push(`Personas con saldo pendiente: ${r.deudores_cantidad??0}.`);
  y=text(lines.join(' '),left,y,width,8.5,false,muted)+14;
 }

 // 04 Estabilidad de ingresos
 y=ensure(y,170);y=section('04  ESTABILIDAD DE LOS INGRESOS',y);
 const average=r.promedio_mensual_ventas_minor==null?'Aún no hay meses completos':soles(r.promedio_mensual_ventas_minor);
 const facts=[
  ['Promedio mensual de ventas',average],
  ['Mejor mes',A.mejor_mes?`${A.mejor_mes.mes} · ${soles(A.mejor_mes.minor)}`:na],
  ['Peor mes',A.peor_mes?`${A.peor_mes.mes} · ${soles(A.peor_mes.minor)}`:na],
  ['Variación entre meses',A.variacion?`${A.variacion} del promedio`:'Se necesitan 3 meses completos'],
  ['Tendencia de ventas',A.tendencia?`${A.tendencia} (${A.tendencia_cambio})`:'Se necesitan 4 meses completos'],
  ['Días con ventas',A.regularidad||na],
  ['Venta promedio por operación',A.ticket_promedio_minor?soles(A.ticket_promedio_minor):na]
 ];
 const colW=(width-16)/2;
 facts.forEach(([label,value],i)=>{const cx=left+(i%2)*(colW+16),cy=y+Math.floor(i/2)*38;text(label.toUpperCase(),cx,cy,colW,7.5,true,muted);text(value,cx,cy+13,colW,9.5,true);});
 y+=Math.ceil(facts.length/2)*38+4;
 const count=r.meses_con_informacion??0;
 y=text(`${r.meses_completos} ${r.meses_completos===1?'mes completo incluido':'meses completos incluidos'}; ${count} ${count===1?'mes':'meses'} con operaciones. Historial declarado desde ${date(r.inicio_historial_declarado)}.${r.desde<r.inicio_historial_declarado?' El periodo comienza antes del historial registrado: cobertura parcial.':''}`,left,y,width,8.5,false,muted)+14;

 // 05 Principales gastos
 const cats=(r.gastos_por_categoria||[]).filter(c=>BigInt(c.total_minor)>0n).slice(0,3);
 if(cats.length){
  y=ensure(y,120);y=section('05  PRINCIPALES GASTOS OPERATIVOS',y);
  cats.forEach((c,i)=>{if(i%2===0)doc.rect(left,y,width,24).fill('#F8FAFD');text(c.nombre||'Sin categoría',left+14,y+7,300,9.5);text(soles(c.total_minor),left+264,y+7,126,9.5);text(require('./certificate-analysis').percent(c.total_minor,r.gastos_minor)||'-',left+404,y+7,100,9.5);y+=25;});
  y+=10;
 }

 // 06 Notas y alcance
 const notes='Ventas y cobros son distintos: un cobro posterior no crea otra venta. Las compras de mercadería se usan como referencia del costo, porque FINKI no lleva inventario; por eso la utilidad bruta es aproximada. El resultado operativo (ventas - compras - gastos) no es utilidad contable ni dinero disponible. El capital de trabajo suma el saldo registrado en cuentas y las cuentas por cobrar, y resta las cuentas por pagar; la liquidez es (cuentas + por cobrar) ÷ por pagar. La antigüedad se cuenta desde la fecha de la venta hasta el cierre del periodo.';
 const disclaimer='Esta constancia resume la actividad económica registrada por el usuario en FINKI durante el periodo indicado. La información no ha sido auditada, no constituye certificación oficial, documento tributario, aprobación crediticia ni garantía de acceso a financiamiento. No incluye operaciones pendientes de sincronización.';
 doc.font('Helvetica').fontSize(8.5);
 const notesHeight=doc.heightOfString(notes,{width,lineGap:2});
 const scopeHeight=doc.heightOfString(disclaimer,{width:width-24,lineGap:2})+43;
 y=ensure(y,23+notesHeight+14+scopeHeight);
 y=section('06  NOTAS DE LECTURA',y);
 y=text(notes,left,y,width,8.5,false,muted)+14;
 box(left,y,width,scopeHeight);
 text('Alcance del documento',left+12,y+10,width-24,9,true);
 text(disclaimer,left+12,y+28,width-24,8.5,false,muted);

 // Anexo: evolución mensual, solo si aporta información.
 if(r.serie_mensual.length>1){
  doc.addPage();text('ANEXO · EVOLUCIÓN MENSUAL',left,48,width,18,true);text(r.negocio_nombre,left,77,width,10);let top=110;
  const columns=[['Mes',64],['Ventas',92],['Cobros',92],['Pagos',92],['Gastos',85],['Compras',86]];
  const header=()=>{box(left,top,width,28,navy);let x=left;for(const [label,w]of columns){text(label,x+8,top+9,w-12,8,true,'#FFFFFF');x+=w;}top+=32;};header();
  for(const m of r.serie_mensual){if(top>720){doc.addPage();top=50;header();}let x=left;const vals=[m.mes+(m.parcial?' *':''),soles(m.ventas_minor),soles(m.cobros_minor),soles(m.pagos_minor),soles(m.gastos_minor),soles(m.compras_minor)];doc.rect(left,top,width,27).fill('#F4F7FC');vals.forEach((v,i)=>{text(v,x+8,top+9,columns[i][1]-12,8);x+=columns[i][1];});top+=30;}
  if(top+65>limit){doc.addPage();top=50;} text('* Mes parcial. El promedio usa solo meses calendario completos, incluidos meses sin registros con cero; la ausencia de registros no demuestra ausencia de actividad.',left,top+12,width,8.5,false,muted);
 }
 const pages=doc.bufferedPageRange();for(let p=0;p<pages.count;p++){doc.switchToPage(p);doc.page.margins.bottom=0;rule(792);text(`FINKI | Código ${id}`,left,800,410,7,false,muted);text(`${p+1} / ${pages.count}`,497,800,56,8,true,muted);}
 doc.end();
});};
module.exports.period=period;
