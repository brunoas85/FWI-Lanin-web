import 'package:flutter/foundation.dart';

import '../parsing.dart';

/// Item de `data` en `GET /vista_datos_meteorologicos` (docs/API.md). A
/// diferencia de `/estaciones`, acá los valores llegan como números JSON
/// reales, no strings — [parseNum] igual tolera ambos por si el servidor
/// cambia de formato sin avisar.
@immutable
class DatoMeteorologico {
  const DatoMeteorologico({
    required this.estacion,
    this.estacionId,
    this.fecha,
    this.hora,
    this.temperatura,
    this.humedad,
    this.viento10m,
    this.vientoKmh,
    this.direccion,
    this.lluviaAyer,
    this.acumulado,
  });

  final String estacion;
  final String? estacionId;
  final String? fecha;
  final String? hora;
  final num? temperatura;
  final num? humedad;

  /// Viento corregido a 10 metros — el único de los dos que muestra
  /// Vista total (ver `vista_total.py`, columna "Viento").
  final num? viento10m;

  /// Viento sin corregir. El endpoint lo manda pero ninguna pantalla lo
  /// usa hoy — se porta completo igual, por fidelidad con la fuente.
  final num? vientoKmh;

  final String? direccion;
  final num? lluviaAyer;
  final num? acumulado;

  factory DatoMeteorologico.fromJson(Map<String, dynamic> json) {
    return DatoMeteorologico(
      estacion: json['estacion'] as String? ?? '',
      estacionId: json['estacion_id'] as String?,
      fecha: json['fecha'] as String?,
      hora: json['hora'] as String?,
      temperatura: parseNum(json['temperatura']),
      humedad: parseNum(json['humedad']),
      viento10m: parseNum(json['viento_10m']),
      vientoKmh: parseNum(json['viento_kmh']),
      direccion: json['direccion'] as String?,
      lluviaAyer: parseNum(json['lluvia_ayer']),
      acumulado: parseNum(json['acumulado']),
    );
  }
}
