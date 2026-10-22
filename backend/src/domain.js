'use strict';
const { createHash } = require('node:crypto');
const { fail } = require('./errors');
const LIMIT = 100000000000000n;
function money(value, signed = false) {
  if (typeof value !== 'string' || value.length>16 || value==='-0' || !(signed ? /^-?(0|[1-9][0-9]*)$/ : /^[1-9][0-9]*$/).test(value)) fail(422, 'INVALID_AMOUNT', 'Importe requerido como cadena entera de céntimos');
  const n = BigInt(value);
  if (n > LIMIT || n < -LIMIT || (!signed && n <= 0n)) fail(422, 'INVALID_AMOUNT', 'Importe fuera del rango permitido');
  return n;
}
function canonical(value) {
  if (Array.isArray(value)) return '[' + value.map(canonical).join(',') + ']';
  if (value !== null && typeof value === 'object') return '{' + Object.keys(value).sort().map(k => JSON.stringify(k) + ':' + canonical(value[k])).join(',') + '}';
  return JSON.stringify(value);
}
const hash = value => createHash('sha256').update(value).digest('hex');
function today(zone = 'America/Lima') { return new Intl.DateTimeFormat('en-CA', { timeZone: zone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date()); }
function dateWithin(date, business, account) {
  if (date < business.inicio_historial || date > today(business.zona_horaria) || (account && date < account.fecha_apertura)) fail(422, 'INVALID_DATE', 'Fecha fuera del historial, anterior a apertura o futura');
}
function nextVersion(row) { return (BigInt(row.version) + 1n).toString(); }
const json = value => typeof value === 'string' ? JSON.parse(value) : value;
module.exports = { LIMIT, money, canonical, hash, today, dateWithin, nextVersion, json };
