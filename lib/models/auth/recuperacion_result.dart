/// Respuesta de `POST /auth/forgot-password`.
///
/// Importante: el backend actual NO envía correo (confirmado en el código:
/// `auth.service.ts -> solicitarRecuperacion`, comentario "Sin correo
/// configurado → token en respuesta (MVP)"). El `resetToken` viene directo
/// en esta respuesta solo cuando el correo sí existe en la base; si no
/// existe, el backend responde con el mismo mensaje genérico pero sin
/// `reset_token`, a propósito, para no revelar qué correos están
/// registrados.
class RecuperacionResult {
  final String mensaje;
  final String? resetToken;

  const RecuperacionResult({required this.mensaje, this.resetToken});

  factory RecuperacionResult.fromJson(Map<String, dynamic> json) {
    return RecuperacionResult(
      mensaje: json['mensaje'] as String? ?? '',
      resetToken: json['reset_token'] as String?,
    );
  }
}
