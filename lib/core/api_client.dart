import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'auth_session.dart';

/// Cliente HTTP compartido por todos los repositorios `Api*`.
///
/// Responsabilidades (para no repetirlas en cada repositorio):
///  - Anteponer [AppConfig.apiBaseUrl] a cada ruta.
///  - Adjuntar `Authorization: Bearer <accessToken>` cuando hay sesión.
///  - Decodificar el envelope de error `{ error: { code, message } }`.
///  - Si el backend responde 401 por token expirado, intentar UNA vez
///    `POST /auth/refresh` con el refreshToken guardado y reintentar la
///    petición original con el accessToken nuevo. Si el refresh también
///    falla, se cierra la sesión (el usuario vuelve al login).
class ApiClient {
  final AuthSession session;
  final http.Client _http;

  ApiClient({required this.session, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final base = Uri.parse('${AppConfig.apiBaseUrl}/$cleanPath');
    if (query == null || query.isEmpty) return base;
    final filtered = <String, String>{};
    query.forEach((key, value) {
      if (value != null) filtered[key] = value.toString();
    });
    return base
        .replace(queryParameters: {...base.queryParameters, ...filtered});
  }

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && session.accessToken != null) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    return headers;
  }

  Future<dynamic> get(String path,
      {Map<String, dynamic>? query, bool auth = true}) {
    return _send('GET', path, query: query, auth: auth);
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) {
    return _send('POST', path, body: body, auth: auth);
  }

  Future<dynamic> put(String path, {Object? body, bool auth = true}) {
    return _send('PUT', path, body: body, auth: auth);
  }

  // Nuevo (2026-10-15): lo necesita Reproducción para /reproduccion/:id/confirmar
  // y /reproduccion/:id/cerrar -- el resto de módulos sigue usando put/post/delete.
  Future<dynamic> patch(String path, {Object? body, bool auth = true}) {
    return _send('PATCH', path, body: body, auth: auth);
  }

  Future<dynamic> delete(String path, {bool auth = true}) {
    return _send('DELETE', path, auth: auth);
  }

  // Nuevo (2026-11-05): lo necesita Ubicación para subir la foto de
  // Potrero (`POST /ubicaciones-potreros/:id/foto`, multipart/form-data)
  // -- el resto de módulos solo manda JSON, por eso es un método aparte en
  // vez de otra rama dentro de `_send`.
  Future<dynamic> postMultipart(
    String path, {
    required List<int> bytes,
    required String campo,
    required String nombreArchivo,
    bool auth = true,
  }) {
    return _sendMultipart(path,
        bytes: bytes, campo: campo, nombreArchivo: nombreArchivo, auth: auth);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool auth = true,
    bool esReintento = false,
  }) async {
    final uri = _uri(path, query);
    http.Response respuesta;
    try {
      respuesta = await _ejecutar(method, uri, body, auth)
          .timeout(AppConfig.requestTimeout);
    } catch (e) {
      throw NetworkException('No se pudo conectar con el backend ($uri). '
          '¿Está corriendo `npm run dev` en tu PC? Detalle: $e');
    }

    if (respuesta.statusCode == 401 &&
        auth &&
        !esReintento &&
        session.refreshToken != null) {
      final renovado = await _intentarRefrescarToken();
      if (renovado) {
        return _send(method, path,
            query: query, body: body, auth: auth, esReintento: true);
      }
      await session.cerrarSesion();
    }

    return _procesarRespuesta(respuesta);
  }

  Future<http.Response> _ejecutar(
      String method, Uri uri, Object? body, bool auth) {
    final headers = _headers(auth: auth);
    final jsonBody = body != null ? jsonEncode(body) : null;
    switch (method) {
      case 'GET':
        return _http.get(uri, headers: headers);
      case 'POST':
        return _http.post(uri, headers: headers, body: jsonBody);
      case 'PUT':
        return _http.put(uri, headers: headers, body: jsonBody);
      case 'PATCH':
        return _http.patch(uri, headers: headers, body: jsonBody);
      case 'DELETE':
        return _http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Método HTTP no soportado: $method');
    }
  }

  // 2026-11-10: `MultipartFile.fromBytes` sin `contentType` explícito
  // queda como `application/octet-stream` por defecto -- el backend
  // (`upload.middleware.ts`, `filtroSoloImagenes`) exige que el
  // `mimetype` empiece con `image/` y lo rechaza con 500 "Error interno
  // del servidor" si no. Por eso ahora se infiere el tipo a partir de la
  // extensión del archivo (confirmado: este era el bug detrás de "Error
  // interno del servidor" al subir la foto de un Potrero).
  MediaType _tipoImagen(String nombreArchivo) {
    final ext = nombreArchivo.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'bmp':
        return MediaType('image', 'bmp');
      case 'heic':
        return MediaType('image', 'heic');
      case 'jpg':
      case 'jpeg':
      default:
        return MediaType('image', 'jpeg');
    }
  }

  Future<dynamic> _sendMultipart(
    String path, {
    required List<int> bytes,
    required String campo,
    required String nombreArchivo,
    bool auth = true,
    bool esReintento = false,
  }) async {
    final uri = _uri(path);
    http.Response respuesta;
    try {
      final request = http.MultipartRequest('POST', uri);
      if (auth && session.accessToken != null) {
        request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
      request.files.add(http.MultipartFile.fromBytes(
        campo,
        bytes,
        filename: nombreArchivo,
        contentType: _tipoImagen(nombreArchivo),
      ));
      final streamed =
          await _http.send(request).timeout(AppConfig.requestTimeout);
      respuesta = await http.Response.fromStream(streamed);
    } catch (e) {
      throw NetworkException('No se pudo conectar con el backend ($uri). '
          '¿Está corriendo `npm run dev` en tu PC? Detalle: $e');
    }

    if (respuesta.statusCode == 401 &&
        auth &&
        !esReintento &&
        session.refreshToken != null) {
      final renovado = await _intentarRefrescarToken();
      if (renovado) {
        return _sendMultipart(path,
            bytes: bytes,
            campo: campo,
            nombreArchivo: nombreArchivo,
            auth: auth,
            esReintento: true);
      }
      await session.cerrarSesion();
    }

    return _procesarRespuesta(respuesta);
  }

  Future<bool> _intentarRefrescarToken() async {
    try {
      final uri = _uri('/auth/refresh');
      final respuesta = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': session.refreshToken}),
          )
          .timeout(AppConfig.requestTimeout);

      if (respuesta.statusCode != 200) return false;

      final data = jsonDecode(respuesta.body) as Map<String, dynamic>;
      await session.actualizarAccessToken(data['accessToken'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }

  dynamic _procesarRespuesta(http.Response respuesta) {
    if (respuesta.statusCode == 204 || respuesta.body.isEmpty) {
      if (respuesta.statusCode >= 200 && respuesta.statusCode < 300)
        return null;
    }

    dynamic data;
    try {
      data = respuesta.body.isNotEmpty ? jsonDecode(respuesta.body) : null;
    } catch (_) {
      data = null;
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return data;
    }

    // Envelope confirmado en errorHandler.ts: { error: { code, message } }
    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      final error = data['error'] as Map<String, dynamic>;
      throw ApiException(
        statusCode: respuesta.statusCode,
        code: error['code'] as String? ?? 'UNKNOWN_ERROR',
        message:
            error['message'] as String? ?? 'Error desconocido del servidor',
      );
    }

    throw ApiException(
      statusCode: respuesta.statusCode,
      code: 'UNKNOWN_ERROR',
      message:
          'El servidor respondió ${respuesta.statusCode} sin el formato de error esperado',
    );
  }
}
