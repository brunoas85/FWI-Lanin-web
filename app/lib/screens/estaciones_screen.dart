import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/async_data.dart';
import '../data/fwi_repository.dart';
import '../data/models/estacion.dart';
import '../data/parsing.dart' show estaDesactualizada;
import '../theme/app_breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/font_scale.dart';
import '../widgets/ancho_maximo.dart';
import '../widgets/error_pantalla_completa.dart';
import '../widgets/visor_imagen_pantalla_completa.dart';

/// Pantalla Estaciones — `/estaciones`. Spec exacta en
/// docs/B1_PARIDAD_UI.md §2.
///
/// **Apartamiento de paridad acordado:** el original, si a una estación le
/// falta fecha u hora, NO la marca como desactualizada (se salta el
/// chequeo entero — solo marca desactualizado si hay fecha/hora pero el
/// parseo falla). Se decidió corregir esto: sin dato también cuenta como
/// desactualizado, ya que no se puede verificar la antigüedad. Ver
/// [estaDesactualizada].
///
/// **Apartamiento pedido al revisar C12:** el botón del mapa ya no
/// descarga el archivo (ni con el `FilePicker` del original ni abriendo
/// el navegador externo, como se hacía hasta C12) — abre
/// [VisorImagenPantallaCompleta], que lo muestra dentro de la app con
/// zoom y desplazamiento.
///
/// **Adaptación a escritorio (Épica F, web):** la lista vertical de una
/// sola columna, pensada para un celular, deja huecos enormes a los
/// costados en un monitor. En escritorio (`context.isDesktop`) las
/// tarjetas pasan a una grilla ([_GrillaEstaciones]) en vez de la lista
/// con divisores ([_ListaEstaciones]); por debajo del punto de corte se
/// arma exactamente la misma lista de siempre.
class EstacionesScreen extends StatefulWidget {
  const EstacionesScreen({super.key, this.client, this.imagenMapa});

  /// Inyectable para tests — ver test/screens/estaciones_screen_test.dart.
  /// En la app real se omite y se usa el cliente por defecto.
  final FwiApiClient? client;

  /// Inyectable para tests: evita que "Ver mapa de estaciones" dispare una
  /// llamada de red real al abrir [VisorImagenPantallaCompleta]. En la app
  /// real se omite y esa pantalla usa `NetworkImage(mapaUrl)`.
  final ImageProvider? imagenMapa;

  @override
  State<EstacionesScreen> createState() => _EstacionesScreenState();
}

class _EstacionesScreenState extends State<EstacionesScreen> {
  late final _client = widget.client ?? FwiApiClient();
  late final _repository = FwiRepository(_client);
  late final AsyncData<List<Estacion>> _estaciones;

  @override
  void initState() {
    super.initState();
    _estaciones = AsyncData(_repository.fetchEstaciones)
      ..addListener(_onStateChanged);
  }

  void _onStateChanged() => setState(() {});

