import '../../models/animal.dart';
import '../../models/catalogo/especie.dart';
import '../../models/catalogo/raza.dart';
import '../../models/pagina.dart';
import 'animal_repository.dart';

class MockAnimalRepository implements AnimalRepository {
  final List<Animal> _animales = [
    const Animal(
      id: 1,
      codigo: 'ANI-0001',
      nombre: 'Lucera',
      genero: 'Hembra',
      estado: 'Activo',
      especieId: 1,
      razaId: 1,
      especie: Especie(id: 1, nombre: 'Vaca'),
      raza: Raza(id: 1, especieId: 1, nombre: 'Holstein'),
    ),
    const Animal(
      id: 2,
      codigo: 'ANI-0002',
      nombre: 'Pinto',
      genero: 'Macho',
      estado: 'Activo',
      especieId: 2,
      razaId: 3,
      especie: Especie(id: 2, nombre: 'Cerdo'),
      raza: Raza(id: 3, especieId: 2, nombre: 'Yorkshire'),
    ),
  ];
  int _correlativo = 3;

  @override
  Future<Pagina<Animal>> listar({
    int? especieId,
    int? razaId,
    int? loteId,
    String? estado,
    String? genero,
    String? buscar,
    int pagina = 1,
    int limite = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var filtrados = _animales.where((a) {
      if (especieId != null && a.especieId != especieId) return false;
      if (razaId != null && a.razaId != razaId) return false;
      if (estado != null && estado != 'Todos' && a.estado != estado) return false;
      if (genero != null && a.genero != genero) return false;
      if (buscar != null && buscar.isNotEmpty) {
        final q = buscar.toLowerCase();
        if (!a.nombreVisible.toLowerCase().contains(q) && !a.codigo.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Pagina(
      data: filtrados,
      pagina: 1,
      limite: filtrados.length,
      total: filtrados.length,
      totalPaginas: 1,
    );
  }

  @override
  Future<Animal?> obtenerPorId(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _animales.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> obtenerHistorial(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return {
      'eventosSanitarios': [],
      'produccionLeche': [],
      'registrosPeso': [],
      'seguimientoGestacion': [],
      'lineaDeTiempo': [],
    };
  }

  @override
  Future<Animal> crear(CrearAnimalDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final nuevo = Animal(
      id: _correlativo,
      codigo: 'ANI-${_correlativo.toString().padLeft(4, '0')}',
      nombre: dto.nombre,
      genero: dto.genero,
      estado: dto.estado ?? 'Activo',
      especieId: dto.especieId,
      razaId: dto.razaId,
      loteId: dto.loteId,
      potreroId: dto.potreroId,
      madreId: dto.madreId,
      padreId: dto.padreId,
      fechaNacimiento: dto.fechaNacimiento,
      fechaIngreso: dto.fechaIngreso,
      origen: dto.origen,
    );
    _animales.add(nuevo);
    _correlativo++;
    return nuevo;
  }

  @override
  Future<Animal> actualizar(int id, ActualizarAnimalDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _animales.indexWhere((a) => a.id == id);
    if (idx == -1) throw Exception('Animal no encontrado (mock)');
    final actual = _animales[idx];
    final actualizado = Animal(
      id: actual.id,
      codigo: actual.codigo,
      nombre: dto.nombre ?? actual.nombre,
      genero: dto.genero ?? actual.genero,
      estado: dto.estado ?? actual.estado,
      especieId: dto.especieId ?? actual.especieId,
      razaId: dto.razaId ?? actual.razaId,
      loteId: dto.loteId ?? actual.loteId,
      potreroId: dto.potreroId ?? actual.potreroId,
      madreId: dto.madreId ?? actual.madreId,
      padreId: dto.padreId ?? actual.padreId,
      fechaNacimiento: dto.fechaNacimiento ?? actual.fechaNacimiento,
      fechaIngreso: dto.fechaIngreso ?? actual.fechaIngreso,
      origen: dto.origen ?? actual.origen,
      especie: actual.especie,
      raza: actual.raza,
    );
    _animales[idx] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminar(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _animales.removeWhere((a) => a.id == id);
  }
}
