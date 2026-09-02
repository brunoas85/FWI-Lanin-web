import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/async_data.dart';
import '../data/fwi_repository.dart';
import '../data/models/vista_total_row.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/font_scale.dart';
import '../widgets/ancho_maximo.dart';
import '../widgets/error_pantalla_completa.dart';

/// Pantalla Vista total (Vista Rápida) — `/vista_total`. Spec exacta en
/// docs/B1_PARIDAD_UI.md §4. Dos tablas (meteorológica y de índices FWI)
/// con la primera columna ("Estación") fija y el resto con scroll
/// horizontal — misma estructura que `build_table()` en `vista_total.py`.
///
/// **Adaptación a escritorio (Épica F, web):** sin límite de ancho, las
/// tablas quedan pegadas al borde izquierdo con un hueco enorme a la
/// derecha en un monitor — `DataTable` no se estira para llenar el
/// espacio disponible. [AnchoMaximo] centra el contenido a 1200px en
/// escritorio; por debajo del punto de corte no cambia nada.
class VistaTotalScreen extends StatefulWidget {
  const VistaTotalScreen({super.key, this.client});

  /// Inyectable para tests — ver test/screens/vista_total_screen_test.dart.
  final FwiApiClient? client;

  @override
  State<VistaTotalScreen> createState() => _VistaTotalScreenState();
}

class _VistaTotalScreenState extends State<VistaTotalScreen> {
  late final _client = widget.client ?? FwiApiClient();
  late final _repository = FwiRepository(_client);
  late final AsyncData<VistaTotalData> _vistaTotal;

  @override
  void initState() {
    super.initState();
    _vistaTotal = AsyncData(_repository.fetchVistaTotal)
      ..addListener(_onStateChanged);
  }

  void _onStateChanged() => setState(() {});

