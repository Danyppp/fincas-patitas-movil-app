import '../models/animal.dart';
import '../models/sexo.dart';
import '../models/species.dart';
import 'animal_repository.dart';

/// Implementación con datos de referencia.
///
/// Se usa mientras el backend de Milena (Express + TS sobre Neon) no
/// tenga listos los endpoints de animales. El `Future.delayed` simula
/// latencia de red para que las pantallas ya manejen sus estados de
/// carga desde ahora.
class MockAnimalRepository implements AnimalRepository {
  static final _bovino = Species(
    id: 'sp-bovino',
    name: 'bovino',
    displayName: 'Bovino',
    gestationDays: 283,
    isProductiveMilk: true,
  );

  static final _porcino = Species(
    id: 'sp-porcino',
    name: 'porcino',
    displayName: 'Porcino',
    gestationDays: 114,
    isProductiveMilk: false,
  );

  static final List<Animal> _animales = [
    Animal(
      id: 'a1',
      code: 'CER-2026-00001',
      name: 'Lola',
      sex: Sexo.hembra,
      speciesId: _bovino.id,
      breedId: null,
      birthDate: DateTime(2023, 4, 12),
      acquisitionDate: DateTime(2023, 4, 20),
      origin: 'Nacida en finca',
      initialWeightKg: 32,
      currentWeightKg: 410,
      healthStatus: 'sana',
      vaccinationStatus: 'al_dia',
      reproductiveStatus: 'gestante',
      status: 'activo',
      notes: 'Buena productora de leche.',
      createdAt: DateTime(2023, 4, 20),
      updatedAt: DateTime(2026, 8, 20),
      species: _bovino,
    ),
    Animal(
      id: 'a2',
      code: 'CER-2026-00002',
      name: 'Toro Bravo',
      sex: Sexo.macho,
      speciesId: _bovino.id,
      breedId: null,
      birthDate: DateTime(2022, 1, 5),
      acquisitionDate: DateTime(2022, 6, 1),
      origin: 'Comprado',
      initialWeightKg: 60,
      currentWeightKg: 560,
      healthStatus: 'sana',
      vaccinationStatus: 'al_dia',
      reproductiveStatus: 'activo',
      status: 'activo',
      notes: null,
      createdAt: DateTime(2022, 6, 1),
      updatedAt: DateTime(2026, 7, 2),
      species: _bovino,
    ),
    Animal(
      id: 'a3',
      code: 'CER-2026-00003',
      name: 'Pecas',
      sex: Sexo.hembra,
      speciesId: _porcino.id,
      breedId: null,
      birthDate: DateTime(2024, 9, 1),
      acquisitionDate: DateTime(2024, 9, 10),
      origin: 'Nacida en finca',
      initialWeightKg: 1.4,
      currentWeightKg: 95,
      healthStatus: 'en_observacion',
      vaccinationStatus: 'pendiente',
      reproductiveStatus: 'no_aplica',
      status: 'activo',
      notes: 'Revisar cojera en pata trasera.',
      createdAt: DateTime(2024, 9, 10),
      updatedAt: DateTime(2026, 8, 28),
      species: _porcino,
    ),
  ];

  @override
  Future<List<Animal>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.unmodifiable(_animales);
  }

  @override
  Future<Animal> getById(String id) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _animales.firstWhere(
      (a) => a.id == id,
      orElse: () => throw StateError('Animal no encontrado: $id'),
    );
  }

  @override
  Future<Animal> create(CreateAnimalDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final nuevo = Animal(
      id: 'a${_animales.length + 1}',
      code: 'CER-2026-${(_animales.length + 1).toString().padLeft(5, '0')}',
      name: dto.name,
      sex: dto.sex,
      speciesId: dto.speciesId,
      breedId: dto.breedId,
      birthDate: dto.birthDate,
      healthStatus: 'sana',
      vaccinationStatus: 'pendiente',
      reproductiveStatus: 'no_aplica',
      status: 'activo',
      notes: dto.notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _animales.add(nuevo);
    return nuevo;
  }
}
