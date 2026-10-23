'use strict';
const {fail}=require('../errors');
const normalize=q=>q.normalize('NFD').replace(/\p{Diacritic}/gu,'').toLowerCase().replace(/\s+/g,' ').trim();
const shift=(d,n)=>new Date(Date.parse(d+'T00:00:00Z')+n*86400000).toISOString().slice(0,10);
// Pick the civil date in the business zone first. UTC is only calendar arithmetic.
const businessToday=(business,instant=new Date())=>new Intl.DateTimeFormat('en-CA',{timeZone:business.zona_horaria||'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).format(instant);
const morning=q=>/\b(esta manana|hoy (?:en|por) la manana)\b/.test(normalize(q));
function period(input,end){
  const q=normalize(input),month=end.slice(0,7)+'-01';
  const dates=[...q.matchAll(/\b(\d{4}-\d{2}-\d{2}|\d{2}\/\d{2}\/\d{4})\b/g)].map(m=>m[1].includes('/')?m[1].split('/').reverse().join('-'):m[1]);
  if(dates.length){
    if(dates.length>2||dates.some(d=>!Number.isFinite(Date.parse(d+'T00:00:00Z'))||new Date(d+'T00:00:00Z').toISOString().slice(0,10)!==d))fail(422,'INVALID_PERIOD','Usa fechas válidas DD/MM/AAAA o AAAA-MM-DD.');
    const [a,b=a]=dates;if(a>b||b>end||Number(b.slice(0,4))-Number(a.slice(0,4))>9)fail(422,'INVALID_PERIOD','Revisa las fechas: el periodo está invertido, es futuro o demasiado largo.');return [a,b];
  }
  const matches=[];
  if(/\bultimos? (?:siete|7) dias\b/.test(q))matches.push([shift(end,-6),end]);
  if(/\bayer\b/.test(q))matches.push([shift(end,-1),shift(end,-1)]);
  if(/\b(hoy|del dia|de este dia|este dia|dia de hoy|diarias?)\b/.test(q)||morning(q))matches.push([end,end]);
  if(/\bsemana(?:l)?\b/.test(q)){
    const start=shift(end,-((new Date(end+'T00:00:00Z').getUTCDay()+6)%7));
    matches.push(/semana pasada/.test(q)?[shift(start,-7),shift(start,-1)]:[start,end]);
  }
  if(/\bmes pasado\b/.test(q)){const last=shift(month,-1);matches.push([last.slice(0,7)+'-01',last]);}
  if(/\b(este mes|mes actual|del mes(?! pasado)|mensual)\b/.test(q))matches.push([month,end]);
  const unique=[...new Map(matches.map(p=>[p.join(':'),p])).values()];
  if(unique.length>1)fail(422,'INVALID_PERIOD','¿Qué periodo quieres consultar? Indica uno o escribe las dos fechas.');
  if(unique.length)return unique[0];
  if(/\b(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre|ano|anos|dia|dias|anterior|lunes|martes|miercoles|jueves|viernes|sabado|domingo)\b|\b\d{4}\b/.test(q))fail(422,'QUESTION_UNSUPPORTED','Para ese periodo escribe las fechas DD/MM/AAAA.');
  return [month,end];
}
module.exports={period,businessToday,normalize,morning};
