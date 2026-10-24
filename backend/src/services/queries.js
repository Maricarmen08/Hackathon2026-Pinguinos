'use strict';
const { fail } = require('../errors');
const { today } = require('../domain');
const { membership,requireSession } = require('./auth');
const inRange=(d,a,b)=>d>=a&&d<=b;
const monthStart=d=>d.slice(0,7)+'-01';
function nextMonth(d) { const v=new Date(d+'T00:00:00Z');v.setUTCMonth(v.getUTCMonth()+1);return v.toISOString().slice(0,10); }
function buildReport(business,operations,movements,applications,accounts,closures,from,to) {
  const ops=operations.filter(o=>o.estado==='CONFIRMADO');
  const moves=movements.filter(m=>m.estado==='CONFIRMADO');
  const om=new Map(ops.map(o=>[o.id,o])),mm=new Map(moves.map(m=>[m.id,m]));
  const sum=(rows,field)=>rows.reduce((n,r)=>n+BigInt(r[field]),0n);
  const periodOps=ops.filter(o=>inRange(o.fecha_operacion,from,to));
  const sales=sum(periodOps.filter(o=>o.tipo==='VENTA'),'total_minor');
  const purchases=sum(periodOps.filter(o=>o.tipo==='COMPRA_MERCADERIA'),'total_minor');
  const expenses=sum(periodOps.filter(o=>o.tipo==='GASTO_OPERATIVO'),'total_minor');
  let collected=0n,paid=0n,oldCollected=0n,oldPaid=0n;
  const settled=new Map();
  for(const a of applications) {
    const o=om.get(a.operacion_id),m=mm.get(a.movimiento_id);if(!o||!m)continue;
    if(m.fecha_movimiento<=to)settled.set(o.id,(settled.get(o.id)||0n)+BigInt(a.monto_minor));
    if(!inRange(m.fecha_movimiento,from,to))continue;
    if(o.tipo==='VENTA')collected+=BigInt(a.monto_minor);
    else if(['COMPRA_MERCADERIA','GASTO_OPERATIVO'].includes(o.tipo))paid+=BigInt(a.monto_minor);
    else if(o.tipo==='SALDO_CXC')oldCollected+=BigInt(a.monto_minor);
    else if(o.tipo==='SALDO_CXP')oldPaid+=BigInt(a.monto_minor);
  }
  const outstanding=ops.filter(o=>o.fecha_operacion<=to).map(o=>({...o,liquidado_minor:(settled.get(o.id)||0n).toString(),pendiente_minor:(BigInt(o.total_minor)-(settled.get(o.id)||0n)).toString()}));
  const pendingIn=sum(outstanding.filter(o=>['VENTA','SALDO_CXC'].includes(o.tipo)),'pendiente_minor');
  const pendingOut=sum(outstanding.filter(o=>!['VENTA','SALDO_CXC'].includes(o.tipo)),'pendiente_minor');
  const balances=accounts.filter(a=>a.fecha_apertura<=to).map(a=>{
    const balance=moves.filter(m=>m.cuenta_id===a.id&&m.fecha_movimiento<=to).reduce((n,m)=>n+(m.direccion==='ENTRADA'?1n:-1n)*BigInt(m.monto_minor),BigInt(a.saldo_inicial_minor));
    return {...a,saldo_registrado_minor:balance.toString()};
  });
  const external=moves.filter(m=>m.clase!=='TRANSFERENCIA'&&inRange(m.fecha_movimiento,from,to));
  const incoming=sum(external.filter(m=>m.direccion==='ENTRADA'),'monto_minor');
  const outgoing=sum(external.filter(m=>m.direccion==='SALIDA'),'monto_minor');
  const start=business.inicio_historial>from?business.inicio_historial:from;
  let first=monthStart(start);if(first!==start)first=nextMonth(first);
  const months=[];
  for(let d=first;nextMonth(d)<=new Date(Date.parse(to+'T00:00:00Z')+86400000).toISOString().slice(0,10);d=nextMonth(d)) {
    months.push({mes:d.slice(0,7),ventas_minor:sum(ops.filter(o=>o.tipo==='VENTA'&&o.fecha_operacion>=d&&o.fecha_operacion<nextMonth(d)),'total_minor').toString()});
    if(months.length>120)fail(422,'PERIOD_TOO_LONG','Máximo 120 meses por reporte');
  }
  const n=BigInt(months.length),total=sum(months,'ventas_minor');
  const covered=closures.filter(c=>inRange(c.fecha,start,to));
  const firstSale=ops.filter(o=>o.tipo==='VENTA'&&o.fecha_operacion<=to).map(o=>o.fecha_operacion).sort()[0]||null;
  const historyMonths=Math.max(0,(Number(to.slice(0,4))-Number(business.inicio_historial.slice(0,4)))*12+Number(to.slice(5,7))-Number(business.inicio_historial.slice(5,7))-(to.slice(8)<business.inicio_historial.slice(8)?1:0));
  const series=[];
  for(let d=monthStart(from);d<=to;d=nextMonth(d)) {
    if(series.length>=120)fail(422,'PERIOD_TOO_LONG','Máximo 120 meses por reporte');
    const a=d<from?from:d, b=nextMonth(d)>to?to:new Date(Date.parse(nextMonth(d)+'T00:00:00Z')-86400000).toISOString().slice(0,10);
    const monthOps=periodOps.filter(o=>inRange(o.fecha_operacion,a,b));
    let cash=0n,pay=0n;
    for(const item of applications){const o=om.get(item.operacion_id),m=mm.get(item.movimiento_id);if(!o||!m||!inRange(m.fecha_movimiento,a,b))continue;if(o.tipo==='VENTA')cash+=BigInt(item.monto_minor);if(['COMPRA_MERCADERIA','GASTO_OPERATIVO'].includes(o.tipo))pay+=BigInt(item.monto_minor);}
    series.push({mes:d.slice(0,7),desde:a,hasta:b,parcial:a!==d||b<new Date(Date.parse(nextMonth(d)+'T00:00:00Z')-86400000).toISOString().slice(0,10)||d<business.inicio_historial,
      ventas_minor:sum(monthOps.filter(o=>o.tipo==='VENTA'),'total_minor').toString(),cobros_minor:cash.toString(),pagos_minor:pay.toString(),
      gastos_minor:sum(monthOps.filter(o=>o.tipo==='GASTO_OPERATIVO'),'total_minor').toString(),compras_minor:sum(monthOps.filter(o=>o.tipo==='COMPRA_MERCADERIA'),'total_minor').toString(),
      dias_con_ventas:new Set(monthOps.filter(o=>o.tipo==='VENTA').map(o=>o.fecha_operacion)).size});
  }
  const days=start<=to?Math.floor((Date.parse(to)-Date.parse(start))/86400000)+1:0;
  const activeDays=new Set(periodOps.filter(o=>o.tipo==='VENTA'&&o.fecha_operacion>=start).map(o=>o.fecha_operacion)).size;
  const recorded=ops.filter(o=>o.fecha_operacion<=to).map(o=>o.fecha_operacion).sort();
  return {
    negocio_id:business.id,moneda:business.moneda||'PEN',desde:from,hasta:to,version_formula:'1.1.0',
    negocio_nombre:business.nombre,inicio_historial_declarado:business.inicio_historial,primer_registro:recorded[0]||null,ultimo_registro:recorded.at(-1)||null,
    serie_mensual:series,meses_con_informacion:new Set(periodOps.map(o=>o.fecha_operacion.slice(0,7))).size,
    meses_con_ventas:series.filter(m=>BigInt(m.ventas_minor)>0n).length,dias_observados:days,
    regularidad_base_puntos:days?String((BigInt(activeDays)*10000n+BigInt(days)/2n)/BigInt(days)):null,
    ventas_minor:sales.toString(),compras_minor:purchases.toString(),gastos_minor:expenses.toString(),
    resultado_operativo_simplificado_minor:(sales-purchases-expenses).toString(),
    cobros_ventas_minor:collected.toString(),pagos_operativos_minor:paid.toString(),flujo_operativo_minor:(collected-paid).toString(),
    cobros_deudas_iniciales_minor:oldCollected.toString(),pagos_deudas_iniciales_minor:oldPaid.toString(),
    entradas_externas_minor:incoming.toString(),salidas_externas_minor:outgoing.toString(),
    por_cobrar_minor:pendingIn.toString(),por_pagar_minor:pendingOut.toString(),
    cuentas:balances,pendientes:outstanding.filter(o=>BigInt(o.pendiente_minor)>0n),
    meses_completos:months.length,promedio_mensual_ventas_minor:n?((total+n/2n)/n).toString():null,ventas_mensuales:months,
    primera_venta_registrada:firstSale,meses_historial:historyMonths,
    dias_con_ventas:new Set(periodOps.filter(o=>o.tipo==='VENTA').map(o=>o.fecha_operacion)).size,
    dias_con_cierre:covered.length,
    advertencias:[...(n?[]:['HISTORIAL_INSUFICIENTE_PARA_PROMEDIO']), 'COBERTURA_NO_VERIFICADA','RESULTADO_SIMPLIFICADO_NO_UTILIDAD_CONTABLE','NO_CERTIFICACION_NI_APROBACION_CREDITICIA']
  };
}
function readService(db) {
  const load=async(s,bid,actor)=>{
    await requireSession(s,actor);const {business}=await membership(s,bid,actor.sub);
    const [ops,moves,apps,accounts,closures]=await Promise.all(['operaciones','movimientos','aplicaciones','cuentas','cierres_diarios'].map(t=>s.list(t,{negocio_id:bid})));
    return {business,ops,moves,apps,accounts,closures};
  };
  return {
    async ask(bid,actor,question){
      return db.snapshot(async s=>{
        await requireSession(s,actor);const {business}=await membership(s,bid,actor.sub);
        const conversation=require('./question-language').dialogue(question,business);
        if(conversation)return conversation;
        const d=await load(s,bid,actor),categories=await s.list('categorias',{negocio_id:bid}),people=await s.list('terceros',{negocio_id:bid});return require('./insights').answer(d.business,[d.ops,d.moves,d.apps,d.accounts,d.closures],question,categories,people);
      });
    },
    async dailySales(bid,actor){
      return db.snapshot(async s=>{const d=await load(s,bid,actor);return require('./daily-sales').dailySales(d.business,[d.ops,d.moves,d.apps,d.accounts,d.closures]);});
    },
    async questionPeriod(bid,actor,question){
      return db.snapshot(async s=>{await requireSession(s,actor);const {business}=await membership(s,bid,actor.sub);const p=require('./insights-period');return p.period(question,p.businessToday(business));});
    },
    async snapshot(bid,actor) {
      return db.snapshot(async s=>{
        await requireSession(s,actor);const {business}=await membership(s,bid,actor.sub);
        const counter=await s.get('sync_contadores',{negocio_id:bid});
        const entidades=[{tabla:'negocios',registros:[business]}];
        for(const table of ['categorias','terceros','cuentas','operaciones','movimientos','aplicaciones','transferencias','cierres_diarios'])
          entidades.push({tabla:table,registros:await s.list(table,{negocio_id:bid})});
        return {cursor:String(counter.ultimo_seq),entidades};
      });
    },
    async indicators(bid,actor,filters={}) {
      return db.snapshot(async s=>{
        const d=await load(s,bid,actor),from=filters.desde||d.business.inicio_historial,to=filters.hasta||today(d.business.zona_horaria);
        if(from>to||to>today(d.business.zona_horaria))fail(422,'INVALID_PERIOD','Período invertido o futuro');
        if(Number(to.slice(0,4))-Number(from.slice(0,4))>10)fail(422,'PERIOD_TOO_LONG','Máximo 10 años por consulta');
        const counter=await s.get('sync_contadores',{negocio_id:bid});
        return {...buildReport(d.business,d.ops,d.moves,d.apps,d.accounts,d.closures,from,to),corte_sync_seq:String(counter.ultimo_seq)};
      });
    },
    async list(bid,actor,table,filters={}) {
      return db.read(async s=>{
        await requireSession(s,actor);await membership(s,bid,actor.sub);
        const eq={negocio_id:bid},opts={limit:(filters.limit||30)+1,offset:filters.offset||0};
        const field=table==='operaciones'?'fecha_operacion':table==='movimientos'?'fecha_movimiento':null;
        if(field) {
          opts.order=[[field,'DESC'],['id','DESC']];opts.ranges=[];
          if(filters.desde)opts.ranges.push([field,'>=',filters.desde]);
          if(filters.hasta)opts.ranges.push([field,'<=',filters.hasta]);
          if(filters.estado)eq.estado=filters.estado;
          if(table==='operaciones') for(const k of ['tipo','tercero_id','categoria_id'])if(filters[k])eq[k]=filters[k];
          if(table==='movimientos'&&filters.cuenta_id)eq.cuenta_id=filters.cuenta_id;
          if(filters.q)opts.search={columns:['concepto'],term:filters.q};
        } else {opts.order=[['nombre','ASC'],['id','ASC']];if(filters.q)opts.search={columns:['nombre'],term:filters.q};}
        const rows=await s.list(table,eq,opts),limit=filters.limit||30;
        return {items:rows.slice(0,limit),next_offset:rows.length>limit?(filters.offset||0)+limit:null};
      });
    },
    async operation(bid,actor,id) {
      return db.snapshot(async s=>{
        await requireSession(s,actor);await membership(s,bid,actor.sub);
        const o=await s.get('operaciones',{id,negocio_id:bid});if(!o)fail(404,'NOT_FOUND','Operación no encontrada');
        const applications=await s.list('aplicaciones',{negocio_id:bid,operacion_id:id}),movements=[];
        for(const a of applications)movements.push(await s.get('movimientos',{id:a.movimiento_id,negocio_id:bid}));
        const paid=applications.reduce((n,a)=>n+(movements.find(m=>m.id===a.movimiento_id)?.estado==='CONFIRMADO'?BigInt(a.monto_minor):0n),0n);
        return {...o,aplicaciones:applications,movimientos:movements,liquidado_minor:paid.toString(),pendiente_minor:o.estado==='ANULADO'?'0':(BigInt(o.total_minor)-paid).toString()};
      });
    }
  };
}
module.exports={buildReport,readService};
