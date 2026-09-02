import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Override persistido de [FwiApiClient.defaultBaseUrl] — C11: que la URL
/// del API se pueda cambiar sin recompilar (hoy es una IP hardcodeada; si
/// Parques la cambia, la app queda muerta hasta publicar una versión nueva).
///
/// No es un `ChangeNotifier`: a diferencia de `FontScale` (que necesita
/// reflejar cambios en pantallas ya abiertas), acá alcanza con leer el
/// valor una vez al construir cada pantalla — `main.dart` lo hace en
/// `onGenerateRoute`. Cambiar la URL no re-renderiza nada al instante; se
/// aplica en la próxima navegación, que para una acción de configuración
/// poco frecuente es una simplificación razonable.
class ApiConfig {
  static const _prefsKey = 'api_base_url';

  String? _override;

  /// La URL vigente: la guardada por el usuario, o [FwiApiClient.defaultBaseUrl]
  /// si nunca se configuró una.
  String get baseUrl => _override ?? FwiApiClient.defaultBaseUrl;

  /// Si hay una URL guardada de una sesión anterior, la carga. Se llama una
  /// vez al arrancar la app, antes de `runApp` — ver `main.dart`.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) _override = saved;
  }

  /// Guarda una URL nueva, o borra el override y vuelve al default si
  /// [url] es `null` o queda vacío tras recortar espacios.
  ///
  /// Tira [FormatException] si [url] no es una URL `http(s)` válida, sin
  /// tocar el valor guardado — a diferencia del original (una constante de
  /// código, nunca tipeada por un usuario), acá el valor lo escribe una
  /// persona a mano, y un typo no debería dejar la app sin poder hablar
  /// con el servidor hasta que alguien lo note y lo corrija.
  Future<void> setBaseUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      _override = null;
      await prefs.remove(_prefsKey);
      return;
    }

    final uri = Uri.tryParse(trimmed);
    final esValida =
        uri != null &&
        uri.isAbsolute &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    if (!esValida) {
      throw const FormatException('La URL debe empezar con http:// o https://');
    }

    _override = trimmed;
    await prefs.setString(_prefsKey, trimmed);
  }
}
