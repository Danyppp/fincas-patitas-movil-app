import '../../models/auth/login_result.dart';
import '../../models/auth/recuperacion_result.dart';

/// Contrato del módulo Auth, independiente de si los datos vienen del
/// backend real o de un mock. Coincide con `POST /api/auth/register`,
/// `POST /api/auth/login`, `POST /api/auth/forgot-password` y
/// `POST /api/auth/reset-password` de `backend_appmovil_fincas`.
abstract class AuthRepository {
  /// Registra un usuario nuevo. El backend fuerza `rol_id=3` (Empleado)
  /// del lado del servidor: el cliente no puede elegir el rol — no se
  /// envía ningún campo de rol en esta llamada, ni la UI debe ofrecer
  /// selección de rol en el formulario de registro (decisión confirmada).
  Future<void> registrar({
    required String nombreUsuario,
    required String correoElectronico,
    required String contrasena,
    String? telefono,
  });

  /// Login solo por correo electrónico — el backend no soporta login por
  /// nombre de usuario.
  Future<LoginResult> iniciarSesion({
    required String correoElectronico,
    required String contrasena,
  });

  /// Logout es un no-op del lado del servidor (sin estado). La limpieza
  /// real de tokens la hace `AuthSession.cerrarSesion()` desde la UI.
  Future<void> cerrarSesion();

  /// HU-03, paso 1: solicita la recuperación de contraseña.
  ///
  /// El backend NO envía correo — devuelve el `reset_token` directo en la
  /// respuesta (solo si el correo existe). La UI debe mostrar ese token al
  /// usuario para que lo use en el siguiente paso, no prometer un enlace
  /// por email.
  Future<RecuperacionResult> solicitarRecuperacion({
    required String correoElectronico,
  });

  /// HU-03, paso 2: restablece la contraseña usando el token del paso
  /// anterior.
  Future<void> restablecerContrasena({
    required String token,
    required String nuevaContrasena,
  });
}
