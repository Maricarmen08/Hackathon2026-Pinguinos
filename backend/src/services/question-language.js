'use strict';
const {normalize,period,businessToday}=require('./insights-period');
const {fail}=require('../errors');
// Deliberately small spelling dictionary: never fuzzy-match amounts or dates.
const spelling={ventaz:'ventas',bentas:'ventas',vendi:'vendi',venddi:'vendi',gastee:'gaste',gastoz:'gastos',cobre:'cobre',cobree:'cobre',deven:'deben',devo:'debo',probeedores:'proveedores',resumem:'resumen',oi:'hoy',oy:'hoy'};
const periodText=input=>normalize(input).replace(/\b[a-z]+\b/g,w=>spelling[w]||w);
function questionText(input){return periodText(input).replace(/[¿?¡!,:;.]/g,' ').replace(/\s+/g,' ').trim();}
function greeting(input){
 const q=questionText(input).replace(/\bfinki\b/g,'').replace(/\s+/g,' ').trim();
 if(/^(hola|que tal|buenos dias|buenas tardes|buenas noches|buenas|como estas|hola que tal)$/.test(q))return '¡Hola! Soy Finki. Estoy aquí para ayudarte con las cuentas de tu negocio. Puedes preguntarme cuánto vendiste, cuánto gastaste o quiénes te deben.';
 return null;
}
function dialogue(input,business,asOf=businessToday(business)){
 const hello=greeting(input);if(hello)return {respuesta:hello,fuente:'ORIENTACION',datos_suficientes:false};
 const q=questionText(input);
 const ambiguous=/\b(hice|he hecho|hicimos)\b/.test(q)&&! /\b(venta|ventas|vendi|vendido|cobre|cobrado|gaste|gastado|compra|compras)\b/.test(q);
 const accounts=/\bcuentas\b/.test(q)&&! /\b(cobrar|pagar|deben|debo|saldo|saldos|banco)\b/.test(q);
 if(!ambiguous&&!accounts)return null;
 if(/\bmanana\b/.test(q.replace(/esta manana|hoy (?:en|por) la manana/g,'')))fail(422,'QUESTION_OUT_OF_SCOPE','Puedo consultar registros, pero no predecir resultados.');
 const [from,to]=period(periodText(input),asOf),range=`del ${from} al ${to}`;
 return {respuesta:accounts?'¿Quieres un resumen de tu negocio o revisar lo que te deben y lo que debes?':'¿Quieres saber cuánto vendiste o cuánto dinero cobraste en ese periodo?',fuente:'ACLARACION',datos_suficientes:false,desde:from,hasta:to,
  opciones:accounts?[
   {titulo:'Resumen del negocio',pregunta:`resumen ${range}`},
   {titulo:'Lo que me deben',pregunta:`por cobrar ${range}`},
   {titulo:'Lo que debo',pregunta:`por pagar ${range}`}]:[
   {titulo:'Ventas',pregunta:`ventas ${range}`},
   {titulo:'Dinero cobrado',pregunta:`cobros ${range}`} ]};
}
// Send only generic vocabulary for intention classification, never the raw
// question, names, contact details, identifiers, dates or monetary amounts.
const externalWords=new Set(('cuanto cuanto he mi mis me del de la el en por que un una quiero saber necesito dime favor ayuda revisar negocio negocios comercial panorama facture facturado facturacion ingreso ingresos egreso egresos ventas vendi vendido gastos gaste gastado compras compre mercaderia cobros cobre cobrado pagos pague pagado deben debo deuda deudas proveedores clientes resumen balance resultado comparar comparacion mas menos mejor peor dinero plata total movimiento movimientos actividad cuentas pendiente pendientes').split(' '));
function externalQuestion(input){
 const words=questionText(input).match(/\b[a-z]+\b/g)||[];
 const safe=words.filter(w=>externalWords.has(w));
 if(!safe.some(w=>/^(factur|ingres|egres|vent|vend|gast|compr|mercader|cobr|pag|deb|resumen|balance|resultado|compar|panorama|movimiento|actividad|cuentas)/.test(w)))fail(422,'QUESTION_PRIVATE','Reformula tu pregunta usando solo el indicador que deseas consultar, sin nombres ni datos personales.');
 return safe.join(' ').slice(0,300);
}
module.exports={questionText,periodText,greeting,dialogue,externalQuestion};
