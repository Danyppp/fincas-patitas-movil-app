import '../../core/api_client.dart';
import '../../models/financiera/producto_stock.dart';
import '../../models/inventario/movimiento_stock.dart';
import 'stock_repository.dart';

class ApiStockRepository implements StockRepository {
  final ApiClient client;

  ApiStockRepository({required this.client});

  @override
  Future<List<ProductoStock>> listarStock() async {
    final data = await client.get('/stock') as List<dynamic>;
    return data
        .map((e) => ProductoStock.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<MovimientoStock>> listarMovimientos(
      {String? producto, int limite = 50}) async {
    final query = <String>['limite=$limite'];
    if (producto != null) query.add('producto=$producto');
    final data = await client.get('/stock/movimientos?${query.join('&')}')
        as List<dynamic>;
    return data
        .map((e) => MovimientoStock.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> ajustar({
    required String producto,
    required double cantidad,
    required String motivo,
  }) async {
    await client.post('/stock/ajuste', body: {
      'producto': producto,
      'cantidad': cantidad,
      'motivo': motivo,
    });
  }
}
