import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../models/reproduccion/seguimiento_gestacion.dart' show AnimalReferencia;
import 'produccion_repository.dart';

class MockProduccionRepository implements ProduccionRepository {
  final List<ProduccionLeche> _leche = [
    ProduccionLeche(
      id: 1,
      animalId: 1,
      litros: 12.5,
      jornada: 'Mañana',
      registradoEn: DateTime.now(),
      animal: const AnimalReferencia(id: 1, codigo: 'ANI-0001', nombre: 'Lucera'),
    ),
    ProduccionLeche(
      id: 2,
      loteId: 1,
      litros: 40,
      jornada: 'Tarde',
      observaciones: 'Registro de ejemplo por lote',
      registradoEn: DateTime.now(),
      loteNombre: 'Lote 01',
    ),
  ];
  final List<ProduccionHuevos> _huevos = [
    ProduccionHuevos(id: 1, loteId: 1, cantidad: 24, cantidadRotos: 2, loteNombre: 'Lote 01', registradoEn: DateTime.now()),
  ];
  int _correlativoLeche = 3;
  int _correlativoHuevos = 2;

  @override
  Future<List<ProduccionLeche>> listarLeche({int? animalId, int? loteId}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _leche
        .where((r) => (animalId == null || r.animalId == animalId) && (loteId == null || r.loteId == loteId))
        .toList();
  }

  @override
  Future<ProduccionLeche> crearLeche(CrearProduccionLecheDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final nuevo = ProduccionLeche(
      id: _correlativoLeche++,
      animalId: dto.animalId,
      loteId: dto.loteId,
      litros: dto.litros,
      jornada: dto.jornada,
      observaciones: dto.observaciones,
      registradoEn: dto.registradoEn ?? DateTime.now(),
    );
    _leche.add(nuevo);
    return nuevo;
  }

  @override
  Future<ProduccionLeche> actualizarLeche(int id, ActualizarProduccionLecheDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _leche.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _leche[idx];
    final actualizado = ProduccionLeche(
      id: actual.id,
      animalId: actual.animalId,
      loteId: actual.loteId,
      litros: dto.litros ?? actual.litros,
      jornada: dto.jornada ?? actual.jornada,
      observaciones: dto.observaciones ?? actual.observaciones,
      registradoEn: dto.registradoEn ?? actual.registradoEn,
      animal: actual.animal,
      loteNombre: actual.loteNombre,
    );
    _leche[idx] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminarLeche(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _leche.removeWhere((r) => r.id == id);
  }

  @override
  Future<List<ProduccionHuevos>> listarHuevos({int? loteId, int? animalId}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _huevos
        .where((r) => (loteId == null || r.loteId == loteId) && (animalId == null || r.animalId == animalId))
        .toList();
  }

  @override
  Future<ProduccionHuevos> crearHuevos(CrearProduccionHuevosDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final nuevo = ProduccionHuevos(
      id: _correlativoHuevos++,
      loteId: dto.loteId,
      animalId: dto.animalId,
      cantidad: dto.cantidad,
      cantidadRotos: dto.cantidadRotos ?? 0,
      observaciones: dto.observaciones,
      registradoEn: dto.registradoEn ?? DateTime.now(),
    );
    _huevos.add(nuevo);
    return nuevo;
  }

  @override
  Future<ProduccionHuevos> actualizarHuevos(int id, ActualizarProduccionHuevosDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _huevos.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _huevos[idx];
    final actualizado = ProduccionHuevos(
      id: actual.id,
      loteId: actual.loteId,
      animalId: actual.animalId,
      cantidad: dto.cantidad ?? actual.cantidad,
      cantidadRotos: dto.cantidadRotos ?? actual.cantidadRotos,
      observaciones: dto.observaciones ?? actual.observaciones,
      registradoEn: dto.registradoEn ?? actual.registradoEn,
      loteNombre: actual.loteNombre,
      animal: actual.animal,
    );
    _huevos[idx] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminarHuevos(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _huevos.removeWhere((r) => r.id == id);
  }
}
