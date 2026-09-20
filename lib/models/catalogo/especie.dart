/// Catálogo de especies (`GET /api/especies`). El backend devuelve un
/// arreglo plano `[{id, nombre}]`, sin envoltorio de paginación.
class Especie {
  final int id;
  final String nombre;

  const Especie({required this.id, required this.nombre});

  factory Especie.fromJson(Map<String, dynamic> json) {
    return Especie(id: json['id'] as int, nombre: json['nombre'] as String);
  }

  @override
  String toString() => nombre;
}
