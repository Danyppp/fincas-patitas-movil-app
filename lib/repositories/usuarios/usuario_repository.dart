import '../../models/auth/usuario.dart';

/// Contrato mínimo para listar usuarios candidatos a "Encargado" de un
/// Lote/Potrero (ver decisiones-diseno-vs-backend-ubicacion.md, sección
/// 8). Reutiliza el modelo `Usuario` que ya existe para la sesión
/// (`models/auth/usuario.dart`) -- mismo shape que devuelve el backend.
///
/// A propósito NO incluye crear/editar/eliminar usuarios ni cambiar
/// roles/contraseñas -- eso es "Gestión de usuarios y operarios" en
/// Cuenta, que sigue siendo "próximamente" y es un alcance aparte.
abstract class UsuarioRepository {
  /// `GET /users` -- en el backend real exige rol Administrador
  /// (`requireAdmin`). Si la sesión activa no es Administrador, el
  /// backend responde 403 y la pantalla que llame esto debe mostrar un
  /// aviso en vez de la lista.
  Future<List<Usuario>> listarUsuarios();
}
