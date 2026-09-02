import 'api_client.dart';
import 'models/dato_meteorologico.dart';
import 'models/estacion.dart';
import 'models/estacion_detalle.dart';
import 'models/indice_fwi.dart';
import 'models/vista_total_row.dart';
import 'parsing.dart';

/// Orden de respaldo para Estaciones cuando el API todavía no envía el
/// campo `orden` para una estación. Réplica de `ORDEN_FALLBACK` en
/// `estaciones.py` — 8 estaciones, no 6, a diferencia de la lista de
/// Vista total.
const _ordenFallbackEstaciones = [
  'ALUMINE',
  'RUCACHOROI',
  'QUILLEN',
  'TROMEN',
  'PAIMUN',
  'HUA HUM',
  'CHAPELCO',
  'BARILOCHE',
];

/// Orden de prioridad de Vista total. Réplica de `ORDEN_DESEADO` en
/// `config.py` — 6 estaciones, no 8.
///
/// Deliberadamente **distinto** del de Estaciones, y no se unifican: es
/// un hallazgo documentado en docs/API.md ("Las dos pantallas ordenan
/// las estaciones de forma distinta") — unificar sería más prolijo pero
/// cambiaría qué estación aparece 6.ª y cuál 7.ª en cada pantalla,
/// rompiendo paridad.
const _ordenDeseadoVistaTotal = [
  'ALUMINE',
  'RUCACHOROI',
  'QUILLEN',
  'TROMEN',
  'PAIMUN',
  'CHAPELCO',
];

/// Capa de datos: un único punto de acceso al API para toda la app.
/// Reemplaza el `requests.get()` suelto y reimplementado en cada pantalla
/// del original (ver docs/API.md y TASKS.md, tarea C3).
class FwiRepository {
  FwiRepository(this._client);

  final FwiApiClient _client;

  Future<List<Estacion>> fetchEstaciones() async {
    final json = await _client.getJson('/estaciones') as List;
    final estaciones = json
        .whereType<Map<String, dynamic>>()
        .map(Estacion.fromJson)
        .toList();
    return _ordenarEstaciones(estaciones);
  }

  Future<EstacionDetalle> fetchEstacionDetalle(String id) async {
    final json = await _client.getJson('/estacion/$id') as Map<String, dynamic>;
    return EstacionDetalle.fromJson(json);
  }

