'use strict';
const mysql = require('mysql2/promise');
const TABLES = require('./tables');
const { assertDatabaseCredentials } = require('../config');
const JSON_FIELDS = new Set(['respuesta','payload','detalle','parametros','indicadores','resultado','correccion_usuario','errores']);
const adapt = (field, value) => JSON_FIELDS.has(field) && value !== null ? JSON.stringify(value) : value;
function table(name) { if (!Object.hasOwn(TABLES, name)) throw new Error('Unknown table'); return '\x60' + name + '\x60'; }
function column(t, name) { if (!TABLES[t].includes(name)) throw new Error('Unknown column'); return '\x60' + name + '\x60'; }
function where(t, eq, opts = {}) {
  const conditions = [], values = [];
  for (const [key, val] of Object.entries(eq)) {
    const c = column(t,key);
    if (val === null) conditions.push(c + ' IS NULL');
    else if (Array.isArray(val)) { if (!val.length) conditions.push('FALSE'); else { conditions.push(c + ' IN (' + val.map(() => '?').join(',') + ')'); values.push(...val); } }
    else { conditions.push(c + ' = ?'); values.push(val); }
  }
  for (const [key, op, val] of opts.ranges || []) { if (!['>=','<=','>','<'].includes(op)) throw new Error('Invalid operator'); conditions.push(column(t,key) + ' ' + op + ' ?'); values.push(val); }
  if (opts.search) {
    conditions.push('(' + opts.search.columns.map(k => column(t,k) + " LIKE ? ESCAPE '='").join(' OR ') + ')');
    values.push(...opts.search.columns.map(() => '%' + opts.search.term.replace(/[=%_]/g,'=$&') + '%'));
  }
  return { sql: conditions.length ? ' WHERE ' + conditions.join(' AND ') : '', values };
}
class Session {
  constructor(conn) { this.conn = conn; }
  async list(t, eq = {}, opts = {}) {
    const w = where(t,eq,opts); let sql = 'SELECT * FROM ' + table(t) + w.sql;
    if (opts.order) sql += ' ORDER BY ' + opts.order.map(([k,d]) => column(t,k) + (d === 'DESC' ? ' DESC' : ' ASC')).join(',');
    if (opts.limit !== undefined) { if (!Number.isSafeInteger(opts.limit) || opts.limit < 1 || opts.limit > 1000 || !Number.isSafeInteger(opts.offset || 0)) throw new Error('Invalid limit'); sql += ' LIMIT ? OFFSET ?'; w.values.push(opts.limit,opts.offset || 0); }
    if (opts.lock) sql += opts.lock === 'update' ? ' FOR UPDATE' : ' FOR SHARE';
    const [rows] = await this.conn.execute(sql,w.values); return rows;
  }
  async get(t, eq, lock) { return (await this.list(t,eq,{ limit:1,lock }))[0] || null; }
  async insert(t, row) {
    const keys = Object.keys(row);
    await this.conn.execute('INSERT INTO ' + table(t) + ' (' + keys.map(k=>column(t,k)).join(',') + ') VALUES (' + keys.map(()=>'?').join(',') + ')',keys.map(k=>adapt(k,row[k])));
    return row;
  }
  async update(t, eq, row) {
    if (!Object.keys(eq).length) throw new Error('Unsafe UPDATE');
    const keys=Object.keys(row),w=where(t,eq);
    const [result] = await this.conn.execute('UPDATE ' + table(t) + ' SET ' + keys.map(k=>column(t,k)+'=?').join(',') + w.sql,[...keys.map(k=>adapt(k,row[k])),...w.values]);
    return result.affectedRows;
  }
}
class Database {
  constructor(config) {
    assertDatabaseCredentials(config);
    this.config=config;
    this.pool=mysql.createPool({ host:config.DB_HOST,port:config.DB_PORT,user:config.DB_USER,password:config.DB_PASSWORD,database:config.DB_NAME,
      waitForConnections:true,connectionLimit:5,queueLimit:50,connectTimeout:5000,
      supportBigNumbers:true,bigNumberStrings:true,dateStrings:true,decimalNumbers:false,jsonStrings:true,multipleStatements:false,charset:'utf8mb4' });
  }
  async connection() {
    const c=await this.pool.getConnection();
    try { await c.query("SET SESSION time_zone='+00:00', sql_mode='STRICT_ALL_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION', foreign_key_checks=1, unique_checks=1, innodb_lock_wait_timeout=5"); return c; }
    catch(e) { c.release();throw e; }
  }
  async read(fn) { const c=await this.connection(); try { return await fn(new Session(c)); } finally { c.release(); } }
  async transaction(fn, retries=2) {
    for(let attempt=0;;attempt++) {
      const c=await this.connection();
      try { await c.beginTransaction(); const result=await fn(new Session(c)); await c.commit(); return result; }
      catch(e) { await c.rollback(); if (!['ER_LOCK_DEADLOCK','ER_LOCK_WAIT_TIMEOUT'].includes(e.code) || attempt>=retries) throw e; }
      finally { c.release(); }
    }
  }
  async snapshot(fn) {
    const c=await this.connection();
    try { await c.query('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ'); await c.query('START TRANSACTION WITH CONSISTENT SNAPSHOT, READ ONLY'); const data=await fn(new Session(c)); await c.commit();return data; }
    catch(e) { await c.rollback();throw e; } finally { c.release(); }
  }
  async ping() {
    const c=await this.connection();
    try {
      const [[r]]=await c.query('SELECT VERSION() AS version, DATABASE() AS db, CURRENT_USER() AS account');
      if (!r.version.startsWith('8.4.') || r.db!==this.config.DB_NAME) throw new Error('Unsupported database configuration');
      assertDatabaseCredentials(this.config, r.account.split('@')[0]);
      const [rows]=await c.query('SELECT version,nombre FROM schema_migraciones ORDER BY version');
      if (!rows.some(x=>x.version===1&&x.nombre==='001_initial_schema.sql') || !rows.some(x=>x.version===2&&x.nombre==='002_reporting_views.sql')) throw new Error('Missing migrations');
      return true;
    } finally { c.release(); }
  }
  async close() { await this.pool.end(); }
}
module.exports={ Database,Session,where };
