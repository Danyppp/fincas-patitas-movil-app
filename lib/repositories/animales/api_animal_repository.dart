import '../../core/api_client.dart';
import '../../models/animal.dart';
import '../../models/pagina.dart';
import 'animal_repository.dart';

class ApiAnimalRepository implements AnimalRepository {
  final ApiClient client;

  ApiAnimalRepository({required this.client});

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
    final data = await client.get('/animales', query: {
      if (especieId != null) 'especie_id': especieId,
      if (razaId != null) 'raza_id': razaId,
      if (loteId != null) 'lote_id': loteId,
      if (estado != null) 'estado': estado,
      if (genero != null) 'genero': genero,
      if (buscar != null && buscar.isNotEmpty) 'buscar': buscar,
      'page': pagina,
      'limit': limite,
    });
    return Pagina.fromJson(data as Map<String, dynamic>, Animal.fromJson);
  }

  @override
  Future<Animal?> obtenerPorId(int id) async {
    final data = await client.get('/animales/$id');
    if (data == null) return null;
    return Animal.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> obtenerHistorial(int id) async {
    final data = await client.get('/animales/$id/historial');
    return data as Map<String, dynamic>;
  }

  @override
  Future<Animal> crear(CrearAnimalDTO dto) async {
    final data = await client.post('/animales', body: dto.toJson());
    return Animal.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Animal> actualizar(int id, ActualizarAnimalDTO dto) async {
    final data = await client.put('/animales/$id', body: dto.toJson());
    return Animal.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> eliminar(int id) async {
    await client.delete('/animales/$id');
  }
}
