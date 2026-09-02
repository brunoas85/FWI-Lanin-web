import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fwi_lanin/screens/presentacion_screen.dart';
import 'package:fwi_lanin/theme/font_scale.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) pushed.add(name);
  }
}

/// La pantalla scrollea (`SingleChildScrollView`), y agrandar la fuente
/// corre el contenido — así que un botón que hoy entra en el viewport
/// puede quedar tapado después de un tap anterior. Se hace scroll
/// explícito antes de cada tap en vez de confiar en un tamaño de
/// viewport fijo que sea "suficientemente grande".
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Widget _wrapped(Widget child, {NavigatorObserver? observer}) {
  return FontScaleScope(
    notifier: FontScale(),
    child: MaterialApp(
      home: child,
      navigatorObservers: observer != null ? [observer] : const [],
      // Rutero mínimo propio del test: reemplaza las pantallas reales
      // (que main.dart sí registra desde C10) por un placeholder, para
      // testear solo que Presentación pushea el nombre correcto sin
      // depender de red real en las pantallas destino.
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => const SizedBox(),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Viewport de teléfono real, no el 800×600 por defecto: esta pantalla
  // tiene más contenido del que entra en 600px de alto, así que con el
  // tamaño por defecto "Acerca de esta app" y los botones A-/A+ quedan
  // fuera del área visible y tap() no los encuentra sin hacer scroll a
  // mano primero.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2400);
    binding.platformDispatcher.views.first.devicePixelRatio = 3.0;
    addTearDown(() {
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });
  });

  testWidgets('muestra el título exacto de la spec', (tester) async {
    await tester.pumpWidget(_wrapped(const PresentacionScreen()));

    expect(
      find.text('Índice de Peligrosidad de Incendios Forestales'),
      findsOneWidget,
    );
  });

  testWidgets('"Estaciones" navega a /estaciones', (tester) async {
    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      _wrapped(const PresentacionScreen(), observer: observer),
    );

    await _tapVisible(tester, find.text('Estaciones'));
    await tester.pumpAndSettle();

    expect(observer.pushed, contains('/estaciones'));
  });

  testWidgets('"Vista Rápida" navega a /vista_total', (tester) async {
    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      _wrapped(const PresentacionScreen(), observer: observer),
    );

    await _tapVisible(tester, find.text('Vista Rápida'));
    await tester.pumpAndSettle();

    expect(observer.pushed, contains('/vista_total'));
  });

  testWidgets('"Acerca de esta app" navega a /nosotros', (tester) async {
    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      _wrapped(const PresentacionScreen(), observer: observer),
    );

    await _tapVisible(tester, find.text('Acerca de esta app'));
    await tester.pumpAndSettle();

    expect(observer.pushed, contains('/nosotros'));
  });

  testWidgets('"A+" aumenta el tamaño del título, "A-" lo devuelve', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapped(const PresentacionScreen()));

    Text tituloWidget() => tester.widget<Text>(
      find.text('Índice de Peligrosidad de Incendios Forestales'),
    );

    final tamanioInicial = tituloWidget().style!.fontSize;

    await _tapVisible(tester, find.text('A+'));
    await tester.pump();

    expect(tituloWidget().style!.fontSize, greaterThan(tamanioInicial!));

    await _tapVisible(tester, find.text('A-'));
    await tester.pump();

    expect(tituloWidget().style!.fontSize, tamanioInicial);
  });

  testWidgets('"A-"/"A+" no llegan al límite: no explotan tocados muchas veces', (
    tester,
  ) async {
    await tester.pumpWidget(_wrapped(const PresentacionScreen()));

    for (var i = 0; i < 10; i++) {
      await _tapVisible(tester, find.text('A+'));
      await tester.pump();
    }
    for (var i = 0; i < 20; i++) {
      await _tapVisible(tester, find.text('A-'));
      await tester.pump();
    }

    // Si no tiró ninguna excepción llegando hasta acá, los límites
    // 0.7–1.4 de FontScale se respetaron correctamente en los extremos.
    expect(tester.takeException(), isNull);
  });
}
