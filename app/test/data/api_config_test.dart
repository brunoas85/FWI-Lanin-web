import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fwi_lanin/data/api_client.dart';
import 'package:fwi_lanin/data/api_config.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiConfig', () {
    test('sin nada guardado, baseUrl es el default hardcodeado', () async {
      final config = ApiConfig();
      await config.load();
      expect(config.baseUrl, FwiApiClient.defaultBaseUrl);
    });

    test('load() recupera una URL guardada en una sesión anterior', () async {
      SharedPreferences.setMockInitialValues({
        'api_base_url': 'http://192.168.1.50:4102/api',
      });
      final config = ApiConfig();
      await config.load();
      expect(config.baseUrl, 'http://192.168.1.50:4102/api');
    });

    test('setBaseUrl guarda la URL y queda disponible sin volver a load()', () async {
      final config = ApiConfig();
      await config.setBaseUrl('http://nuevo-servidor.com:8080/api');
      expect(config.baseUrl, 'http://nuevo-servidor.com:8080/api');
    });

    test('setBaseUrl recorta espacios', () async {
      final config = ApiConfig();
      await config.setBaseUrl('  http://x.com/api  ');
      expect(config.baseUrl, 'http://x.com/api');
    });

    test('setBaseUrl persiste entre instancias (vía SharedPreferences)', () async {
      await ApiConfig().setBaseUrl('http://persistido.com/api');

      final otraInstancia = ApiConfig();
      await otraInstancia.load();
      expect(otraInstancia.baseUrl, 'http://persistido.com/api');
    });

    test('setBaseUrl(null) borra el override y vuelve al default', () async {
      final config = ApiConfig();
      await config.setBaseUrl('http://custom.com/api');
      expect(config.baseUrl, isNot(FwiApiClient.defaultBaseUrl));

      await config.setBaseUrl(null);
      expect(config.baseUrl, FwiApiClient.defaultBaseUrl);

      // También lo borra de la persistencia, no solo en memoria.
      final otraInstancia = ApiConfig();
      await otraInstancia.load();
      expect(otraInstancia.baseUrl, FwiApiClient.defaultBaseUrl);
    });

    test('setBaseUrl("") (vacío tras recortar) también borra el override', () async {
      final config = ApiConfig();
      await config.setBaseUrl('http://custom.com/api');
      await config.setBaseUrl('   ');
      expect(config.baseUrl, FwiApiClient.defaultBaseUrl);
    });

    test('setBaseUrl con texto que no es una URL tira FormatException y no cambia nada', () async {
      final config = ApiConfig();
      await config.setBaseUrl('http://original.com/api');

      await expectLater(
        () => config.setBaseUrl('esto no es una url'),
        throwsFormatException,
      );
      expect(config.baseUrl, 'http://original.com/api');
    });

    test('setBaseUrl rechaza esquemas que no son http/https', () async {
      final config = ApiConfig();
      await expectLater(
        () => config.setBaseUrl('ftp://servidor.com/api'),
        throwsFormatException,
      );
    });

    test('setBaseUrl acepta https', () async {
      final config = ApiConfig();
      await config.setBaseUrl('https://servidor-seguro.com/api');
      expect(config.baseUrl, 'https://servidor-seguro.com/api');
    });
  });
}
