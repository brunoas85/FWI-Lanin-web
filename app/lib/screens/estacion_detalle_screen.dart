import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/async_data.dart';
import '../data/fwi_repository.dart';
import '../data/models/estacion_detalle.dart';
import '../data/parsing.dart' show estaDesactualizada;
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/font_scale.dart';
import '../widgets/ancho_maximo.dart';
import '../widgets/error_pantalla_completa.dart';

/// Pantalla Detalle de estación — `/estacion/<id>`. Spec exacta en
/// docs/B1_PARIDAD_UI.md §3.
///
/// **Adaptación a escritorio (Épica F, web):** las cajas meteorológicas y
/// de índices FWI son `Expanded` dentro de `Row`s de a pares — sin límite
/// de ancho quedarían enormes y desproporcionadas en un monitor.
/// [AnchoMaximo] centra el contenido a 700px en escritorio, sin tocar el
/// layout de a pares (queda para una vuelta futura si hace falta más).
///
/// **Apartamiento ya pre-aprobado en B1:** ante un error de red, el
/// original muestra `data = {}` con todo en "0.0" y fecha
/// `25/08/2025` (el default hardcodeado `'20250825'`), sin ningún
/// indicio de error. B1 lo marca explícitamente como punto donde no
/// conviene mantener paridad. Acá se usa el mismo mecanismo de
/// carga/éxito/error con reintento que las demás pantallas (C3/C5), en
/// vez de mostrar ceros silenciosos.
///
/// El chequeo de "desactualizado" del original ya parsea fecha/hora sin
/// la guarda que causaba el apartamiento de C5 — cualquier fallo
/// (incluida fecha/hora vacía) cae directo a DESACTUALIZADO. Coincide
/// exactamente con [estaDesactualizada] (`data/parsing.dart`, compartida
/// con Estaciones): se reutiliza tal cual, sin apartamiento nuevo que
/// acordar acá.
class EstacionDetalleScreen extends StatefulWidget {
  const EstacionDetalleScreen({
    super.key,
    required this.estacionId,
    this.client,
  });

  final String estacionId;

  /// Inyectable para tests.
  final FwiApiClient? client;

  @override
  State<EstacionDetalleScreen> createState() => _EstacionDetalleScreenState();
}

class _EstacionDetalleScreenState extends State<EstacionDetalleScreen> {
  late final _client = widget.client ?? FwiApiClient();
  late final _repository = FwiRepository(_client);
  late final AsyncData<EstacionDetalle> _estacion;

  @override
  void initState() {
    super.initState();
    _estacion = AsyncData(
      () => _repository.fetchEstacionDetalle(widget.estacionId),
    )..addListener(_onStateChanged);
  }

  void _onStateChanged() => setState(() {});

