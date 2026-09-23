import '../../core/api_client.dart';
import '../../models/inventario/insumo.dart';
import 'insumo_repository.dart';

class ApiInsumoRepository implements InsumoRepository {
  final ApiClient client;

  ApiInsumoRepository({required this.client});

  @override
  Future<List<Insumo>> listar({int? categoriaId, bool soloStockBajo = false}) async {
    // HU-18: el backend expone un endpoint aparte para stock bajo
    // (`/bodega/alertas/stock-bajo`); no es un filtro de query en `/bodega`.
    final data = soloStockBajo
        ? await client.get('/bodega/alertas/stock-bajo')
        : await client.get('/bodega', query: {
            if (categoriaId != null) 'categoria_id': categoriaId,
          });
    return (data as List<dynamic>)
        .map((i) => Insumo.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Insumo?> obtenerPorId(int id) async {
    final data = await client.get('/bodega/$id');
    if (data == null) return null;
    return Insumo.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Insumo> crear(CrearInsumoDTO dto) async {
    final data = await client.post('/bodega', body: dto.toJson());
    return Insumo.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Insumo> actualizar(int id, ActualizarInsumoDTO dto) async {
    final data = await client.put('/bodega/$id', body: dto.toJson());
    return Insumo.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> eliminar(int id) async {
    await client.delete('/bodega/$id');
  }

  @override
  Future<Insumo> registrarMovimiento(
    int insumoId, {
    required String tipo,
    required double cantidad,
    required String motivo,
  }) async {
    final data = await client.post('/bodega/$insumoId/movimientos', body: {
      'tipo': tipo,
      'cantidad': cantidad,
      'motivo': motivo,
    }) as Map<String, dynamic>;
    // El backend devuelve el registro del movimiento, con el insumo
    // actualizado anidado en `.bodega` (ver hallazgo documentado en
    // decisiones-diseno-vs-backend-inventario.md, sección 0).
    return Insumo.fromJson(data['bodega'] as Map<String, dynamic>);
  }
}