  Future<VistaTotalData> fetchVistaTotal() async {
    final datosJson = await _client.getJson(
      '/vista_datos_meteorologicos',
    ) as Map<String, dynamic>;
    final fwiJson = await _client.getJson('/vista_fwi') as Map<String, dynamic>;

    final datos = ((datosJson['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DatoMeteorologico.fromJson)
        .toList();
    final indices = ((fwiJson['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(IndiceFwi.fromJson)
        .toList();

    final filas = _ordenarPorNombreDeseado(
      _combinarVistaTotal(datos, indices),
      _ordenDeseadoVistaTotal,
      (fila) => fila.estacion,
    );

    // El original (formato_fecha en vista_total.py) solo usa el campo
    // "fecha" acá y descarta la "hora" — pero el API la manda (docs/API.md),
    // así que se preserva: ninguna pantalla la usa todavía, y guardar más
    // fidelidad de la que el original aprovechaba no cambia nada visible.
    final fechaReporteObj = datosJson['fecha_reporte'] as Map?;

    return VistaTotalData(
      filas: filas,
      fechaReporte: parseFechaHora(
        fechaReporteObj?['fecha'] as String?,
        fechaReporteObj?['hora'] as String?,
      ),
    );
  }

  Future<String> fetchNosotros() => _client.getText('/nosotros');

  void close() => _client.close();

  // ── Combinación y orden ──────────────────────────────────────────
  // Réplica directa de get_combined_data() y ordenar_datos_por_prioridad()
  // en vista_total.py, y del criterio de tres niveles de estaciones.py.

  /// Combina por nombre de estación tal cual viene (sin normalizar):
  /// igual que el original, que asume que los dos endpoints usan la
  /// misma grafía porque salen del mismo backend.
  List<VistaTotalRow> _combinarVistaTotal(
    List<DatoMeteorologico> datos,
    List<IndiceFwi> indices,
  ) {
    final porNombre =
        <String, ({DatoMeteorologico? datos, IndiceFwi? indice})>{};
    for (final d in datos) {
      if (d.estacion.isEmpty) continue;
      porNombre[d.estacion] = (datos: d, indice: null);
    }
    for (final i in indices) {
      final existente = porNombre[i.estacion];
      if (existente != null) {
        porNombre[i.estacion] = (datos: existente.datos, indice: i);
      }
      // Si no hay match del lado meteorológico, el original tampoco
      // agrega la estación (combined_dict solo se puebla desde
      // meteorological_data) — mismo comportamiento acá.
    }
    return porNombre.entries
        .map(
          (e) => VistaTotalRow(
            estacion: e.key,
            temperatura: e.value.datos?.temperatura,
            humedad: e.value.datos?.humedad,
            viento10m: e.value.datos?.viento10m,
            direccion: e.value.datos?.direccion,
            lluviaAyer: e.value.datos?.lluviaAyer,
            acumulado: e.value.datos?.acumulado,
            ffmc: e.value.indice?.ffmc,
            dmc: e.value.indice?.dmc,
            dc: e.value.indice?.dc,
            isi: e.value.indice?.isi,
            bui: e.value.indice?.bui,
            fwi: e.value.indice?.fwi,
          ),
        )
        .toList();
  }

  /// Tres niveles de prioridad, igual que estaciones.py:
  /// 1. Campo `orden` numérico del API, si vino.
  /// 2. Si no, posición en [_ordenFallbackEstaciones] por nombre normalizado.
  /// 3. Si tampoco matchea, al final, en el orden en que llegó del API.
  List<Estacion> _ordenarEstaciones(List<Estacion> estaciones) {
    int nivel(Estacion e) {
      if (e.orden != null) return 0;
      final idx = _ordenFallbackEstaciones.indexOf(normalizarNombre(e.nombre));
      return idx >= 0 ? 1 : 2;
    }

    // Dart's List.sort no garantiza estabilidad; el nivel 3 depende de
    // conservar el orden de llegada del API para los no matcheados, así
    // que se desempata por índice original explícitamente en vez de
    // asumir que el sort es estable.
    final indexadas = estaciones.indexed.toList();
    indexadas.sort((a, b) {
      final (ia, ea) = a;
      final (ib, eb) = b;
      final na = nivel(ea), nb = nivel(eb);
      if (na != nb) return na.compareTo(nb);
      switch (na) {
        case 0:
          return ea.orden!.compareTo(eb.orden!);
        case 1:
          final fa = _ordenFallbackEstaciones.indexOf(
            normalizarNombre(ea.nombre),
          );
          final fb = _ordenFallbackEstaciones.indexOf(
            normalizarNombre(eb.nombre),
          );
          return fa.compareTo(fb);
        default:
          return ia.compareTo(ib);
      }
    });
    return indexadas.map((e) => e.$2).toList();
  }

  /// Réplica de `ordenar_datos_por_prioridad`: los nombres de
  /// [ordenDeseado] van primero, en ese orden; el resto queda al final,
  /// en el orden en que llegó.
  List<T> _ordenarPorNombreDeseado<T>(
    List<T> items,
    List<String> ordenDeseado,
    String Function(T) nombreDe,
  ) {
    final porNombre = <String, T>{};
    for (final item in items) {
      porNombre[normalizarNombre(nombreDe(item))] = item;
    }

    final ordenados = <T>[];
    final agregados = <T>{};
    for (final nombre in ordenDeseado) {
      final item = porNombre[nombre];
      if (item != null) {
        ordenados.add(item);
        agregados.add(item);
      }
    }
    for (final item in items) {
      if (!agregados.contains(item)) ordenados.add(item);
    }
    return ordenados;
  }
}
