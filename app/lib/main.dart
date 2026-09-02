import 'package:flutter/material.dart';

import 'data/api_client.dart';
import 'data/api_config.dart';
import 'screens/estacion_detalle_screen.dart';
import 'screens/estaciones_screen.dart';
import 'screens/nosotros_screen.dart';
import 'screens/presentacion_screen.dart';
import 'screens/vista_total_screen.dart';
import 'theme/app_theme.dart';
import 'theme/font_scale.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiConfig = ApiConfig();
  await apiConfig.load();
  runApp(FwiLaninApp(apiConfig: apiConfig));
}

class FwiLaninApp extends StatefulWidget {
  const FwiLaninApp({super.key, required this.apiConfig});

  final ApiConfig apiConfig;

  @override
  State<FwiLaninApp> createState() => _FwiLaninAppState();
}

class _FwiLaninAppState extends State<FwiLaninApp> {
  final _fontScale = FontScale();

  @override
  void initState() {
    super.initState();
    _fontScale.load();
  }

  @override
  void dispose() {
    _fontScale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FontScaleScope(
      notifier: _fontScale,
      child: MaterialApp(
        title: 'FWI Lanin',
        theme: buildAppTheme(),
        initialRoute: '/',
        onGenerateRoute: (settings) =>
            onGenerateRoute(settings, widget.apiConfig),
      ),
    );
  }
}

/// Réplica del árbol de rutas de `route_change` en `main.py`. A diferencia
/// de Flet — que reconstruye la pila de vistas entera en cada cambio de
/// ruta, porque no la retiene entre navegaciones —, el `Navigator` de
/// Flutter sí mantiene su propia pila de push/pop: alcanza con registrar
/// cada ruta una vez acá. El resto del comportamiento original (Atrás
/// vuelve a la pantalla anterior, Home siempre en la base de la pila,
/// `/estacion/<id>` deja Estaciones debajo en el historial) sale gratis
/// de cómo funciona `Navigator`, dado que hoy la única forma de llegar a
/// `/estacion/<id>` en toda la app es tocando una tarjeta ya dentro de
/// `EstacionesScreen` — no hace falta la reconstrucción manual de pila
/// que el original necesitaba para su propio modelo de ruteo.
///
/// Rutas no reconocidas caen en Home, igual que el original — con una
/// diferencia interna sin efecto observable: el original vacía toda la
/// pila y la reconstruye con solo Home; acá simplemente se apila Home
/// arriba de donde ya estabas. Ningún llamado real de la app navega hoy
/// a una ruta desconocida (no hay deep links todavía), así que replicar
/// el vaciado completo de pila sería resolver un caso sin disparador real.
///
/// [apiConfig] resuelve, en un solo lugar, con qué `FwiApiClient` se
/// construye cada pantalla (C11) — la URL guardada por el usuario, o la
/// hardcodeada del original si nunca configuró una.
Route<dynamic> onGenerateRoute(RouteSettings settings, ApiConfig apiConfig) {
  final name = settings.name ?? '/';

  // Un FwiApiClient por pantalla, construido solo si hace falta — Home no
  // pide datos al API, así que no vale la pena abrir un http.Client() que
  // nunca se usa ni se cierra.
  FwiApiClient client() => FwiApiClient(baseUrl: apiConfig.baseUrl);

  final Widget pantalla;
  if (name.startsWith('/estacion/')) {
    pantalla = EstacionDetalleScreen(
      estacionId: name.substring('/estacion/'.length),
      client: client(),
    );
  } else if (name == '/estaciones') {
    pantalla = EstacionesScreen(client: client());
  } else if (name == '/vista_total') {
    pantalla = VistaTotalScreen(client: client());
  } else if (name == '/nosotros') {
    pantalla = NosotrosScreen(client: client(), apiConfig: apiConfig);
  } else {
    // "/", "/presentacion" y cualquier ruta no reconocida.
    pantalla = const PresentacionScreen();
  }
  return MaterialPageRoute(settings: settings, builder: (_) => pantalla);
}
