import 'categoria_bodega.dart';

/// Modelo de un insumo de bodega según la tabla real `bodega` (Prisma
/// schema del backend). OJO con el nombre: en el backend `bodega` NO es
/// una bodega física — es cada insumo/producto individual (medicamentos,
/// alimento, etc.). No existe el concepto de múltiples bodegas físicas en
/// este proyecto, por eso el modelo en el cliente se llama `Insumo` y no
/// `Bodega`, para no confundir a quien lea el código.
///
/// `descripcion` y `stockBajo` fueron confirmados con Dany:
/// - `descripcion`: columna agregada al backend (rama
///   `feature/inventario-registro-detallado`) para el subtítulo de la
///   tarjeta en el diseño (ej. "Aftogan • Frasco multidosis").
/// - `stockBajo`: el backend ya lo calcula y lo incluye en `GET /bodega`
///   (`stock_actual <= stock_minimo`); si no viene en la respuesta (por
///   ejemplo en `GET /bodega/:id`), se recalcula igual en el cliente como
///   respaldo.
class Insumo {
  final int id;
  final int categoriaId;
  final String nombre;
  final String? descripcion;
  final String unidadMedida;
  final double stockActual;
  final double stockMinimo;
  final bool stockBajo;
  final CategoriaBodega? categoria;

  const Insumo({
    required this.id,
    required this.categoriaId,
    required this.nombre,
    required this.unidadMedida,
    required this.stockActual,
    required this.stockMinimo,
    required this.stockBajo,
    this.descripcion,
    this.categoria,
  });

  /// Estados derivados en el cliente (el backend no los guarda, solo
  /// expone `stock_actual`/`stock_minimo`). Acordado con Dany el
  /// 2026-09-23:
  /// - Normal: stockActual > stockMinimo
  /// - Bajo: 0 < stockActual <= stockMinimo
  /// - Agotado: stockActual <= 0
  EstadoStock get estado {
    if (stockActual <= 0) return EstadoStock.agotado;
    if (stockActual <= stockMinimo) return EstadoStock.bajo;
    return EstadoStock.normal;
  }

  /// Bandera de "reposición urgente" (decisión de Dany, 2026-09-23):
  /// agotado o con una sola unidad disponible. Es solo informativa, no
  /// dispara ninguna orden de pedido (eso se descartó por completo).
  bool get reposicionUrgente => stockActual <= 0 || stockActual <= 1;

  factory Insumo.fromJson(Map<String, dynamic> json) {
    final stockActual = _parseDouble(json['stock_actual']) ?? 0;
    final stockMinimo = _parseDouble(json['stock_minimo']) ?? 0;
    return Insumo(
      id: json['id'] as int,
      categoriaId: json['categoria_id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      unidadMedida: json['unidad_medida'] as String,
      stockActual: stockActual,
      stockMinimo: stockMinimo,
      stockBajo: json['stock_bajo'] is bool
          ? json['stock_bajo'] as bool
          : stockActual <= stockMinimo,
      categoria: json['categorias_bodega'] is Map<String, dynamic>
          ? CategoriaBodega.fromJson(
              json['categorias_bodega'] as Map<String, dynamic>)
          : null,
    );
  }

  static double? _parseDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }

  /// Usado por el repositorio Mock y por la pantalla de Registro de
  /// Movimiento para reflejar en memoria el stock actualizado sin tener
  /// que volver a pedirle todo el insumo al backend.
  Insumo copyWith({
    double? stockActual,
    double? stockMinimo,
    String? nombre,
    String? descripcion,
    bool? stockBajo,
  }) {
    final nuevoStockActual = stockActual ?? this.stockActual;
    final nuevoStockMinimo = stockMinimo ?? this.stockMinimo;
    return Insumo(
      id: id,
      categoriaId: categoriaId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      unidadMedida: unidadMedida,
      stockActual: nuevoStockActual,
      stockMinimo: nuevoStockMinimo,
      stockBajo: stockBajo ?? (nuevoStockActual <= nuevoStockMinimo),
      categoria: categoria,
    );
  }
}

enum EstadoStock { normal, bajo, agotado }

/// DTO para `POST /api/bodega`. `stockInicial` es opcional (el backend lo
/// asume en 0 si no se manda).
class CrearInsumoDTO {
  final int categoriaId;
  final String nombre;
  final String? descripcion;
  final String unidadMedida;
  final double? stockInicial;
  final double? stockMinimo;

  const CrearInsumoDTO({
    required this.categoriaId,
    required this.nombre,
    required this.unidadMedida,
    this.descripcion,
    this.stockInicial,
    this.stockMinimo,
  });

  Map<String, dynamic> toJson() => {
        'categoria_id': categoriaId,
        'nombre': nombre,
        if (descripcion != null && descripcion!.isNotEmpty)
          'descripcion': descripcion,
        'unidad_medida': unidadMedida,
        if (stockInicial != null) 'stock_inicial': stockInicial,
        if (stockMinimo != null) 'stock_minimo': stockMinimo,
      };
}

/// DTO para `PUT /api/bodega/:id`. No incluye stock: el stock solo se
/// mueve a través de `POST /bodega/:id/movimientos` (registro de
/// movimiento), nunca editando el insumo directamente.
class ActualizarInsumoDTO {
  final int? categoriaId;
  final String? nombre;
  final String? descripcion;
  final String? unidadMedida;
  final double? stockMinimo;

  const ActualizarInsumoDTO({
    this.categoriaId,
    this.nombre,
    this.descripcion,
    this.unidadMedida,
    this.stockMinimo,
  });

  Map<String, dynamic> toJson() => {
        if (categoriaId != null) 'categoria_id': categoriaId,
        if (nombre != null) 'nombre': nombre,
        if (descripcion != null) 'descripcion': descripcion,
        if (unidadMedida != null) 'unidad_medida': unidadMedida,
        if (stockMinimo != null) 'stock_minimo': stockMinimo,
      };
}