  @override
  void dispose() {
    _vistaTotal.removeListener(_onStateChanged);
    _repository.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista Rápida'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _Cuerpo(estado: _vistaTotal.state, onReintentar: _vistaTotal.load),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({required this.estado, required this.onReintentar});

  final DataState<VistaTotalData> estado;
  final Future<void> Function() onReintentar;

  @override
  Widget build(BuildContext context) {
    final vista = switch (estado) {
      DataSuccess<VistaTotalData>(:final data) => data,
      DataError<VistaTotalData>(:final staleData) => staleData,
      DataLoading<VistaTotalData>(:final staleData) => staleData,
    };

    if (vista == null) {
      if (estado is DataError<VistaTotalData>) {
        return ErrorPantallaCompleta(
          mensaje: 'No se pudo conectar con el servidor.',
          onReintentar: onReintentar,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    // Réplica literal de `f"Datos meteorológicos {fecha_reporte}"`: si no
    // hay fecha, queda un espacio de más al final del título — no es un
    // typo a corregir, es lo que muestra el original.
    final fechaFmt = vista.fechaReporte == null
        ? ''
        : formatearFechaReporte(vista.fechaReporte!);

    return RefreshIndicator(
      onRefresh: onReintentar,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(kDefaultPadding),
        child: AnchoMaximo(
          maxWidth: 1200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 30,
            children: [
              Text(
                'Datos meteorológicos $fechaFmt',
                style: TextStyle(
                  fontSize: context.scaled(20),
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              _TablaDatos(columnas: _columnasMeteo, filas: vista.filas),
              Text(
                'Índices FWI',
                style: TextStyle(
                  fontSize: context.scaled(20),
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              _TablaDatos(columnas: _columnasFwi, filas: vista.filas),
              const _Referencias(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tabla con primera columna fija + resto con scroll horizontal ─────

class _Columna {
  const _Columna(this.header, this.valorDe, {this.unidad = '', this.tooltip});

  final String header;
  final String Function(VistaTotalRow) valorDe;
  final String unidad;
  final String? tooltip;
}

class _TablaDatos extends StatelessWidget {
  const _TablaDatos({required this.columnas, required this.filas});

  final List<_Columna> columnas;
  final List<VistaTotalRow> filas;

  static const _alturaEncabezado = 56.0;
  static const _alturaFila = 48.0;

  @override
  Widget build(BuildContext context) {
    final fija = columnas.first;
    final resto = columnas.sublist(1);

    Widget celda(String texto, {bool encabezado = false}) => Container(
      height: encabezado ? _alturaEncabezado : _alturaFila,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        texto,
        style: TextStyle(
          fontWeight: encabezado ? FontWeight.bold : FontWeight.normal,
          color: encabezado ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                celda(fija.header, encabezado: true),
                for (final fila in filas) celda(fija.valorDe(fila)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll(
                  Color(0xFFEEEEEE),
                ),
                headingRowHeight: _alturaEncabezado,
                dataRowMinHeight: _alturaFila,
                dataRowMaxHeight: _alturaFila,
                columns: [
                  for (final c in resto)
                    DataColumn(
                      label: _EncabezadoColumna(
                        texto: c.header,
                        tooltip: c.tooltip,
                      ),
                    ),
                ],
                rows: [
                  for (final fila in filas)
                    DataRow(
                      cells: [
                        for (final c in resto)
                          DataCell(
                            Text(
                              _conUnidad(c.valorDe(fila), c.unidad),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EncabezadoColumna extends StatelessWidget {
  const _EncabezadoColumna({required this.texto, this.tooltip});

  final String texto;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      texto,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
    return tooltip == null ? label : Tooltip(message: tooltip, child: label);
  }
}

class _Referencias extends StatelessWidget {
  const _Referencias();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Text(
            'Referencias',
            style: TextStyle(
              fontSize: context.scaled(20),
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          for (final (sigla, descripcion) in referenciasFwi)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(
                  '$sigla:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: Text(
                    descripcion,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Datos de columnas y referencias — públicos y testeados aparte ────

/// Réplica literal de `referencias` en vista_total.py, incluidos los
/// espacios de más en la descripción de BUI (no es un typo del original
/// a corregir: docs/B1_PARIDAD_UI.md exige texto exacto).
const referenciasFwi = [
  (
    'FFMC',
    'FFMC < 75 → no habría ignición de combustibles finos (sin propagación).',
  ),
  ('DMC', 'DMC ≥ 20 → probabilidad de focos causados por rayos.'),
  (
    'DC',
    'DC = 15 → Combustible grueso saturado. DC ≥ 200 → difícil de controlar.',
  ),
  ('ISI', 'ISI ≥ 10 → rápida propagación, posible coronamiento en coníferas.'),
  (
    'BUI',
    'BUI < 30 → fuegos leves; > 60 →    combustibles medianos/gruesos ardiendo.',
  ),
  ('FWI', 'FWI > 3 → combustión sostenida y crecimiento del fuego.'),
];

final _tooltipsFwi = {for (final (s, d) in referenciasFwi) s: d};

String _fmtNum(num? v) => v == null ? 'S/D' : v.toString();

String _fmtStr(String? v) => (v == null || v.trim().isEmpty) ? 'S/D' : v;

/// Réplica de `if valor != "S/D" and unidad: valor = f"{valor} {unidad}"`.
String _conUnidad(String valor, String unidad) =>
    valor == 'S/D' || unidad.isEmpty ? valor : '$valor $unidad';

final _columnasMeteo = [
  _Columna('Estación', (f) => f.estacion),
  _Columna('Temp.', (f) => _fmtNum(f.temperatura), unidad: '°C'),
  _Columna('Hum.', (f) => _fmtNum(f.humedad), unidad: '%'),
  _Columna('Viento', (f) => _fmtNum(f.viento10m), unidad: 'km/h'),
  _Columna('Dir. Viento', (f) => _fmtStr(f.direccion)),
  _Columna('Lluvia 24 hs', (f) => _fmtNum(f.lluviaAyer), unidad: 'mm'),
  _Columna('Acum anual', (f) => _fmtNum(f.acumulado), unidad: 'mm'),
];

final _columnasFwi = [
  _Columna('Estación', (f) => f.estacion),
  _Columna('FFMC', (f) => _fmtNum(f.ffmc), tooltip: _tooltipsFwi['FFMC']),
  _Columna('DMC', (f) => _fmtNum(f.dmc), tooltip: _tooltipsFwi['DMC']),
  _Columna('DC', (f) => _fmtNum(f.dc), tooltip: _tooltipsFwi['DC']),
  _Columna('ISI', (f) => _fmtNum(f.isi), tooltip: _tooltipsFwi['ISI']),
  _Columna('BUI', (f) => _fmtNum(f.bui), tooltip: _tooltipsFwi['BUI']),
  _Columna('FWI', (f) => _fmtNum(f.fwi), tooltip: _tooltipsFwi['FWI']),
];

/// `DateTime` -> `DD/MM/AA`. Réplica de `formato_fecha` en vista_total.py,
/// pero partiendo del `DateTime` ya parseado por el repositorio en vez del
/// string crudo `AAAAMMDD` (mismo resultado: el original tampoco usaba la
/// hora para este título).
String formatearFechaReporte(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${dos(fecha.year % 100)}';
}
