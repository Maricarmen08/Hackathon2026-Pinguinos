'use strict';
const path = require('node:path');
const dotenv = require('dotenv');
const { z } = require('zod');
function allowsLocalCredentials(config) {
  return config.NODE_ENV === 'development' && config.HOST === '127.0.0.1'
    && ['127.0.0.1', 'localhost', '::1'].includes(config.DB_HOST);
}
function assertDatabaseCredentials(config, effectiveUser = config.DB_USER) {
  if ((effectiveUser.toLowerCase() === 'root' || config.DB_PASSWORD === '') && !allowsLocalCredentials(config)) {
    throw new Error('Configuración incorrecta: root o contraseña vacía requieren NODE_ENV=development, MySQL local y HOST=127.0.0.1.');
  }
}
function loadConfig(env = process.env, filename = '.env') {
  if (env === process.env) dotenv.config({ path: path.resolve(__dirname, '..', filename), quiet: true });
  const schema = z.object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('production'),
    HOST: z.string().default('127.0.0.1'),
    PORT: z.coerce.number().int().min(0).max(65535).default(3000),
    DB_HOST: z.string().min(1).default('127.0.0.1'), DB_PORT: z.coerce.number().int().min(1).max(65535).default(3306),
    DB_NAME: z.string().regex(/^[a-zA-Z][a-zA-Z0-9_]{0,63}$/),
    DB_USER: z.string().trim().min(1),
    DB_PASSWORD: z.string(),
    JWT_SECRET: z.string().min(43), JWT_REFRESH_SECRET: z.string().min(43),
    CORS_ORIGINS: z.string().default(''),
    AI_ENABLED: z.enum(['0','1']).default('0').transform(v=>v==='1'),
    AI_PROVIDER: z.enum(['gemini','openai']).default('gemini'),
    GEMINI_API_KEY: z.string().default(''),
    GEMINI_MODEL: z.literal('gemini-3.5-flash-lite').default('gemini-3.5-flash-lite'),
    AI_MAX_REQUESTS_PER_DAY: z.coerce.number().int().min(1).max(100).default(20),
    OPENAI_API_KEY: z.string().default(''),
    AI_TRANSCRIPTION_MODEL: z.string().min(1).max(100).default('gpt-transcribe'),
    AI_EXTRACTION_MODEL: z.string().min(1).max(100).default('gpt-4o-mini')
  }).refine(v => v.JWT_SECRET !== v.JWT_REFRESH_SECRET, { message: 'Los secretos JWT deben ser independientes' });
  const result = schema.safeParse(env);
  if (!result.success) throw new Error('Configuración incompleta/incorrecta: ' + result.error.issues.map(x => x.path.join('.') || x.message).join(', ') + '. Revisar backend/.env sin publicar secretos.');
  assertDatabaseCredentials(result.data);
  return result.data;
}
module.exports = { loadConfig, allowsLocalCredentials, assertDatabaseCredentials };
