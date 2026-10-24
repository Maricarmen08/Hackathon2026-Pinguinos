'use strict';
const express=require('express'),cors=require('cors'),helmet=require('helmet');
const {rateLimit}=require('express-rate-limit');
const {randomUUID}=require('node:crypto');
const {fail,errorHandler,ApiError}=require('./errors');
const v=require('./validators');
const {authService,requireSession,membership}=require('./services/auth');
const {commandService}=require('./services/commands');
const {readService}=require('./services/queries');
const {json}=require('./domain');
const {certificateFile}=require('./services/certificate');
const {createProvider}=require('./services/ai-provider');
const {intakeService}=require('./services/intake');
const {localEvidenceService}=require('./services/local-intake');
const wrap=fn=>(req,res,next)=>Promise.resolve(fn(req,res,next)).catch(next);
function createApp({db,config}) {
  const app=express(),auth=authService(db,config),execute=commandService(db),reads=readService(db);
  const provider=createProvider(config),intake=intakeService(db,execute,provider);
  const localEvidence=localEvidenceService(db,execute);
  app.disable('x-powered-by');app.set('trust proxy',1);
  app.set('json replacer',(key,value)=>typeof value==='string'&&key.endsWith('_en')&&/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(\.\d{1,6})?$/.test(value)?value.replace(' ','T')+'Z':value);
  app.use((req,res,next)=>{req.requestId=randomUUID();res.set('X-Request-ID',req.requestId);res.set('Cache-Control','no-store');next();});
  app.use(helmet({contentSecurityPolicy:false,crossOriginOpenerPolicy:{policy:'same-origin-allow-popups'}}));
  const origins=config.CORS_ORIGINS.split(',').map(v=>v.trim()).filter(Boolean);
  app.use(cors((req,cb)=>{
    const origin=req.header('Origin');
    const sameHost=origin&&(origin===`${req.protocol}://${req.get('host')}`||origin===`https://${req.get('host')}`);
    return !origin||sameHost||origins.includes(origin)?cb(null,{origin:true,credentials:false}):cb(new ApiError(403,'CORS_FORBIDDEN','Origen no permitido'));
  }));
  app.use(express.json({limit:'64kb',strict:true}));
  const router=express.Router();
  const limiter=rateLimit({windowMs:60*1000,limit:10,standardHeaders:'draft-8',legacyHeaders:false,
    handler:(req,res)=>res.status(429).json({error:{code:'AUTH_RATE_LIMIT',message:'Demasiados intentos; espera un minuto'},request_id:req.requestId})});
  const secured=wrap(async(req,_res,next)=>{
    const match=/^Bearer ([A-Za-z0-9._-]+)$/.exec(req.get('Authorization')||'');
    if(!match)fail(401,'TOKEN_REQUIRED','Se requiere token de acceso');
    req.actor=auth.jwt.verify(match[1],'access');
    await db.read(s=>requireSession(s,req.actor));next();
  });
  const bid=req=>v.uuid.parse(req.params.id);
  router.get('/negocios/:id/ventas/hoy',secured,wrap(async(req,res)=>{res.json(await reads.dailySales(bid(req),req.actor));}));
  const filters=(req,allowed)=>{
    if(Object.keys(req.query).some(k=>!allowed.includes(k)))fail(422,'UNSUPPORTED_FILTER','Filtro no admitido por esta ruta');
    return v.filters.parse(req.query);
  };
  const sendCommand=type=>wrap(async(req,res)=>{
    if(type && req.body?.tipo && req.body.tipo!==type)fail(422,'COMMAND_ROUTE_MISMATCH','Tipo incompatible con la ruta');
    const c=v.command(type?{...req.body,tipo:type}:req.body);
    const id=req.params.id?bid(req):c.payload.id;
    if(!req.params.id && c.tipo!=='CREAR_NEGOCIO')fail(422,'INVALID_COMMAND','Comando incompatible');
    const result=await execute(id,c,req.actor);res.status(result.replayed?200:201).json(result);
  });
  router.get('/health/live',(_req,res)=>res.json({status:'ok',api:'v1'}));
  router.get('/health/ready',wrap(async(_req,res)=>{await db.ping();res.json({status:'ready'});}));
  router.post('/auth/registro',limiter,wrap(async(req,res)=>res.status(201).json(await auth.register(v.register.parse(req.body)))));
  router.post('/auth/login',limiter,wrap(async(req,res)=>res.json(await auth.login(v.login.parse(req.body)))));
  router.post('/auth/refresh',limiter,wrap(async(req,res)=>res.json(await auth.refresh(v.refresh.parse(req.body).refresh_token))));
  router.post('/auth/logout',secured,wrap(async(req,res)=>res.json(await auth.logout(req.actor))));
  router.get('/auth/me',secured,wrap(async(req,res)=>res.json(await auth.me(req.actor))));
  const google=require('./services/google-auth');
  const googleAuth=google.googleAuthService(db,auth,google.googleVerifier(config));
  const googleInput=zGoogle=>require('zod').z.object(zGoogle).strict();
  const googleBase={id_token:require('zod').z.string().min(20).max(8192),nonce:require('zod').z.string().min(32).max(128)};
  router.post('/auth/google',limiter,wrap(async(req,res)=>res.json(await googleAuth.login(googleInput({...googleBase,dispositivo:require('./validators').device}).parse(req.body)))));
  router.post('/perfil/google',secured,limiter,wrap(async(req,res)=>res.json(await googleAuth.link(req.actor,googleInput({...googleBase,clave_actual:require('zod').z.string().min(1).max(128)}).parse(req.body)))));
  router.get('/perfil',secured,wrap(async(req,res)=>res.json(await auth.me(req.actor))));
  router.patch('/perfil',secured,wrap(async(req,res)=>res.json(await auth.updateProfile(req.actor,v.profile.parse(req.body)))));
  const accountLimit=rateLimit({windowMs:15*60000,limit:5,keyGenerator:req=>req.actor.sub,standardHeaders:'draft-8',legacyHeaders:false,
    handler:(req,res)=>res.status(429).json({error:{code:'ACCOUNT_RATE_LIMIT',message:'Demasiados intentos; espera 15 minutos'},request_id:req.requestId})});
  router.post('/perfil/contrasena',secured,accountLimit,wrap(async(req,res)=>res.json(await auth.changePassword(req.actor,v.changePassword.parse(req.body)))));
  const photos=require('./services/profile-photo').profilePhotoService(config);
  const photoLimit=rateLimit({windowMs:60000,limit:10,keyGenerator:req=>req.actor.sub,standardHeaders:'draft-8',legacyHeaders:false});
  router.get('/perfil/foto',secured,wrap(async(req,res)=>res.json(await photos.get(req.actor))));
  router.put('/perfil/foto',secured,photoLimit,express.raw({type:'application/octet-stream',limit:'512kb'}),wrap(async(req,res)=>res.json(await photos.put(req.actor,req.body))));
  router.delete('/perfil/foto',secured,photoLimit,wrap(async(req,res)=>res.json(await photos.remove(req.actor))));
  router.get('/negocios',secured,wrap(async(req,res)=>res.json({items:(await auth.me(req.actor)).negocios})));
  router.post('/negocios',secured,sendCommand('CREAR_NEGOCIO'));
  router.get('/negocios/:id',secured,wrap(async(req,res)=>res.json((await db.read(s=>membership(s,bid(req),req.actor.sub))).business)));
  router.patch('/negocios/:id',secured,sendCommand('ACTUALIZAR_NEGOCIO'));
  router.post('/negocios/:id/comandos',secured,sendCommand());
  for(const [path,type]of Object.entries({categorias:'CREAR_CATEGORIA',terceros:'CREAR_TERCERO',cuentas:'CREAR_CUENTA',operaciones:'REGISTRAR_OPERACION',cobros:'REGISTRAR_COBRO',pagos:'REGISTRAR_PAGO',transferencias:'REGISTRAR_TRANSFERENCIA','movimientos-no-operativos':'REGISTRAR_MOVIMIENTO_NO_OPERATIVO'}))router.post('/negocios/:id/'+path,secured,sendCommand(type));
  const operationFilters=['desde','hasta','tipo','tercero_id','categoria_id','estado','q','limit','offset'];
  for(const table of ['categorias','terceros','operaciones','movimientos'])router.get('/negocios/:id/'+table,secured,wrap(async(req,res)=>res.json(await reads.list(bid(req),req.actor,table,filters(req,table==='operaciones'?operationFilters:table==='movimientos'?['desde','hasta','cuenta_id','estado','q','limit','offset']:['q','limit','offset'])))));
  router.get('/negocios/:id/historial',secured,wrap(async(req,res)=>res.json(await reads.list(bid(req),req.actor,'operaciones',filters(req,operationFilters)))));
  router.get('/negocios/:id/operaciones/:operationId',secured,wrap(async(req,res)=>res.json(await reads.operation(bid(req),req.actor,v.uuid.parse(req.params.operationId)))));
  for(const route of ['indicadores','reportes/actividad'])router.get('/negocios/:id/'+route,secured,wrap(async(req,res)=>res.json(await reads.indicators(bid(req),req.actor,filters(req,['desde','hasta'])))));
  router.get('/negocios/:id/cuentas',secured,wrap(async(req,res)=>{filters(req,[]);res.json({items:(await reads.indicators(bid(req),req.actor)).cuentas});}));
  const aiLimit=rateLimit({windowMs:60000,limit:6,keyGenerator:req=>req.actor.sub,standardHeaders:'draft-8',legacyHeaders:false});
  router.get('/negocios/:id/ia/estado',secured,wrap(async(req,res)=>{await db.read(s=>membership(s,bid(req),req.actor.sub));res.json({configurado:provider.enabled,proveedor:provider.name,requiere_consentimiento:true,...(provider.availability?provider.availability():{})});}));
  router.post('/negocios/:id/ia/evidencia-local',secured,rateLimit({windowMs:60000,limit:20,keyGenerator:req=>req.actor.sub,standardHeaders:'draft-8',legacyHeaders:false}),express.raw({type:'application/octet-stream',limit:'7mb'}),wrap(async(req,res)=>{
    if(!Buffer.isBuffer(req.body)||req.body.length===0)fail(422,'EMPTY_FILE','El archivo está vacío');
    res.status(201).json(await localEvidence(bid(req),req.actor,v.uuid.parse(req.query.id),req.body));
  }));
  router.get('/negocios/:id/ia/propuestas',secured,wrap(async(req,res)=>{
    const f=filters(req,['limit','offset']);
    const rows=await db.read(async s=>{await requireSession(s,req.actor);await membership(s,bid(req),req.actor.sub,true);return s.list('extracciones',{negocio_id:bid(req),estado:'REQUIERE_REVISION'},{order:[['creado_en','DESC'],['id','DESC']],limit:f.limit+1,offset:f.offset});});
    res.json({items:rows.slice(0,f.limit).map(r=>({id:r.id,version:String(r.version),resultado:json(r.resultado),estado:r.estado,tipo_entrada:r.tipo_entrada,transcripcion:r.tipo_entrada==='AUDIO'?r.texto_entrada:null,creado_en:r.creado_en})),next_offset:rows.length>f.limit?f.offset+f.limit:null});
  }));
  router.post('/negocios/:id/consultas',secured,wrap(async(req,res)=>{const z=require('zod').z,q=z.object({pregunta:z.string().trim().min(1).max(300),consentimiento_externo:z.boolean().optional().default(false)}).strict().parse(req.body);res.json(await require('./services/insights-assistant').askAssistant(reads,bid(req),req.actor,q.pregunta,q.consentimiento_externo,provider));}));
  router.post('/negocios/:id/ia/analizar',secured,aiLimit,express.raw({type:'application/octet-stream',limit:'7mb'}),wrap(async(req,res)=>{
    const id=v.uuid.parse(req.query.id),consent=req.get('X-Finki-Consent')==='1';
    const bytes=Buffer.isBuffer(req.body)?req.body:null;
    const text=bytes?null:require('zod').z.object({texto:require('zod').z.string().trim().min(1).max(6000)}).strict().parse(req.body).texto;
    if(bytes&&bytes.length===0)fail(422,'EMPTY_FILE','El archivo está vacío');
    const consentVersion=require('zod').z.string().max(40).parse(req.get('X-Finki-Consent-Version')||'legacy-v3');
    res.status(201).json(await intake(bid(req),req.actor,{id,bytes,text,consent,consentVersion}));
  }));
  router.get('/negocios/:id/constancias',secured,wrap(async(req,res)=>{
    const f=filters(req,['limit','offset']);
    const rows=await db.read(async s=>{await requireSession(s,req.actor);await membership(s,bid(req),req.actor.sub);return s.list('reportes',{negocio_id:bid(req)},{order:[['creado_en','DESC'],['id','DESC']],limit:f.limit+1,offset:f.offset});});
    res.json({items:rows.slice(0,f.limit).map(r=>({id:r.id,desde:r.desde,hasta:r.hasta,generado_en:r.generado_en,estado:r.estado})),next_offset:rows.length>f.limit?f.offset+f.limit:null});
  }));
  router.get('/negocios/:id/constancias/:reportId',secured,wrap(async(req,res)=>{
    const row=await db.read(async s=>{await requireSession(s,req.actor);await membership(s,bid(req),req.actor.sub);return s.get('reportes',{id:v.uuid.parse(req.params.reportId),negocio_id:bid(req)});});
    if(!row)fail(404,'NOT_FOUND','Constancia no encontrada');
    res.json(await certificateFile(row));
  }));
  router.get('/negocios/:id/pendientes',secured,wrap(async(req,res)=>{
    const f=filters(req,['hasta','direccion','tercero_id','q','limit','offset']),r=await reads.indicators(bid(req),req.actor,f);
    let items=r.pendientes;
    if(f.direccion)items=items.filter(o=>(['VENTA','SALDO_CXC'].includes(o.tipo))===(f.direccion==='COBRAR'));
    if(f.tercero_id)items=items.filter(o=>o.tercero_id===f.tercero_id);
    if(f.q)items=items.filter(o=>o.concepto.toLowerCase().includes(f.q.toLowerCase()));
    res.json({items:items.slice(f.offset,f.offset+f.limit),next_offset:items.length>f.offset+f.limit?f.offset+f.limit:null,hasta:r.hasta});
  }));
  router.get('/negocios/:id/sync/cambios',secured,wrap(async(req,res)=>{
    const keys=Object.keys(req.query);if(keys.some(k=>!['cursor','limit'].includes(k)))fail(422,'INVALID_QUERY','Parámetro desconocido');
    const cursor=req.query.cursor||'0';if(typeof cursor!=='string'||!/^(0|[1-9][0-9]{0,18})$/.test(cursor))fail(422,'INVALID_CURSOR','Cursor no válido');
    const limit=Number(req.query.limit||100);if(!Number.isInteger(limit)||limit<1||limit>100)fail(422,'INVALID_LIMIT','Límite no válido');
    const rows=await db.read(async s=>{await membership(s,bid(req),req.actor.sub);return s.list('cambios_sync',{negocio_id:bid(req)},{ranges:[['seq','>',cursor]],order:[['seq','ASC']],limit});});
    res.json({items:rows.map(r=>({...r,payload:json(r.payload)})),cursor:rows.at(-1)?.seq||cursor});
  }));
  router.get('/negocios/:id/sync/snapshot',secured,wrap(async(req,res)=>res.json(await reads.snapshot(bid(req),req.actor))));
  app.use('/api/v1',router);
  const path=require('node:path'),fs=require('node:fs'),webDir=path.join(__dirname,'..','web_build');
  if(fs.existsSync(path.join(webDir,'index.html'))){
    app.use(express.static(webDir));
    app.get(/^(?!\/api\/).*/,(_req,res)=>res.sendFile(path.join(webDir,'index.html')));
  }
  app.use((_req,_res,next)=>next(new ApiError(404,'NOT_FOUND','Ruta no encontrada')));
  app.use(errorHandler);
  return app;
}
module.exports={createApp};
