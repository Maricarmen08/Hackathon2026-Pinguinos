'use strict';
const {buildReport}=require('./queries');

const {soles}=require('./certificate');
const {fail}=require('../errors');
const shift=(d,n)=>new Date(Date.parse(d+'T00:00:00Z')+n*86400000).toISOString().slice(0,10);
const {period,businessToday,morning}=require('./insights-period');
const {questionText,periodText,dialogue}=require('./question-language');
// Whitelisted intents and date grammar. No generated SQL or external provider.
function answer(business,data,question,categories=[],people=[],asOf=businessToday(business)){
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
  const prefix=`Del ${label}: `;
  const coverage=from<business.inicio_historial?` Historial disponible desde ${day(business.inicio_historial)}; el periodo está incompleto.`:'';
  const result=(text,extra={},stock=false)=>({respuesta:text+(stock?'':coverage||(!sufficient?' Sin movimientos registrados en ese periodo.':''))+(morning(q)?' No separo por horas: muestro el día completo.':''),desde:from,hasta:to,datos_suficientes:sufficient,indicadores:r,fuente:'REGISTROS',...extra});
  if(q.includes('producto')&&/vend|venta/.test(q))return result('Todavía no puedo comparar productos: los registros no detallan un inventario por producto. Puedo mostrar las ventas totales.',{datos_suficientes:false});
  if(/\b(quien|quienes|clientes?|deudores?)\b/.test(q)&&/deb|fiad|cobrar/.test(q)){
    const groups=new Map();for(const o of r.pendientes.filter(o=>['VENTA','SALDO_CXC'].includes(o.tipo))){const id=o.tercero_id||null;groups.set(id,(groups.get(id)||0n)+BigInt(o.pendiente_minor));}
    const debtors=[...groups].sort((a,b)=>a[1]===b[1]?0:a[1]>b[1]?-1:1).map(([id,n])=>({tercero_id:id,nombre:people.find(p=>p.id===id)?.nombre||'Sin cliente identificado',pendiente_minor:n.toString()}));
    return result(debtors.length?`${debtors.slice(0,5).map(d=>`${d.nombre}: ${soles(d.pendiente_minor)}`).join('; ')}. Pendiente al ${day(to)}, descontando abonos.`:`Nadie tiene una deuda pendiente registrada al ${day(to)}.`,{deudores:debtors,datos_suficientes:debtors.length>0},true);
  }
  if(/compar|mas que|menos que|evoluci|creci/.test(q)&&/vend|venta|negocio/.test(q)){
    if(q.includes('mes pasado')&&!/\d{4}|\d{2}\//.test(q)){
      const start=end.slice(0,7)+'-01',last=shift(start,-1),a=last.slice(0,7)+'-01',cur=report(start,end),prev=report(a,last);
      return result(`Mes actual hasta ${end}: ventas ${soles(cur.ventas_minor)}; mes anterior completo (${a} al ${last}): ${soles(prev.ventas_minor)}. Diferencia ${soles((BigInt(cur.ventas_minor)-BigInt(prev.ventas_minor)).toString())}. El mes actual es parcial. ${a<business.inicio_historial?'No existe cobertura completa del mes anterior.':'No es una predicción.'}`,{indicadores:cur,desde:start,hasta:end,comparacion:prev,datos_suficientes:cur.primer_registro!==null&&a>=business.inicio_historial});
    }
    const days=Math.round((Date.parse(to)-Date.parse(from))/86400000)+1,a=shift(from,-days),b=shift(from,-1),prev=report(a,b);
    return result(`${prefix}ventas ${soles(r.ventas_minor)}; periodo anterior de igual duración (${a} al ${b}), ${soles(prev.ventas_minor)}. Diferencia ${soles((BigInt(r.ventas_minor)-BigInt(prev.ventas_minor)).toString())}. ${a<business.inicio_historial?'No hay cobertura completa del periodo anterior.':'Son registros, no una predicción.'}`,{comparacion:prev,datos_suficientes:sufficient&&a>=business.inicio_historial});
  }
  if(/por que|recom|consej|como va|como esta|me fue|resumen|balance|resultado|ganancia|utilidad|\bgane\b|ganado/.test(q))return result([
    `Resumen de tu negocio · ${label}`,
    '',
    'Actividad del periodo',
    `Ventas: ${soles(r.ventas_minor)}`,
    `Gastos operativos: ${soles(r.gastos_minor)}`,
    `Compras de mercadería: ${soles(r.compras_minor)}`,
    '',
    'Dinero cobrado y pagado',
    `Cobros de ventas: ${soles(r.cobros_ventas_minor)}`,
    `Pagos operativos: ${soles(r.pagos_operativos_minor)}`,
    'Los cobros y pagos no crean nuevas ventas, gastos ni compras.',
    '',
    `Deudas al ${day(to)}`,
    `Por cobrar: ${soles(r.por_cobrar_minor)}`,
    `Por pagar: ${soles(r.por_pagar_minor)}`,
    '',
    `Resultado simplificado: ${soles(r.resultado_operativo_simplificado_minor)}`,
    'Ventas menos compras y gastos. No es utilidad contable ni dinero disponible.',
    !sufficient?'No hay datos suficientes para recomendar cambios.':BigInt(r.resultado_operativo_simplificado_minor)<0n?'Las compras y los gastos superan las ventas registradas; no puedo determinar causas externas ni pérdidas contables.':''
  ].filter((line,index,lines)=>line!==''||index<lines.length-1).join('\n'));
  if(/gasto mas grande|mayor gasto individual|gasto individual mas/.test(q)){
    const expenses=rows.filter(o=>o.tipo==='GASTO_OPERATIVO').sort((a,b)=>BigInt(a.total_minor)===BigInt(b.total_minor)?a.id.localeCompare(b.id):BigInt(a.total_minor)>BigInt(b.total_minor)?-1:1);
    return result(expenses.length?`${soles(expenses[0].total_minor)} fue tu gasto más grande · ${label}.\n${expenses[0].concepto||'Gasto registrado'}. No incluye compras de mercadería.`:`No hay gastos operativos registrados · ${label}.`,{gasto_mayor:expenses[0]||null});
  }
  if(/(en que|mayor|mas).*gast|gast.*(categoria|mas)/.test(q)){
    const groups=new Map();for(const o of rows.filter(o=>o.tipo==='GASTO_OPERATIVO'))groups.set(o.categoria_id,(groups.get(o.categoria_id)||0n)+BigInt(o.total_minor));
    const cats=[...groups].sort((a,b)=>a[1]===b[1]?0:a[1]>b[1]?-1:1).map(([id,n])=>({nombre:categories.find(c=>c.id===id)?.nombre||'General',monto_minor:n.toString()}));
    return result(cats.length?`${prefix}mayor gasto operativo ${cats[0].nombre}: ${soles(cats[0].monto_minor)}. Las compras se muestran aparte.`:`${prefix}no hay gastos operativos registrados.`,{categorias:cats});
  }
  if(/me deben|por cobrar|fiados|fiado/.test(q)&&!/debo|pagar/.test(q))return result(`${soles(r.por_cobrar_minor)} por cobrar al ${day(to)}. Ya descuenta los abonos registrados.`,{},true);
  if(/debo|por pagar|deudas pendientes/.test(q))return result(`${soles(r.por_pagar_minor)} por pagar al ${day(to)}. Ya descuenta los pagos registrados.`,{},true);
  if(/mercaderia|compras|compre/.test(q))return result(`${prefix}compras de mercadería ${soles(r.compras_minor)}. No son pagos ni costo contable de productos vendidos.`);
  if(/cobr|recibi|recibido/.test(q))return result(`${prefix}cobros de ventas ${soles(r.cobros_ventas_minor)}; cobros de deudas iniciales ${soles(r.cobros_deudas_iniciales_minor)}. No crean ventas nuevas.`);
  if(/pague|pagos|pagado/.test(q))return result(`${prefix}pagos operativos ${soles(r.pagos_operativos_minor)}; pagos de deudas iniciales ${soles(r.pagos_deudas_iniciales_minor)}. No crean gastos ni compras nuevos.`);
  if(/movimiento|flujo|dinero.*mov/.test(q))return result(`${prefix}entradas externas ${soles(r.entradas_externas_minor)}, salidas externas ${soles(r.salidas_externas_minor)}. Excluyen transferencias entre cuentas; no representan ventas ni utilidad.`);
  if(/gast|egresos operativos/.test(q))return result(`${prefix}gastos operativos ${soles(r.gastos_minor)} y compras de mercadería ${soles(r.compras_minor)} por separado. No se suman sus pagos.`);
  if(/vend|ventas/.test(q))return result(`${soles(r.ventas_minor)} en ventas · ${label}.`);
  fail(422,'QUESTION_UNSUPPORTED','No estoy seguro de qué cuenta quieres revisar. Cuéntame si buscas ventas, gastos, cobros o deudas.');
}
module.exports={answer,period};


