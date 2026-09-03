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
// El catch-all `api/proxy/[...path].js` sólo llegaba a matchear un único
// segmento de ruta en este proyecto (bug/limitación del router de Vercel
// para funciones sin framework) — `/api/proxy/estaciones` andaba pero
// `/api/proxy/estacion/<id>` daba 404 de plataforma. Se reemplaza por una
// función fija en `/api/proxy` + un rewrite en vercel.json que manda
// cualquier `/api/proxy/*` acá; el path real se reconstruye parseando
// `req.url` (que preserva la ruta original pedida por el navegador).
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

  const url = new URL(req.url, 'http://internal');
  const prefix = '/api/proxy/';
  const segmentos = url.pathname.startsWith(prefix)
    ? url.pathname.slice(prefix.length)
    : '';
  const target = `${API_ORIGIN}/${segmentos}${url.search}`;

  try {
    const upstream = await fetch(target, { signal: AbortSignal.timeout(TIMEOUT_MS) });
    // Buffer, no .text(): /mapa_estaciones devuelve un JPEG binario, y
    // decodificarlo/reenmarcarlo como texto UTF-8 corrompe los bytes.
    const body = Buffer.from(await upstream.arrayBuffer());
    res
      .status(upstream.status)
      .setHeader('Content-Type', upstream.headers.get('content-type') || 'application/octet-stream')
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
