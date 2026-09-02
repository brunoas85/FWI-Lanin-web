import 'package:flutter/widgets.dart';

/// Punto de corte para la adaptación a escritorio de la versión web
/// (Épica F). Por debajo, cada pantalla renderiza el mismo árbol de
/// widgets que la app móvil — cero cambios de layout. Por encima, las
/// pantallas que lo necesitan ganan una variante propia (ver
/// `context.isDesktop` y [AnchoMaximo]).
///
/// 900px es el punto donde un teléfono en horizontal grande todavía cae
/// del lado "mobile" y una tablet/notebook chica ya cae del lado
/// "desktop" — no corresponde a ningún valor de Material, es una
/// elección simple para este proyecto.
const double kDesktopBreakpoint = 900;

extension BreakpointContext on BuildContext {
  bool get isDesktop => MediaQuery.sizeOf(this).width >= kDesktopBreakpoint;
}
