import '../../core/api_client.dart';
import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';
import 'produccion_repository.dart';

class ApiProduccionRepository implements ProduccionRepository {
  final ApiClient client;

  ApiProduccionRepository({required this.client});

  @override
  Future<List<ProduccionLeche>> listarLeche({int? animalId}) async {
    final data = await client.get('/produccion-leche', query: {
      if (animalId != null) 'animal_id': animalId,
    }) as List<dynamic>;
    return data.map((e) => ProduccionLeche.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ProduccionLeche> crearLeche(CrearProduccionLecheDTO dto) async {
    final data = await client.post('/produccion-leche', body: dto.toJson());
    return ProduccionLeche.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<ProduccionLeche> actualizarLeche(int id, ActualizarProduccionLecheDTO dto) async {
    final data = await client.put('/produccion-leche/$id', body: dto.toJson());
    return ProduccionLeche.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> eliminarLeche(int id) async {
    await client.delete('/produccion-leche/$id');
  }

  @override
  Future<List<ProduccionHuevos>> listarHuevos({int? loteId}) async {
    final data = await client.get('/produccion-huevos', query: {
      if (loteId != null) 'lote_id': loteId,
    }) as List<dynamic>;
    return data.map((e) => ProduccionHuevos.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ProduccionHuevos> crearHuevos(CrearProduccionHuevosDTO dto) async {
    final data = await client.post('/produccion-huevos', body: dto.toJson());
    return ProduccionHuevos.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<ProduccionHuevos> actualizarHuevos(int id, ActualizarProduccionHuevosDTO dto) async {
    final data = await client.put('/produccion-huevos/$id', body: dto.toJson());
    return ProduccionHuevos.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> eliminarHuevos(int id) async {
    await client.delete('/produccion-huevos/$id');
  }
}
