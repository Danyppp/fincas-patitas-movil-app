import '../../models/reproduccion/seguimiento_gestacion.dart';
import 'reproduccion_repository.dart';

class MockReproduccionRepository implements ReproduccionRepository {
  final List<SeguimientoGestacion> _registros = [
    SeguimientoGestacion(
      id: 1,
      animalId: 1,
      tipo: 'IA',
      fechaInseminacion: DateTime.now().subtract(const Duration(days: 30)),
      fechaEstimadaParto: DateTime.now().add(const Duration(days: 253)),
      estado: 'Gestante',
      animal: const AnimalReferencia(id: 1, codigo: 'ANI-0001', nombre: 'Lucera'),
    ),
  ];
  int _correlativo = 2;

  @override
  Future<List<SeguimientoGestacion>> listar({int? animalId, String? estado}) async {
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
      estado: dto.estado ?? 'Gestante',
      notas: dto.notas,
    );
    _registros.add(nuevo);
    return nuevo;
  }

  @override
  Future<SeguimientoGestacion> actualizar(int id, ActualizarSeguimientoDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _registros.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _registros[idx];
    final actualizado = SeguimientoGestacion(
      id: actual.id,
      animalId: actual.animalId,
      machoId: dto.machoId ?? actual.machoId,
      tipo: dto.tipo ?? actual.tipo,
      fechaInseminacion: dto.fechaInseminacion ?? actual.fechaInseminacion,
      fechaEstimadaParto: dto.fechaEstimadaParto ?? actual.fechaEstimadaParto,
      fechaRealParto: dto.fechaRealParto ?? actual.fechaRealParto,
      estado: dto.estado ?? actual.estado,
      notas: dto.notas ?? actual.notas,
      animal: actual.animal,
      macho: actual.macho,
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
