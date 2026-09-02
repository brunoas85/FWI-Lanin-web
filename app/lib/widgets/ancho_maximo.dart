import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';

/// Limita el ancho de [child] y lo centra, pero **solo en escritorio**
/// (`context.isDesktop`) — Épica F, adaptación a pantallas anchas.
///
/// Por debajo del punto de corte devuelve [child] tal cual, sin envolverlo
/// en nada: la app móvil y la web angosta comparten el árbol de widgets
/// exacto, así que no hay forma de que esto cambie un pixel ahí. Sin este
/// límite, contenido pensado para un celular (filas con `Expanded`,
/// tablas) se estira a lo ancho de un monitor entero y queda con huecos
/// enormes entre los elementos — el problema real que motivó esto.
class AnchoMaximo extends StatelessWidget {
  const AnchoMaximo({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.isDesktop) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
