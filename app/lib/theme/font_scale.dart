import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Escala de fuente global, equivalente a `config.FONT_SCALE` del original.
///
/// Rango y paso idénticos al original: 0.7–1.4 en pasos de 0.1, persistida
/// bajo la misma semántica que `client_storage["font_scale"]` (acá, vía
/// [SharedPreferences] — el original usa el almacenamiento local de Flet).
///
/// Deliberadamente NO se aplica con un `MediaQuery.textScaler` global: en
/// el original, los títulos de AppBar y la tabla de Vista Total tienen
/// tamaño fijo y no escalan (verificado contra el código, no documentado
/// en config.py). Un escalado global cambiaría ese comportamiento. En
/// cambio, cada pantalla multiplica explícitamente con [BuildContext.scaled]
/// solo donde el original lo hacía — la misma granularidad por widget.
class FontScale extends ChangeNotifier {
  FontScale();

  static const _prefsKey = 'font_scale';
  static const min = 0.7;
  static const max = 1.4;
  static const step = 0.1;

  double _value = 1.0;
  double get value => _value;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsKey);
    if (saved != null && saved >= min && saved <= max) {
      _value = saved;
      notifyListeners();
    }
  }

  Future<void> increase() => _setValue(_value + step);
  Future<void> decrease() => _setValue(_value - step);

  Future<void> _setValue(double next) async {
    // round evita arrastrar errores de punto flotante (0.1 + 0.1 + ... );
    // el original hace lo mismo con round(config.FONT_SCALE, 1).
    final clamped = double.parse(next.clamp(min, max).toStringAsFixed(1));
    if (clamped == _value) return;
    _value = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, _value);
  }
}

/// Expone el [FontScale] vigente a todo el árbol de widgets debajo de él,
/// y reconstruye a quien lo consulte con [FontScaleScope.of] cuando cambia.
class FontScaleScope extends InheritedNotifier<FontScale> {
  const FontScaleScope({
    super.key,
    required FontScale super.notifier,
    required super.child,
  });

  static FontScale of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FontScaleScope>();
    assert(scope != null, 'FontScaleScope no está presente en el árbol.');
    return scope!.notifier!;
  }
}

extension ScaledFont on BuildContext {
  /// Equivalente directo a `size * config.FONT_SCALE` del original.
  /// Usar solo en los mismos Text que el original escalaba — ver la nota
  /// de clase en [FontScale].
  double scaled(double size) => size * FontScaleScope.of(this).value;
}
