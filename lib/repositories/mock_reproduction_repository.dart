import '../models/reproduccion/event_type.dart';
import '../models/reproduccion/reproductive_event.dart';
import 'reproduction_repository.dart';

/// Datos de referencia para el módulo de Reproducción, hasta que el
/// backend de Milena tenga los endpoints listos.
class MockReproductionRepository implements ReproductionRepository {
  static final List<ReproductiveEvent> _eventos = [
    ReproductiveEvent(
      id: 'r1',
      animalId: 'a1',
      eventType: EventType.inseminacionArtificial,
      eventDate: DateTime(2026, 6, 10),
      gestationStatus: GestationStatus.confirmada,
      estimatedDeliveryDate: DateTime(2027, 3, 20),
      estimatedDeliveryDateTo: DateTime(2027, 3, 27),
      responsible: 'Milena',
      notes: 'Segundo intento, primero no prendió.',
      femaleAnimal: const ReproductiveAnimalMini(id: 'a1', code: 'CER-2026-00001', name: 'Lola'),
    ),
    ReproductiveEvent(
      id: 'r2',
      animalId: 'a3',
      fatherExternal: 'Semental vecino (finca La Esperanza)',
      eventType: EventType.montaNatural,
      eventDate: DateTime(2026, 7, 2),
      gestationStatus: GestationStatus.enSeguimiento,
      responsible: 'Dany',
      femaleAnimal: const ReproductiveAnimalMini(id: 'a3', code: 'CER-2026-00003', name: 'Pecas'),
    ),
  ];

  @override
  Future<List<ReproductiveEvent>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.unmodifiable(_eventos);
  }

  @override
  Future<ReproductiveEvent> create(CreateReproductiveEventDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final nuevo = ReproductiveEvent(
      id: 'r${_eventos.length + 1}',
      animalId: dto.animalId,
      fatherId: dto.fatherId,
      fatherExternal: dto.fatherExternal,
      eventType: dto.eventType,
      eventDate: dto.eventDate,
      gestationStatus: GestationStatus.enSeguimiento,
      responsible: dto.responsible,
      notes: dto.notes,
    );
    _eventos.add(nuevo);
    return nuevo;
  }

  @override
  Future<ReproductiveEvent> updateGestationStatus(
    String eventId,
    GestationStatus status,
  ) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final index = _eventos.indexWhere((e) => e.id == eventId);
    if (index == -1) {
      throw StateError('Evento no encontrado: $eventId');
    }
    final actual = _eventos[index];
    final actualizado = ReproductiveEvent(
      id: actual.id,
      animalId: actual.animalId,
      fatherId: actual.fatherId,
      fatherExternal: actual.fatherExternal,
      eventType: actual.eventType,
      eventDate: actual.eventDate,
      gestationStatus: status,
      estimatedDeliveryDate: actual.estimatedDeliveryDate,
      estimatedDeliveryDateTo: actual.estimatedDeliveryDateTo,
      responsible: actual.responsible,
      notes: actual.notes,
      femaleAnimal: actual.femaleAnimal,
      maleAnimal: actual.maleAnimal,
    );
    _eventos[index] = actualizado;
    return actualizado;
  }
}
