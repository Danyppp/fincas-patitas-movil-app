/// Movimiento del stock de un producto de finca
/// (`GET /api/stock/movimientos`): una entrada (producción), una salida
/// (venta) o un ajuste manual. Todo cambio en el stock de Huevos o Leche
/// deja uno de estos registros.
///
/// `cantidad` es Decimal en Prisma: llega como STRING en el JSON. En un
/// ajuste puede ser negativa.
class MovimientoStock {
  final int id;
  final String producto; // 'Huevos' | 'Leche'
  final String unidad; // 'unidades' | 'litros'
  final String tipo; // 'Entrada' | 'Salida' | 'Ajuste'
  final double cantidad;
  final String
      origen; // 'ProduccionHuevos' | 'ProduccionLeche' | 'Venta' | 'Manual'
  final String? motivo;
  final String? usuario;
  final DateTime fecha;

  const MovimientoStock({
    required this.id,
    required this.producto,
    required this.unidad,
    required this.tipo,
    required this.cantidad,
    required this.origen,
    required this.fecha,
    this.motivo,
    this.usuario,
  });

  factory MovimientoStock.fromJson(Map<String, dynamic> json) {
    final productoJson = json['productos_finca'] as Map<String, dynamic>?;
    final usuarioJson = json['usuarios'] as Map<String, dynamic>?;
    return MovimientoStock(
      id: json['id'] as int,
      producto: (productoJson?['nombre'] as String?) ?? '',
      unidad: (productoJson?['unidad'] as String?) ?? '',
      tipo: json['tipo'] as String,
      cantidad: _parseDouble(json['cantidad']) ?? 0,
      origen: json['origen'] as String,
      motivo: json['motivo'] as String?,
      usuario: usuarioJson?['nombre_usuario'] as String?,
      fecha: DateTime.parse(json['fecha'] as String).toLocal(),
    );
  }

  /// Texto legible del origen, para no mostrar los nombres internos.
  String get origenTexto {
    switch (origen) {
      case 'ProduccionHuevos':
        return 'Producción de huevos';
      case 'ProduccionLeche':
        return 'Producción de leche';
      case 'Venta':
        return 'Venta';
      case 'Manual':
        return 'Ajuste manual';
      default:
        return origen;
    }
  }

  static double? _parseDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }
}
