import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Cliente HTTP único para los 6 endpoints del API. Centraliza base URL,
/// timeout y el mapeo de errores a excepciones tipadas.
///
/// El original reimplementaba `requests.get()` suelto en cada pantalla:
/// dos de las cuatro llamadas no tenían timeout y podían colgar la app
/// indefinidamente si el servidor no respondía (ver docs/API.md y TASKS.md).
///
/// [defaultBaseUrl] sigue siendo la IP hardcodeada del original en Android —
/// pero ya no es la única fuente: `main.dart` la reemplaza por la guardada en
/// [ApiConfig] si el usuario configuró una (C11), sin recompilar.
///
/// **En la build web (Épica F):** un navegador servido por HTTPS no puede
/// llamar directo a esa IP en HTTP plano (*mixed content*, lo bloquea el
/// propio navegador). El default ahí es `/api/proxy` — ruta relativa al
/// mismo origen que sirve la página, resuelta por la función serverless de
/// `web/api/proxy/` (F1), que reenvía al servidor real. `kIsWeb` es una
/// constante de compilación: cada plataforma termina con un único valor
/// fijo en el binario, no hay chequeo en tiempo de ejecución.
class FwiApiClient {
  FwiApiClient({http.Client? client, this.baseUrl = defaultBaseUrl})
    : _client = client ?? http.Client();

  static const defaultBaseUrl = kIsWeb
      ? '/api/proxy'
      : 'http://181.114.143.184:4102/api';
  static const _timeout = Duration(seconds: 5);

  final http.Client _client;
  final String baseUrl;

  /// GET que devuelve el body ya decodificado como JSON (`Map` o `List`
  /// según el endpoint — ver docs/API.md, cada uno tiene una forma distinta).
  Future<dynamic> getJson(String path) async {
    final body = await _get(path);
    try {
      return jsonDecode(body);
    } on FormatException catch (e) {
      throw FwiParseException('Respuesta inválida de $path: $e');
    }
  }

  /// GET que devuelve el body tal cual, como texto plano. Usado por
  /// `/nosotros`, que no devuelve JSON.
  Future<String> getText(String path) => _get(path);

  Future<String> _get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const FwiTimeoutException();
    } on http.ClientException catch (e) {
      throw FwiNetworkException(e.message);
    } catch (e) {
      // Cualquier otro fallo de bajo nivel (DNS, socket, etc.) se mapea
      // igual a "problema de red" — a la pantalla no le importa la causa
      // exacta, solo que no hay dato y hay que ofrecer reintentar.
      throw FwiNetworkException(e.toString());
    }

    if (response.statusCode != 200) {
      throw FwiServerException(response.statusCode);
    }
    return response.body;
  }

  void close() => _client.close();
}
