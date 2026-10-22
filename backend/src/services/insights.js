'use strict';
const {buildReport}=require('./queries');
const {today}=require('../domain');
const {soles}=require('./certificate');
const {fail}=require('../errors');
const shift=(d,n)=>new Date(Date.parse(d+'T00:00:00Z')+n*86400000).toISOString().slice(0,10);
function answer(business,data,question,categories=[]){
  const q=question.normalize('NFD').replace(/\p{Diacritic}/gu,'').toLowerCase(),end=today(business.zona_horaria),month=end.slice(0,7)+'-01';
  const report=(a,b)=>buildReport(business,...data,a,b),current=report(month,end);
  if(q.includes('producto')&&q.includes('vend'))return {respuesta:'Todavía no puedo comparar productos: tus registros no detallan cantidades por producto. Puedo mostrarte tus ventas totales sin inventar un ranking.',datos_suficientes:false,indicadores:current};
  if(q.includes('gast')&&q.includes('semana')&&!q.includes('resumen')){
    const dow=new Date(end+'T00:00:00Z').getUTCDay(),start=shift(end,-((dow+6)%7)),r=report(start,end);
    return {respuesta:`Esta semana registraste ${soles(r.gastos_minor)} en gastos de funcionamiento y ${soles(r.compras_minor)} en compras de mercadería. Son registros de gastos y compras, no la suma de sus pagos.`,desde:start,hasta:end,indicadores:r};
  }
  if(q.includes('resumen')||q.includes('semana')){
    const dow=new Date(end+'T00:00:00Z').getUTCDay(),start=shift(end,-((dow+6)%7)),elapsed=Math.floor((Date.parse(end)-Date.parse(start))/86400000),prev=report(shift(start,-7),shift(start,-7+elapsed)),r=report(start,end);
    return {respuesta:`Esta semana registraste ${soles(r.ventas_minor)} en ventas, cobraste ${soles(r.cobros_ventas_minor)} y registraste ${soles(r.gastos_minor)} en gastos. Tus compras fueron ${soles(r.compras_minor)}. Te deben ${soles(r.por_cobrar_minor)} al cierre. En los mismos días de la semana anterior registraste ${soles(prev.ventas_minor)} en ventas.`,desde:start,hasta:end,indicadores:r,comparacion:{desde:prev.desde,hasta:prev.hasta,ventas_minor:prev.ventas_minor}};
  }
  if(q.includes('deben'))return {respuesta:`Al ${end}, te deben ${soles(current.por_cobrar_minor)}. Es saldo de ventas y deudas anteriores al historial.`,indicadores:current};
  if(q.includes('mercaderia'))return {respuesta:`Este mes registraste ${soles(current.compras_minor)} en compras de mercadería. Los pagos realizados se muestran aparte y no crean nuevas compras.`,indicadores:current};
  if(q.includes('en que')&&q.includes('gast')){
    const by=new Map();for(const o of data[0])if(o.estado==='CONFIRMADO'&&o.tipo==='GASTO_OPERATIVO'&&o.fecha_operacion>=month&&o.fecha_operacion<=end)by.set(o.categoria_id,(by.get(o.categoria_id)||0n)+BigInt(o.total_minor));
    const rows=[...by].sort((a,b)=>a[1]===b[1]?0:a[1]>b[1]?-1:1).map(([id,n])=>({nombre:categories.find(c=>c.id===id)?.nombre||'General',monto_minor:n.toString()}));
    return {respuesta:rows.length?`Tu mayor gasto registrado este mes es ${rows[0].nombre}: ${soles(rows[0].monto_minor)}.`:'Este mes todavía no hay gastos registrados.',categorias:rows,indicadores:current};
  }
  if(q.includes('mes pasado')&&q.includes('vend')){
    const last=shift(month,-1),previous=report(last.slice(0,7)+'-01',last);
    return {respuesta:`Este mes (hasta ${end}) registraste ${soles(current.ventas_minor)} en ventas; el mes anterior completo, ${soles(previous.ventas_minor)}. La comparación incluye un mes actual parcial.`,indicadores:current,comparacion:{desde:previous.desde,hasta:previous.hasta,ventas_minor:previous.ventas_minor}};
  }
  if(q.includes('vend')||q.includes('ventas')){
    const r=q.includes('hoy')?report(end,end):q.includes('mes')?current:null;
    if(r)return {respuesta:`Del ${r.desde} al ${r.hasta} registraste ${soles(r.ventas_minor)} en ventas y recibiste ${soles(r.cobros_ventas_minor)} en cobros de ventas. Son cifras distintas: los cobros pueden corresponder a ventas de otro día.`,indicadores:r};
  }
  fail(422,'QUESTION_UNSUPPORTED','Prueba una de las preguntas sugeridas para consultar tus datos.');
}
module.exports={answer};
