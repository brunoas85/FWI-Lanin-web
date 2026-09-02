/// Utilidades de parseo tolerante, replicando cómo el original maneja
/// valores ausentes o con formato irregular del API (ver docs/API.md):
/// números que llegan como string, campos que pueden faltar, y "-" como
/// marcador de dato ausente (visto en dirección de viento).
library;

/// Convierte un valor numérico que puede venir como String, num o null.
/// Trata cadenas vacías y "-" como ausencia de dato. Devuelve null si no
/// se puede interpretar, en vez de lanzar.
num? parseNum(Object? value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') return null;
    return num.tryParse(trimmed);
  }
  return null;
}

double? parseDouble(Object? value) => parseNum(value)?.toDouble();

/// Umbral de "desactualizado" (Estaciones y Detalle de estación, C5/C6):
/// más de 24 horas desde la última lectura. Sin dato (`actualizadoEn ==
/// null`, ya sea por fecha/hora vacías o con formato roto) **también**
/// cuenta como desactualizado — no se puede verificar la antigüedad.
///
/// El original de Estaciones tenía un bug acá: si faltaba fecha u hora,
/// se saltaba el chequeo entero y NO marcaba desactualizado (solo lo
/// hacía si había fecha/hora pero el parseo fallaba). Se corrigió al
/// refinar C5 — acordado con el usuario, documentado en TASKS.md. El
/// Detalle de estación no tenía ese bug: ya trataba cualquier fallo de
/// parseo, incluida la ausencia de dato, como desactualizado.
///
/// Toma el `DateTime?` ya parseado (no el modelo) porque tanto [Estacion]
/// como [EstacionDetalle] lo necesitan y son clases distintas.
bool estaDesactualizada(DateTime? actualizadoEn) {
  if (actualizadoEn == null) return true;
  return DateTime.now().difference(actualizadoEn) > const Duration(hours: 24);
}

/// Fecha `AAAAMMDD` + hora opcional `HH:MM:SS` -> [DateTime]. Devuelve
/// null si [fecha] no matchea el formato esperado (ver "Notas de formato"
/// en docs/API.md) en vez de lanzar — un campo de fecha con formato raro
/// no debería tirar abajo toda la pantalla.
DateTime? parseFechaHora(String? fecha, String? hora) {
  if (fecha == null || fecha.length != 8) return null;
  final anio = int.tryParse(fecha.substring(0, 4));
  final mes = int.tryParse(fecha.substring(4, 6));
  final dia = int.tryParse(fecha.substring(6, 8));
  if (anio == null || mes == null || dia == null) return null;

  var h = 0, m = 0, s = 0;
  if (hora != null && hora.isNotEmpty) {
    final partes = hora.split(':');
    if (partes.length == 3) {
      h = int.tryParse(partes[0]) ?? 0;
      m = int.tryParse(partes[1]) ?? 0;
      s = int.tryParse(partes[2]) ?? 0;
    }
  }
  return DateTime(anio, mes, dia, h, m, s);
}

/// Espejo de `_normalizar_nombre` / `formato_normalizado` del original:
/// recorta espacios, saca acentos, pasa a mayúsculas — para poder
/// comparar "Quillén" (si el API alguna vez lo manda así) contra "QUILLEN"
/// en las listas de orden.
///
/// Dart no trae normalización Unicode NFKD en el SDK. El universo de
/// nombres es acotado (8 estaciones en español), así que alcanza con un
/// reemplazo directo de los caracteres acentuados posibles — no hace
/// falta traer un paquete de normalización Unicode para esto.
String normalizarNombre(String? s) {
  if (s == null) return '';
  const acentos = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };
  final sinAcentos = s
      .trim()
      .toLowerCase()
      .split('')
      .map((c) => acentos[c] ?? c)
      .join();
  return sinAcentos.toUpperCase();
}
