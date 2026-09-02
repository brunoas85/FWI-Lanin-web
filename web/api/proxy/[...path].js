// Proxy HTTPS -> HTTP para el API de FWI Lanín — F1 (TASKS.md, Épica F).
//
// La web se sirve por HTTPS en Vercel; el servidor real todavía habla HTTP
// plano (ver C11/D3 en TASKS.md). Un navegador bloquea que una página
// HTTPS llame directo a un endpoint HTTP ("mixed content") — esta función
// reenvía la llamada desde el servidor de Vercel, donde esa restricción no
// aplica. De paso, al quedar en el mismo origen que la página, evita
// también un problema de CORS que iba a aparecer igual (el Flask real no
// manda esas cabeceras hoy).
//
// Función Node sin dependencias: Vercel ya expone `req.query`/`res.status`/
// `res.send` en las funciones bajo api/ sin necesidad de instalar nada.
// Sirve GET únicamente — los 6 endpoints del API (docs/API.md) son todos
// de lectura.

const API_ORIGIN = process.env.FWI_API_ORIGIN || 'http://181.114.143.184:4102/api';
const TIMEOUT_MS = 8000;

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Método no soportado' });
    return;
  }

  const { path, ...resto } = req.query;
  const segmentos = Array.isArray(path) ? path.join('/') : (path ?? '');

  const query = new URLSearchParams();
  for (const [clave, valor] of Object.entries(resto)) {
    if (Array.isArray(valor)) {
      valor.forEach((v) => query.append(clave, v));
    } else if (valor !== undefined) {
      query.append(clave, valor);
    }
  }
  const queryString = query.toString();
  const target = `${API_ORIGIN}/${segmentos}${queryString ? `?${queryString}` : ''}`;

  try {
    const upstream = await fetch(target, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    const body = await upstream.text();
    res
      .status(upstream.status)
      .setHeader('Content-Type', upstream.headers.get('content-type') || 'text/plain; charset=utf-8')
      .send(body);
  } catch (err) {
    const timeout = err?.name === 'TimeoutError' || err?.name === 'AbortError';
    res.status(502).json({
      error: timeout
        ? 'El servidor de FWI Lanín no respondió a tiempo'
        : 'No se pudo conectar con el servidor de FWI Lanín',
    });
  }
}
