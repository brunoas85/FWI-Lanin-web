import 'package:flutter/foundation.dart';

/// Una fila de Vista total: combina lo que trae `/vista_datos_meteorologicos`
/// y `/vista_fwi` para la misma estación, en un solo objeto — igual que
/// `get_combined_data()` en el original (`vista_total.py`), que arma un
/// dict por estación con estos mismos 12 campos y descarta el resto
/// (`estacion_id`, `fecha`, `hora`, `viento_kmh`: ningún campo de las dos
/// tablas de esa pantalla los usa).
///
/// Construida por [FwiRepository.fetchVistaTotal] — ver ese archivo para
/// la lógica de combinación y orden.
@immutable
class VistaTotalRow {
  const VistaTotalRow({
    required this.estacion,
    this.temperatura,
    this.humedad,
    this.viento10m,
    this.direccion,
    this.lluviaAyer,
    this.acumulado,
    this.ffmc,
    this.dmc,
    this.dc,
    this.isi,
    this.bui,
    this.fwi,
  });

  final String estacion;
  final num? temperatura;
  final num? humedad;
  final num? viento10m;
  final String? direccion;
  final num? lluviaAyer;
  final num? acumulado;
  final num? ffmc;
  final num? dmc;
  final num? dc;
  final num? isi;
  final num? bui;
  final num? fwi;
}

/// Resultado completo de Vista total: las filas ya combinadas y
/// ordenadas, más la fecha del reporte para el título de la pantalla
/// ("Datos meteorológicos DD/MM/AA" en el original).
@immutable
class VistaTotalData {
  const VistaTotalData({required this.filas, this.fechaReporte});

  final List<VistaTotalRow> filas;
  final DateTime? fechaReporte;
}
