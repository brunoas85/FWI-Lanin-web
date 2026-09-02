import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fwi_lanin/data/api_config.dart';
import 'package:fwi_lanin/main.dart';
import 'package:fwi_lanin/screens/estacion_detalle_screen.dart';
import 'package:fwi_lanin/screens/estaciones_screen.dart';
import 'package:fwi_lanin/screens/nosotros_screen.dart';
import 'package:fwi_lanin/screens/presentacion_screen.dart';
import 'package:fwi_lanin/screens/vista_total_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('onGenerateRoute', () {
    // El builder de la ruta ya devuelve el widget pre-construido (ver
    // onGenerateRoute: `pantalla` se arma antes del builder, no adentro),
    // así que el BuildContext que recibe nunca se usa — pasar uno falso
    // alcanza.
    Widget construir(String nombre, {ApiConfig? apiConfig}) {
      final route = onGenerateRoute(
        RouteSettings(name: nombre),
        apiConfig ?? ApiConfig(),
      );
      return (route as MaterialPageRoute).builder(_ContextoFalso());
    }

    test('"/estaciones" -> EstacionesScreen', () {
      expect(construir('/estaciones'), isA<EstacionesScreen>());
    });

    test('"/vista_total" -> VistaTotalScreen', () {
      expect(construir('/vista_total'), isA<VistaTotalScreen>());
    });

    test('"/nosotros" -> NosotrosScreen', () {
      expect(construir('/nosotros'), isA<NosotrosScreen>());
    });

    test('"/estacion/<id>" -> EstacionDetalleScreen con el id extraído', () {
      final pantalla = construir('/estacion/IALUMI4');
      expect(pantalla, isA<EstacionDetalleScreen>());
      expect((pantalla as EstacionDetalleScreen).estacionId, 'IALUMI4');
    });

    test('"/" -> PresentacionScreen (Home)', () {
      expect(construir('/'), isA<PresentacionScreen>());
    });

    test(
      'ruta desconocida -> PresentacionScreen (Home), igual que el original',
      () {
        expect(construir('/esto-no-existe'), isA<PresentacionScreen>());
      },
    );

    test('nombre nulo -> PresentacionScreen (Home)', () {
      final route = onGenerateRoute(const RouteSettings(), ApiConfig());
      expect(
        (route as MaterialPageRoute).builder(_ContextoFalso()),
        isA<PresentacionScreen>(),
      );
    });

    test(
      'cada pantalla se construye con un FwiApiClient apuntando a apiConfig.baseUrl (C11)',
      () async {
        final apiConfig = ApiConfig();
        await apiConfig.setBaseUrl('http://servidor-configurado.com/api');

        final estaciones =
            construir('/estaciones', apiConfig: apiConfig) as EstacionesScreen;
        expect(estaciones.client?.baseUrl, apiConfig.baseUrl);

        final vistaTotal =
            construir('/vista_total', apiConfig: apiConfig)
                as VistaTotalScreen;
        expect(vistaTotal.client?.baseUrl, apiConfig.baseUrl);

        final nosotros =
            construir('/nosotros', apiConfig: apiConfig) as NosotrosScreen;
        expect(nosotros.client?.baseUrl, apiConfig.baseUrl);
        expect(nosotros.apiConfig, same(apiConfig));

        final detalle =
            construir('/estacion/X', apiConfig: apiConfig)
                as EstacionDetalleScreen;
        expect(detalle.client?.baseUrl, apiConfig.baseUrl);
      },
    );
  });

  testWidgets('la app arranca mostrando Presentación (Home)', (
    tester,
  ) async {
    await tester.pumpWidget(FwiLaninApp(apiConfig: ApiConfig()));
    await tester.pump();

    expect(find.byType(PresentacionScreen), findsOneWidget);
  });
}

class _ContextoFalso implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('BuildContext no usado por estas pantallas');
}
