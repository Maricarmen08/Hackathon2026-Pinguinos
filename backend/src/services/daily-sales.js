'use strict';
const {buildReport}=require('./queries');
const {businessToday}=require('./insights-period');
function dayWindow(business,instant=new Date()){
  const day=businessToday(business,instant),now=instant.getTime();
  const first=(lo,hi,predicate)=>{while(lo<hi){const mid=Math.floor((lo+hi)/2);if(predicate(businessToday(business,new Date(mid))))hi=mid;else lo=mid+1;}return new Date(lo).toISOString();};
  return {fecha:day,vigente_desde_utc:first(now-36*3600000,now,d=>d>=day),vigente_hasta_utc:first(now,now+36*3600000,d=>d>day)};
}
function dailySales(business,data,instant=new Date()){
  const window=dayWindow(business,instant),r=buildReport(business,...data,window.fecha,window.fecha);
  return {negocio_id:business.id,zona_horaria:business.zona_horaria,desde:window.fecha,hasta:window.fecha,...window,ventas_minor:r.ventas_minor,consultado_en:instant.toISOString()};
}
module.exports={dailySales,dayWindow};
