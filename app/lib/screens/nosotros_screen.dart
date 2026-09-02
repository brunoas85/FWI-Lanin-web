import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/api_client.dart';
import '../data/api_config.dart';
import '../data/async_data.dart';
import '../data/fwi_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/font_scale.dart';
import '../widgets/ancho_maximo.dart';

/// Pantalla Nosotros — `/nosotros`. Spec exacta en
/// docs/B1_PARIDAD_UI.md §5.
///
/// **Decisiones tomadas al refinar C8** (las dos que B1 dejaba abiertas):
/// - Se saca la línea "Tecnologías utilizadas: ..." en vez de reemplazarla
///   por un texto nuevo.
/// - La versión ya no es un string fijo (`"Versión 1.2 - Julio 2026"`,
///   desfasado del APK real 1.5): se lee del build con `package_info_plus`,
///   así no vuelve a desfasarse en cada release. Sin fecha, porque el
///   build no la conoce.
///
/// **Agregado en C11:** mantener presionado el texto de versión abre un
/// diálogo para cambiar la URL del API guardada. Sin ícono ni botón
/// visible a propósito — es una acción para el personal técnico del
/// Parque, no para el público general que usa la app; el original nunca
/// tuvo ninguna pantalla de configuración alcanzable (ver C9).
class NosotrosScreen extends StatefulWidget {
  const NosotrosScreen({
    super.key,
    this.client,
    this.obtenerVersion,
    this.apiConfig,
  });

  /// Inyectable para tests — ver test/screens/nosotros_screen_test.dart.
  final FwiApiClient? client;

  /// Inyectable para tests: evita depender del mock de canal de plataforma
  /// de `package_info_plus` solo para leer un string. En la app real se
  /// omite y se usa [_versionDesdeBuild].
  final Future<String> Function()? obtenerVersion;

  /// La instancia real la pasa `main.dart` (`onGenerateRoute`) — es la
  /// misma que ya cargó `ApiConfig.load()` al arrancar, así que un cambio
  /// acá persiste y `onGenerateRoute` lo lee en la próxima navegación. Si
  /// se omite (tests que no ejercitan el diálogo), se crea una sin cargar.
  final ApiConfig? apiConfig;

  @override
  State<NosotrosScreen> createState() => _NosotrosScreenState();
}

Future<String> _versionDesdeBuild() async =>
    (await PackageInfo.fromPlatform()).version;

class _NosotrosScreenState extends State<NosotrosScreen> {
  late final _client = widget.client ?? FwiApiClient();
  late final _repository = FwiRepository(_client);
  late final _apiConfig = widget.apiConfig ?? ApiConfig();
  late final AsyncData<String> _texto;
  late final Future<String> _version =
      (widget.obtenerVersion ?? _versionDesdeBuild)();

  @override
  void initState() {
    super.initState();
    _texto = AsyncData(_cargarTexto)..addListener(_onStateChanged);
  }

  /// Réplica de `obtener_texto_nosotros()`: si el API falla o devuelve
  /// vacío, cae al texto embebido — nunca propaga el error. La pantalla
  /// siempre tiene contenido que mostrar, nunca un estado de error.
  Future<String> _cargarTexto() async {
    try {
      final texto = await _repository.fetchNosotros();
      return texto.trim().isEmpty ? textoNosotrosDefault : texto;
    } catch (_) {
      return textoNosotrosDefault;
    }
  }

  void _onStateChanged() => setState(() {});

  @override
  void dispose() {
    _texto.removeListener(_onStateChanged);
    _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF607D8B), // BLUE_GREY_500
      appBar: AppBar(
        title: const Text('Acerca de nosotros'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _Cuerpo(
        estado: _texto.state,
        version: _version,
        apiConfig: _apiConfig,
      ),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.estado,
    required this.version,
    required this.apiConfig,
  });

  final DataState<String> estado;
  final Future<String> version;
  final ApiConfig apiConfig;

