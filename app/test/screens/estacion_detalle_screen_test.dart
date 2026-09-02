import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fwi_lanin/data/api_client.dart';
import 'package:fwi_lanin/screens/estacion_detalle_screen.dart';
import 'package:fwi_lanin/theme/font_scale.dart';

void main() {
  group('formatearFechaLarga', () {
    test('AAAAMMDD -> DD/MM/AAAA (año completo)', () {
      expect(formatearFechaLarga('20260822'), '22/08/2026');
    });

    test('formato inesperado se devuelve tal cual', () {
      expect(formatearFechaLarga(''), '');
      expect(formatearFechaLarga('2026-08-22'), '2026-08-22');
    });
  });

  group('EstacionDetalleScreen', () {
    // home: en vez de initialRoute + onGenerateRoute: un initialRoute con
    // segmentos ("/estacion/IALUMI4") hace que Flutter genere UNA ruta por
    // cada prefijo del path ("/", "/estacion", "/estacion/IALUMI4") si
    // onGenerateRoute matchea cualquier nombre — construía la pantalla 3
    // veces (y disparaba 3 fetches) en vez de una. No hace falta routing
    // real acá; el test de "flecha atrás" ya cubre eso con Navigator.push.
    Widget wrapped(http.Client mockClient, {NavigatorObserver? observer}) {
      return FontScaleScope(
        notifier: FontScale(),
        child: MaterialApp(
          navigatorObservers: observer != null ? [observer] : const [],
          home: EstacionDetalleScreen(
            estacionId: 'IALUMI4',
            client: FwiApiClient(client: mockClient),
          ),
        ),
      );
    }

    final actualizada = DateTime.now().subtract(const Duration(hours: 1));
    String fecha(DateTime dt) =>
        '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
    String hora(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

    final jsonEstacion = jsonEncode({
      'nombre': 'Alumine',
      'Date': fecha(actualizada),
      'Hora': hora(actualizada),
      'Temp': '7.5',
      'HR': '55.0',
      'WS': '5.0',
      'W 10': '7.4',
      'WD': 'E',
      'PPT': '0.0',
      'Acum': '338.39',
      'FFMC': '84.57161',
      'DMC': '7.48446',
      'DC': '52.13452',
      'ISI': '2.88559',
      'BUI': '11.01546',
      'FWI': '3.15134',
      'Estado FWI': 'BAJO',
      'api': 'WUNDERGROUND',
      'latitud': '-39.232743',
      'longitud': '-70.926031',
    });

    testWidgets('muestra nombre, fecha completa, y "ACTUALIZADO" si es reciente', (
      tester,
    ) async {
      final client = MockClient((_) async => http.Response(jsonEstacion, 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('Alumine'), findsOneWidget);
      expect(
        find.textContaining('Último registro: '),
        findsOneWidget,
      );
      expect(find.text('ACTUALIZADO'), findsOneWidget);
      expect(find.text('DESACTUALIZADO'), findsNothing);
    });

    testWidgets('el FWI grande se muestra con un decimal, y el estado', (tester) async {
      final client = MockClient((_) async => http.Response(jsonEstacion, 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('3.2'), findsOneWidget); // 3.15134 -> 3.2, un decimal
      expect(find.text('BAJO'), findsOneWidget);
    });

    testWidgets('las 6 cajas meteorológicas muestran valor y etiqueta', (tester) async {
      final client = MockClient((_) async => http.Response(jsonEstacion, 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('7.5°C'), findsOneWidget);
      expect(find.text('Temperatura'), findsOneWidget);
      expect(find.text('55%'), findsOneWidget);
      expect(find.text('Humedad'), findsOneWidget);
      expect(find.text('5.0 km/h E'), findsOneWidget);
      expect(find.text('7.4 km/h E'), findsOneWidget);
      expect(find.text('Viento (corrección a 10 metros)'), findsOneWidget);
      expect(find.text('0.0 mm'), findsOneWidget);
      expect(find.text('338.4 mm'), findsOneWidget); // 338.39 -> 338.4
    });

    testWidgets('las 5 cajas de índices FWI muestran sigla y un decimal', (tester) async {
      final client = MockClient((_) async => http.Response(jsonEstacion, 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('FFMC'), findsOneWidget);
      expect(find.text('84.6'), findsOneWidget); // 84.57161 -> 84.6
      expect(find.text('DMC'), findsOneWidget);
      expect(find.text('7.5'), findsOneWidget); // 7.48446 -> 7.5
      expect(find.text('DC'), findsOneWidget);
      expect(find.text('ISI'), findsOneWidget);
      expect(find.text('BUI'), findsOneWidget);
    });

    testWidgets('una estación desactualizada (>24h) muestra el chip rojo', (tester) async {
      final vieja = DateTime.now().subtract(const Duration(hours: 30));
      final json = jsonEncode({
        'nombre': 'Rucachoroi',
        'Date': fecha(vieja),
        'Hora': hora(vieja),
        'Estado FWI': 'ALTO',
      });
      final client = MockClient((_) async => http.Response(json, 200));

      await tester.pumpWidget(wrapped(client));
      await tester.pumpAndSettle();

      expect(find.text('DESACTUALIZADO'), findsOneWidget);
      expect(find.text('ACTUALIZADO'), findsNothing);
    });

    testWidgets('flecha atrás hace pop de la navegación', (tester) async {
      final client = MockClient((_) async => http.Response(jsonEstacion, 200));

      await tester.pumpWidget(
        FontScaleScope(
          notifier: FontScale(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  child: const Text('abrir detalle'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EstacionDetalleScreen(
                        estacionId: 'IALUMI4',
                        client: FwiApiClient(client: client),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir detalle'));
      await tester.pumpAndSettle();
      expect(find.text('Alumine'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('abrir detalle'), findsOneWidget);
      expect(find.text('Alumine'), findsNothing);
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

      expect(find.text('No se pudo cargar la estación.'), findsOneWidget);
      expect(intentos, 1);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(intentos, 2);
    });
  });
}
