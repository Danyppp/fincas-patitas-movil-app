import '../../core/api_client.dart';
import '../../models/auth/login_result.dart';
import '../../models/auth/recuperacion_result.dart';
import 'auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  final ApiClient client;

  ApiAuthRepository({required this.client});

  @override
  Future<void> registrar({
    required String nombreUsuario,
    required String correoElectronico,
    required String contrasena,
    String? telefono,
  }) async {
    await client.post(
      '/auth/register',
      auth: false,
      body: {
        'nombre_usuario': nombreUsuario,
        'correo_electronico': correoElectronico,
        'contrasena': contrasena,
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      },
    );
  }

  @override
  Future<LoginResult> iniciarSesion({
    required String correoElectronico,
    required String contrasena,
  }) async {
    final data = await client.post(
      '/auth/login',
      auth: false,
      body: {
        'correo_electronico': correoElectronico,
        'contrasena': contrasena,
      },
    );
    return LoginResult.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> cerrarSesion() async {
    // Stateless en el servidor (204 sin cuerpo) — se llama por completitud
    // del contrato, la limpieza real la hace AuthSession.
    await client.post('/auth/logout');
  }

  @override
  Future<RecuperacionResult> solicitarRecuperacion({
    required String correoElectronico,
  }) async {
    // Ojo: el backend espera la clave "email", no "correo_electronico"
    // (inconsistencia real del contrato, confirmada en auth.routes.ts).
    final data = await client.post(
      '/auth/forgot-password',
      auth: false,
      body: {'email': correoElectronico},
    );
    return RecuperacionResult.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> restablecerContrasena({
    required String token,
    required String nuevaContrasena,
  }) async {
    // Ojo: el backend espera "nueva_password", no "nueva_contrasena".
    await client.post(
      '/auth/reset-password',
      auth: false,
      body: {'token': token, 'nueva_password': nuevaContrasena},
    );
  }
}
