/// Excepciones tipadas del cliente de API — reemplazan el `except
/// Exception` genérico del original, que no distinguía "no hay conexión"
/// de "el servidor devolvió un error" de "la respuesta no se pudo leer".
/// Cada pantalla (C4-C9) puede mostrar un mensaje distinto según el tipo.
sealed class FwiApiException implements Exception {
  const FwiApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

final class FwiTimeoutException extends FwiApiException {
  const FwiTimeoutException() : super('El servidor no respondió a tiempo.');
}

final class FwiNetworkException extends FwiApiException {
  const FwiNetworkException(super.message);
}

final class FwiServerException extends FwiApiException {
  const FwiServerException(this.statusCode)
    : super('El servidor respondió con un error ($statusCode).');
  final int statusCode;
}

final class FwiParseException extends FwiApiException {
  const FwiParseException(super.message);
}
