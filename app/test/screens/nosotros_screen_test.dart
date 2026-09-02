import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fwi_lanin/data/api_client.dart';
import 'package:fwi_lanin/data/api_config.dart';
import 'package:fwi_lanin/screens/nosotros_screen.dart';
import 'package:fwi_lanin/theme/font_scale.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('parseTextoNosotros', () {
    test('"## " produce un título', () {
      final r = parseTextoNosotros('## Equipo de trabajo');
      expect(r, [isA<TituloNosotros>()]);
      expect((r.single as TituloNosotros).texto, 'Equipo de trabajo');
    });

    test('"### " produce un subtítulo', () {
      final r = parseTextoNosotros('### Colaboradores');
      expect(r, [isA<SubtituloNosotros>()]);
      expect((r.single as SubtituloNosotros).texto, 'Colaboradores');
    });

    test('líneas "- " consecutivas se agrupan en un solo bloque de viñetas', () {
      final r = parseTextoNosotros('- Uno\n- Dos\n- Tres');
      expect(r, [isA<BulletsNosotros>()]);
      expect((r.single as BulletsNosotros).items, ['Uno', 'Dos', 'Tres']);
    });

    test('líneas de párrafo consecutivas se unen con espacio', () {
      final r = parseTextoNosotros('Primera línea\nsegunda línea.');
      expect(r, [isA<ParrafoNosotros>()]);
      expect(
        (r.single as ParrafoNosotros).texto,
        'Primera línea segunda línea.',
      );
    });

    test('una línea en blanco cierra el párrafo', () {
      final r = parseTextoNosotros('Uno.\n\nDos.');
      expect(r, [isA<ParrafoNosotros>(), isA<ParrafoNosotros>()]);
      expect((r[0] as ParrafoNosotros).texto, 'Uno.');
      expect((r[1] as ParrafoNosotros).texto, 'Dos.');
    });

    test('bullets seguidos de párrafo cierran el bloque de viñetas', () {
      final r = parseTextoNosotros('- Uno\nUn párrafo.');
      expect(r, [isA<BulletsNosotros>(), isA<ParrafoNosotros>()]);
    });

    test('texto completo del default se parsea sin explotar', () {
      final r = parseTextoNosotros(textoNosotrosDefault);
      expect(r.whereType<TituloNosotros>().length, 1);
      expect(r.whereType<SubtituloNosotros>().length, 3);
      expect(r.whereType<BulletsNosotros>().length, 3);
      expect(r.whereType<ParrafoNosotros>().length, 4);
    });
  });

  group('NosotrosScreen', () {
    Future<String> version() async => '1.6.0';

    Widget wrapped(http.Client mockClient) {
      return FontScaleScope(
        notifier: FontScale(),
        child: MaterialApp(
          home: NosotrosScreen(
            client: FwiApiClient(client: mockClient),
            obtenerVersion: version,
          ),
        ),
      );
    }

    testWidgets('muestra el encabezado fijo y el texto del API', (
      tester,
    ) async {
      final client = MockClient(
        (_) async => http.Response('## Un título\n\nUn párrafo.', 200),
      );

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('Sobre App FWI Lanín'), findsOneWidget);
      expect(find.text('Un título'), findsOneWidget);
      expect(find.text('Un párrafo.'), findsOneWidget);
    });

    testWidgets('si el API falla, cae al texto embebido por defecto', (
      tester,
    ) async {
      final client = MockClient((_) async => http.Response('error', 500));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('Equipo de trabajo'), findsOneWidget);
      expect(find.text('Parque Nacional Lanín'), findsOneWidget);
      expect(find.text('BIT COTESMA'), findsOneWidget);
      expect(find.text('Marcos Vallejos (Facilitador y Programador)'), findsOneWidget);
      expect(find.text('Bruno Ojeda (estudiante programador)'), findsOneWidget);
      // Nunca se muestra un estado de error para esta pantalla.
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('si el API devuelve vacío, cae al texto embebido', (
      tester,
    ) async {
      final client = MockClient((_) async => http.Response('   ', 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('Equipo de trabajo'), findsOneWidget);
    });

    testWidgets('no muestra la línea de tecnologías utilizadas', (
      tester,
    ) async {
      final client = MockClient((_) async => http.Response('Texto.', 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.textContaining('Tecnologías utilizadas'), findsNothing);
    });

    testWidgets('muestra la versión real del build, leída dinámicamente', (
      tester,
    ) async {
      final client = MockClient((_) async => http.Response('Texto.', 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('Versión 1.6.0'), findsOneWidget);
    });

    testWidgets('flecha atrás hace pop de la navegación', (tester) async {
      final client = MockClient((_) async => http.Response('Texto.', 200));

      await tester.pumpWidget(
        FontScaleScope(
          notifier: FontScale(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  child: const Text('abrir nosotros'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NosotrosScreen(
                        client: FwiApiClient(client: client),
                        obtenerVersion: version,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir nosotros'));
      await tester.pumpAndSettle();
      expect(find.text('Acerca de nosotros'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('abrir nosotros'), findsOneWidget);
    });

    testWidgets('el botón "Volver al inicio" también hace pop', (
      tester,
    ) async {
      final client = MockClient((_) async => http.Response('Texto.', 200));

      await tester.pumpWidget(
        FontScaleScope(
          notifier: FontScale(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  child: const Text('abrir nosotros'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NosotrosScreen(
                        client: FwiApiClient(client: client),
                        obtenerVersion: version,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir nosotros'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Volver al inicio'));
      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();

      expect(find.text('abrir nosotros'), findsOneWidget);
    });
  });

  group('diálogo oculto de URL del API (C11)', () {
    Future<String> version() async => '1.6.0';
    final texto = MockClient((_) async => http.Response('Texto.', 200));

    Widget wrapped(ApiConfig apiConfig) {
      return FontScaleScope(
        notifier: FontScale(),
        child: MaterialApp(
          home: NosotrosScreen(
            client: FwiApiClient(client: texto),
            obtenerVersion: version,
            apiConfig: apiConfig,
          ),
        ),
      );
    }

    testWidgets('mantener presionada la versión abre el diálogo', (
      tester,
    ) async {
      await tester.pumpWidget(wrapped(ApiConfig()));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Versión 1.6.0'));
      await tester.pumpAndSettle();

      expect(find.text('URL del servidor'), findsOneWidget);
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.controller?.text, FwiApiClient.defaultBaseUrl);
    });

    testWidgets('"Guardar" con una URL válida la persiste y avisa', (
      tester,
    ) async {
      final apiConfig = ApiConfig();
      await tester.pumpWidget(wrapped(apiConfig));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Versión 1.6.0'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'http://nuevo-servidor.com:9000/api',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(apiConfig.baseUrl, 'http://nuevo-servidor.com:9000/api');
      expect(find.text('URL del servidor'), findsNothing);
      expect(
        find.text('URL guardada. Se aplica en la próxima navegación.'),
        findsOneWidget,
      );

      // El SnackBar tiene su propio timer de auto-descarte (4s por
      // default): hay que dejarlo terminar antes de que el test cierre
      // el árbol de widgets, o queda un Timer pendiente (mismo gotcha
      // que el MockClient con delay de C5).
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('una URL inválida muestra el error y no cierra el diálogo', (
      tester,
    ) async {
      final apiConfig = ApiConfig();
      await tester.pumpWidget(wrapped(apiConfig));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Versión 1.6.0'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'esto no es una url');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('URL del servidor'), findsOneWidget); // sigue abierto
      expect(
        find.text('La URL debe empezar con http:// o https://'),
        findsOneWidget,
      );
      expect(apiConfig.baseUrl, FwiApiClient.defaultBaseUrl); // sin cambios
    });

    testWidgets('"Restablecer" borra una URL previamente configurada', (
      tester,
    ) async {
      final apiConfig = ApiConfig();
      await apiConfig.setBaseUrl('http://viejo.com/api');

      await tester.pumpWidget(wrapped(apiConfig));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Versión 1.6.0'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restablecer'));
      await tester.pumpAndSettle();

      expect(apiConfig.baseUrl, FwiApiClient.defaultBaseUrl);
    });

    testWidgets('"Cancelar" cierra sin guardar cambios', (tester) async {
      final apiConfig = ApiConfig();
      await tester.pumpWidget(wrapped(apiConfig));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Versión 1.6.0'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'http://no-deberia-guardarse.com/api',
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(apiConfig.baseUrl, FwiApiClient.defaultBaseUrl);
    });
  });
}
