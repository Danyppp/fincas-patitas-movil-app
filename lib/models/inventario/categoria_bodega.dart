/// Categoría de insumo de bodega (`GET /api/categorias-bodega`). El
/// backend devuelve un arreglo plano `[{id, nombre}]`, igual que
/// especies/razas en el módulo Animales.
class CategoriaBodega {
  final int id;
  final String nombre;

  const CategoriaBodega({required this.id, required this.nombre});

  factory CategoriaBodega.fromJson(Map<String, dynamic> json) {
    return CategoriaBodega(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
    );
  }

  @override
  String toString() => nombre;
}
