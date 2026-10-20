import '../../models/reproduccion/seguimiento_gestacion.dart';
import 'reproduccion_repository.dart';

const _usuarioDemo =
    UsuarioReferencia(id: 1, nombreUsuario: 'Usuario de prueba');

class MockReproduccionRepository implements ReproduccionRepository {
  final List<SeguimientoGestacion> _registros = [
    SeguimientoGestacion(
      id: 1,
      animalId: 1,
      tipo: 'IA',
      fechaInseminacion: DateTime.now().subtract(const Duration(days: 30)),
      fechaEstimadaParto: DateTime.now().add(const Duration(days: 253)),
      estado: 'Gestante',
      animal:
          const AnimalReferencia(id: 1, codigo: 'ANI-0001', nombre: 'Lucera'),
      creadoPor: _usuarioDemo,
      confirmadoPor: _usuarioDemo,
      confirmadoEn: DateTime.now().subtract(const Duration(days: 28)),
    ),
  ];
  int _correlativo = 2;

  @override
  Future<List<SeguimientoGestacion>> listar(
      {int? animalId, String? estado}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _registros.where((r) {
      if (animalId != null && r.animalId != animalId) return false;
      if (estado != null && r.estado != estado) return false;
      return true;
    }).toList();
  }

  @override
  Future<SeguimientoGestacion?> obtenerPorId(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _registros.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SeguimientoGestacion> crear(CrearSeguimientoDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final nuevo = SeguimientoGestacion(
      id: _correlativo++,
      animalId: dto.animalId,
      machoId: dto.machoId,
      tipo: dto.tipo,
      fechaInseminacion: dto.fechaInseminacion,
      fechaEstimadaParto: dto.fechaEstimadaParto,
      estado: 'Pendiente',
      notas: dto.notas,
      creadoPor: _usuarioDemo,
    );
    _registros.add(nuevo);
    return nuevo;
  }

  @override
  Future<SeguimientoGestacion> actualizar(
      int id, ActualizarSeguimientoDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _registros.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _registros[idx];
    if (actual.estaCerrado) {
      throw Exception(
          'El registro ya está cerrado y no se puede editar (mock)');
    }
    final actualizado = SeguimientoGestacion(
      id: actual.id,
      animalId: actual.animalId,
      machoId: dto.machoId ?? actual.machoId,
      tipo: dto.tipo ?? actual.tipo,
      fechaInseminacion: dto.fechaInseminacion ?? actual.fechaInseminacion,
      fechaEstimadaParto: dto.fechaEstimadaParto ?? actual.fechaEstimadaParto,
      estado: actual.estado,
      notas: dto.notas ?? actual.notas,
      animal: actual.animal,
      macho: actual.macho,
      creadoPor: actual.creadoPor,
      confirmadoPor: actual.confirmadoPor,
      confirmadoEn: actual.confirmadoEn,
      cerradoPor: actual.cerradoPor,
      cerradoEn: actual.cerradoEn,
    );
    _registros[idx] = actualizado;
    return actualizado;
  }

  @override
  Future<SeguimientoGestacion> confirmar(int id, {String? notas}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _registros.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _registros[idx];
    if (!actual.estaPendiente) {
      throw Exception(
          'Solo se puede confirmar un seguimiento en estado Pendiente (mock)');
    }
    final actualizado = SeguimientoGestacion(
      id: actual.id,
      animalId: actual.animalId,
      machoId: actual.machoId,
      tipo: actual.tipo,
      fechaInseminacion: actual.fechaInseminacion,
      fechaEstimadaParto: actual.fechaEstimadaParto,
      estado: 'Gestante',
      notas: notas ?? actual.notas,
      animal: actual.animal,
      macho: actual.macho,
      creadoPor: actual.creadoPor,
      confirmadoPor: _usuarioDemo,
      confirmadoEn: DateTime.now(),
    );
    _registros[idx] = actualizado;
    return actualizado;
  }

  @override
  Future<SeguimientoGestacion> cerrar(int id, CerrarSeguimientoDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _registros.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _registros[idx];
    if (actual.estaCerrado) {
      throw Exception('El registro ya fue cerrado (mock)');
    }
    final actualizado = SeguimientoGestacion(
      id: actual.id,
      animalId: actual.animalId,
      machoId: actual.machoId,
      tipo: actual.tipo,
      fechaInseminacion: actual.fechaInseminacion,
      fechaEstimadaParto: actual.fechaEstimadaParto,
      fechaRealParto: dto.fechaRealParto ?? actual.fechaRealParto,
      estado: dto.resultado,
      notas: dto.notas ?? actual.notas,
      animal: actual.animal,
      macho: actual.macho,
      creadoPor: actual.creadoPor,
      confirmadoPor: actual.confirmadoPor,
      confirmadoEn: actual.confirmadoEn,
      cerradoPor: _usuarioDemo,
      cerradoEn: DateTime.now(),
    );
    _registros[idx] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminar(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _registros.removeWhere((r) => r.id == id);
  }
}
