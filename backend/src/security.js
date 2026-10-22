'use strict';
const { randomBytes, scrypt, timingSafeEqual, randomUUID } = require('node:crypto');
const { promisify } = require('node:util');
const jwt = require('jsonwebtoken');
const { fail } = require('./errors');
const derive = promisify(scrypt);
let active = 0;
async function key(password, salt) {
  if (active >= 2) fail(503, 'AUTH_BUSY', 'Autenticación ocupada');
  active++;
  try { return await derive(password, salt, 64, { N: 131072, r: 8, p: 1, maxmem: 256 * 1024 * 1024 }); }
  finally { active--; }
}
async function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  return '$scrypt$N=131072,r=8,p=1$' + salt + '$' + (await key(password, salt)).toString('hex');
}
async function verifyPassword(password, encoded) {
  const parts = typeof encoded === 'string' ? encoded.split('$') : [];
  if (parts.length !== 5 || parts[1] !== 'scrypt' || parts[2] !== 'N=131072,r=8,p=1' || !/^[0-9a-f]{32}$/.test(parts[3]) || !/^[0-9a-f]{128}$/.test(parts[4])) return false;
  return timingSafeEqual(await key(password, parts[3]), Buffer.from(parts[4], 'hex'));
}
function tokens(config) {
  const options = { algorithm: 'HS256', issuer: 'pinguinos-api', audience: 'pinguinos-mobile' };
  return {
    issue(userId, deviceId, sessionId, familyId) {
      const payload = { sub: userId, did: deviceId, sid: sessionId };
      return {
        access_token: jwt.sign({ ...payload, typ: 'access' }, config.JWT_SECRET, { ...options, expiresIn: '15m', jwtid: randomUUID() }),
        refresh_token: jwt.sign({ ...payload, fid: familyId, typ: 'refresh' }, config.JWT_REFRESH_SECRET, { ...options, expiresIn: '30d', jwtid: randomUUID() }),
        token_type: 'Bearer', expires_in: 900
      };
    },
    verify(raw, type) {
      try {
        const claims = jwt.verify(raw, type === 'access' ? config.JWT_SECRET : config.JWT_REFRESH_SECRET, { ...options, algorithms: ['HS256'] });
        if (claims.typ !== type || !claims.sub || !claims.did || !claims.sid) throw new Error();
        return claims;
      } catch { fail(401, 'INVALID_TOKEN', 'Sesión no válida o vencida'); }
    }
  };
}
module.exports = { hashPassword, verifyPassword, tokens };
