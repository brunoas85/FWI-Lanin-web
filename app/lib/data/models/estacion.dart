import 'package:flutter/foundation.dart';

import '../parsing.dart';

/// Item de `GET /estaciones` (docs/API.md). Todos los valores llegan como
/// String en el JSON crudo, salvo `orden` — ver [Estacion.fromJson].
@immutable
class Estacion {
  const Estacion({
    required this.id,
    required this.nombre,
    required this.estadoFwi,
    this.orden,
    this.fwi,
    this.temperatura,
    this.humedad,
    this.viento,
    this.ppt,
    this.latitud,
    this.longitud,
    this.api,
    this.fecha,
    this.hora,
  });

  final String id;
  final String nombre;
  final String estadoFwi;

  /// Único campo numérico real del endpoint. Null si el servidor todavía
  /// no lo envía para esta estación — ver el criterio de orden en
  /// [FwiRepository] (`docs/API.md`, "Las dos pantallas ordenan...").
  final int? orden;

  final double? fwi;
  final double? temperatura;
  final double? humedad;
  final double? viento;
  final double? ppt;
  final double? latitud;
  final double? longitud;
  final String? api;

  /// `AAAAMMDD` crudo — ver [actualizadoEn] para la versión parseada.
  final String? fecha;

  /// `HH:MM:SS` crudo.
  final String? hora;

  DateTime? get actualizadoEn => parseFechaHora(fecha, hora);

  factory Estacion.fromJson(Map<String, dynamic> json) {
    return Estacion(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      estadoFwi: (json['estado_fwi'] as String? ?? '').trim().toUpperCase(),
      orden: parseNum(json['orden'])?.toInt(),
      fwi: parseDouble(json['fwi']),
      temperatura: parseDouble(json['temperatura']),
      humedad: parseDouble(json['humedad']),
      viento: parseDouble(json['viento']),
      ppt: parseDouble(json['ppt']),
      latitud: parseDouble(json['latitud']),
      longitud: parseDouble(json['longitud']),
      api: json['api'] as String?,
      fecha: json['fecha'] as String?,
      hora: json['hora'] as String?,
    );
  }
}
