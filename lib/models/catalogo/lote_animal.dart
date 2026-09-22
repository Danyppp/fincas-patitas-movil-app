/// Catálogo de lotes de animales (`GET /lotes-animales`). El backend
/// devuelve un arreglo plano `[{id, nombre, potrero_id}]`, sin envoltorio
/// de paginación. Es de solo lectura desde la app móvil por ahora (el CRUD
/// de lotes existe en el backend, pero no es prioridad de este sprint).
class LoteAnimal {
  final int id;
  final String nombre;
  final int? potreroId;

  const LoteAnimal({required this.id, required this.nombre, this.potreroId});

  factory LoteAnimal.fromJson(Map<String, dynamic> json) {
    return LoteAnimal(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      potreroId: json['potrero_id'] as int?,
    );
  }

  @override
  String toString() => nombre;
}
