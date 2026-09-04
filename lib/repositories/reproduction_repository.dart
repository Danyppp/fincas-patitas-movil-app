import '../models/reproduccion/event_type.dart' show GestationStatus;
import '../models/reproduccion/reproductive_event.dart';

// Reexport para que las pantallas no tengan que importar el enum aparte.
export '../models/reproduccion/event_type.dart' show GestationStatus;

/// Contrato del repositorio de eventos reproductivos. Mismo patrón que
/// [AnimalRepository]: las pantallas solo conocen esta interfaz.
abstract class ReproductionRepository {
  Future<List<ReproductiveEvent>> getAll();
  Future<ReproductiveEvent> create(CreateReproductiveEventDTO dto);
  Future<ReproductiveEvent> updateGestationStatus(
    String eventId,
    GestationStatus status,
  );
}
