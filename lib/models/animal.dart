import 'catalogo/especie.dart';
import 'catalogo/raza.dart';

/// Modelo del animal según la tabla real `animales` (Prisma schema del
/// backend). Reemplaza por completo el modelo anterior (basado en el
/// esquema web/Supabase con UUIDs) — este usa id entero autoincremental y
/// nombres de campo en español, tal como los expone la API.
///
/// `codigo` (ej. "ANI-0001") lo genera el backend; nunca se envía al crear.
class Animal {
  final int id;
  final String codigo;
  final String? nombre;
  final String genero;
  final DateTime? fechaNacimiento;
  final String? origen;
  final DateTime? fechaIngreso;
  final String estado;
  final int especieId;
  final int razaId;
  final int? loteId;
  final int? potreroId;
  final int? madreId;
  final int? padreId;
  final Especie? especie;
  final Raza? raza;
  final String? loteNombre;

  const Animal({
    required this.id,
    required this.codigo,
    required this.genero,
    required this.estado,
    required this.especieId,
    required this.razaId,
    this.nombre,
    this.fechaNacimiento,
    this.origen,
    this.fechaIngreso,
    this.loteId,
    this.potreroId,
    this.madreId,
    this.padreId,
    this.especie,
    this.raza,
    this.loteNombre,
  });

  factory Animal.fromJson(Map<String, dynamic> json) {
    return Animal(
      id: json['id'] as int,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String?,
      genero: json['genero'] as String,
      fechaNacimiento: _parseFecha(json['fecha_nacimiento']),
      origen: json['origen'] as String?,
      fechaIngreso: _parseFecha(json['fecha_ingreso']),
      estado: json['estado'] as String? ?? 'Activo',
      especieId: json['especie_id'] as int,
      razaId: json['raza_id'] as int,
      loteId: json['lote_id'] as int?,
      potreroId: json['potrero_id'] as int?,
      madreId: json['madre_id'] as int?,
      padreId: json['padre_id'] as int?,
      especie: json['especies'] is Map<String, dynamic>
          ? Especie.fromJson(json['especies'] as Map<String, dynamic>)
          : null,
      raza: json['razas'] is Map<String, dynamic>
          ? Raza.fromJson(json['razas'] as Map<String, dynamic>)
          : null,
      loteNombre: (json['lotes_animales'] is Map<String, dynamic>)
          ? (json['lotes_animales'] as Map<String, dynamic>)['nombre'] as String?
          : null,
    );
  }

  static DateTime? _parseFecha(dynamic valor) {
    if (valor == null) return null;
    return DateTime.tryParse(valor as String);
  }

  String get nombreVisible => (nombre != null && nombre!.isNotEmpty) ? nombre! : codigo;
}

/// DTO para `POST /api/animales`. `codigo` no existe aquí: el backend lo
/// autogenera.
class CrearAnimalDTO {
  final String? nombre;
  final String genero;
  final DateTime? fechaNacimiento;
  final String? origen;
  final DateTime? fechaIngreso;
  final String? estado;
  final int especieId;
  final int razaId;
  final int? loteId;
  final int? potreroId;
  final int? madreId;
  final int? padreId;

  const CrearAnimalDTO({
    required this.genero,
    required this.especieId,
    required this.razaId,
    this.nombre,
    this.fechaNacimiento,
    this.origen,
    this.fechaIngreso,
    this.estado,
    this.loteId,
    this.potreroId,
    this.madreId,
    this.padreId,
  });

  Map<String, dynamic> toJson() => {
        if (nombre != null && nombre!.isNotEmpty) 'nombre': nombre,
        'genero': genero,
        if (fechaNacimiento != null)
          'fecha_nacimiento': fechaNacimiento!.toIso8601String(),
        if (origen != null && origen!.isNotEmpty) 'origen': origen,
        if (fechaIngreso != null) 'fecha_ingreso': fechaIngreso!.toIso8601String(),
        if (estado != null) 'estado': estado,
        'especie_id': especieId,
        'raza_id': razaId,
        if (loteId != null) 'lote_id': loteId,
        if (potreroId != null) 'potrero_id': potreroId,
        if (madreId != null) 'madre_id': madreId,
        if (padreId != null) 'padre_id': padreId,
      };
}

/// DTO para `PUT /api/animales/:id`. Todo es opcional (actualización
/// parcial), EXCEPTO Lote/Potrero/Madre/Padre: esos 4 siempre se envían
/// (incluso en `null`), porque este formulario reemplaza el estado
/// completo de esas relaciones — si el usuario elige "Sin asignar" /
/// "Sin especificar" para quitarlos, el backend necesita recibir el
/// `null` explícito para de verdad limpiar la relación (antes se omitía
/// el campo y el backend nunca se enteraba del cambio).
///
/// `peso`, si se envía, crea además un registro en `registros_peso`
/// (efecto secundario confirmado en `animal.service.ts`).
///
/// Nota: el campo "causa" (para Muerto/Vendido) se retiró — la tabla
/// `animales` real no tiene ninguna columna para guardarla, así que se
/// decidió no exigirla por ahora (ver decisiones-diseno-vs-backend-animales.md).
class ActualizarAnimalDTO {
  final String? nombre;
  final String? genero;
  final DateTime? fechaNacimiento;
  final String? origen;
  final DateTime? fechaIngreso;
  final String? estado;
  final double? peso;
  final int? especieId;
  final int? razaId;
  final int? loteId;
  final int? potreroId;
  final int? madreId;
  final int? padreId;

  const ActualizarAnimalDTO({
    this.nombre,
    this.genero,
    this.fechaNacimiento,
    this.origen,
    this.fechaIngreso,
    this.estado,
    this.peso,
    this.especieId,
    this.razaId,
    this.loteId,
    this.potreroId,
    this.madreId,
    this.padreId,
  });

  Map<String, dynamic> toJson() => {
        if (nombre != null) 'nombre': nombre,
        if (genero != null) 'genero': genero,
        if (fechaNacimiento != null)
          'fecha_nacimiento': fechaNacimiento!.toIso8601String(),
        if (origen != null) 'origen': origen,
        if (fechaIngreso != null) 'fecha_ingreso': fechaIngreso!.toIso8601String(),
        if (estado != null) 'estado': estado,
        if (peso != null) 'peso': peso,
        if (especieId != null) 'especie_id': especieId,
        if (razaId != null) 'raza_id': razaId,
        // Estos 4 SIEMPRE se envían (incluso null) para poder limpiar la
        // relación desde el formulario. Ver comentario de la clase.
        'lote_id': loteId,
        'potrero_id': potreroId,
        'madre_id': madreId,
        'padre_id': padreId,
      };
}
