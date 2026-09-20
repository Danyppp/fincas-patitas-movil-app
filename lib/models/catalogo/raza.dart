/// Catálogo de razas (`GET /api/razas?especie_id=`). Arreglo plano
/// `[{id, especie_id, nombre}]`, sin paginación.
class Raza {
  final int id;
  final int especieId;
  final String nombre;

  const Raza({required this.id, required this.especieId, required this.nombre});

  factory Raza.fromJson(Map<String, dynamic> json) {
    return Raza(
      id: json['id'] as int,
      especieId: json['especie_id'] as int,
      nombre: json['nombre'] as String,
    );
  }

  @override
  String toString() => nombre;
}
