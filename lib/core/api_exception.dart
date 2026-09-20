/// Representa el envelope de error uniforme que devuelve el backend real:
/// `{ "error": { "code": "STRING_CODE", "message": "..." } }`.
///
/// Confirmado leyendo directamente `errorHandler.ts` y varios controladores
/// del repo `backend_appmovil_fincas` — no es solo lo documentado en
/// Swagger, es lo que el código realmente responde.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  /// true cuando el backend respondió 401 (token ausente/ inválido/expirado).
  bool get isAuthError => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

/// Error de red/conexión (backend no disponible, timeout, etc.) — distinto
/// de un error de negocio devuelto por el backend.
class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
