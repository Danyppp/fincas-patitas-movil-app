import '../../models/auth/usuario.dart';
import 'usuario_repository.dart';

class MockUsuarioRepository implements UsuarioRepository {
  @override
  Future<List<Usuario>> listarUsuarios() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const [
      Usuario(
          id: 1,
          nombreUsuario: 'Dany (Admin)',
          correoElectronico: 'dany@fincapatitas.test',
          rolId: 1),
      Usuario(
          id: 2,
          nombreUsuario: 'Carlos Operario',
          correoElectronico: 'carlos@fincapatitas.test',
          rolId: 3),
      Usuario(
          id: 3,
          nombreUsuario: 'Laura Encargada',
          correoElectronico: 'laura@fincapatitas.test',
          rolId: 2),
    ];
  }
}
