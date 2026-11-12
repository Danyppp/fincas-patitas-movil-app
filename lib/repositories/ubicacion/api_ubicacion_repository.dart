import '../../core/api_client.dart';
import '../../models/animal.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';
import 'ubicacion_repository.dart';

class ApiUbicacionRepository implements UbicacionRepository {
  final ApiClient client;

  ApiUbicacionRepository({required this.client});

  // -- Lotes --

  @override
  Future<List<LoteAnimal>> listarLotes() async {
    final data = await client.get('/lotes-animales') as List<dynamic>;
    return data
        .map((l) => LoteAnimal.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<LoteAnimal?> obtenerLote(int id) async {
    final data =
        await client.get('/lotes-animales/$id') as Map<String, dynamic>?;
    return data != null ? LoteAnimal.fromJson(data) : null;
  }

  @override
  Future<LoteAnimal> crearLote(CrearLoteDTO dto) async {
    final data = await client.post('/lotes-animales', body: dto.toJson())
        as Map<String, dynamic>;
    return LoteAnimal.fromJson(data);
  }

  @override
  Future<LoteAnimal> actualizarLote(int id, ActualizarLoteDTO dto) async {
    final data = await client.put('/lotes-animales/$id', body: dto.toJson())
        as Map<String, dynamic>;
    return LoteAnimal.fromJson(data);
  }

  @override
  Future<void> eliminarLote(int id) async {
    await client.delete('/lotes-animales/$id');
  }

  @override
  Future<LoteAnimal> asignarEncargadoLote(int id, int? encargadoId) async {
    final data = await client.patch('/lotes-animales/$id/encargado',
        body: {'encargado_id': encargadoId}) as Map<String, dynamic>;
    return LoteAnimal.fromJson(data);
  }

  // -- Potreros --

  @override
  Future<List<Potrero>> listarPotreros() async {
    // El comentario @openapi de potrero.routes.ts dice '/potreros', pero
    // el montaje real en routes/index.ts es '/ubicaciones-potreros'.
    final data = await client.get('/ubicaciones-potreros') as List<dynamic>;
    return data
        .map((p) => Potrero.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Potrero?> obtenerPotrero(int id) async {
    final data =
        await client.get('/ubicaciones-potreros/$id') as Map<String, dynamic>?;
    return data != null ? Potrero.fromJson(data) : null;
  }

  @override
  Future<Potrero> crearPotrero(CrearPotreroDTO dto) async {
    final data = await client.post('/ubicaciones-potreros', body: dto.toJson())
        as Map<String, dynamic>;
    return Potrero.fromJson(data);
  }

  @override
  Future<Potrero> actualizarPotrero(int id, ActualizarPotreroDTO dto) async {
    final data = await client.put('/ubicaciones-potreros/$id',
        body: dto.toJson()) as Map<String, dynamic>;
    return Potrero.fromJson(data);
  }

  @override
  Future<void> eliminarPotrero(int id) async {
    await client.delete('/ubicaciones-potreros/$id');
  }

  @override
  Future<List<Animal>> animalesDelPotrero(int id) async {
    final data = await client.get('/ubicaciones-potreros/$id/animales')
        as Map<String, dynamic>;
    final animales = data['animales'] as List<dynamic>;
    return animales
        .map((a) => Animal.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Potrero> agregarEncargadoPotrero(int id, int usuarioId) async {
    final data = await client.post('/ubicaciones-potreros/$id/encargados',
        body: {'usuario_id': usuarioId}) as Map<String, dynamic>;
    return Potrero.fromJson(data);
  }

  @override
  Future<Potrero> quitarEncargadoPotrero(int id, int usuarioId) async {
    final data =
        await client.delete('/ubicaciones-potreros/$id/encargados/$usuarioId')
            as Map<String, dynamic>;
    return Potrero.fromJson(data);
  }

  @override
  Future<Potrero> subirFotoPotrero(
    int id, {
    required List<int> bytes,
    required String nombreArchivo,
  }) async {
    final data = await client.postMultipart(
      '/ubicaciones-potreros/$id/foto',
      bytes: bytes,
      campo: 'foto',
      nombreArchivo: nombreArchivo,
    ) as Map<String, dynamic>;
    return Potrero.fromJson(data);
  }
}
