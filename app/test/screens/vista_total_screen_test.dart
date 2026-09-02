import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fwi_lanin/data/api_client.dart';
import 'package:fwi_lanin/screens/vista_total_screen.dart';
import 'package:fwi_lanin/theme/font_scale.dart';

void main() {
  group('formatearFechaReporte', () {
    test('DateTime -> DD/MM/AA (año a 2 dígitos)', () {
      expect(formatearFechaReporte(DateTime(2026, 8, 22)), '22/08/26');
    });

    test('rellena con cero día y mes de un dígito', () {
      expect(formatearFechaReporte(DateTime(2026, 1, 5)), '05/01/26');
    });
  });

  group('VistaTotalScreen', () {
    Widget wrapped(http.Client mockClient) {
      return FontScaleScope(
        notifier: FontScale(),
        child: MaterialApp(
          home: VistaTotalScreen(client: FwiApiClient(client: mockClient)),
        ),
      );
    }

    http.Client mockCliente({
      required String metJson,
      required String fwiJson,
      int statusCode = 200,
    }) {
      return MockClient((request) async {
        if (request.url.path.endsWith('/vista_datos_meteorologicos')) {
          return http.Response(metJson, statusCode);
        }
        if (request.url.path.endsWith('/vista_fwi')) {
          return http.Response(fwiJson, statusCode);
        }
        return http.Response('not found', 404);
      });
    }

    final metJson = jsonEncode({
      'data': [
        {
          'estacion': 'Alumine',
          'temperatura': 7.5,
          'humedad': 55,
          'viento_10m': 15,
          'direccion': 'E',
          'lluvia_ayer': 0.0,
          'acumulado': 338,
        },
        {
          'estacion': 'Rucachoroi',
          'temperatura': 4,
          'humedad': 60,
          // sin viento_10m, direccion, lluvia_ayer, acumulado -> S/D
        },
      ],
      'fecha_reporte': {'fecha': '20260822', 'hora': '12:00:03'},
      'status': 'success',
    });

    final fwiJson = jsonEncode({
      'data': [
        {
          'estacion': 'Alumine',
          'ffmc': 84,
          'dmc': 7,
          'dc': 52,
          'isi': 2,
          'bui': 11,
          'fwi': 3,
        },
        {'estacion': 'Rucachoroi', 'ffmc': 90, 'fwi': 5},
      ],
      'status': 'success',
    });

    testWidgets('muestra el título con la fecha del reporte formateada', (
      tester,
    ) async {
      final client = mockCliente(metJson: metJson, fwiJson: fwiJson);

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('Datos meteorológicos 22/08/26'), findsOneWidget);
      expect(find.text('Índices FWI'), findsOneWidget);
    });

    testWidgets('la columna fija de estación muestra ambos nombres', (
      tester,
    ) async {
      final client = mockCliente(metJson: metJson, fwiJson: fwiJson);

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('Alumine'), findsNWidgets(2)); // tabla meteo + fwi
      expect(find.text('Rucachoroi'), findsNWidgets(2));
    });

    testWidgets('valores numéricos con unidad y S/D para datos faltantes', (
      tester,
    ) async {
      final client = mockCliente(metJson: metJson, fwiJson: fwiJson);

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('7.5 °C'), findsOneWidget);
      expect(find.text('55 %'), findsOneWidget);
      expect(find.text('15 km/h'), findsOneWidget);
      expect(find.text('E'), findsOneWidget);
      expect(find.text('0.0 mm'), findsOneWidget); // Lluvia 24 hs
      expect(find.text('338 mm'), findsOneWidget); // Acum anual

      // Rucachoroi: sin viento/dirección/lluvia/acumulado.
      expect(find.text('S/D'), findsWidgets);
    });

    testWidgets('los índices FWI se muestran sin unidad, tal como llegan', (
      tester,
    ) async {
      final client = mockCliente(metJson: metJson, fwiJson: fwiJson);

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('84'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('la sección Referencias muestra las 6 siglas', (
      tester,
    ) async {
      final client = mockCliente(metJson: metJson, fwiJson: fwiJson);

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('Referencias'), findsOneWidget);
      for (final sigla in ['FFMC:', 'DMC:', 'DC:', 'ISI:', 'BUI:', 'FWI:']) {
        expect(find.text(sigla), findsOneWidget);
      }
    });

    testWidgets(
      'el encabezado FFMC de la tabla FWI tiene tooltip con la referencia',
      (tester) async {
        final client = mockCliente(metJson: metJson, fwiJson: fwiJson);

        await tester.pumpWidget(wrapped(client));
        await tester.pumpAndSettle();

        final tooltip = tester.widget<Tooltip>(
          find.ancestor(
            of: find.text('FFMC').first,
            matching: find.byType(Tooltip),
          ),
        );
        expect(
          tooltip.message,
          'FFMC < 75 → no habría ignición de combustibles finos (sin propagación).',
        );
      },
    );

    testWidgets('flecha atrás hace pop de la navegación', (tester) async {
      final client = mockCliente(metJson: metJson, fwiJson: fwiJson);

      await tester.pumpWidget(
        FontScaleScope(
          notifier: FontScale(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  child: const Text('abrir vista total'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          VistaTotalScreen(client: FwiApiClient(client: client)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir vista total'));
      await tester.pumpAndSettle();
      expect(find.text('Vista Rápida'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('abrir vista total'), findsOneWidget);
    });

    testWidgets('si falla sin datos previos, muestra pantalla de error con reintentar', (
      tester,
    ) async {
      var intentos = 0;
      final client = MockClient((_) async {
        intentos++;
        return http.Response('error', 500);
      });

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
      // El repositorio hace los dos GET en secuencia; si el primero
      // (/vista_datos_meteorologicos) falla, tira antes de llegar al
      // segundo — por eso 1 intento por carga, no 2.
      expect(intentos, 1);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(intentos, 2);
    });

    testWidgets('pull-to-refresh dispara una nueva carga', (tester) async {
      var intentos = 0;
      final client = MockClient((request) async {
        intentos++;
        if (request.url.path.endsWith('/vista_datos_meteorologicos')) {
          return http.Response(metJson, 200);
        }
        return http.Response(fwiJson, 200);
      });

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();
      expect(intentos, 2);

      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(intentos, 4);
      expect(find.text('Alumine'), findsNWidgets(2));
    });
  });
}
