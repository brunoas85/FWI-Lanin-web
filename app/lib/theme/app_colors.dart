import 'package:flutter/material.dart';

/// Paleta de la app, portada literal de `COLORS` en config.py del original.
///
/// Varios tokens no tienen ningún consumidor hoy (documentado en B1):
/// [secondary], [warning], [info] y [stationRow] no se usan en ninguna
/// pantalla alcanzable; [accent] solo aparece en la pantalla de
/// Configuración, que `main.py` no navega desde ningún botón. Se portan
/// igual, completos, para que este archivo sea un espejo 1:1 de la fuente
/// y no una selección editorializada.
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF2E7D32);
  static const secondary = Color(0xFF4CAF50);
  static const accent = Color(0xFFFF9101);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const error = Color(0xFFF44336);
  static const success = Color(0xFF4CAF50);
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const border = Color(0xFFE0E0E0);
  static const warning = Color(0xFFFFEB3B);
  static const info = Color(0xFF095592);
  static const stationRow = Color(0xFFBCECB2);
}

/// Estados del índice FWI, portados de `FWI_COLORS` en config.py.
///
/// El orden importa para [ORDEN_DESEADO]-adyacentes en C3, pero acá solo
/// determina el orden de declaración, no tiene efecto propio.
enum FwiLevel { bajo, moderado, alto, muyAlto, extremo, desconocido }

extension FwiLevelColors on FwiLevel {
  /// Color de fondo del estado, según el gráfico oficial de FWI.
  Color get color => switch (this) {
    FwiLevel.bajo => const Color(0xFF00B054),
    FwiLevel.moderado => const Color(0xFF0071C2),
    FwiLevel.alto => const Color(0xFFFFFF01),
    FwiLevel.muyAlto => const Color(0xFFFEB900),
    FwiLevel.extremo => const Color(0xFFFD0002),
    FwiLevel.desconocido => const Color(0xFF757575),
  };

  /// Color del texto sobre [color]. Todos son blancos salvo ALTO: el
  /// amarillo puro (#FFFF01) del oficial no da contraste suficiente con
  /// blanco, así que ese caso usa [AppColors.textPrimary] — excepción ya
  /// presente en el original, documentada en B1.
  Color get textColor =>
      this == FwiLevel.alto ? AppColors.textPrimary : Colors.white;

  /// Etiqueta tal como la muestra la app (mayúsculas, con espacio en
  /// "MUY ALTO"), para no reconstruirla a mano en cada pantalla.
  String get label => switch (this) {
    FwiLevel.bajo => 'BAJO',
    FwiLevel.moderado => 'MODERADO',
    FwiLevel.alto => 'ALTO',
    FwiLevel.muyAlto => 'MUY ALTO',
    FwiLevel.extremo => 'EXTREMO',
    FwiLevel.desconocido => 'DESCONOCIDO',
  };
}

/// Interpreta el texto crudo de `estado_fwi` que manda el API (ya
/// normalizado a mayúsculas por los modelos de C3) como un [FwiLevel].
/// Cualquier valor que no matchee exactamente uno de los 5 estados reales
/// cae en [FwiLevel.desconocido] — mismo fallback que
/// `FWI_COLORS.get(x, FWI_COLORS['DESCONOCIDO'])` en el original.
///
/// Usado por Estaciones (C5) y reutilizable tal cual por Detalle (C6) y
/// Vista total (C7), que necesitan el mismo mapeo.
FwiLevel fwiLevelFromEstado(String estado) => switch (estado) {
  'BAJO' => FwiLevel.bajo,
  'MODERADO' => FwiLevel.moderado,
  'ALTO' => FwiLevel.alto,
  'MUY ALTO' => FwiLevel.muyAlto,
  'EXTREMO' => FwiLevel.extremo,
  _ => FwiLevel.desconocido,
};

/// Colores de las cajas meteorológicas, portados de `WEATHER_COLORS`.
///
/// Solo [lluvia] tiene un uso real hoy (ícono de gota en Estaciones). Las
/// otras tres cajas del Detalle de estación (temperatura, humedad, viento)
/// usan las seis **el mismo** [temperatura] — hallazgo de B1: la intención
/// original era diferenciarlas y el código no lo hace. Para la paridad,
/// las seis cajas van de este mismo color; diferenciarlas sería una
/// mejora, no una migración.
enum WeatherMetric { temperatura, humedad, viento, lluvia }

extension WeatherMetricColors on WeatherMetric {
  Color get color => switch (this) {
    WeatherMetric.temperatura => const Color(0xFF607D8B),
    WeatherMetric.humedad => const Color(0xFF00BCD4),
    WeatherMetric.viento => const Color(0xFF795548),
    WeatherMetric.lluvia => const Color(0xFF3F51B5),
  };
}
