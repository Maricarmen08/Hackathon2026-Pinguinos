'use strict';
// Valida database/hackathon_pinguinos_dev.sql en una base TEMPORAL nueva:
//   hackathon_pinguinos_install_check
// 1) la crea importando el SQL único (con el nombre sustituido),
// 2) cuenta tablas/vistas/FK/CHECK y la compara, SOLO LECTURA, con hackathon_pinguinos_dev,
// 3) ejecuta el recorrido HTTP real (registro, negocio, ventas, fiados, abonos, PDF, IA con doble).
// Nunca escribe en hackathon_pinguinos_dev ni en hackathon_pinguinos_test.
// Uso: node scripts/verify-install.js --install-check [--drop-after]
// Credenciales de administrador MySQL local por variables: FINKI_ADMIN_USER (root),
// FINKI_ADMIN_PASSWORD (vacía en Laragon por defecto), DB_HOST (127.0.0.1), DB_PORT (3306).
const mysql=require('mysql2/promise'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {spawnSync}=require('node:child_process'),{randomBytes}=require('node:crypto');
const SOURCE='hackathon_pinguinos_dev',TARGET='hackathon_pinguinos_install_check';
const SQL_FILE=path.join(__dirname,'../../database/hackathon_pinguinos_dev.sql');
const EXPECTED={tables:24,views:5,fks:59,checks:114};
const args=new Set(process.argv.slice(2));
const host=process.env.DB_HOST||'127.0.0.1',port=Number(process.env.DB_PORT||3306);
const user=process.env.FINKI_ADMIN_USER||'root',password=process.env.FINKI_ADMIN_PASSWORD||'';
const ok=m=>console.log('  OK    '+m),bad=m=>{console.log('  FALLO '+m);failures++;},info=m=>console.log('  ·     '+m);
let failures=0;

const STRUCTURE={
  tablas:`SELECT table_name,table_type,engine,table_collation FROM information_schema.tables WHERE table_schema=? ORDER BY 1`,
  columnas:`SELECT table_name,column_name,ordinal_position,column_default,is_nullable,column_type,character_set_name,collation_name,extra,generation_expression FROM information_schema.columns WHERE table_schema=? ORDER BY 1,3`,
  indices:`SELECT table_name,index_name,non_unique,seq_in_index,column_name,sub_part,expression FROM information_schema.statistics WHERE table_schema=? ORDER BY 1,2,4`,
  claves_foraneas:`SELECT k.table_name,k.constraint_name,k.ordinal_position,k.column_name,k.referenced_table_name,k.referenced_column_name,r.update_rule,r.delete_rule FROM information_schema.key_column_usage k JOIN information_schema.referential_constraints r ON r.constraint_schema=k.constraint_schema AND r.constraint_name=k.constraint_name AND r.table_name=k.table_name WHERE k.table_schema=? AND k.referenced_table_name IS NOT NULL ORDER BY 1,2,3`,
  checks:`SELECT c.constraint_name,c.check_clause FROM information_schema.check_constraints c WHERE c.constraint_schema=? ORDER BY 1`,
  vistas:`SELECT table_name,security_type,view_definition FROM information_schema.views WHERE table_schema=? ORDER BY 1`,
  migraciones:null
};
// Los CHECK guardan el introductor de juego de caracteres de la conexión que los creó
// (_ascii, _utf8mb4…); no cambia la regla, por eso se normaliza antes de comparar.
const norm=(rows,schema)=>rows.map(r=>JSON.stringify(Object.values(r)).split(schema).join('<db>').replace(/_(?:ascii|utf8mb4|utf8mb3|utf8|latin1|binary)(?=\\\\')/g,''));

async function describe(c,schema){
  const out={};
  for(const [k,sql] of Object.entries(STRUCTURE)){
    if(!sql)continue;
    const [rows]=await c.query({sql,values:[schema],rowsAsArray:false});out[k]=norm(rows,schema);
  }
  const [mig]=await c.query('SELECT version,nombre,contrato_version FROM `'+schema+'`.schema_migraciones ORDER BY version');
  out.migraciones=norm(mig,schema);
  const [routines]=await c.execute('SELECT routine_name FROM information_schema.routines WHERE routine_schema=? ORDER BY 1',[schema]);
  out.rutinas=routines.map(r=>r.ROUTINE_NAME||r.routine_name);
  return out;
}

async function main(){
  if(!args.has('--install-check'))throw new Error('Uso: node scripts/verify-install.js --install-check [--drop-after]');
  const sql=fs.readFileSync(SQL_FILE,'utf8');
  if(/\b(DROP|TRUNCATE)\b|\bDELETE\s+FROM\b/i.test(sql.replace(/--.*$/gm,'')))throw new Error('El SQL único contiene sentencias destructivas: revisar antes de importar');
  if(!sql.includes('CREATE DATABASE '+SOURCE+'\n'))throw new Error('Formato inesperado del SQL único');
  const admin=await mysql.createConnection({host,port,user,password,multipleStatements:true,charset:'utf8mb4'});
  try{
    console.log('\n[1] Servidor');
    const [[v]]=await admin.query('SELECT VERSION() AS v');
    if(String(v.v).startsWith('8.4.'))ok('MySQL '+v.v);
    else if(process.env.FINKI_ALLOW_NON_84==='1')info('MySQL '+v.v+' (no es 8.4; solo validación preliminar)');
    else throw new Error('Se requiere MySQL 8.4; servidor '+v.v);
    const [exists]=await admin.execute('SELECT SCHEMA_NAME FROM information_schema.schemata WHERE SCHEMA_NAME IN (?,?)',[TARGET,SOURCE]);
    const names=exists.map(r=>r.SCHEMA_NAME||r.schema_name);
    if(names.includes(TARGET))throw new Error(TARGET+' ya existe. Revísala y, si es la de una validación anterior, bórrala manualmente antes de repetir.');

    console.log('\n[2] Importar el SQL único en '+TARGET+' (nunca en '+SOURCE+')');
    await admin.query(sql.split(SOURCE).join(TARGET));
    ok('Importación terminada sin errores');

    console.log('\n[3] Objetos creados');
    const [[n]]=await admin.execute(`SELECT
      (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=? AND table_type='BASE TABLE') AS tables,
      (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=? AND table_type='VIEW') AS views,
      (SELECT COUNT(*) FROM information_schema.referential_constraints WHERE constraint_schema=?) AS fks,
      (SELECT COUNT(*) FROM information_schema.table_constraints WHERE table_schema=? AND constraint_type='CHECK') AS checks`,[TARGET,TARGET,TARGET,TARGET]);
    for(const k of Object.keys(EXPECTED))(Number(n[k])===EXPECTED[k]?ok:bad)(`${k}: ${n[k]} (esperado ${EXPECTED[k]})`);
    const [[d]]=await admin.query('SELECT COUNT(*) AS n FROM `'+TARGET+'`.usuarios');
    (Number(d.n)===0?ok:bad)('Sin usuarios ni datos personales ('+d.n+' usuarios)');

    console.log('\n[4] Comparación de estructura con '+SOURCE+' (solo lectura)');
    if(!names.includes(SOURCE))info(SOURCE+' no existe en este MySQL: comparación omitida');
    else{
      const a=await describe(admin,SOURCE),b=await describe(admin,TARGET);
      for(const k of Object.keys(STRUCTURE)){
        const onlyDev=a[k].filter(x=>!b[k].includes(x)),onlyNew=b[k].filter(x=>!a[k].includes(x));
        if(!onlyDev.length&&!onlyNew.length)ok(`${k}: idénticos (${a[k].length})`);
        else{bad(`${k}: ${onlyDev.length} solo en ${SOURCE}, ${onlyNew.length} solo en el SQL único`);
          for(const x of onlyDev.slice(0,15))console.log('        dev   > '+x);
          for(const x of onlyNew.slice(0,15))console.log('        nuevo > '+x);}
      }
      info('Rutinas de instalación en '+SOURCE+' (no las usa Express; no se incluyen): '+(a.rutinas.join(', ')||'ninguna'));
    }
  }finally{await admin.end();}

  console.log('\n[5] Recorrido real de la API sobre '+TARGET);
  const privateDir=fs.mkdtempSync(path.join(os.tmpdir(),'finki-install-check-'));
  const env={...process.env,FINKI_INSTALL_CHECK:'1',NODE_ENV:'development',HOST:'127.0.0.1',PORT:'0',
    DB_HOST:host,DB_PORT:String(port),DB_NAME:TARGET,DB_USER:user,DB_PASSWORD:password,
    JWT_SECRET:randomBytes(48).toString('base64url'),JWT_REFRESH_SECRET:randomBytes(48).toString('base64url'),
    CORS_ORIGINS:'',AI_ENABLED:'0',GEMINI_API_KEY:'',OPENAI_API_KEY:'',FINKI_PRIVATE_DIR:privateDir};
  const run=spawnSync(process.execPath,['--test','--test-reporter=spec',path.join(__dirname,'../test/install-check.integration.js')],{env,cwd:path.join(__dirname,'..'),encoding:'utf8'});
  const output=(run.stdout||'')+(run.stderr||'');
  for(const line of output.split(/\r?\n/))if(/^\s*(✔|✖|ℹ (tests|pass|fail|skipped))/.test(line))console.log('      '+line.trim());
  if(run.status===0&&/ℹ pass [1-9]/.test(output)&&/ℹ fail 0/.test(output))ok('Registro, negocio, ventas, gastos, compras, fiados, abonos, pagos, constancia PDF e IA (doble) funcionan');
  else{bad('El recorrido de la API falló; detalle completo abajo');console.log(output.slice(-6000));}
  fs.rmSync(privateDir,{recursive:true,force:true});

  if(args.has('--drop-after')){
    const c=await mysql.createConnection({host,port,user,password});
    try{await c.query('DROP DATABASE `'+TARGET+'`');info('Base temporal '+TARGET+' eliminada (solo esa).');}finally{await c.end();}
  }else info('Base temporal conservada para inspección: '+TARGET+'. Contiene solo datos de ensayo.');

  console.log('\n'+(failures?`RESULTADO: ${failures} comprobación(es) fallaron.`:'RESULTADO: instalación nueva validada.'));
  process.exitCode=failures?1:0;
}
main().catch(e=>{console.error('\nABORTADO: '+e.message+'\nNo se modificó '+SOURCE+'.');process.exitCode=1;});
