'use strict';
const { randomUUID } = require('node:crypto');
const { fail } = require('../errors');
const { money, dateWithin, nextVersion } = require('../domain');
const { utc } = require('./auth');
function financialService() {
  return async function apply(s,business,actor,type,payload,changed) {
    const bid=business.id;
    const add=async(table,row)=>{
      await s.insert(table,{...row,negocio_id:bid,creado_por:actor.sub});
      const saved=await s.get(table,{id:row.id,negocio_id:bid});
      changed.push({tabla:table,registro:saved});return saved;
    };
    const get=async(table,id)=>{
      const row=await s.get(table,{id,negocio_id:bid},['operaciones','movimientos','transferencias'].includes(table)?'update':'share');
      if(!row)fail(404,'ENTITY_NOT_FOUND','Registro no encontrado en el negocio');return row;
    };
    const account=async(id,date)=>{
      const row=await get('cuentas',id);
      if(!row.activa || row.moneda!=='PEN')fail(422,'ACCOUNT_UNAVAILABLE','Cuenta inactiva o moneda incompatible');
      dateWithin(date,business,row);return row;
    };
    const outstanding=async o=>{
      let applied=0n;
      for(const a of await s.list('aplicaciones',{negocio_id:bid,operacion_id:o.id})) {
        const m=await get('movimientos',a.movimiento_id);
        if(m.estado==='CONFIRMADO')applied+=BigInt(a.monto_minor);
      }
      return BigInt(o.total_minor)-applied;
    };
    const settle=async(movement,allocations,isIncome)=>{
      movement={...movement};
      if(!movement.cuenta_id){
        if(movement.canal!=='EFECTIVO')fail(422,'ACCOUNT_REQUIRED','Elige dónde recibiste o pagaste ese dinero');
        let cash=await s.get('cuentas',{negocio_id:bid,tipo:'EFECTIVO',activa:1});
        if(!cash){
          const member=await s.get('membresias',{negocio_id:bid,usuario_id:actor.sub,estado:'ACTIVA'});
          if(member?.rol!=='PROPIETARIO')fail(403,'OWNER_REQUIRED','Pide al titular crear una cuenta para recibir o pagar dinero');
          cash=await add('cuentas',{id:randomUUID(),nombre:'Efectivo',tipo:'EFECTIVO',moneda:'PEN',saldo_inicial_minor:'0',fecha_apertura:business.inicio_historial,activa:1});
        }
        movement.cuenta_id=cash.id;
      }
      await account(movement.cuenta_id,movement.fecha_movimiento);
      const total=money(movement.monto_minor),seen=new Set();let sum=0n,third;
      // Todos los comandos toman primero el contador del negocio: serialización.
      for(const a of [...allocations].sort((a,b)=>a.operacion_id.localeCompare(b.operacion_id))) {
        if(seen.has(a.operacion_id))fail(422,'DUPLICATE_ALLOCATION','Operación repetida en el mismo cobro/pago');
        seen.add(a.operacion_id);const o=await get('operaciones',a.operacion_id);
        if(o.estado!=='CONFIRMADO' || !(isIncome?['VENTA','SALDO_CXC']:['COMPRA_MERCADERIA','GASTO_OPERATIVO','SALDO_CXP']).includes(o.tipo))fail(422,'INCOMPATIBLE_OPERATION','Operación incompatible con cobro/pago');
        if(movement.fecha_movimiento<o.fecha_operacion)fail(422,'INVALID_DATE','No liquidar antes de la operación');
        if(third===undefined)third=o.tercero_id;else if(third!==o.tercero_id)fail(422,'MIXED_COUNTERPARTIES','No mezclar contrapartes en un movimiento');
        const n=money(a.monto_minor);if(n>await outstanding(o))fail(409,'EXCEEDS_OUTSTANDING','El abono supera el pendiente');
        sum+=n;
      }
      if(sum!==total)fail(422,'ALLOCATION_MISMATCH','Las aplicaciones deben sumar el movimiento completo');
      const m=await add('movimientos',{...movement,direccion:isIncome?'ENTRADA':'SALIDA',clase:isIncome?'COBRO':'PAGO',estado:'CONFIRMADO'});
      for(const a of allocations)await add('aplicaciones',{...a,movimiento_id:m.id});
    };
    const voidRow=async(table,row,motivo)=>{
      const updated={estado:'ANULADO',anulado_en:utc(new Date()),anulado_por:actor.sub,motivo_anulacion:motivo,version:nextVersion(row),actualizado_en:utc(new Date())};
      await s.update(table,{id:row.id,negocio_id:bid},updated);
      changed.push({tabla:table,registro:{...row,...updated},version_anterior:String(row.version)});
    };
    if(type==='REGISTRAR_OPERACION') {
      const o={...payload.operacion};dateWithin(o.fecha_operacion,business);
      const opening=['SALDO_CXC','SALDO_CXP'].includes(o.tipo);
      if(opening && (o.categoria_id!==null || o.condicion!=='CREDITO'))fail(422,'INVALID_OPENING','Deuda inicial requiere crédito sin categoría');
      if(!opening) {
        if(!o.categoria_id){
          let general=await s.get('categorias',{negocio_id:bid,tipo:o.tipo,nombre_normalizado:'general'});
          if(!general)general=await add('categorias',{id:randomUUID(),nombre:'General',nombre_normalizado:'general',tipo:o.tipo,activa:1});
          o.categoria_id=general.id;
        }
        const c=await get('categorias',o.categoria_id);if(!c.activa||c.tipo!==o.tipo)fail(422,'INVALID_CATEGORY','Categoría inactiva o incompatible');
      }
      if(o.condicion==='CREDITO' && !o.tercero_id)fail(422,'COUNTERPARTY_REQUIRED','Crédito requiere cliente o proveedor');
      if(o.tercero_id && !(await get('terceros',o.tercero_id)).activo)fail(422,'COUNTERPARTY_INACTIVE','Contraparte inactiva');
      if(o.vence_el && (o.condicion!=='CREDITO'||o.vence_el<o.fecha_operacion))fail(422,'INVALID_DUE_DATE','Vencimiento incompatible');
      const expected=money(o.total_minor),paid=payload.pagos_iniciales.reduce((n,m)=>n+money(m.monto_minor),0n);
      if(paid>expected)fail(409,'EXCEEDS_OUTSTANDING','Los pagos iniciales superan el importe');
      if(o.condicion==='CONTADO' && paid!==expected)fail(422,'CASH_NOT_SETTLED','Contado requiere liquidación completa');
      await add('operaciones',{...o,estado:'CONFIRMADO'});
      for(const initial of payload.pagos_iniciales) {
        const {aplicacion_id,...m}=initial;
        await settle(m,[{id:aplicacion_id,operacion_id:o.id,monto_minor:m.monto_minor}],['VENTA','SALDO_CXC'].includes(o.tipo));
      }
    } else if(type==='REGISTRAR_COBRO'||type==='REGISTRAR_PAGO') {
      await settle(payload.movimiento,payload.aplicaciones,type==='REGISTRAR_COBRO');
    } else if(type==='REGISTRAR_TRANSFERENCIA') {
      if(payload.cuenta_origen_id===payload.cuenta_destino_id || payload.movimiento_salida_id===payload.movimiento_entrada_id)fail(422,'INVALID_TRANSFER','Cuentas y movimientos deben ser distintos');
      await account(payload.cuenta_origen_id,payload.fecha);await account(payload.cuenta_destino_id,payload.fecha);
      const {movimiento_salida_id,movimiento_entrada_id,...t}=payload;
      await add('transferencias',{...t,estado:'CONFIRMADO'});
      for(const [id,cuenta_id,direccion]of [[movimiento_salida_id,t.cuenta_origen_id,'SALIDA'],[movimiento_entrada_id,t.cuenta_destino_id,'ENTRADA']])
        await add('movimientos',{id,cuenta_id,direccion,clase:'TRANSFERENCIA',monto_minor:t.monto_minor,fecha_movimiento:t.fecha,canal:'TRANSFERENCIA',concepto:t.concepto,transferencia_id:t.id,estado:'CONFIRMADO'});
    } else if(type==='REGISTRAR_MOVIMIENTO_NO_OPERATIVO') {
      await account(payload.cuenta_id,payload.fecha_movimiento);
      await add('movimientos',{...payload,direccion:['APORTE','PRESTAMO_RECIBIDO'].includes(payload.clase)?'ENTRADA':'SALIDA',estado:'CONFIRMADO'});
    } else if(type.startsWith('ANULAR_')) {
      const table={ANULAR_OPERACION:'operaciones',ANULAR_MOVIMIENTO:'movimientos',ANULAR_TRANSFERENCIA:'transferencias'}[type];
      const row=await get(table,payload.id);
      if(row.estado!=='CONFIRMADO'||String(row.version)!==payload.expected_version)fail(409,'VERSION_CONFLICT','Registro anulado o versión desactualizada');
      if(table==='operaciones') {
        if(row.condicion==='CONTADO') {
          const handled=new Set();
          for(const a of await s.list('aplicaciones',{negocio_id:bid,operacion_id:row.id})) {
            if(handled.has(a.movimiento_id))continue;
            handled.add(a.movimiento_id);
            const m=await get('movimientos',a.movimiento_id);
            if(m.estado!=='CONFIRMADO')continue;
            const all=await s.list('aplicaciones',{negocio_id:bid,movimiento_id:m.id});
            if(all.some(x=>x.operacion_id!==row.id))fail(409,'SHARED_PAYMENT','Movimiento compartido requiere corrección conjunta');
            await voidRow('movimientos',m,payload.motivo);
          }
        } else if(await outstanding(row)!==BigInt(row.total_minor))fail(409,'LIVE_PAYMENTS','Anula primero los cobros/pagos relacionados');
      }
      if(table==='movimientos') {
        if(row.transferencia_id)fail(409,'TRANSFER_ATOMIC','Anula la transferencia completa');
        for(const a of await s.list('aplicaciones',{negocio_id:bid,movimiento_id:row.id})) {
          const o=await get('operaciones',a.operacion_id);
          if(o.estado==='CONFIRMADO' && o.condicion==='CONTADO')fail(409,'CASH_AGGREGATE_REQUIRED','Anula la operación de contado completa');
        }
      }
      if(table==='transferencias') {
        const legs=await s.list('movimientos',{negocio_id:bid,transferencia_id:row.id});
        if(legs.length!==2||legs.some(l=>l.estado!=='CONFIRMADO'))fail(409,'INCONSISTENT_TRANSFER','Transferencia requiere revisión');
        for(const leg of legs)await voidRow('movimientos',leg,payload.motivo);
      }
      await voidRow(table,row,payload.motivo);
    } else fail(422,'UNKNOWN_COMMAND','Comando no implementado');
  };
}
module.exports={financialService};
