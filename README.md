# FWI Lanín — Web

Versión web (PWA) de la app FWI Lanín — Índice Meteorológico de Peligro de
Incendios Forestales del Parque Nacional Lanín. Mismo código Flutter que la
app de Android, con un target web agregado: no es un proyecto aparte, es
la misma app compilada para navegador.

## Estructura

```
app/    Proyecto Flutter completo (mismo código que la app de Android)
web/    Config de despliegue a Vercel + proxy del API
```

`app/` es el proyecto Flutter tal cual — `app/lib/` es el código Dart,
`app/web/` es la carpeta que genera el propio Flutter para el target web
(`manifest.json`, íconos, `index.html`). `app/android/` sigue ahí porque
es el mismo código fuente que la app de Android, pero no lo toca el
deploy web.

`web/` **no** tiene código Dart — solo:
- `web/vercel.json` — le dice a Vercel cómo compilar (clona Flutter,
  corre `flutter build web --release` dentro de `app/`, copia el
  resultado a `web/public/`, que es lo que Vercel sirve).
- `web/api/proxy/[...path].js` — función serverless de Vercel. Ver
  "Por qué hay un proxy" más abajo.

## Cómo desplegar en Vercel

1. En [vercel.com](https://vercel.com) → **Add New… → Project → Import
   Git Repository** → elegir este repo (`brunoas85/FWI-Lanin-web`).
2. En **Configure Project**:
   - **Root Directory** → `web` (ahí vive `vercel.json`).
   - **Framework Preset** → `Other` (el build ya está definido en
     `vercel.json`, no hace falta que Vercel adivine el framework).
3. **Environment Variables** → agregar:
   - `FWI_API_ORIGIN` = `http://181.114.143.184:4102/api`
   
   (Es la URL real del servidor de datos. Sin esta variable, el proxy
   usa ese mismo valor como *fallback* — pero conviene setearla
   explícita: si el día de mañana cambia la IP del servidor, alcanza
   con editar esta variable y volver a desplegar, sin tocar código.)
4. **Deploy**. El primer build tarda unos minutos — clona el SDK de
   Flutter completo, no hay nada cacheado todavía.
5. Al terminar, Vercel da una URL `*.vercel.app`. Ahí ya debería andar
   completa: Presentación, Estaciones (con datos reales), Vista total,
   Detalle de estación, Nosotros — y es instalable como PWA desde el
   navegador del celular ("Agregar a pantalla de inicio").

## Por qué hay un proxy (`web/api/proxy/`)

El servidor de datos (`http://181.114.143.184:4102/api`) habla HTTP
plano, sin HTTPS. Vercel sirve todo por HTTPS. Un navegador **bloquea**
que una página HTTPS llame directo a un endpoint HTTP (*mixed content*)
— sin este proxy, la web compilaría bien pero ninguna pantalla que
necesita datos (Estaciones, Vista total, Detalle, Nosotros) podría
cargarlos.

`web/api/proxy/[...path].js` es una función de Vercel (Node, sin
dependencias) que recibe la llamada en HTTPS y la reenvía al servidor
real en HTTP, desde el propio servidor de Vercel — ahí esa restricción
no aplica. Como de paso queda en el mismo origen que la página, también
evita un problema de CORS que iba a aparecer igual (el servidor Flask no
manda esas cabeceras hoy).

La app (`ApiConfig`/`FwiApiClient`, en `app/lib/data/`) ya sabe usar
`/api/proxy` como base cuando compila para web — no hace falta tocar
nada ahí, es automático según la plataforma de destino
(`kIsWeb` en `app/lib/data/api_client.dart`).

## Desarrollo local

Para compilar y probar localmente hace falta el SDK de Flutter
instalado (ver [flutter.dev](https://docs.flutter.dev/get-started/install)):

```bash
cd app
flutter pub get
flutter build web --release
cd build/web && python3 -m http.server 8080
```

Ojo: sirviendo así, sin el proxy de Vercel corriendo al lado, las
pantallas que piden datos (Estaciones, Vista total, etc.) van a mostrar
error de conexión — es esperado, el proxy solo existe una vez
desplegado en Vercel.

Para correr los tests (103 tests, cubren toda la lógica de datos y
pantallas):

```bash
cd app
flutter test
```
