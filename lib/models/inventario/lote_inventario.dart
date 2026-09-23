/// Lote de un insumo (`lotes_inventario` en el backend). Un insumo puede
/// tener varios lotes con vencimientos distintos — por eso "vencimiento"
/// no es un campo del insumo, sino que se consulta aparte por insumo
/// (decisión de Dany, 2026-09-23: sí mostrar el vencimiento más próximo
/// en la tarjeta del listado, aunque implique una consulta extra por
/// insumo, igual que la segunda consulta de genealogía en Animales).
class LoteInventario {
  final int id;
  final int insumoId;
  final String? numeroLote;
  final DateTime fechaVencimiento;
  final double cantidadDisponible;
  final double costoUnitario;

  const LoteInventario({
    required this.id,
    required this.insumoId,
    required this.fechaVencimiento,
    required this.cantidadDisponible,
    required this.costoUnitario,
    this.numeroLote,
  });

  factory LoteInventario.fromJson(Map<String, dynamic> json) {
    return LoteInventario(
      id: json['id'] as int,
      insumoId: json['insumo_id'] as int,
      numeroLote: json['numero_lote'] as String?,
      fechaVencimiento: DateTime.parse(json['fecha_vencimiento'] as String),
      cantidadDisponible: _parseDouble(json['cantidad_disponible']) ?? 0,
      costoUnitario: _parseDouble(json['costo_unitario']) ?? 0,
    );
  }

  static double? _parseDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }
}
