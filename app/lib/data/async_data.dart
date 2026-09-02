import 'package:flutter/foundation.dart';

/// Estado de una operación de red, con caché en memoria del último dato
/// bueno: si una recarga falla, [DataError.staleData] conserva lo último
/// que sí funcionó para que la pantalla siga mostrando algo en vez de
/// quedar en blanco.
///
/// Funcionalidad nueva — el original no cachea nada: si `requests.get()`
/// falla, cada pantalla cae a una lista vacía o a un valor fijo,
/// indistinguible de "no hay estaciones" real (ver TASKS.md, C3).
sealed class DataState<T> {
  const DataState();
}

final class DataLoading<T> extends DataState<T> {
  const DataLoading({this.staleData});

  /// Dato de una carga anterior, si había uno, para que un consumidor
  /// (ej. `RefreshIndicator`) pueda seguir mostrando la lista de siempre
  /// con el spinner nativo encima en vez de vaciar la pantalla en cada
  /// recarga — agregado al refinar C5, primer consumidor real que lo
  /// necesitaba.
  final T? staleData;
}

final class DataSuccess<T> extends DataState<T> {
  const DataSuccess(this.data);
  final T data;
}

final class DataError<T> extends DataState<T> {
  const DataError(this.error, {this.staleData});
  final Object error;
  final T? staleData;
}

/// ViewModel genérico para "pedir algo al repositorio y mostrarlo",
/// reutilizable por cada pantalla (C4-C9) en vez de repetir el mismo
/// try/catch + estado a mano en cada una — que es exactamente lo que
/// hacía el original, con manejo de errores distinto en cada pantalla
/// (algunas con timeout, otras sin; algunas con fallback, otras no).
///
/// Mismo patrón que [FontScale] en `theme/font_scale.dart`: `ChangeNotifier`
/// puro, sin paquete de manejo de estado — decisión tomada al refinar C3.
class AsyncData<T> extends ChangeNotifier {
  AsyncData(this._fetch, {bool autoLoad = true}) {
    if (autoLoad) load();
  }

  final Future<T> Function() _fetch;

  DataState<T> _state = const DataLoading();
  DataState<T> get state => _state;

  /// Carga (o recarga, para reintentar) los datos. Si ya había un dato
  /// bueno de una carga anterior y esta falla, se conserva como
  /// [DataError.staleData].
  Future<void> load() async {
    final anterior = switch (_state) {
      DataSuccess<T>(:final data) => data,
      DataError<T>(:final staleData) => staleData,
      DataLoading<T>(:final staleData) => staleData,
    };

    _state = DataLoading<T>(staleData: anterior);
    notifyListeners();

    try {
      final data = await _fetch();
      _state = DataSuccess(data);
    } catch (error) {
      _state = DataError<T>(error, staleData: anterior);
    }
    notifyListeners();
  }
}
