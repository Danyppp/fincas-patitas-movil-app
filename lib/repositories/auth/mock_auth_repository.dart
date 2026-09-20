import '../../models/auth/login_result.dart';
import '../../models/auth/recuperacion_result.dart';
import '../../models/auth/usuario.dart';
import 'auth_repository.dart';

/// Implementación de referencia sin backend — útil para trabajar en la UI
/// sin depender de que el backend esté corriendo. Acepta cualquier
/// correo/contraseña no vacíos.
class MockAuthRepository implements AuthRepository {
  final List<Map<String, String>> _usuarios = [
    {
      'correo': 'dany@fincasypatitas.test',
      'contrasena': '123456',
      'nombre': 'Dany (mock)'
    },
  ];

  String? _ultimoTokenGenerado;

  @override
  Future<void> registrar({
    required String nombreUsuario,
    required String correoElectronico,
    required String contrasena,
    String? telefono,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _usuarios.add({
      'correo': correoElectronico,
      'contrasena': contrasena,
      'nombre': nombreUsuario,
    });
  }

  @override
  Future<LoginResult> iniciarSesion({
    required String correoElectronico,
    required String contrasena,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final usuario = _usuarios.firstWhere(
      (u) => u['correo'] == correoElectronico && u['contrasena'] == contrasena,
      orElse: () => throw Exception('Correo o contraseña incorrectos (mock)'),
    );

    return LoginResult(
      accessToken: 'mock-access-token',
      refreshToken: 'mock-refresh-token',
      expiresIn: 900,
      usuario: Usuario(
        id: 1,
        nombreUsuario: usuario['nombre']!,
        correoElectronico: usuario['correo']!,
        rolId: 3,
      ),
    );
  }

  @override
  Future<void> cerrarSesion() async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<RecuperacionResult> solicitarRecuperacion({
    required String correoElectronico,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final existe = _usuarios.any((u) => u['correo'] == correoElectronico);
    if (!existe) {
      // Mismo comportamiento que el backend real: mensaje genérico, sin token.
      return const RecuperacionResult(
        mensaje: 'Si el correo existe, se generó un token de recuperación.',
      );
    }
    _ultimoTokenGenerado =
        'mock-reset-token-${DateTime.now().millisecondsSinceEpoch}';
    return RecuperacionResult(
      mensaje: 'Token de recuperación generado.',
      resetToken: _ultimoTokenGenerado,
    );
  }

  @override
  Future<void> restablecerContrasena({
    required String token,
    required String nuevaContrasena,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (token != _ultimoTokenGenerado) {
      throw Exception('Token inválido o expirado (mock)');
    }
    // En el mock no hace falta persistir la nueva contraseña por usuario;
    // basta con no lanzar error para simular éxito.
  }
}
