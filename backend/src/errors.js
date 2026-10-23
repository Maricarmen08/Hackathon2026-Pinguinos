'use strict';
const { randomUUID } = require('node:crypto');
class ApiError extends Error {
  constructor(status, code, message, fields) { super(message); Object.assign(this, { status, code, fields }); }
}
const fail = (status, code, message) => { throw new ApiError(status, code, message); };
function errorHandler(err, req, res, _next) {
  const requestId = req.requestId || randomUUID();
  let status = err.status || 500, code = err.code || 'INTERNAL_ERROR', message = err.message;
  let fields = err.fields;
  if (err.name === 'ZodError') { status = 422; code = 'VALIDATION_ERROR'; message = 'Revisa los campos enviados'; fields = err.issues.map(x => ({ path: x.path.join('.'), message: x.message })); }
  else if (err.type === 'entity.too.large') { status = 413; code = 'REQUEST_TOO_LARGE'; message = 'Solicitud demasiado grande'; }
  else if (err.type === 'entity.parse.failed') { status = 400; code = 'INVALID_JSON'; message = 'JSON no válido'; }
  else if (err.code === 'ER_DUP_ENTRY') { status = 409; code = 'DUPLICATE'; message = 'Identificador o dato único ya registrado'; }
  else if (['ER_NO_REFERENCED_ROW_2', 'ER_CHECK_CONSTRAINT_VIOLATED'].includes(err.code)) { status = 422; code = 'INTEGRITY_ERROR'; message = 'Los datos no cumplen las reglas de integridad'; }
  else if (['ECONNREFUSED', 'ETIMEDOUT', 'ER_ACCESS_DENIED_ERROR', 'ER_BAD_DB_ERROR', 'ER_CON_COUNT_ERROR', 'ER_LOCK_DEADLOCK', 'ER_LOCK_WAIT_TIMEOUT'].includes(err.code)) { status = 503; code = 'DATABASE_UNAVAILABLE'; message = 'La base de datos no está disponible; reintenta con el mismo command_id'; }
  if (status >= 500) { message = ({AI_QUOTA_EXHAUSTED:'La ayuda por internet está pausada por cuota. Puedes continuar localmente o registrar manualmente.',AI_BUSY:'Hay una interpretación en curso. Espera o registra manualmente.',AI_BUDGET_UNAVAILABLE:'No se pudo verificar el límite de IA. Puedes continuar localmente.',AI_NOT_CONFIGURED:'La ayuda por internet no está configurada. Puedes continuar localmente o registrar manualmente.',AI_PROVIDER_UNAVAILABLE:'La ayuda por internet no está disponible por ahora. Puedes continuar localmente.'})[code] || 'Servicio temporalmente no disponible'; code = status === 503 ? code : 'INTERNAL_ERROR'; console.error(JSON.stringify({ request_id: requestId, code })); }
  res.status(status).json({ error: { code, message, ...(fields ? { field_errors:fields } : {}) }, request_id: requestId });
}
module.exports = { ApiError, fail, errorHandler };
