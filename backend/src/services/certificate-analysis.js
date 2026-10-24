'use strict';
// Indicadores del análisis de la constancia. Todo sale de los datos del reporte
// (importes en centavos como texto); aquí solo se calculan razones y alertas.
const big=v=>BigInt(v??0);
// Porcentaje con un decimal: num/den*100, redondeado. null si no hay denominador.
function percent(num,den){
  const n=big(num),d=big(den);if(d===0n)return null;
  const neg=(n<0n)!==(d<0n),a=(n<0n?-n:n),b=(d<0n?-d:d);
  const tenth=(a*1000n+b/2n)/b;
  return `${neg&&tenth!==0n?'-':''}${tenth/10n}.${tenth%10n}%`;
}
const ratio=(num,den)=>{const d=big(den);if(d<=0n)return null;const hundredths=(big(num)*100n+d/2n)/d;return `${hundredths/100n}.${String(hundredths%100n).padStart(2,'0')}`;};
const monthName=m=>{const [y,mo]=m.split('-');return `${['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'][Number(mo)-1]} ${y}`;};

function analyze(r){
  const sales=big(r.ventas_minor),purchases=big(r.compras_minor),expenses=big(r.gastos_minor);
  const gross=sales-purchases,operating=big(r.resultado_operativo_simplificado_minor);
  const cash=big(r.saldo_cuentas_minor),receivable=big(r.por_cobrar_minor),payable=big(r.por_pagar_minor);
  const working=cash+receivable-payable;
  const out={
    utilidad_bruta_minor:gross.toString(),margen_bruto:percent(gross,sales),margen_operativo:percent(operating,sales),
    peso_gastos:percent(expenses,sales),
    cobranza:sales>0n?percent(r.cobros_ventas_minor,sales):null,
    capital_trabajo_minor:working.toString(),liquidez:ratio(cash+receivable,payable),
    ticket_promedio_minor:big(r.ventas_cantidad)>0n?((sales+big(r.ventas_cantidad)/2n)/big(r.ventas_cantidad)).toString():null,
    regularidad:r.regularidad_base_puntos==null?null:`${(Number(r.regularidad_base_puntos)/100).toFixed(1)}%`
  };
  // Antigüedad de las cuentas por cobrar.
  const aging=(r.antiguedad_por_cobrar_minor||['0','0','0','0']).map(big);
  out.antiguedad=['Hasta 30 días','31 a 60 días','61 a 90 días','Más de 90 días'].map((label,i)=>({label,minor:aging[i].toString(),porcentaje:percent(aging[i],receivable)}));
  out.vencido_60=receivable>0n?percent(aging[2]+aging[3],receivable):null;
  out.concentracion_top3=big(r.deudores_cantidad)>=3?percent(r.deudores_top3_minor,receivable):null;
  // Estabilidad: solo meses calendario completos.
  const full=(r.serie_mensual||[]).filter(m=>!m.parcial);
  const values=full.map(m=>big(m.ventas_minor));
  out.meses_completos=full.length;
  if(full.length>0){
    let best=0,worst=0;values.forEach((v,i)=>{if(v>values[best])best=i;if(v<values[worst])worst=i;});
    out.mejor_mes={mes:monthName(full[best].mes),minor:values[best].toString()};
    out.peor_mes={mes:monthName(full[worst].mes),minor:values[worst].toString()};
    const nums=values.map(Number),mean=nums.reduce((a,b)=>a+b,0)/nums.length;
    out.variacion=full.length>=3&&mean>0?`${(Math.sqrt(nums.reduce((a,b)=>a+(b-mean)**2,0)/nums.length)/mean*100).toFixed(0)}%`:null;
    if(full.length>=4){
      const recent=values.slice(-3),before=values.slice(-6,-3);
      const sum=a=>a.reduce((x,y)=>x+y,0n);
      const a=sum(recent)*BigInt(before.length),b=sum(before)*BigInt(recent.length);
      if(b>0n){const change=Number((a-b)*1000n/b)/10;out.tendencia=change>10?'Creciente':change<-10?'Decreciente':'Estable';out.tendencia_cambio=`${change>0?'+':''}${change.toFixed(1)}%`;}
    }
  }
  // Lectura rápida: hechos que un analista revisa primero, máximo cinco.
  const notes=[];
  if(sales===0n)notes.push('No hay ventas registradas en el periodo.');
  else{
    if(operating<0n)notes.push('El resultado operativo del periodo es negativo: las compras y los gastos superaron a las ventas.');
    else if(out.margen_operativo)notes.push(`El resultado operativo es positivo, con un margen de ${out.margen_operativo} sobre las ventas.`);
    if(out.cobranza){const c=Number(out.cobranza.replace('%',''));if(c<70)notes.push(`Solo se cobró ${out.cobranza} de lo vendido en el periodo; el resto sigue pendiente o es crédito a clientes.`);else notes.push(`Cobranza de ${out.cobranza}: la mayor parte de lo vendido se cobra en el periodo.`);}
  }
  if(out.vencido_60&&Number(out.vencido_60.replace('%',''))>=40)notes.push(`${out.vencido_60} de las cuentas por cobrar tiene más de 60 días de antigüedad.`);
  if(out.concentracion_top3&&Number(out.concentracion_top3.replace('%',''))>=60)notes.push(`Tres personas concentran ${out.concentracion_top3} de las cuentas por cobrar.`);
  if(out.liquidez&&Number(out.liquidez)<1)notes.push('Lo que tiene en cuentas y le deben es menor que lo que debe pagar (liquidez menor a 1).');
  if(out.tendencia)notes.push(`Ventas mensuales con tendencia ${out.tendencia.toLowerCase()} (${out.tendencia_cambio} frente a los tres meses anteriores).`);
  if(full.length<3)notes.push('Hay pocos meses completos registrados; los promedios y la tendencia son referenciales.');
  out.lectura=notes.slice(0,5);
  return out;
}
module.exports={analyze,percent,ratio,monthName};
