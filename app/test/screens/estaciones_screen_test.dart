import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fwi_lanin/data/api_client.dart';
import 'package:fwi_lanin/data/models/estacion.dart';
import 'package:fwi_lanin/screens/estaciones_screen.dart';
import 'package:fwi_lanin/theme/font_scale.dart';
import 'package:fwi_lanin/widgets/visor_imagen_pantalla_completa.dart';

// PNG 1×1 transparente, mínimo válido — evita que el test de "Ver mapa de
// estaciones" dispare una descarga de red real.
final _imagenDePrueba = MemoryImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQI12P4//8/AAX+Av7c'
    'zFnnAAAAAElFTkSuQmCC',
  ),
);

String _fechaApi(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}'
    '${dt.month.toString().padLeft(2, '0')}'
    '${dt.day.toString().padLeft(2, '0')}';

String _horaApi(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}:'
    '${dt.second.toString().padLeft(2, '0')}';

void main() {
  // estaDesactualizada() se mudó a data/parsing.dart (la necesitan tanto
  // Estacion como EstacionDetalle) — sus tests unitarios viven en
  // test/data/parsing_test.dart. Acá queda solo la cobertura a nivel
  // pantalla: "el ícono de desactualizado solo aparece en la estación
  // vieja", más abajo.

  group('formatearFechaCorta', () {
    test('AAAAMMDD -> DD/MM/AA', () {
      expect(formatearFechaCorta('20260822'), '22/08/26');
    });

    test('formato inesperado se devuelve tal cual', () {
      expect(formatearFechaCorta(''), '');
      expect(formatearFechaCorta('2026-08-22'), '2026-08-22');
    });
  });

  group('textoActualizacion', () {
    test('fecha y hora: "Act." pegado, sin espacio', () {
      final e = Estacion(
        id: 'X',
        nombre: 'X',
        estadoFwi: 'BAJO',
        fecha: '20260822',
        hora: '12:00:03',
      );
      expect(textoActualizacion(e), 'Act.22/08/26 - 12:00:03');
    });

    test('sin fecha ni hora: "Sin datos"', () {
      final e = Estacion(id: 'X', nombre: 'X', estadoFwi: 'BAJO', fecha: '', hora: '');
      expect(textoActualizacion(e), 'Sin datos');
    });

    test('solo fecha: sin separador', () {
      final e = Estacion(id: 'X', nombre: 'X', estadoFwi: 'BAJO', fecha: '20260822', hora: '');
      expect(textoActualizacion(e), 'Act.22/08/26');
    });
  });

  group('EstacionesScreen', () {
    Widget wrapped(http.Client mockClient, {NavigatorObserver? observer}) {
      return FontScaleScope(
        notifier: FontScale(),
        child: MaterialApp(
          home: EstacionesScreen(
            client: FwiApiClient(client: mockClient),
            imagenMapa: _imagenDePrueba,
          ),
          navigatorObservers: observer != null ? [observer] : const [],
          onGenerateRoute: (settings) =>
              MaterialPageRoute(settings: settings, builder: (_) => const SizedBox()),
        ),
      );
    }

    String jsonDe(List<Map<String, dynamic>> estaciones) => jsonEncode(estaciones);

    final tresEstaciones = [
      {
        'id': 'IALUMI4', 'nombre': 'Alumine', 'estado_fwi': 'BAJO', 'orden': 1,
        'fwi': '2.5', 'fecha': _fechaApi(DateTime.now()), 'hora': _horaApi(DateTime.now()),
        'ppt': '0.0',
      },
      {
        'id': 'ILASCO33', 'nombre': 'Rucachoroi', 'estado_fwi': 'ALTO', 'orden': 2,
        'fwi': '4.0',
        'fecha': _fechaApi(DateTime.now().subtract(const Duration(hours: 30))),
        'hora': _horaApi(DateTime.now().subtract(const Duration(hours: 30))),
        'ppt': '0.0',
      },
      {
        'id': 'IALUMI6', 'nombre': 'Quillen', 'estado_fwi': 'MODERADO', 'orden': 3,
        'fwi': '1.2', 'fecha': _fechaApi(DateTime.now()), 'hora': _horaApi(DateTime.now()),
        'ppt': '5.0',
      },
    ];

    testWidgets('muestra un spinner mientras carga', (tester) async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(jsonDe(tresEstaciones), 200);
      });

      await tester.pumpWidget(wrapped(client));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Dejar que el timer del mock termine antes de que el test cierre el
      // árbol de widgets — si no, queda un Timer pendiente y el binding de
      // test lo marca como error, aunque el spinner ya se haya verificado.
      await tester.pump(const Duration(milliseconds: 60));
    });

    testWidgets('renderiza una tarjeta por estación, con N-1 divisores', (tester) async {
      final client = MockClient((_) async => http.Response(jsonDe(tresEstaciones), 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('Alumine'), findsOneWidget);
      expect(find.text('Rucachoroi'), findsOneWidget);
      expect(find.text('Quillen'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.text('Ver mapa de estaciones'), findsOneWidget);
    });

    testWidgets('tocar "Ver mapa de estaciones" abre el visor de imagen', (
      tester,
    ) async {
      final client = MockClient((_) async => http.Response(jsonDe(tresEstaciones), 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver mapa de estaciones'));
      await tester.pumpAndSettle();

      expect(find.byType(VisorImagenPantallaCompleta), findsOneWidget);
      expect(find.text('Mapa de estaciones'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('el ícono de desactualizado solo aparece en la estación vieja', (tester) async {
      final client = MockClient((_) async => http.Response(jsonDe(tresEstaciones), 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('el ícono de lluvia solo aparece si ppt > 0', (tester) async {
      final client = MockClient((_) async => http.Response(jsonDe(tresEstaciones), 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.water_drop), findsOneWidget);
    });

    testWidgets('el valor FWI se muestra con un decimal', (tester) async {
      final client = MockClient((_) async => http.Response(jsonDe(tresEstaciones), 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('2.5'), findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
      expect(find.text('1.2'), findsOneWidget);
    });

    testWidgets('tocar una tarjeta navega a /estacion/<id>', (tester) async {
      final client = MockClient((_) async => http.Response(jsonDe(tresEstaciones), 200));
      final observer = _RecordingNavigatorObserver();

      await tester.pumpWidget(wrapped(client, observer: observer));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alumine'));
      await tester.pumpAndSettle();

      expect(observer.pushed, contains('/estacion/IALUMI4'));
    });

    testWidgets('si falla sin datos previos, muestra pantalla de error con reintentar', (tester) async {
      var intentos = 0;
      final client = MockClient((_) async {
        intentos++;
        return http.Response('error', 500);
      });

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
      expect(intentos, 1);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(intentos, 2);
    });

    testWidgets('pull-to-refresh dispara una nueva carga', (tester) async {
      var intentos = 0;
      final client = MockClient((_) async {
        intentos++;
        return http.Response(jsonDe(tresEstaciones), 200);
      });

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();
      expect(intentos, 1);

      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(intentos, 2);
      // La lista sigue mostrándose después del refresh.
      expect(find.text('Alumine'), findsOneWidget);
    });
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushed.add(name);
  }
}
