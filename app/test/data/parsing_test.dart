import 'package:flutter_test/flutter_test.dart';
import 'package:fwi_lanin/data/parsing.dart';

void main() {
  group('parseNum', () {
    test('acepta num directo', () {
      expect(parseNum(3.5), 3.5);
      expect(parseNum(3), 3);
    });

    test('parsea strings numéricos', () {
      expect(parseNum('3.15134'), 3.15134);
      expect(parseNum('0'), 0);
    });

    test('trata "-" y vacío como ausente', () {
      expect(parseNum('-'), isNull);
      expect(parseNum(''), isNull);
      expect(parseNum('   '), isNull);
    });

    test('null y no numérico dan null en vez de tirar', () {
      expect(parseNum(null), isNull);
      expect(parseNum('no es un numero'), isNull);
    });
  });

  group('parseFechaHora', () {
    test('parsea AAAAMMDD + HH:MM:SS', () {
      expect(parseFechaHora('20260822', '12:00:03'), DateTime(2026, 8, 22, 12, 0, 3));
    });

    test('fecha sin hora usa medianoche', () {
      expect(parseFechaHora('20260822', null), DateTime(2026, 8, 22));
    });

    test('formato inválido da null en vez de tirar', () {
      expect(parseFechaHora('2026-08-22', '12:00:00'), isNull);
      expect(parseFechaHora(null, '12:00:00'), isNull);
      expect(parseFechaHora('', '12:00:00'), isNull);
    });
  });

  group('estaDesactualizada', () {
    test('false si actualizó hace menos de 24h', () {
      final hace1h = DateTime.now().subtract(const Duration(hours: 1));
      expect(estaDesactualizada(hace1h), isFalse);
    });

    test('true si actualizó hace más de 24h', () {
      final hace25h = DateTime.now().subtract(const Duration(hours: 25));
      expect(estaDesactualizada(hace25h), isTrue);
    });

    test('respeta el límite de 24h con margen (evita flakiness de reloj real)', () {
      // Comparar contra el instante EXACTO de 24h sería una carrera: el
      // DateTime.now() de adentro de la función siempre corre algunos
      // milisegundos después que este, así que "exactamente 24h" ya daría
      // desactualizado. Se prueba con margen de un minuto a cada lado.
      final pocoMenos = DateTime.now().subtract(
        const Duration(hours: 23, minutes: 59),
      );
      final pocoMas = DateTime.now().subtract(
        const Duration(hours: 24, minutes: 1),
      );
      expect(estaDesactualizada(pocoMenos), isFalse);
      expect(estaDesactualizada(pocoMas), isTrue);
    });

    test('true si no hay dato (null) — corregido respecto al original de Estaciones', () {
      expect(estaDesactualizada(null), isTrue);
    });
  });

  group('normalizarNombre', () {
    test('mayúsculas y recorta espacios', () {
      expect(normalizarNombre('  alumine  '), 'ALUMINE');
    });

    test('saca acentos', () {
      expect(normalizarNombre('Quillén'), 'QUILLEN');
      expect(normalizarNombre('Ñandú'), 'NANDU');
    });

    test('null da string vacío', () {
      expect(normalizarNombre(null), '');
    });
  });
}
