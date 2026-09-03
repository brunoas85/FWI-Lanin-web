import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/font_scale.dart';
import '../widgets/ancho_maximo.dart';

/// Pantalla Presentación (Home) — `/`. Spec exacta en docs/B1_PARIDAD_UI.md
/// §1. Sin AppBar. El fondo visual es la imagen `briga.png` (el
/// brigadista) detrás del contenido, semitransparente (opacity 0.45)
/// sobre un fondo **blanco** — igual que el original, que fuerza
/// `page.bgcolor = "#FFFFFF"` en `main.py` (la `View` en sí no fija su
/// propio bgcolor, así que el blanco de la Page es lo que se termina
/// viendo detrás).
///
/// **Ajuste pedido tras el deploy web:** `BoxFit.cover` (imagen a pantalla
/// completa) recortaba demasiado al brigadista en pantallas anchas — se
/// pasa a `BoxFit.contain` para mostrarla completa. Eso solo, con el
/// blanco de fondo asomando a los costados en ventanas panorámicas, no
/// convenció: se agrega detrás una segunda imagen, `background1.png` (un
/// incendio forestal en las sierras), a pantalla completa y desenfocada
/// (`BoxFit.cover` + blur), así los costados quedan cubiertos por esa
/// foto en vez de blanco liso.
///
/// Bug propio corregido al revisar C12: acá se había puesto
/// `Scaffold(backgroundColor: Colors.transparent)`, que en vez de dejar
/// ver el blanco del tema (`AppColors.background`, ya seteado en
/// `buildAppTheme()`) revelaba el canvas negro por defecto de Flutter
/// detrás de todo — la imagen semitransparente quedaba mucho más oscura
/// que en el original. Sacar ese override alcanza para que el `Scaffold`
/// vuelva a heredar el blanco del tema.
///
/// El título duplicado `texto1` (size 26) del original nunca se renderiza
/// — B1 lo marca como código muerto. No se porta: no tiene efecto visual
/// observable, y copiarlo agregaría código muerto a propósito.
///
/// **Apartamientos pedidos al revisar C12 en un dispositivo real** (el
/// original usaba estos valores tal cual, documentados en B1 §1):
/// - Logos 20% más grandes (90/120/90 → 108/144/108), misma proporción.
/// - Se saca el logo de BIT (el botón "Acerca de esta app" queda solo).
/// - Botones principales sin ancho fijo (140px original hacía que "Vista
///   Rápida" cayera en dos líneas en un dispositivo real) — ver
///   [_BotonPrincipal].
/// - "Acerca de esta app" pasa a la misma fila que A-/A+, en el margen
///   izquierdo.
///
/// **Adaptación a escritorio (Épica F, web):** sin límite de ancho, la fila
/// de logos (`_FilaLogos`, con `Expanded`) se estira hasta el borde de un
/// monitor entero y los 3 logos terminan con huecos enormes entre sí — se
/// verificó con una captura real antes de decidir el arreglo. [AnchoMaximo]
/// limita el contenido a 640px de ancho en escritorio (`context.isDesktop`)
/// y no hace nada por debajo de ese punto de corte: la app móvil no cambia.
class PresentacionScreen extends StatelessWidget {
  const PresentacionScreen({super.key});

