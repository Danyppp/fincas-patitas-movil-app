import '../../core/api_client.dart';
import '../../models/salud/evento_sanitario.dart';
import 'evento_sanitario_repository.dart';

class ApiEventoSanitarioRepository implements EventoSanitarioRepository {
  final ApiClient client;

  ApiEventoSanitarioRepository({required this.client});

  @override
  Future<List<EventoSanitario>> listar({
    int? animalId,
    String? tipoEvento,
    bool incluirEliminados = false,
  }) async {
    final data = await client.get('/eventos-sanitarios', query: {
      if (animalId != null) 'animal_id': animalId,
      if (tipoEvento != null) 'tipo_evento': tipoEvento,
      // 2026-11-01: solo se manda cuando es true -- mismo patrón de
      // Producción (`incluir_eliminados`), para no cambiar el
      // comportamiento por defecto de ninguna pantalla existente.
      if (incluirEliminados) 'incluir_eliminados': 'true',
    });
    return (data as List<dynamic>)
        .map((e) => EventoSanitario.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<EventoSanitario?> obtenerPorId(int id) async {
    final data = await client.get('/eventos-sanitarios/$id');
    if (data == null) return null;
    return EventoSanitario.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<EventoSanitario> crear(CrearEventoSanitarioDTO dto) async {
    final data = await client.post('/eventos-sanitarios', body: dto.toJson());
    return EventoSanitario.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<EventoSanitario> actualizar(
      int id, ActualizarEventoSanitarioDTO dto) async {
    final data =
        await client.put('/eventos-sanitarios/$id', body: dto.toJson());
    return EventoSanitario.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<EventoSanitario> cambiarEstado(int id, String estado) async {
    final data = await client
        .patch('/eventos-sanitarios/$id/estado', body: {'estado': estado});
    return EventoSanitario.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> eliminar(int id) async {
    await client.delete('/eventos-sanitarios/$id');
  }
}
