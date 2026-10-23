'use strict';
const {period}=require('./insights');
const {today}=require('../domain');
const {fail}=require('../errors');
const canonical={VENTAS:'ventas',GASTOS:'gastos',COMPRAS:'compras de mercadería',COBROS:'cobros',PAGOS:'pagos',POR_COBRAR:'me deben',POR_PAGAR:'debo pagar',DEUDORES:'quién me debe más',RESUMEN:'resumen',COMPARACION:'comparar ventas'};
async function askAssistant(reads,bid,actor,question,consent,provider){
  try{return await reads.ask(bid,actor,question);}catch(e){
    if(e.code!=='QUESTION_UNSUPPORTED'||!consent)throw e;
    // Authorization has already passed in reads.ask. Unsupported dates remain
    // unsupported: the model cannot select or invent a period.
    const normalized=question.normalize('NFD').replace(/\p{Diacritic}/gu,'').toLowerCase();
    if(/\b(drop|select|insert|update|delete|alter|sql)\b|predec|pronostic|\bmanana\b|proxim|banco/.test(normalized.replace(/esta manana|hoy (?:en|por) la manana/g,'')))throw e;
    const [from,to]=reads.questionPeriod?await reads.questionPeriod(bid,actor,question):period(normalized,today());
    if(!provider.classifyQuestion)fail(503,'AI_NOT_CONFIGURED','La interpretación externa de preguntas requiere Gemini. Puedes usar las sugerencias.');
    const intent=await provider.classifyQuestion(question);
    if(!canonical[intent])throw e;
    const answer=await reads.ask(bid,actor,`${canonical[intent]} del ${from} al ${to}`);
    return {...answer,interpretacion_externa:true};
  }
}
module.exports={askAssistant};
