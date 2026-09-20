import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth/usuario.dart';

/// Guarda en memoria (y persiste en disco con [SharedPreferences]) la
/// sesión activa: accessToken, refreshToken y el usuario autenticado.
///
/// Es un [ChangeNotifier] para que `main.dart` pueda decidir, sin lógica
/// duplicada, si mostrar `LoginScreen` o `HomeShell` cada vez que cambia
/// el estado de sesión (login, logout, token renovado).
class AuthSession extends ChangeNotifier {
  static const _kAccessToken = 'auth_access_token';
  static const _kRefreshToken = 'auth_refresh_token';
  static const _kUsuarioJson = 'auth_usuario_json';

  String? _accessToken;
  String? _refreshToken;
  Usuario? _usuario;
  bool _initialized = false;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  Usuario? get usuario => _usuario;
  bool get isAuthenticated => _accessToken != null;
  bool get isInitialized => _initialized;

  /// Carga la sesión guardada (si existe) al arrancar la app, para que el
  /// usuario no tenga que iniciar sesión otra vez en cada `flutter run`.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccessToken);
    _refreshToken = prefs.getString(_kRefreshToken);
    final usuarioJson = prefs.getString(_kUsuarioJson);
    if (usuarioJson != null) {
      _usuario = Usuario.fromJsonString(usuarioJson);
    }
    _initialized = true;
    notifyListeners();
  }

  /// [recordarEnDispositivo] controla el checkbox "Recordar en este
  /// dispositivo" del Login — es 100% client-side (el backend no sabe ni
  /// le importa): en `true` (default) la sesión se persiste en
  /// [SharedPreferences] y sobrevive a cerrar la app; en `false` solo se
  /// guarda en memoria, así que un refresh o reinicio del navegador/app
  /// vuelve a pedir credenciales.
  Future<void> guardarSesion({
    required String accessToken,
    required String refreshToken,
    required Usuario usuario,
    bool recordarEnDispositivo = true,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _usuario = usuario;

    final prefs = await SharedPreferences.getInstance();
    if (recordarEnDispositivo) {
      await prefs.setString(_kAccessToken, accessToken);
      await prefs.setString(_kRefreshToken, refreshToken);
      await prefs.setString(_kUsuarioJson, usuario.toJsonString());
    } else {
      // No persistir: si había una sesión guardada de una vez anterior con
      // "Recordar" activado, se limpia para no dejarla huérfana en disco.
      await prefs.remove(_kAccessToken);
      await prefs.remove(_kRefreshToken);
      await prefs.remove(_kUsuarioJson);
    }

    notifyListeners();
  }

  /// Reemplaza solo el accessToken (usado tras `POST /auth/refresh`).
  Future<void> actualizarAccessToken(String accessToken) async {
    _accessToken = accessToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, accessToken);
    notifyListeners();
  }

  Future<void> cerrarSesion() async {
    _accessToken = null;
    _refreshToken = null;
    _usuario = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
    await prefs.remove(_kUsuarioJson);

    notifyListeners();
  }
}
