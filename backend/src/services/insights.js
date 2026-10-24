'use strict';
const {buildReport}=require('./queries');

const {soles:baseSoles}=require('./certificate');
const {symbolFor}=require('../countries');
const {fail}=require('../errors');
const shift=(d,n)=>new Date(Date.parse(d+'T00:00:00Z')+n*86400000).toISOString().slice(0,10);
const {period,businessToday,morning}=require('./insights-period');
const {questionText,periodText,dialogue}=require('./question-language');
// Whitelisted intents and date grammar. No generated SQL or external provider.
function answer(business,data,question,categories=[],people=[],asOf=businessToday(business)){
  const symbol=symbolFor(business.moneda),soles=v=>baseSoles(v,symbol);
  const q=questionText(question),end=asOf;
  if(/\b(drop|select|insert|update|delete|alter|sql)\b/.test(q))fail(422,'QUESTION_UNSUPPORTED','Solo puedo consultar indicadores del negocio seleccionado.');
  const conversationalAnswer=dialogue(question,business,asOf);
  if(conversationalAnswer)return conversationalAnswer;
  const conversational=q.replace(/[¿?¡!.,]/g,'').trim();
  if(/^(hola|buenos dias|buenas tardes|buenas noches|quien eres|que eres|como te llamas|quien soy|quien soy yo)$/.test(conversational))return {
    respuesta:/^quien soy/.test(conversational)?'Puedes ver tus datos en Perfil. Aquí te ayudo a revisar las cuentas de tu negocio.':'Soy Finki, tu asistente para consultar ventas, gastos y fiados de tu negocio. ¿Qué quieres revisar?',
    fuente:'ORIENTACION',datos_suficientes:false
  };
  if(/predec|pronostic|\bmanana\b|proxim|banco|credito me dar|clima|contrasena|mi clave/.test(q.replace(/esta manana|hoy (?:en|por) la manana/g,'')))fail(422,'QUESTION_OUT_OF_SCOPE','Puedo revisar los registros de tu negocio. No puedo predecir ventas, consultar bancos ni recuperar contraseñas.');
  const [from,to]=period(periodText(question),end),report=(a,b)=>buildReport(business,...data,a,b),r=report(from,to);
  const rows=data[0].filter(o=>o.estado==='CONFIRMADO'&&o.fecha_operacion>=from&&o.fecha_operacion<=to);
  const sufficient=rows.length>0||data[1].some(m=>m.estado==='CONFIRMADO'&&m.fecha_movimiento>=from&&m.fecha_movimiento<=to);
  const day=d=>d.split('-').reverse().join('/'),label=from===to?day(to):`${day(from)} al ${day(to)}`;
  const when=from===to?(to===end?'hoy':to===shift(end,-1)?'ayer':`el ${day(to).slice(0,5)}`):(from===end.slice(0,7)+'-01'&&to===end?'este mes':from===shift(end,-((new Date(end+'T00:00:00Z').getUTCDay()+6)%7))&&to===end?'esta semana':`del ${day(from).slice(0,5)} al ${day(to).slice(0,5)}`);
  const prefix='';
  const cmp=(now,before)=>{const d=BigInt(now)-BigInt(before);return d===0n?'Es lo mismo.':d>0n?`Vendiste ${soles(d.toString())} más.`:`Vendiste ${soles((-d).toString())} menos.`;};
  const coverage=from<business.inicio_historial?` Ojo: solo tengo tus registros desde el ${day(business.inicio_historial)}.`:'';
  const result=(text,extra={},stock=false)=>({respuesta:text+(stock?'':coverage||(!sufficient?' Todavía no hay registros en ese periodo.':''))+(morning(q)?' No separo por horas; te muestro el día completo.':''),desde:from,hasta:to,datos_suficientes:sufficient,indicadores:r,fuente:'REGISTROS',...extra});
  if(q.includes('producto')&&/vend|venta/.test(q))return result('Todavía no puedo comparar productos: los registros no detallan un inventario por producto. Puedo mostrar las ventas totales.',{datos_suficientes:false});
  if(/\b(quien|quienes|alguien|alguno|algunos|clientes?|deudores?|personas?|gente)\b/.test(q)&&/deb|deud|fiad|\bfie\b|cobrar|moros|no me (?:ha |han )?pag/.test(q)&&!/\bdebo\b|le debo|les debo/.test(q)){
    const groups=new Map();for(const o of r.pendientes.filter(o=>['VENTA','SALDO_CXC'].includes(o.tipo))){const id=o.tercero_id||null;groups.set(id,(groups.get(id)||0n)+BigInt(o.pendiente_minor));}
    const debtors=[...groups].sort((a,b)=>a[1]===b[1]?0:a[1]>b[1]?-1:1).map(([id,n])=>({tercero_id:id,nombre:people.find(p=>p.id===id)?.nombre||'Sin cliente identificado',pendiente_minor:n.toString()}));
    return result(debtors.length?`${debtors.length===1?'Te debe 1 persona':`Te deben ${debtors.length} personas`}:\n${debtors.slice(0,5).map(d=>`• ${d.nombre}: ${soles(d.pendiente_minor)}`).join('\n')}${debtors.length>5?`\nY ${debtors.length-5} más.`:''}`:'Nadie te debe nada por ahora.',{deudores:debtors,datos_suficientes:debtors.length>0},true);
  }
  if(/compar|mas que|menos que|evoluci|creci/.test(q)&&/vend|venta|negocio/.test(q)){
    if(q.includes('mes pasado')&&!/\d{4}|\d{2}\//.test(q)){
      const start=end.slice(0,7)+'-01',last=shift(start,-1),a=last.slice(0,7)+'-01',cur=report(start,end),prev=report(a,last);
      return result(`Este mes llevas ${soles(cur.ventas_minor)} en ventas. El mes pasado vendiste ${soles(prev.ventas_minor)}. ${cmp(cur.ventas_minor,prev.ventas_minor)} Ojo: este mes todavía no termina. ${a<business.inicio_historial?'No tengo todos los registros del mes pasado.':''}`.trim(),{indicadores:cur,desde:start,hasta:end,comparacion:prev,datos_suficientes:cur.primer_registro!==null&&a>=business.inicio_historial});
    }
    const days=Math.round((Date.parse(to)-Date.parse(from))/86400000)+1,a=shift(from,-days),b=shift(from,-1),prev=report(a,b);
    return result(`Vendiste ${soles(r.ventas_minor)} ${when}. En el periodo anterior (del ${day(a).slice(0,5)} al ${day(b).slice(0,5)}) vendiste ${soles(prev.ventas_minor)}. ${cmp(r.ventas_minor,prev.ventas_minor)} ${a<business.inicio_historial?'No tengo todos los registros del periodo anterior.':''}`.trim(),{comparacion:prev,datos_suficientes:sufficient&&a>=business.inicio_historial});
  }
  if(/por que|recom|consej|como va|como esta|me fue|resumen|balance|resultado|ganancia|utilidad|\bgane\b|ganado/.test(q))return result([
    `${['hoy','esta semana','este mes'].includes(when)?'Así va tu negocio':'Así le fue a tu negocio'} ${when}:`,
    `• Vendiste: ${soles(r.ventas_minor)}`,
    `• Gastaste: ${soles(r.gastos_minor)}`,
    `• Compraste mercadería: ${soles(r.compras_minor)}`,
    `• Te deben: ${soles(r.por_cobrar_minor)}`,
    `• Debes: ${soles(r.por_pagar_minor)}`,
    `Ventas menos gastos y compras: ${soles(r.resultado_operativo_simplificado_minor)}. No es tu ganancia exacta ni el dinero que tienes ahora.`,
    !sufficient?'Aún hay pocos registros para darte consejos.':BigInt(r.resultado_operativo_simplificado_minor)<0n?'Las compras y los gastos superan a las ventas registradas.':''
  ].filter((line,index,lines)=>line!==''||index<lines.length-1).join('\n'));
  if(/gasto mas grande|mayor gasto individual|gasto individual mas/.test(q)){
    const expenses=rows.filter(o=>o.tipo==='GASTO_OPERATIVO').sort((a,b)=>BigInt(a.total_minor)===BigInt(b.total_minor)?a.id.localeCompare(b.id):BigInt(a.total_minor)>BigInt(b.total_minor)?-1:1);
    return result(expenses.length?`Tu gasto más grande ${when} fue ${soles(expenses[0].total_minor)}: ${expenses[0].concepto||'gasto registrado'}.`:`No hay gastos registrados ${when}.`,{gasto_mayor:expenses[0]||null});
  }
  if(/(en que|mayor|mas).*gast|gast.*(categoria|mas)/.test(q)){
    const groups=new Map();for(const o of rows.filter(o=>o.tipo==='GASTO_OPERATIVO'))groups.set(o.categoria_id,(groups.get(o.categoria_id)||0n)+BigInt(o.total_minor));
    const cats=[...groups].sort((a,b)=>a[1]===b[1]?0:a[1]>b[1]?-1:1).map(([id,n])=>({nombre:categories.find(c=>c.id===id)?.nombre||'General',monto_minor:n.toString()}));
    return result(cats.length?`Gastaste más en ${cats[0].nombre}: ${soles(cats[0].monto_minor)} ${when}.`:`No hay gastos registrados ${when}.`,{categorias:cats});
  }
  if(/me deb(?:e|en)|me estan debiendo|me quedaron? debiendo|por cobrar|falta(?:n)? cobrar|pendientes? de cobr|fiados?/.test(q)&&!/\bdebo\b|pagar/.test(q))return result(BigInt(r.por_cobrar_minor)>0n?`Te deben ${soles(r.por_cobrar_minor)} en total.`:'Nadie te debe nada por ahora.',{},true);
  if(/debo|por pagar|tengo que pagar|a pagar|deudas?\b/.test(q))return result(BigInt(r.por_pagar_minor)>0n?`Debes pagar ${soles(r.por_pagar_minor)} en total.`:'No debes nada por ahora.',{},true);
  if(/mercaderia|compras|compre/.test(q))return result(`Compraste mercadería por ${soles(r.compras_minor)} ${when}.`);
  if(/cobr|recibi|recibido/.test(q))return result(`Cobraste ${soles((BigInt(r.cobros_ventas_minor)+BigInt(r.cobros_deudas_iniciales_minor)).toString())} ${when}. Es plata que ya te pagaron, no son ventas nuevas.`);
  if(/pague|pagos|pagado/.test(q))return result(`Pagaste ${soles((BigInt(r.pagos_operativos_minor)+BigInt(r.pagos_deudas_iniciales_minor)).toString())} ${when}. Son pagos de lo que debías, no gastos nuevos.`);
  if(/movimiento|flujo|dinero.*mov|\bentr(?:o|aron)\b|\bsali(?:o|eron)\b/.test(q))return result(`Entró ${soles(r.entradas_externas_minor)} y salió ${soles(r.salidas_externas_minor)} ${when}. No cuento lo que moviste entre tus cuentas.`);
  if(/gast|egresos operativos/.test(q))return result(`Gastaste ${soles(r.gastos_minor)} ${when}. Aparte, compraste mercadería por ${soles(r.compras_minor)}.`);
  if(/vend|ventas|factur|ingres|recaud/.test(q))return result(`Vendiste ${soles(r.ventas_minor)} ${when}.`);
  fail(422,'QUESTION_UNSUPPORTED','No te entendí bien. Prueba con: «¿Cuánto vendí hoy?», «¿Cuánto gasté?» o «¿Quién me debe?».');
}
module.exports={answer,period};