  @override
  void dispose() {
    _estacion.removeListener(_onStateChanged);
    _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estacion.state;
    final detalle = switch (estado) {
      DataSuccess<EstacionDetalle>(:final data) => data,
      DataError<EstacionDetalle>(:final staleData) => staleData,
      DataLoading<EstacionDetalle>(:final staleData) => staleData,
    };

    if (detalle == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: estado is DataError<EstacionDetalle>
            ? ErrorPantallaCompleta(
                mensaje: 'No se pudo cargar la estación.',
                onReintentar: _estacion.load,
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final desactualizada = estaDesactualizada(detalle.actualizadoEn);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          detalle.nombre,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: context.scaled(20),
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              desactualizada ? 'DESACTUALIZADO' : 'ACTUALIZADO',
              style: TextStyle(
                fontSize: context.scaled(12),
                fontWeight: FontWeight.bold,
                color: desactualizada ? AppColors.error : AppColors.success,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _estacion.load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(kDefaultPadding),
          child: AnchoMaximo(
            maxWidth: 700,
            child: Column(
              spacing: 10,
              children: [
                Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: 15),
                  child: Text(
                    'Último registro: ${formatearFechaLarga(detalle.fecha ?? '')} - ${detalle.hora ?? ''}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: context.scaled(14),
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Image(
                    image: AssetImage(_imagenBui(detalle.estadoFwi)),
                    fit: BoxFit.fitWidth,
                    repeat: ImageRepeat.noRepeat,
                  ),
                ),
                _BarraIndiceFwi(detalle: detalle),
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: _CajaMeteorologica(
                        icono: Icons.device_thermostat,
                        valor: '${(detalle.temp ?? 0).toStringAsFixed(1)}°C',
                        valorSize: 18,
                        etiqueta: 'Temperatura',
                      ),
                    ),
                    Expanded(
                      child: _CajaMeteorologica(
                        icono: Icons.water_drop_outlined,
                        valor: '${(detalle.hr ?? 0).toStringAsFixed(0)}%',
                        valorSize: 18,
                        etiqueta: 'Humedad',
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: _CajaMeteorologica(
                        icono: Icons.air,
                        valor:
                            '${(detalle.ws ?? 0).toStringAsFixed(1)} km/h ${detalle.wd ?? 'N'}',
                        valorSize: 16,
                        etiqueta: 'Viento',
                      ),
                    ),
                    Expanded(
                      child: _CajaMeteorologica(
                        icono: Icons.air,
                        valor:
                            '${(detalle.w10 ?? 0).toStringAsFixed(1)} km/h ${detalle.wd ?? 'N'}',
                        valorSize: 16,
                        etiqueta: 'Viento (corrección a 10 metros)',
                        etiquetaSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: _CajaMeteorologica(
                        icono: Icons.water_drop,
                        valor: '${(detalle.ppt ?? 0).toStringAsFixed(1)} mm',
                        valorSize: 18,
                        etiqueta: 'Precipitación',
                      ),
                    ),
                    Expanded(
                      child: _CajaMeteorologica(
                        icono: Icons.opacity,
                        valor: '${(detalle.acum ?? 0).toStringAsFixed(1)} mm',
                        valorSize: 18,
                        etiqueta: 'Precip. acumuladas',
                      ),
                    ),
                  ],
                ),
                Text(
                  'Componentes FWI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: context.scaled(16),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: _CajaIndice(sigla: 'FFMC', valor: detalle.ffmc),
                    ),
                    Expanded(
                      child: _CajaIndice(sigla: 'DMC', valor: detalle.dmc),
                    ),
                    Expanded(
                      child: _CajaIndice(sigla: 'DC', valor: detalle.dc),
                    ),
                  ],
                ),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: _CajaIndice(sigla: 'ISI', valor: detalle.isi),
                    ),
                    Expanded(
                      child: _CajaIndice(sigla: 'BUI', valor: detalle.bui),
                    ),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _imagenBui(String estadoFwi) {
  const mapeo = {
    'BAJO': 'assets/images/BUI_Bajo.png',
    'MODERADO': 'assets/images/BUI_Moderado.png',
    'ALTO': 'assets/images/BUI_Alto.png',
    'MUY ALTO': 'assets/images/BUI_Muy_Alto.png',
    'EXTREMO': 'assets/images/BUI_Extremo.png',
  };
  return mapeo[estadoFwi] ?? 'assets/images/BUI_Bajo.png';
}

class _BarraIndiceFwi extends StatelessWidget {
  const _BarraIndiceFwi({required this.detalle});

  final EstacionDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final estadoTexto = detalle.estadoFwi.isEmpty
        ? 'DESCONOCIDO'
        : detalle.estadoFwi;
    final nivel = fwiLevelFromEstado(estadoTexto);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: nivel.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            'ÍNDICE FWI',
            style: TextStyle(
              fontSize: context.scaled(14),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            (detalle.fwi ?? 0).toStringAsFixed(1),
            style: TextStyle(
              fontSize: context.scaled(22),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            estadoTexto,
            style: TextStyle(
              fontSize: context.scaled(14),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una de las 6 cajas meteorológicas (Temperatura, Humedad, Viento, Viento
/// 10m, Precipitación, Acumulada) — mismo fondo/forma/tipografía en las 6,
/// según B1 §3.4.
class _CajaMeteorologica extends StatelessWidget {
  const _CajaMeteorologica({
    required this.icono,
    required this.valor,
    required this.valorSize,
    required this.etiqueta,
    this.etiquetaSize = 12,
  });

  final IconData icono;
  final String valor;
  final double valorSize;
  final String etiqueta;
  final double etiquetaSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WeatherMetric.temperatura.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: Colors.white, size: 24),
              const SizedBox(width: 4),
              Text(
                valor,
                style: TextStyle(
                  fontSize: context.scaled(valorSize),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.scaled(etiquetaSize),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una de las 5 cajas de índices FWI (FFMC, DMC, DC, ISI, BUI) — B1 §3.6.
class _CajaIndice extends StatelessWidget {
  const _CajaIndice({required this.sigla, required this.valor});

  final String sigla;
  final double? valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sigla,
            style: TextStyle(
              fontSize: context.scaled(12),
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            (valor ?? 0).toStringAsFixed(1),
            style: TextStyle(
              fontSize: context.scaled(16),
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// `AAAAMMDD` -> `DD/MM/AAAA` — año completo, a diferencia de la versión
/// corta que usa Estaciones ([formatearFechaCorta] en estaciones_screen.dart;
/// B1 marca explícitamente esta diferencia entre las dos pantallas).
String formatearFechaLarga(String fecha) {
  if (fecha.length == 8 && RegExp(r'^\d{8}$').hasMatch(fecha)) {
    return '${fecha.substring(6, 8)}/${fecha.substring(4, 6)}/${fecha.substring(0, 4)}';
  }
  return fecha;
}
