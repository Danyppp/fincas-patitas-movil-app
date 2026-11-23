import '../../models/financiera/producto_stock.dart';
import '../../models/inventario/movimiento_stock.dart';
import 'stock_repository.dart';

class MockStockRepository implements StockRepository {
  final List<ProductoStock> _stock = [
    const ProductoStock(
        id: 1, nombre: 'Huevos', unidad: 'unidades', stockActual: 100),
    const ProductoStock(
        id: 2, nombre: 'Leche', unidad: 'litros', stockActual: 12.5),
  ];

  final List<MovimientoStock> _movimientos = [
    MovimientoStock(
      id: 2,
      producto: 'Leche',
      unidad: 'litros',
      tipo: 'Ajuste',
      cantidad: 12.5,
      origen: 'Manual',
      motivo: 'Stock inicial',
      usuario: 'demo',
      fecha: DateTime(2026, 11, 20, 8),
    ),
    MovimientoStock(
      id: 1,
      producto: 'Huevos',
      unidad: 'unidades',
      tipo: 'Ajuste',
      cantidad: 100,
      origen: 'Manual',
      motivo: 'Stock inicial',
      usuario: 'demo',
      fecha: DateTime(2026, 11, 20, 8),
    ),
  ];

  @override
  Future<List<ProductoStock>> listarStock() async => List.of(_stock);

  @override
  Future<List<MovimientoStock>> listarMovimientos(
      {String? producto, int limite = 50}) async {
    final lista = producto == null
        ? _movimientos
        : _movimientos.where((m) => m.producto == producto);
    return lista.take(limite).toList();
  }

  @override
  Future<void> ajustar({
    required String producto,
    required double cantidad,
    required String motivo,
  }) async {
    final i = _stock.indexWhere((p) => p.nombre == producto);
    if (i < 0) return;
    final p = _stock[i];
    if (p.stockActual + cantidad < 0) {
      throw Exception('Stock insuficiente');
    }
    _stock[i] = ProductoStock(
        id: p.id,
        nombre: p.nombre,
        unidad: p.unidad,
        stockActual: p.stockActual + cantidad);
    _movimientos.insert(
      0,
      MovimientoStock(
        id: _movimientos.length + 1,
        producto: producto,
        unidad: p.unidad,
        tipo: 'Ajuste',
        cantidad: cantidad,
        origen: 'Manual',
        motivo: motivo,
        usuario: 'demo',
        fecha: DateTime.now(),
      ),
    );
  }
}
