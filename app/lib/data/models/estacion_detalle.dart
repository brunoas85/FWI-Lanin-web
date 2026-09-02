import 'package:flutter/foundation.dart';

import '../parsing.dart';

/// `GET /estacion/<id>` (docs/API.md). Convención de nombres propia,
/// distinta de todos los demás endpoints: claves `Capitalizadas`, dos con
/// espacio (`"Estado FWI"`, `"W 10"`). Se preserva tal cual en
/// [fromJson] — es la única fuente de esa rareza, el resto del código
/// usa nombres de campo normales.
@immutable
class EstacionDetalle {
  const EstacionDetalle({
    required this.nombre,
    required this.estadoFwi,
    this.fecha,
    this.hora,
    this.temp,
    this.hr,
    this.ws,
    this.w10,
    this.wd,
    this.ppt,
    this.acum,
    this.ffmc,
    this.dmc,
    this.dc,
    this.isi,
    this.bui,
    this.fwi,
    this.api,
    this.latitud,
    this.longitud,
  });

  final String nombre;
  final String estadoFwi;
  final String? fecha;
  final String? hora;
  final double? temp;
  final double? hr;

  /// Viento en km/h.
  final double? ws;

  /// Viento corregido a 10 metros.
  final double? w10;

  /// Dirección del viento como texto (`"E"`, `"SE"`, `"ONO"`…). Puede
  /// venir `"-"` cuando no hay dato — se conserva el string literal, no
  /// se convierte a null: es un valor de texto válido para mostrar.
  final String? wd;

  final double? ppt;
  final double? acum;
  final double? ffmc;
  final double? dmc;
  final double? dc;
  final double? isi;
  final double? bui;
  final double? fwi;
  final String? api;
  final double? latitud;
  final double? longitud;

  DateTime? get actualizadoEn => parseFechaHora(fecha, hora);

  factory EstacionDetalle.fromJson(Map<String, dynamic> json) {
    return EstacionDetalle(
      nombre: json['nombre'] as String? ?? '',
      estadoFwi: (json['Estado FWI'] as String? ?? '').trim().toUpperCase(),
      fecha: json['Date'] as String?,
      hora: json['Hora'] as String?,
      temp: parseDouble(json['Temp']),
      hr: parseDouble(json['HR']),
      ws: parseDouble(json['WS']),
      w10: parseDouble(json['W 10']),
      wd: json['WD'] as String?,
      ppt: parseDouble(json['PPT']),
      acum: parseDouble(json['Acum']),
      ffmc: parseDouble(json['FFMC']),
      dmc: parseDouble(json['DMC']),
      dc: parseDouble(json['DC']),
      isi: parseDouble(json['ISI']),
      bui: parseDouble(json['BUI']),
      fwi: parseDouble(json['FWI']),
      api: json['api'] as String?,
      latitud: parseDouble(json['latitud']),
      longitud: parseDouble(json['longitud']),
    );
  }
}
