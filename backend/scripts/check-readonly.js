'use strict';
const assert = require('node:assert/strict');
const { loadConfig } = require('../src/config');
const { Database } = require('../src/repositories/database');
const TABLES = require('../src/repositories/tables');
const { buildReport } = require('../src/services/queries');
(async () => {
  let db;
  try {
    const config = loadConfig();
    assert.equal(config.NODE_ENV, 'development');
    assert.equal(config.DB_NAME, 'hackathon_pinguinos_dev');
    db = new Database(config);
    await db.ping();
    await db.snapshot(async s => {
      for (const name of Object.keys(TABLES)) await s.conn.execute('SELECT COUNT(*) AS total FROM `' + name + '`');
      for (const name of ['v_operaciones_saldos','v_cuentas_saldos','v_operaciones_diarias','v_aplicaciones_diarias','v_dinero_diario']) {
        await s.conn.execute('SELECT * FROM `' + name + '` LIMIT 5');
      }
      const businesses = await s.list('negocios', {}, {limit:5});
      let reports = 0;
      for (const b of businesses) {
        assert.equal((await s.get('negocios', {id:b.id})).id, b.id);
        const rows = [];
        for (const table of ['operaciones','movimientos','aplicaciones','cuentas','cierres_diarios']) rows.push(await s.list(table, {negocio_id:b.id}));
        buildReport(b, ...rows, '2026-01-01', '2026-10-22');
        reports++;
      }
      console.log(JSON.stringify({status:'PASS',transaction:'READ ONLY',tables:Object.keys(TABLES).length,views:5,reports,repositoryPagination:true}));
    });
  } catch (e) {
    console.error('Lectura no verificada:', e.code || e.name);
    process.exitCode = 1;
  } finally { if (db) await db.close(); }
})();
