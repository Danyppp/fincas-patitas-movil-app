import '../../core/api_client.dart';
import '../../models/reproduccion/seguimiento_gestacion.dart';
import 'reproduccion_repository.dart';

class ApiReproduccionRepository implements ReproduccionRepository {
  final ApiClient client;

  ApiReproduccionRepository({required this.client});

  @override
  Future<List<SeguimientoGestacion>> listar({
    int? animalId,
    String? estado,
    bool incluirEliminados = false,
  }) async {
    final data = await client.get('/reproduccion', query: {
      if (animalId != null) 'animal_id': animalId,
      if (estado != null) 'estado': estado,
      // Solo se manda cuando es true -- mismo patrón que el resto de la
      // app, para no cambiar el comportamiento por defecto de nadie más.
      if (incluirEliminados) 'incluirEliminados': 'true',
    }) as List<dynamic>;
    return data
        .map((e) => SeguimientoGestacion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<SeguimientoGestacion?> obtenerPorId(int id) async {
    final data = await client.get('/reproduccion/$id');
    if (data == null) return null;
    return SeguimientoGestacion.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<SeguimientoGestacion> crear(CrearSeguimientoDTO dto) async {
    final data = await client.post('/reproduccion', body: dto.toJson());
    return SeguimientoGestacion.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<SeguimientoGestacion> actualizar(
      int id, ActualizarSeguimientoDTO dto) async {
    final data = await client.put('/reproduccion/$id', body: dto.toJson());
    return SeguimientoGestacion.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<SeguimientoGestacion> confirmar(int id, {String? notas}) async {
    final data = await client.patch(
      '/reproduccion/$id/confirmar',
      body: notas == null || notas.isEmpty ? null : {'notas': notas},
    );
    return SeguimientoGestacion.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<SeguimientoGestacion> cerrar(int id, CerrarSeguimientoDTO dto) async {
    final data =
        await client.patch('/reproduccion/$id/cerrar', body: dto.toJson());
    return SeguimientoGestacion.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> eliminar(int id) async {
    await client.delete('/reproduccion/$id');
  }
}
