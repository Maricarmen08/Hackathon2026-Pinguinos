'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { loadConfig, assertDatabaseCredentials } = require('../src/config');
const base = { NODE_ENV:'development', HOST:'127.0.0.1', DB_HOST:'127.0.0.1', DB_NAME:'hackathon_pinguinos_dev', DB_USER:'root', DB_PASSWORD:'', JWT_SECRET:'a'.repeat(64), JWT_REFRESH_SECRET:'b'.repeat(64) };
test('credenciales locales: excepción explícita y rechazo fuera de loopback/desarrollo', () => {
  for (const DB_HOST of ['127.0.0.1','localhost','::1']) assert.equal(loadConfig({...base,DB_HOST}).DB_USER,'root');
  for (const override of [{NODE_ENV:'production'},{NODE_ENV:'test'},{NODE_ENV:undefined},{HOST:'0.0.0.0'},{HOST:'localhost'},{HOST:'192.168.1.2'},{DB_HOST:'192.168.1.2'},{DB_HOST:'example.com'}]) {
    assert.throws(() => loadConfig({...base,...override}), /Configuración/);
    assert.throws(() => loadConfig({...base,DB_PASSWORD:'strong-password',...override}), /Configuración/);
    assert.throws(() => loadConfig({...base,DB_USER:'app',...override}), /Configuración/);
  }
  assert.equal(loadConfig({...base,NODE_ENV:'production',DB_USER:'app',DB_PASSWORD:'strong-password'}).DB_USER,'app');
  assert.throws(() => loadConfig({...base,DB_PASSWORD:undefined}));
});
test('la cuenta efectiva root también debe respetar la excepción local', () => {
  assert.doesNotThrow(() => assertDatabaseCredentials(base,'root'));
  assert.throws(() => assertDatabaseCredentials({...base,NODE_ENV:'production',DB_USER:'app',DB_PASSWORD:'secret'},'root'));
});
