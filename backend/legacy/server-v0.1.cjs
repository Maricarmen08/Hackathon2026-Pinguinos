const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USERNAME || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_DATABASE || 'hackathon_pinguinos',
  waitForConnections: true,
  connectionLimit: 10
});

app.get('/', (req, res) => {
  res.redirect('/login.html');
});

app.post('/api/login', async (req, res) => {
  try {
    const { usuario, clave } = req.body;
    const [users] = await pool.query(
      'SELECT * FROM usuarios WHERE (telefono = ? OR correo = ?) AND clave = ? LIMIT 1',
      [usuario, usuario, clave]
    );
    if (users.length === 0) {
      return res.status(401).json({ ok: false, message: 'Credenciales incorrectas' });
    }
    const user = users[0];
    const [negocios] = await pool.query(
      'SELECT * FROM negocios WHERE usuario_id = ? LIMIT 1',
      [user.id]
    );
    return res.json({
      ok: true,
      usuario: user,
      negocio: negocios[0] || null
    });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.post('/api/registro', async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const {
      nombre_completo,
      telefono,
      correo,
      clave,
      nombre_negocio,
      documento_identidad,
      rubro,
      ciudad
    } = req.body;

    const [uResult] = await conn.query(
      'INSERT INTO usuarios (nombre_completo, telefono, correo, clave) VALUES (?, ?, ?, ?)',
      [nombre_completo, telefono, correo || null, clave]
    );

    const usuarioId = uResult.insertId;
    const prefijo = (nombre_completo || 'USER')
      .replace(/[^a-zA-Z]/g, '')
      .toUpperCase()
      .slice(0, 4);
    const codigoReferido = `${prefijo}${Math.floor(1000 + Math.random() * 9000)}`;

    const [nResult] = await conn.query(
      `INSERT INTO negocios (usuario_id, nombre_negocio, documento_identidad, rubro, ciudad, codigo_referido, puntos_difusion, score_crediticio)
       VALUES (?, ?, ?, ?, ?, ?, 15, 65)`,
      [
        usuarioId,
        nombre_negocio,
        documento_identidad || '',
        rubro || 'Bodega y Abarrotes',
        ciudad || 'Lima, Perú',
        codigoReferido
      ]
    );

    await conn.commit();

    const [users] = await pool.query('SELECT * FROM usuarios WHERE id = ?', [usuarioId]);
    const [negocios] = await pool.query('SELECT * FROM negocios WHERE id = ?', [nResult.insertId]);

    res.status(201).json({
      ok: true,
      usuario: users[0],
      negocio: negocios[0]
    });
  } catch (error) {
    await conn.rollback();
    res.status(400).json({ ok: false, error: error.message });
  } finally {
    conn.release();
  }
});

app.get('/api/negocio/:id', async (req, res) => {
  try {
    const negocioId = Number(req.params.id || 1);
    const [rows] = await pool.query(
      `SELECT n.*, u.nombre_completo AS propietario, u.telefono, u.correo
       FROM negocios n
       INNER JOIN usuarios u ON u.id = n.usuario_id
       WHERE n.id = ? LIMIT 1`,
      [negocioId]
    );
    res.json(rows[0] || {});
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/negocio', async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT n.*, u.nombre_completo AS propietario, u.telefono, u.correo
       FROM negocios n
       INNER JOIN usuarios u ON u.id = n.usuario_id
       LIMIT 1`
    );
    res.json(rows[0] || {});
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.put('/api/negocio/:id', async (req, res) => {
  try {
    const negocioId = Number(req.params.id || 1);
    const { nombre_negocio, propietario, telefono, rubro, ciudad, documento_identidad } = req.body;
    const [neg] = await pool.query('SELECT usuario_id FROM negocios WHERE id = ?', [negocioId]);
    if (neg.length > 0) {
      await pool.query(
        'UPDATE usuarios SET nombre_completo = ?, telefono = ? WHERE id = ?',
        [propietario, telefono, neg[0].usuario_id]
      );
    }
    await pool.query(
      'UPDATE negocios SET nombre_negocio = ?, rubro = ?, ciudad = ?, documento_identidad = ? WHERE id = ?',
      [nombre_negocio, rubro, ciudad || 'Lima, Perú', documento_identidad || '', negocioId]
    );
    const [rows] = await pool.query(
      `SELECT n.*, u.nombre_completo AS propietario, u.telefono, u.correo
       FROM negocios n
       INNER JOIN usuarios u ON u.id = n.usuario_id
       WHERE n.id = ?`,
      [negocioId]
    );
    res.json({ ok: true, negocio: rows[0] || {} });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.get('/api/categorias', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM categorias ORDER BY id ASC');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/transacciones', async (req, res) => {
  try {
    const negocioId = Number(req.query.negocio_id || 1);
    const [rows] = await pool.query(
      'SELECT * FROM transacciones WHERE negocio_id = ? ORDER BY fecha_transaccion DESC, id DESC',
      [negocioId]
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/transacciones', async (req, res) => {
  try {
    const {
      negocio_id = 1,
      tipo = 'INGRESO',
      concepto,
      categoria = 'Abarrotes',
      monto = 0,
      origen_ia = 'VOZ',
      prompt_original = '',
      nombre_archivo_boleta = null
    } = req.body;

    const [catRows] = await pool.query(
      'SELECT id FROM categorias WHERE nombre = ? LIMIT 1',
      [categoria]
    );
    const categoriaId = catRows.length > 0 ? catRows[0].id : null;

    const [result] = await pool.query(
      `INSERT INTO transacciones (negocio_id, categoria_id, tipo, concepto, categoria, monto, origen_ia, prompt_original, nombre_archivo_boleta)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        negocio_id,
        categoriaId,
        tipo,
        concepto,
        categoria,
        monto,
        origen_ia,
        prompt_original,
        nombre_archivo_boleta
      ]
    );

    await pool.query(
      'UPDATE negocios SET score_crediticio = LEAST(100, score_crediticio + 1) WHERE id = ?',
      [negocio_id]
    );

    res.status(201).json({ id: result.insertId, status: 'ok' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/transacciones/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM transacciones WHERE id = ?', [req.params.id]);
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.get('/api/creditos', async (req, res) => {
  try {
    const negocioId = Number(req.query.negocio_id || 1);
    const [rows] = await pool.query(
      'SELECT * FROM solicitudes_credito WHERE negocio_id = ? ORDER BY fecha_solicitud DESC',
      [negocioId]
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/creditos', async (req, res) => {
  try {
    const {
      negocio_id = 1,
      entidad_financiera,
      monto_solicitado,
      plazo_meses = 6,
      cuota_mensual,
      score_actual = 82
    } = req.body;

    const [result] = await pool.query(
      `INSERT INTO solicitudes_credito (negocio_id, entidad_financiera, monto_solicitado, plazo_meses, cuota_mensual, score_actual, estado)
       VALUES (?, ?, ?, ?, ?, ?, 'EN_REVISION')`,
      [negocio_id, entidad_financiera, monto_solicitado, plazo_meses, cuota_mensual, score_actual]
    );
    res.status(201).json({ ok: true, id: result.insertId });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.get('/api/referidos', async (req, res) => {
  try {
    const negocioId = Number(req.query.negocio_id || 1);
    const [rows] = await pool.query(
      'SELECT * FROM referidos WHERE negocio_id = ? ORDER BY fecha_registro DESC',
      [negocioId]
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/referidos', async (req, res) => {
  try {
    const { negocio_id = 1, nombre_comerciante, telefono_comerciante } = req.body;
    const [result] = await pool.query(
      'INSERT INTO referidos (negocio_id, nombre_comerciante, telefono_comerciante, puntos_ganados) VALUES (?, ?, ?, 15)',
      [negocio_id, nombre_comerciante, telefono_comerciante]
    );
    await pool.query(
      'UPDATE negocios SET puntos_difusion = puntos_difusion + 15, score_crediticio = LEAST(100, score_crediticio + 2) WHERE id = ?',
      [negocio_id]
    );
    res.status(201).json({ ok: true, id: result.insertId });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Servidor activo en http://127.0.0.1:${PORT}`);
});
