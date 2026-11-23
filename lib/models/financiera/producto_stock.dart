/// Stock de un producto de finca (`GET /api/stock`): Huevos en unidades y
/// Leche en litros. El stock sube con la producción y baja con las ventas;
/// el backend nunca lo deja en negativo.
///
/// `stock_actual` es Decimal en Prisma: llega como STRING en el JSON.
class ProductoStock {
  final int id;
  final String nombre;
  final String unidad;
  final double stockActual;

  const ProductoStock({
    required this.id,
    required this.nombre,
    required this.unidad,
    required this.stockActual,
  });

  factory ProductoStock.fromJson(Map<String, dynamic> json) {
    return ProductoStock(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      unidad: json['unidad'] as String,
      stockActual: _parseDouble(json['stock_actual']) ?? 0,
    );
  }

  static double? _parseDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }
}
