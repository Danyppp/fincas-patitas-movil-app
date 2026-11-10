import '../../core/api_client.dart';
import '../../models/auth/usuario.dart';
import 'usuario_repository.dart';

class ApiUsuarioRepository implements UsuarioRepository {
  final ApiClient client;

  ApiUsuarioRepository({required this.client});

  @override
  Future<List<Usuario>> listarUsuarios() async {
    final data = await client.get('/users') as List<dynamic>;
    return data
        .map((u) => Usuario.fromJson(u as Map<String, dynamic>))
        .toList();
  }
}
