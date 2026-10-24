'use strict';
// Países disponibles. Para agregar uno: una línea aquí, la misma en
// lib/v1/countries.dart y la moneda en la migración 003. Solo monedas con 2 decimales.
const COUNTRIES = {
  PE: { nombre: 'Perú', moneda: 'PEN', simbolo: 'S/', zona_horaria: 'America/Lima', prefijo: '+51' },
  CO: { nombre: 'Colombia', moneda: 'COP', simbolo: '$', zona_horaria: 'America/Bogota', prefijo: '+57' },
  MX: { nombre: 'México', moneda: 'MXN', simbolo: '$', zona_horaria: 'America/Mexico_City', prefijo: '+52' },
  EC: { nombre: 'Ecuador', moneda: 'USD', simbolo: 'US$', zona_horaria: 'America/Guayaquil', prefijo: '+593' },
  BO: { nombre: 'Bolivia', moneda: 'BOB', simbolo: 'Bs', zona_horaria: 'America/La_Paz', prefijo: '+591' },
  AR: { nombre: 'Argentina', moneda: 'ARS', simbolo: '$', zona_horaria: 'America/Argentina/Buenos_Aires', prefijo: '+54' },
};
const CODES = Object.keys(COUNTRIES);
const symbolFor = currency => Object.values(COUNTRIES).find(c => c.moneda === currency)?.simbolo || 'S/';
const currencyName = currency => ({ PEN: 'Soles (PEN)', COP: 'Pesos colombianos (COP)', MXN: 'Pesos mexicanos (MXN)', USD: 'Dólares (USD)', BOB: 'Bolivianos (BOB)', ARS: 'Pesos argentinos (ARS)' }[currency] || currency);
module.exports = { COUNTRIES, CODES, symbolFor, currencyName };
