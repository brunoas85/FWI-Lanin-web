import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tokens genuinamente globales, independientes de cada pantalla:
/// colores de marca, fondo, error y texto por defecto.
///
/// El estilo de cada `AppBar` NO se fija acá: en el original varía por
/// pantalla — la mayoría usa fondo verde con texto blanco, pero el
/// Detalle de estación usa fondo blanco con texto negro y sin centrar
/// (ver B1). Cada pantalla lo define en C4–C9 contra su spec exacta;
/// bakear un único default acá sería adivinar para la mitad de los casos.
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.surface,
    ),
    dividerColor: AppColors.border,
    textTheme: Typography.blackMountainView.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
  );
}