  @override
  Widget build(BuildContext context) {
    final texto = switch (estado) {
      DataSuccess<String>(:final data) => data,
      DataLoading<String>(:final staleData) => staleData,
      // _cargarTexto nunca tira, así que este caso no ocurre en la
      // práctica — se cubre solo para que el switch sea exhaustivo.
      DataError<String>(:final staleData) => staleData,
    };

    if (texto == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final elementos = parseTextoNosotros(texto);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFEEEEEE), // GREY_200 — la única pantalla gris
      padding: const EdgeInsets.all(kDefaultPadding),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        // Adaptación a escritorio (Épica F, web): un párrafo estirado al
        // ancho completo de un monitor es incómodo de leer. AnchoMaximo
        // centra el texto a 700px en escritorio; en mobile no hace nada.
        child: AnchoMaximo(
          maxWidth: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 15,
            children: [
              Text(
                'Sobre App FWI Lanín',
                style: TextStyle(
                  fontSize: context.scaled(22),
                  fontWeight: FontWeight.bold,
                ),
              ),
              for (final e in elementos) ..._renderElemento(context, e),
              GestureDetector(
                onLongPress: () => _mostrarDialogoUrlApi(context, apiConfig),
                child: FutureBuilder<String>(
                  future: version,
                  builder: (context, snapshot) {
                    final v = snapshot.data;
                    return Text(
                      v == null ? '' : 'Versión $v',
                      style: TextStyle(
                        fontSize: context.scaled(12),
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: const ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(AppColors.primary),
                    foregroundColor: WidgetStatePropertyAll(Colors.white),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver al inicio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Widget> _renderElemento(BuildContext context, ElementoNosotros e) {
  return switch (e) {
    TituloNosotros(:final texto) => [
      const Divider(),
      Text(
        texto,
        style: TextStyle(
          fontSize: context.scaled(22),
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
    SubtituloNosotros(:final texto) => [
      Text(
        texto,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: context.scaled(16),
        ),
      ),
    ],
    BulletsNosotros(:final items) => [
      Container(
        padding: const EdgeInsets.only(left: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 3,
          children: [
            for (final item in items)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 8,
                children: [
                  const Icon(
                    Icons.forest_rounded,
                    size: 6,
                    color: AppColors.primary,
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(fontSize: context.scaled(14)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ],
    ParrafoNosotros(:final texto) => [
      Text(
        texto,
        textAlign: TextAlign.justify,
        style: TextStyle(fontSize: context.scaled(14)),
      ),
    ],
  };
}

// ── Diálogo oculto de configuración de URL (C11) ──────────────────────

/// Abre el diálogo y, si guardó algo, avisa con un `SnackBar` — separado
/// del diálogo en sí para que este último sea un `StatefulWidget` normal,
/// dueño de su propio `TextEditingController` (ver [_DialogoUrlApi]).
Future<void> _mostrarDialogoUrlApi(
  BuildContext context,
  ApiConfig apiConfig,
) async {
  final guardado = await showDialog<bool>(
    context: context,
    builder: (_) => _DialogoUrlApi(apiConfig: apiConfig),
  );

  if (guardado == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL guardada. Se aplica en la próxima navegación.'),
      ),
    );
  }
}

/// Campo de texto para cambiar la URL guardada del API. "Restablecer"
/// borra el override y vuelve al default hardcodeado. Un error de formato
/// (ver [ApiConfig.setBaseUrl]) se muestra en el propio campo, sin cerrar
/// el diálogo ni persistir nada.
///
/// Dueño de su `TextEditingController` como cualquier `StatefulWidget`
/// normal — no un controller creado y destruido a mano por fuera del
/// árbol de widgets, que en el `showDialog` de Flutter dispara una
/// aserción interna del framework (`_FocusInheritedScope`/`_dependents.isEmpty`)
/// si se lo dispone apenas cierra el diálogo, antes de que termine de
/// desmontarse la ruta.
class _DialogoUrlApi extends StatefulWidget {
  const _DialogoUrlApi({required this.apiConfig});

  final ApiConfig apiConfig;

  @override
  State<_DialogoUrlApi> createState() => _DialogoUrlApiState();
}

class _DialogoUrlApiState extends State<_DialogoUrlApi> {
  late final _controller = TextEditingController(
    text: widget.apiConfig.baseUrl,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    try {
      await widget.apiConfig.setBaseUrl(_controller.text);
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _restablecer() async {
    await widget.apiConfig.setBaseUrl(null);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('URL del servidor'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: FwiApiClient.defaultBaseUrl,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(onPressed: _restablecer, child: const Text('Restablecer')),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}

// ── Parseo de texto — puro y testeado aparte de la UI ─────────────────
// Réplica de parse_texto_nosotros() en nosotros.py: una sintaxis markdown
// reducida, propia del proyecto ("## " título, "### " subtítulo, "- "
// viñeta, línea en blanco separa párrafos).

sealed class ElementoNosotros {
  const ElementoNosotros();
}

final class TituloNosotros extends ElementoNosotros {
  const TituloNosotros(this.texto);
  final String texto;
}

final class SubtituloNosotros extends ElementoNosotros {
  const SubtituloNosotros(this.texto);
  final String texto;
}

final class BulletsNosotros extends ElementoNosotros {
  const BulletsNosotros(this.items);
  final List<String> items;
}

final class ParrafoNosotros extends ElementoNosotros {
  const ParrafoNosotros(this.texto);
  final String texto;
}

List<ElementoNosotros> parseTextoNosotros(String texto) {
  final controles = <ElementoNosotros>[];
  final parrafoActual = <String>[];
  var bulletsActuales = <String>[];

  void flushParrafo() {
    if (parrafoActual.isNotEmpty) {
      final t = parrafoActual.join(' ').trim();
      if (t.isNotEmpty) controles.add(ParrafoNosotros(t));
      parrafoActual.clear();
    }
  }

  void flushBullets() {
    if (bulletsActuales.isNotEmpty) {
      controles.add(BulletsNosotros(List.of(bulletsActuales)));
      bulletsActuales = [];
    }
  }

  for (final linea in texto.replaceAll('\r\n', '\n').split('\n')) {
    final s = linea.trim();

    if (s.isEmpty) {
      flushParrafo();
      flushBullets();
      continue;
    }
    if (s.startsWith('## ')) {
      flushParrafo();
      flushBullets();
      controles.add(TituloNosotros(s.substring(3).trim()));
      continue;
    }
    if (s.startsWith('### ')) {
      flushParrafo();
      flushBullets();
      controles.add(SubtituloNosotros(s.substring(4).trim()));
      continue;
    }
    if (s.startsWith('- ')) {
      flushParrafo();
      bulletsActuales.add(s.substring(2).trim());
      continue;
    }
    flushBullets();
    parrafoActual.add(s);
  }
  flushParrafo();
  flushBullets();
  return controles;
}

/// Basado en `TEXTO_NOSOTROS_DEFAULT` de nosotros.py — se usa si
/// `/nosotros` falla o devuelve vacío.
///
/// Ya no es una réplica literal: al revisar C12, se corrigió "Marcos
/// Vallegos" -> "Marcos Vallejos (Facilitador y Programador)" y se sumó
/// el equipo de BIT COTESMA (Bruno Ojeda, Martín Elizalde, Melina
/// Simonetti). Esto solo actualiza el texto de **respaldo** — el texto
/// real que ve la mayoría de los usuarios sale de `GET /nosotros`, servido
/// por el servidor de producción (todavía no migrado a este repo, ver
/// Epic D); ese archivo necesita el mismo cambio aparte, fuera del
/// alcance de este proyecto Flutter.
const textoNosotrosDefault = '''La primera versión de la aplicación FWI Lanín (noviembre de 2025) fue desarrollada en conjunto entre BIT COTESMA y el Departamento de Incendios, Comunicaciones y Emergencias (ICE) del Parque Nacional Lanín.

Esta herramienta tecnológica permite extraer y almacenar datos meteorológicos provenientes de la red de seis estaciones del Parque Nacional Lanín y de dos del Servicio Meteorológico Nacional (SMN), y realiza de manera automática el cálculo del Índice Meteorológico de Incendios Forestales (FWI).

En esta segunda versión, se perfeccionaron diversos aspectos relacionados con la presentación de la información.

La información generada será debidamente interpretada por personal perteneciente al Sistema Federal de Manejo del Fuego.

## Equipo de trabajo

### Parque Nacional Lanín
- Juan Carlos Salazar (Área técnica del ICE Lanín)
- Bruno Andrés Salazar (Programador)
- Juan Manuel Corvalán (Informática)

### Colaboradores
- Marcos Vallejos (Facilitador y Programador)
- Ezequiel Marcuzzi (AFE-SNMF)
- Marcelo Bari (Área Técnica del ICE Nahuel Huapi)

### BIT COTESMA
- Bruno Ojeda (estudiante programador)
- Martín Elizalde (estudiante programador)
- Melina Simonetti (estudiante programador)
''';
