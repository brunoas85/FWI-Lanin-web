import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Pantalla de error a ancho completo con botón de reintentar — se usa
/// cuando una carga falla y no hay ningún dato previo para mostrar en su
/// lugar. Compartida entre pantallas (Estaciones, Detalle de estación):
/// el primer patrón que se repitió idéntico en dos pantallas reales, así
/// que se extrajo acá en vez de duplicarlo por tercera vez.
class ErrorPantallaCompleta extends StatelessWidget {
  const ErrorPantallaCompleta({
    super.key,
    required this.mensaje,
    required this.onReintentar,
  });

  final String mensaje;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 48,
              color: AppColors.textSecondary,
            ),
            Text(mensaje, textAlign: TextAlign.center),
            ElevatedButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
