'use strict';
const PDFDocument=require('pdfkit'),path=require('node:path');
const navy='#12335D',blue='#1762C4',muted='#52657C',line='#DCE5F0',pale='#F1F6FC';
const date=d=>d.split('-').reverse().join('/');
const period=(a,b)=>a===b?date(a):`${date(a)} al ${date(b)}`;
module.exports=function render(r,id,generated,soles){return new Promise((resolve,reject)=>{
 const doc=new PDFDocument({size:'A4',margin:42,bufferPages:true,info:{Title:'FINKI - Constancia de actividad del negocio',Author:'FINKI',Subject:'Resumen de registros del usuario; no certificación oficial',FinkiFormula:String(r.version_formula),FinkiCorte:String(r.corte_sync_seq??'-'),FinkiDocumento:String(r.version_documento||'2.0')}}),chunks=[];
 doc.on('data',b=>chunks.push(b));doc.on('end',()=>resolve(Buffer.concat(chunks)));doc.on('error',reject);
 const left=42,width=511;
 const text=(s,x,y,w=width,size=10,bold=false,color=navy)=>{doc.font(bold?'Helvetica-Bold':'Helvetica').fontSize(size).fillColor(color).text(String(s??'No consignado'),x,y,{width:w,lineGap:2});return doc.y;};
 const box=(x,y,w,h,color=pale)=>doc.roundedRect(x,y,w,h,9).fill(color);
 const rule=y=>doc.moveTo(left,y).lineTo(left+width,y).strokeColor(line).lineWidth(.6).stroke();
 const section=(title,y)=>{text(title,left,y,width,11,true,blue);return y+23;};
 const field=(label,value,x,y,w)=>{text(label.toUpperCase(),x,y,w,7.5,true,muted);return text(value,x,y+14,w,10,true);};
 box(left,38,width,116);
 doc.image(path.join(__dirname,'../../../assets/branding/finki_logo_display.png'),52,48,{fit:[100,92],align:'center',valign:'center'});
 text('CONSTANCIA DE ACTIVIDAD\nDEL NEGOCIO',169,57,366,19,true);
 text('Resumen de movimientos registrados en FINKI',169,112,366,9,false,muted);
 let y=174;
 doc.font('Helvetica-Bold').fontSize(18);const nameHeight=doc.heightOfString(r.negocio_nombre,{width});
 text(r.negocio_nombre,left,y,width,18,true);y+=nameHeight+15;
 const metaY=y;
 const holderEnd=field('Titular / responsable',r.titular_nombre||'No consignado',left,y,245);
 const issuerTime=new Date(generated.replace(' ','T')+'Z');
 const zone=r.zona_horaria||'America/Lima';
 const issued=Number.isFinite(issuerTime.getTime())?new Intl.DateTimeFormat('es-PE',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'numeric',minute:'2-digit'}).format(issuerTime):generated;
 field('Fecha de emisión',issued,309,y,244);
 y=Math.max(holderEnd,metaY+40)+10;
 const periodEnd=field('Periodo evaluado',period(r.desde,r.hasta),left,y,245);
 field('Moneda',require('../countries').currencyName(r.moneda),309,y,244);
 y=Math.max(periodEnd,y+39)+14;
 if(y+245>755){doc.addPage();y=50;} y=section('01  RESUMEN GENERAL',y);
 box(left,y,width,27,navy);text('CONCEPTO',left+14,y+8,340,8,true,'#FFFFFF');text('IMPORTE (S/)',left+366,y+8,129,8,true,'#FFFFFF');y+=31;
 const rows=[['Ventas registradas','ventas_minor'],['Cobros recibidos de ventas','cobros_ventas_minor'],['Gastos operativos registrados','gastos_minor'],['Compras de mercadería registradas','compras_minor'],['Me deben al cierre','por_cobrar_minor'],['Debo pagar al cierre','por_pagar_minor'],['Resultado simplificado','resultado_operativo_simplificado_minor']];
 rows.forEach(([label,key],i)=>{const result=i===rows.length-1;if(result)box(left,y,width,26,pale);else if(i%2===0)doc.rect(left,y,width,26).fill('#F8FAFD');text(label,left+14,y+8,342,9.5,result);doc.font(result?'Helvetica-Bold':'Helvetica').fontSize(11).fillColor(result?blue:navy).text(soles(r[key]),left+356,y+7,{width:140,align:'right'});y+=27;});
 y+=10;if(y+100>755){doc.addPage();y=50;} y=section('02  PROMEDIO Y COBERTURA',y);
 const average=r.promedio_mensual_ventas_minor==null?'Aún no hay meses completos':soles(r.promedio_mensual_ventas_minor);
 const count=r.meses_con_informacion??0;
 const details=`${r.meses_completos} ${r.meses_completos===1?'mes completo incluido':'meses completos incluidos'}. ${count} ${count===1?'mes':'meses'} con operaciones. Historial desde ${date(r.inicio_historial_declarado)}.`;
 text('Promedio mensual de ventas',left,y,300,10,true);text(average,319,y,234,10,true,blue);y+=23;
 y=text(details,left,y,width,8.5,false,muted)+12;
 if(r.desde<r.inicio_historial_declarado)y=text('Periodo con cobertura parcial: comienza antes del historial registrado.',left,y,width,8.5,true,muted)+8;
 const notes='Ventas y cobros son distintos: un abono no crea otra venta. Los saldos al cierre descuentan cobros y pagos válidos hasta esa fecha. Resultado simplificado = ventas - compras - gastos; no es utilidad contable ni dinero disponible.';
 const disclaimer='La presente constancia resume la actividad económica registrada por el usuario en FINKI durante el periodo indicado. La información no ha sido objeto de auditoría independiente y no constituye una certificación oficial, documento tributario ni garantía de acceso a financiamiento. No incluye operaciones pendientes de sincronización';
 doc.font('Helvetica').fontSize(8.5);
 const notesHeight=doc.heightOfString(notes,{width,lineGap:2});
 const scopeHeight=doc.heightOfString(disclaimer,{width:width-24,lineGap:2})+43;
 if(y+23+notesHeight+14+scopeHeight>778){doc.addPage();y=50;}
 y=section('03  OBSERVACIONES',y);
 y=text(notes,left,y,width,8.5,false,muted)+14;
 box(left,y,width,scopeHeight);
 text('Alcance del documento',left+12,y+10,width-24,9,true);
 text(disclaimer,left+12,y+28,width-24,8.5,false,muted);
 // Detail is an annex only when it adds information, instead of an empty page.
 if(r.serie_mensual.length>1){
  doc.addPage();text('EVOLUCIÓN DEL PERIODO',left,48,width,18,true);text(r.negocio_nombre,left,77,width,10);let top=110;
  const columns=[['Mes',60],['Ventas',100],['Cobros',100],['Pagos',100],['Gastos / compras',151]];
  const header=()=>{box(left,top,width,28,navy);let x=left;for(const [label,w]of columns){text(label,x+8,top+9,w-16,8,true,'#FFFFFF');x+=w;}top+=32;};header();
  for(const m of r.serie_mensual){if(top>720){doc.addPage();top=50;header();}let x=left;const vals=[m.mes+(m.parcial?' *':''),soles(m.ventas_minor),soles(m.cobros_minor),soles(m.pagos_minor),`${soles(m.gastos_minor)} / ${soles(m.compras_minor)}`];doc.rect(left,top,width,31).fill('#F4F7FC');vals.forEach((v,i)=>{text(v,x+8,top+9,columns[i][1]-16,8);x+=columns[i][1];});top+=34;}
  if(top+65>755){doc.addPage();top=50;} text('* Mes parcial. Promedio: solo meses calendario completos, incluidos meses sin registros con cero; la ausencia de registros no demuestra ausencia de actividad.',left,top+12,width,8.5,false,muted);
 }
 const pages=doc.bufferedPageRange();for(let p=0;p<pages.count;p++){doc.switchToPage(p);doc.page.margins.bottom=0;rule(792);text(`FINKI | Código ${id}`,left,800,410,7,false,muted);text(`${p+1} / ${pages.count}`,497,800,56,8,true,muted);}
 doc.end();
});};
module.exports.period=period;




