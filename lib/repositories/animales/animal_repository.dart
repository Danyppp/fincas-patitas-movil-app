import '../../models/animal.dart';
import '../../models/pagina.dart';

/// Contrato del módulo Animales contra `/api/animales`.
abstract class AnimalRepository {
  Future<Pagina<Animal>> listar({
    int? especieId,
    int? razaId,
    int? loteId,
    String? estado,
    String? genero,
    String? buscar,
    int pagina = 1,
    int limite = 20,
  });

  Future<Animal?> obtenerPorId(int id);

  /// `{ animal, historial: { eventosSanitarios, produccionLeche,
  /// registrosPeso, seguimientoGestacion, lineaDeTiempo } }`.
  Future<Map<String, dynamic>> obtenerHistorial(int id);

  Future<Animal> crear(CrearAnimalDTO dto);

  Future<Animal> actualizar(int id, ActualizarAnimalDTO dto);

  Future<void> eliminar(int id);
}
