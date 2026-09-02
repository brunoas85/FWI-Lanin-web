import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fwi_lanin/data/api_client.dart';
import 'package:fwi_lanin/data/fwi_repository.dart';

void main() {
  group('FwiRepository.fetchEstaciones', () {
    test('ordena por el campo "orden" cuando el API lo manda', () async {
      final json = jsonEncode([
        {'id': 'X2', 'nombre': 'Chapelco', 'estado_fwi': 'BAJO', 'orden': 7},
        {'id': 'X1', 'nombre': 'Alumine', 'estado_fwi': 'BAJO', 'orden': 1},
        {'id': 'X3', 'nombre': 'Bariloche', 'estado_fwi': 'BAJO', 'orden': 8},
      ]);
      final repo = FwiRepository(
        FwiApiClient(client: MockClient((_) async => http.Response(json, 200))),
      );

      final estaciones = await repo.fetchEstaciones();

      expect(
        estaciones.map((e) => e.nombre),
        ['Alumine', 'Chapelco', 'Bariloche'],
      );
    });

    test('cae al orden de respaldo si falta el campo "orden"', () async {
      final json = jsonEncode([
        {'id': 'X1', 'nombre': 'Chapelco', 'estado_fwi': 'BAJO'},
        {'id': 'X2', 'nombre': 'Alumine', 'estado_fwi': 'BAJO'},
      ]);
      final repo = FwiRepository(
        FwiApiClient(client: MockClient((_) async => http.Response(json, 200))),
      );

      final estaciones = await repo.fetchEstaciones();

      // ORDEN_FALLBACK pone Alumine antes que Chapelco.
      expect(estaciones.map((e) => e.nombre), ['Alumine', 'Chapelco']);
    });

    test('lo que no matchea ni con "orden" ni con el respaldo queda al final, en orden de llegada', () async {
      final json = jsonEncode([
        {'id': 'X1', 'nombre': 'Estacion Nueva', 'estado_fwi': 'BAJO'},
        {'id': 'X2', 'nombre': 'Alumine', 'estado_fwi': 'BAJO'},
      ]);
      final repo = FwiRepository(
        FwiApiClient(client: MockClient((_) async => http.Response(json, 200))),
      );

      final estaciones = await repo.fetchEstaciones();

      expect(estaciones.map((e) => e.nombre), ['Alumine', 'Estacion Nueva']);
    });
  });

  group('FwiRepository.fetchVistaTotal', () {
    // Las 8 estaciones reales (docs/API.md), en un orden de llegada
    // arbitrario para probar que el resultado depende del ordenamiento,
    // no de casualidad.
    const nombresEnLlegada = [
      'Bariloche',
      'Chapelco',
      'Hua Hum',
      'Paimun',
      'Tromen',
      'Quillen',
      'Rucachoroi',
      'Alumine',
    ];

    test(
      'combina por estación y ordena distinto al de Estaciones (Chapelco entra, Hua Hum queda afuera del top 6)',
      () async {
        final datosJson = jsonEncode({
          'data': [
            for (final nombre in nombresEnLlegada)
              {
                'estacion': nombre,
                'temperatura': 10,
                'humedad': 50,
                'viento_10m': 5,
                'direccion': 'N',
                'lluvia_ayer': 0,
                'acumulado': 100,
              },
          ],
          'fecha_reporte': {'fecha': '20260822', 'hora': '12:00:00'},
          'status': 'success',
        });
        final fwiJson = jsonEncode({
          'data': [
            for (final nombre in nombresEnLlegada)
              {
                'estacion': nombre,
                'ffmc': 80,
                'dmc': 10,
                'dc': 50,
                'isi': 3,
                'bui': 12,
                'fwi': 4,
              },
          ],
          'status': 'success',
        });

        final client = MockClient((req) async {
          if (req.url.path.endsWith('vista_datos_meteorologicos')) {
            return http.Response(datosJson, 200);
          }
          return http.Response(fwiJson, 200);
        });
        final repo = FwiRepository(FwiApiClient(client: client));

        final resultado = await repo.fetchVistaTotal();
        final nombres = resultado.filas.map((f) => f.estacion).toList();

        // ORDEN_DESEADO de Vista total termina en Chapelco (no en Hua Hum,
        // que es lo que usa Estaciones) — ver docs/API.md.
        expect(nombres.sublist(0, 6), [
          'Alumine',
          'Rucachoroi',
          'Quillen',
          'Tromen',
          'Paimun',
          'Chapelco',
        ]);
        // Las no listadas quedan al final, en el orden en que llegaron.
        expect(nombres.sublist(6), ['Bariloche', 'Hua Hum']);

        // La combinación trajo los datos de ambos endpoints para la misma fila.
        final alumine = resultado.filas.firstWhere((f) => f.estacion == 'Alumine');
        expect(alumine.temperatura, 10);
        expect(alumine.fwi, 4);

        expect(resultado.fechaReporte, DateTime(2026, 8, 22, 12, 0, 0));
      },
    );

    test('una estación sin match en /vista_fwi queda con los índices en null, no se descarta', () async {
      final datosJson = jsonEncode({
        'data': [
          {'estacion': 'Alumine', 'temperatura': 10},
        ],
        'fecha_reporte': {'fecha': '20260822'},
        'status': 'success',
      });
      final fwiJson = jsonEncode({'data': [], 'status': 'success'});

      final client = MockClient((req) async {
        if (req.url.path.endsWith('vista_datos_meteorologicos')) {
          return http.Response(datosJson, 200);
        }
        return http.Response(fwiJson, 200);
      });
      final repo = FwiRepository(FwiApiClient(client: client));

      final resultado = await repo.fetchVistaTotal();

      expect(resultado.filas, hasLength(1));
      expect(resultado.filas.single.temperatura, 10);
      expect(resultado.filas.single.fwi, isNull);
    });
  });
}