  @override
  void dispose() {
    _estaciones.removeListener(_onStateChanged);
    _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estaciones'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _FondoSutil()),
          Positioned.fill(
            child: _Cuerpo(
              estado: _estaciones.state,
              onReintentar: _estaciones.load,
              mapaUrl: '${_client.baseUrl}/mapa_estaciones',
              imagenMapa: widget.imagenMapa,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo apenas insinuado (misma foto de la portada, `background1.png`,
/// muy desenfocada y a baja opacidad) para que esta pantalla no se sienta
/// una isla en blanco liso, aislada del resto de la app. A propósito
/// mucho más tenue que en la portada — acá el contenido son datos que
/// hay que poder leer rápido, no una imagen de presentación.
class _FondoSutil extends StatelessWidget {
  const _FondoSutil();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.08,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: const Image(
          image: AssetImage('assets/images/background1.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.estado,
    required this.onReintentar,
    required this.mapaUrl,
    this.imagenMapa,
  });

  final DataState<List<Estacion>> estado;
  final Future<void> Function() onReintentar;
  final String mapaUrl;
  final ImageProvider? imagenMapa;

  @override
  Widget build(BuildContext context) {
    final estaciones = switch (estado) {
      DataSuccess<List<Estacion>>(:final data) => data,
      DataError<List<Estacion>>(:final staleData) => staleData,
      DataLoading<List<Estacion>>(:final staleData) => staleData,
    };

    if (estaciones == null) {
      if (estado is DataError<List<Estacion>>) {
        return ErrorPantallaCompleta(
          mensaje: 'No se pudo conectar con el servidor.',
          onReintentar: onReintentar,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onReintentar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(kDefaultPadding),
        child: AnchoMaximo(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              context.isDesktop
                  ? _GrillaEstaciones(estaciones: estaciones)
                  : _ListaEstaciones(estaciones: estaciones),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VisorImagenPantallaCompleta(
                      url: mapaUrl,
                      titulo: 'Mapa de estaciones',
                      imagen: imagenMapa,
                    ),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Icon(Icons.map_outlined, color: AppColors.primary),
                    Text(
                      'Ver mapa de estaciones',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista vertical de una columna con divisores — la de siempre, sin cambios.
class _ListaEstaciones extends StatelessWidget {
  const _ListaEstaciones({required this.estaciones});

  final List<Estacion> estaciones;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < estaciones.length; i++) ...[
          _TarjetaEstacion(estacion: estaciones[i]),
          if (i < estaciones.length - 1)
            const Divider(height: 1, thickness: 1, color: AppColors.border),
        ],
      ],
    );
  }
}

/// Grilla para escritorio (Épica F): tarjetas de ancho fijo en un [Wrap],
/// que acomoda solo tantas columnas como entren en el ancho disponible
/// (2 o 3, según la ventana) — sin `GridView`, para no pelear con el
/// `SingleChildScrollView` que ya envuelve toda la pantalla.
class _GrillaEstaciones extends StatelessWidget {
  const _GrillaEstaciones({required this.estaciones});

  final List<Estacion> estaciones;

  static const _anchoTarjeta = 320.0;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 28,
      runSpacing: 28,
      children: [
        for (final estacion in estaciones)
          SizedBox(
            width: _anchoTarjeta,
            child: _TarjetaEstacion(estacion: estacion),
          ),
      ],
    );
  }
}

class _TarjetaEstacion extends StatelessWidget {
  const _TarjetaEstacion({required this.estacion});

  final Estacion estacion;

  @override
  Widget build(BuildContext context) {
    final desactualizada = estaDesactualizada(estacion.actualizadoEn);
    final huboLluvia = (estacion.ppt ?? 0) > 0;
    final estadoTexto = estacion.estadoFwi.isEmpty
        ? 'SIN DATO'
        : estacion.estadoFwi;
    final nivel = fwiLevelFromEstado(estadoTexto);
    final fwiValor = estacion.fwi ?? 0.0;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(16)),
          elevation: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed) ? 1 : 2,
          ),
        ),
        onPressed: () =>
            Navigator.pushNamed(context, '/estacion/${estacion.id}'),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 44,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: nivel.color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      Flexible(
                        child: Text(
                          estacion.nombre,
                          style: TextStyle(
                            fontSize: context.scaled(18),
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (desactualizada)
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error,
                          size: context.scaled(18),
                        ),
                      if (huboLluvia)
                        Tooltip(
                          message: 'Llovió en las últimas horas',
                          child: Icon(
                            Icons.water_drop,
                            color: WeatherMetric.lluvia.color,
                            size: context.scaled(18),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    textoActualizacion(estacion),
                    style: TextStyle(
                      fontSize: context.scaled(10),
                      fontStyle: FontStyle.italic,
                      color: desactualizada
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: nivel.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    estadoTexto,
                    style: TextStyle(
                      fontSize: context.scaled(12),
                      fontWeight: FontWeight.bold,
                      color: nivel.textColor,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    fwiValor.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: context.scaled(16),
                      fontWeight: FontWeight.bold,
                      color: nivel.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Formateo, pública y testeada por separado — ver test/screens/ ────
// `estaDesactualizada` vive en data/parsing.dart: la necesitan tanto
// Estacion como EstacionDetalle (C6), dos modelos distintos que exponen
// el mismo actualizadoEn — no tiene sentido atarla a un solo modelo.

/// `AAAAMMDD` -> `DD/MM/AA`. Si no matchea ese formato exacto, devuelve
/// el string tal cual llegó (incluso vacío) — mismo fallback que el
/// original.
String formatearFechaCorta(String fecha) {
  if (fecha.length == 8 && RegExp(r'^\d{8}$').hasMatch(fecha)) {
    return '${fecha.substring(6, 8)}/${fecha.substring(4, 6)}/${fecha.substring(2, 4)}';
  }
  return fecha;
}

/// Réplica literal de `'Act.' + ' - '.join(partes)` del original — sin
/// espacio después de "Act.". "Sin datos" si no hay ni fecha ni hora.
String textoActualizacion(Estacion estacion) {
  final fechaFmt = formatearFechaCorta(estacion.fecha ?? '');
  final hora = estacion.hora ?? '';
  final partes = [if (fechaFmt.isNotEmpty) fechaFmt, if (hora.isNotEmpty) hora];
  if (partes.isEmpty) return 'Sin datos';
  return 'Act.${partes.join(' - ')}';
}
