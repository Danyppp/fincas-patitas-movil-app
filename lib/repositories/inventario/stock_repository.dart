import '../../models/financiera/producto_stock.dart';
import '../../models/inventario/movimiento_stock.dart';

/// Stock de los productos de finca (Huevos y Leche): consulta, historial
/// de movimientos y ajuste manual. El stock sube solo con la producción y
/// baja con las ventas; aquí solo se consulta o se ajusta a mano.
abstract class StockRepository {
  Future<List<ProductoStock>> listarStock();

  /// Más recientes primero. [producto] filtra por 'Huevos' o 'Leche'.
  Future<List<MovimientoStock>> listarMovimientos(
      {String? producto, int limite});

  /// Ajuste manual (`POST /stock/ajuste`). [cantidad] puede ser negativa y
  /// el [motivo] es obligatorio. El backend rechaza dejar el stock en
  /// negativo y exige enteros para los huevos.
  Future<void> ajustar({
    required String producto,
    required double cantidad,
    required String motivo,
  });
}
