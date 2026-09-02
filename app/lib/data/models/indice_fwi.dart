import 'package:flutter/foundation.dart';

import '../parsing.dart';

/// Item de `data` en `GET /vista_fwi` (docs/API.md).
///
/// ⚠️ Estos índices vienen **redondeados** a enteros — la misma estación
/// en `/estacion/<id>` trae más decimales (`"3.15134"` vs `3` acá). Es el
/// comportamiento real del servidor, documentado en B2, y se conserva tal
/// cual: Vista total muestra enteros, el Detalle muestra decimales. No
/// hay que "arreglar" esta inconsistencia — forma parte de la paridad.
@immutable
class IndiceFwi {
  const IndiceFwi({
    required this.estacion,
    this.estacionId,
    this.fecha,
    this.hora,
    this.ffmc,
    this.dmc,
    this.dc,
    this.isi,
    this.bui,
    this.fwi,
  });

  final String estacion;
  final String? estacionId;
  final String? fecha;
  final String? hora;
  final num? ffmc;
  final num? dmc;
  final num? dc;
  final num? isi;
  final num? bui;
  final num? fwi;

  factory IndiceFwi.fromJson(Map<String, dynamic> json) => IndiceFwi(
    estacion: json['estacion'] as String? ?? '',
    estacionId: json['estacion_id'] as String?,
    fecha: json['fecha'] as String?,
    hora: json['hora'] as String?,
    ffmc: parseNum(json['ffmc']),
    dmc: parseNum(json['dmc']),
    dc: parseNum(json['dc']),
    isi: parseNum(json['isi']),
    bui: parseNum(json['bui']),
    fwi: parseNum(json['fwi']),
  );
}