  static const _colorTitulo = Color(0xFF546E07); // no está en AppColors
  static const _colorOverlayPrimario = Color(0xFF0D47A1);
  static const _colorOverlayAcercaDe = Color(0xFF383D46);
  static const _colorIconoEstaciones = Color(0xFFE81D1D);
  static const _colorIconoVistaRapida = Color(0xFF9F9D9C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.45,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: const Image(
                  image: AssetImage('assets/images/background1.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: Opacity(
              opacity: 0.45,
              child: Image(
                image: AssetImage('assets/images/briga.png'),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: SingleChildScrollView(
                child: AnchoMaximo(
                  maxWidth: 640,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 24,
                    children: [
                      _FilaLogos(),
                      Text(
                        'Índice de Peligrosidad de Incendios Forestales',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: context.scaled(28),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Anta',
                          color: _colorTitulo,
                        ),
                      ),
                      // Separador explícito de 60px — se SUMA al spacing:24
                      // del Column (24 antes + 60 acá + 24 después = 108px
                      // de hueco real entre título y botones, igual que en
                      // el original: ft.Column(spacing=24) inserta ese
                      // spacing entre TODOS los hijos, incluidos los
                      // contenedores vacíos usados como separador).
                      const SizedBox(height: 60),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _BotonPrincipal(
                            texto: 'Estaciones',
                            icono: Icons.location_on,
                            colorIcono: _colorIconoEstaciones,
                            onPressed: () =>
                                Navigator.pushNamed(context, '/estaciones'),
                          ),
                          _BotonPrincipal(
                            texto: 'Vista Rápida',
                            icono: Icons.table_chart,
                            colorIcono: _colorIconoVistaRapida,
                            onPressed: () =>
                                Navigator.pushNamed(context, '/vista_total'),
                          ),
                        ],
                      ),
                      // Ídem arriba: separador de 50px + spacing:24 a cada lado.
                      const SizedBox(height: 50),
                      // "Acerca de esta app" (izquierda) y A-/A+ (derecha) en
                      // una sola fila — el logo de BIT que acompañaba al
                      // primero se sacó a pedido.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            style: ButtonStyle(
                              backgroundColor: const WidgetStatePropertyAll(
                                Colors.black,
                              ),
                              foregroundColor: const WidgetStatePropertyAll(
                                Colors.white,
                              ),
                              minimumSize: const WidgetStatePropertyAll(
                                Size(0, 36),
                              ),
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(horizontal: 14),
                              ),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              overlayColor: WidgetStatePropertyAll(
                                _colorOverlayAcercaDe.withValues(alpha: 0.4),
                              ),
                              elevation: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.pressed)
                                    ? 0
                                    : 3,
                              ),
                            ),
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: Text(
                              'Acerca de esta app',
                              maxLines: 1,
                              style: TextStyle(fontSize: context.scaled(12)),
                            ),
                            onPressed: () =>
                                Navigator.pushNamed(context, '/nosotros'),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 6,
                            children: [
                              _BotonFuente(
                                texto: 'A-',
                                onPressed: () =>
                                    FontScaleScope.of(context).decrease(),
                              ),
                              _BotonFuente(
                                texto: 'A+',
                                onPressed: () =>
                                    FontScaleScope.of(context).increase(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _abrirUrl(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Fila de los 3 logos superiores. La proporción 1 : 1.33 : 1 del original
/// (`expand=1` / `expand=1.33` / `expand=1`) se replica con flex enteros
/// escalados ×100 — Flutter no acepta flex fraccionario, pero la
/// proporción resultante es idéntica.
///
/// Alturas 20% más grandes que el original (90/120/90 → 108/144/108) —
/// apartamiento pedido al revisar C12 en un dispositivo real; se
/// mantiene la misma proporción entre el logo central y los laterales.
class _FilaLogos extends StatelessWidget {
  const _FilaLogos();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          Expanded(
            flex: 100,
            child: SizedBox(
              height: 108,
              child: Image(
                image: const AssetImage('assets/images/mf_logo1.png'),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Expanded(
            flex: 133,
            child: SizedBox(
              height: 144,
              child: GestureDetector(
                onTap: () => _abrirUrl('https://www.pnlanin.com.ar/'),
                child: const Image(
                  image: AssetImage('assets/images/logo_pnl1.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 100,
            child: SizedBox(
              height: 108,
              child: GestureDetector(
                onTap: () => _abrirUrl('https://www.smn.gob.ar/'),
                child: const Image(
                  image: AssetImage('assets/images/logo.smn1.png'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón "Estaciones" / "Vista Rápida" — mismo estilo que
/// `button_style_primary` en el original (fondo primario, radio 8,
/// elevación 3 al presionar 1, overlay azul al 40%), altura 44 igual.
///
/// **Sin ancho fijo** (el original usa 140px): en un dispositivo real
/// "Vista Rápida" caía en dos líneas a ese ancho. `minimumSize` garantiza
/// al menos 140px (lo que ya le alcanza a "Estaciones"), pero el botón
/// puede crecer más si el contenido lo necesita — así el texto entra
/// en una línea sin importar el idioma, el largo de la etiqueta, o la
/// escala de fuente elegida (0.7×–1.4×).
class _BotonPrincipal extends StatelessWidget {
  const _BotonPrincipal({
    required this.texto,
    required this.icono,
    required this.colorIcono,
    required this.onPressed,
  });

  final String texto;
  final IconData icono;
  final Color colorIcono;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(AppColors.primary),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        minimumSize: const WidgetStatePropertyAll(Size(140, 44)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        overlayColor: WidgetStatePropertyAll(
          PresentacionScreen._colorOverlayPrimario.withValues(alpha: 0.4),
        ),
        elevation: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed) ? 1 : 3,
        ),
      ),
      icon: Icon(icono, color: colorIcono, size: 20),
      label: Text(texto, style: TextStyle(fontSize: context.scaled(14))),
      onPressed: onPressed,
    );
  }
}

/// Botón "A-" / "A+". El original no escala su propio texto con
/// FONT_SCALE (`font_button_style` no define `text_style`) — a propósito
/// no se usa `context.scaled` acá, igual que las excepciones de AppBar y
/// la tabla de Vista total documentadas en C2.
class _BotonFuente extends StatelessWidget {
  const _BotonFuente({required this.texto, required this.onPressed});

  final String texto;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 28,
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll(Colors.black),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? 0 : 2,
          ),
        ),
        onPressed: onPressed,
        child: Text(texto),
      ),
    );
  }
}
