/// Catálogo de potreros (`GET /potreros`). El backend devuelve un arreglo
/// plano `[{id, nombre, capacidad_animales, estado}]`, sin envoltorio de
/// paginación. Es de solo lectura desde la app móvil por ahora.
class Potrero {
  final int id;
  final String nombre;
  final int? capacidadAnimales;
  final String? estado;

  const Potrero({
    required this.id,
    required this.nombre,
    this.capacidadAnimales,
    this.estado,
  });

  factory Potrero.fromJson(Map<String, dynamic> json) {
    return Potrero(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      capacidadAnimales: json['capacidad_animales'] as int?,
      estado: json['estado'] as String?,
    );
  }

  @override
  String toString() => nombre;
}
