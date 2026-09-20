import 'usuario.dart';

/// Respuesta de `POST /api/auth/login`:
/// `{ accessToken, refreshToken, expiresIn, user: {...} }`.
class LoginResult {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final Usuario usuario;

  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.usuario,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'] as int,
      usuario: Usuario.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
