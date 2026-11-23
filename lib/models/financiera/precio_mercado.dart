import '../../utils/fecha_dia.dart';

/// Productos con precio de mercado en la app (decisión de Dany,
/// 2026-11-19: "Leche" y "Huevos"; otros productos quedan fuera por ahora).
const productosConPrecio = ['Leche', 'Huevos'];

/// Modelo de la tabla real `precios_mercado` (`/api/precios-mercado`).
///
/// Cada precio es una fila NUEVA con su fecha de vigencia: no se
/// sobrescribe el anterior, así que la lista completa es el historial. El
/// precio "vigente" de un producto es el más reciente (se calcula en el
/// cliente, no lo manda el backend).
///
/// - `precio` es Decimal en Prisma: llega como STRING en el JSON.
/// - `fecha` es una fecha de calendario (columna `DATE`): se lee con
///   [FechaDia].
class PrecioMercado {
  final int id;
  final String producto;
  final double precio;
  final DateTime fecha;

  const PrecioMercado({
    required this.id,
    required this.producto,
    required this.precio,
    required this.fecha,
  });

  /// Unidad derivada del producto (decisión de Dany, 2026-11-19): Leche en
  /// litros, Huevos en unidades. Coincidencia parcial sin distinguir
  /// mayúsculas, igual que la web. Para otros productos devuelve vacío.
  String get unidad {
    final nombre = producto.toLowerCase();
    if (nombre.contains('leche')) return 'L';
    if (nombre.contains('huevo')) return 'unid.';
    return '';
  }

  factory PrecioMercado.fromJson(Map<String, dynamic> json) {
    return PrecioMercado(
      id: json['id'] as int,
      producto: json['producto'] as String,
      precio: _parseDouble(json['precio']) ?? 0,
      fecha: FechaDia.parseRequerida(json['fecha']),
    );
  }

  static double? _parseDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }
}

/// DTO para `POST /api/precios-mercado`. Obligatorios: producto, precio
/// (> 0) y fecha de vigencia.
class CrearPrecioMercadoDTO {
  final String producto;
  final double precio;
  final DateTime fecha;

  const CrearPrecioMercadoDTO({
    required this.producto,
    required this.precio,
    required this.fecha,
  });

  Map<String, dynamic> toJson() => {
        'producto': producto,
        'precio': precio,
        'fecha': FechaDia.formatear(fecha),
      };
}

/// DTO para `PUT /api/precios-mercado/:id`. Solo se envía lo que no es
/// nulo.
class ActualizarPrecioMercadoDTO {
  final String? producto;
  final double? precio;
  final DateTime? fecha;

  const ActualizarPrecioMercadoDTO({this.producto, this.precio, this.fecha});

  Map<String, dynamic> toJson() => {
        if (producto != null) 'producto': producto,
        if (precio != null) 'precio': precio,
        if (fecha != null) 'fecha': FechaDia.formatear(fecha!),
      };
}
