import 'especie.dart';

/// Resumen del usuario encargado (de un Lote o de un Potrero) -- mismo
/// shape que devuelve el backend en `encargado` (Lote, singular) y dentro
/// de `potrero_encargados[].usuarios` (Potrero, plural).
class EncargadoResumen {
  final int id;
  final String nombreUsuario;
  final String correoElectronico;

  const EncargadoResumen({
    required this.id,
    required this.nombreUsuario,
    required this.correoElectronico,
  });

  factory EncargadoResumen.fromJson(Map<String, dynamic> json) {
    return EncargadoResumen(
      id: json['id'] as int,
      nombreUsuario: json['nombre_usuario'] as String,
      correoElectronico: json['correo_electronico'] as String,
    );
  }
}

/// Catálogo de lotes de animales (`GET /lotes-animales`).
///
/// 2026-11-05 (módulo Ubicación): el backend ahora incluye `especies`,
/// `encargado` (un único usuario o null) y `_count.animales` en cada
/// lote -- antes solo devolvía `{id, nombre, potrero_id}`. Ese
/// `potrero_id` ya NO existe: Lote y Potrero quedaron independientes (ver
/// decisiones-diseno-vs-backend-ubicacion.md, secciones 1-2). Dejó de ser
/// de solo lectura -- ahora tiene CRUD completo desde la app.
class LoteAnimal {
  final int id;
  final String nombre;
  final int? especieId;
  final Especie? especie;
  final DateTime? fechaCreacion;
  final int? capacidadEstimada;
  final String? descripcion;
  final int? encargadoId;
  final EncargadoResumen? encargado;
  final int cantidadAnimales;

  const LoteAnimal({
    required this.id,
    required this.nombre,
    this.especieId,
    this.especie,
    this.fechaCreacion,
    this.capacidadEstimada,
    this.descripcion,
    this.encargadoId,
    this.encargado,
    this.cantidadAnimales = 0,
  });

  factory LoteAnimal.fromJson(Map<String, dynamic> json) {
    return LoteAnimal(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      especieId: json['especie_id'] as int?,
      especie: json['especies'] != null
          ? Especie.fromJson(json['especies'] as Map<String, dynamic>)
          : null,
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.tryParse(json['fecha_creacion'] as String)
          : null,
      capacidadEstimada: json['capacidad_estimada'] as int?,
      descripcion: json['descripcion'] as String?,
      encargadoId: json['encargado_id'] as int?,
      encargado: json['encargado'] != null
          ? EncargadoResumen.fromJson(json['encargado'] as Map<String, dynamic>)
          : null,
      cantidadAnimales:
          (json['_count'] as Map<String, dynamic>?)?['animales'] as int? ?? 0,
    );
  }

  @override
  String toString() => nombre;
}

/// Datos para `POST /lotes-animales`. `nombre` y `especieId` son
/// obligatorios (confirmado por Dany); el resto, opcional.
class CrearLoteDTO {
  final String nombre;
  final int especieId;
  final DateTime? fechaCreacion;
  final int? capacidadEstimada;
  final String? descripcion;

  const CrearLoteDTO({
    required this.nombre,
    required this.especieId,
    this.fechaCreacion,
    this.capacidadEstimada,
    this.descripcion,
  });

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'especie_id': especieId,
        if (fechaCreacion != null)
          'fecha_creacion': fechaCreacion!.toIso8601String().split('T').first,
        if (capacidadEstimada != null) 'capacidad_estimada': capacidadEstimada,
        if (descripcion != null) 'descripcion': descripcion,
      };
}

/// Datos para `PUT /lotes-animales/:id`. Todos opcionales (actualización
/// parcial).
class ActualizarLoteDTO {
  final String? nombre;
  final int? especieId;
  final DateTime? fechaCreacion;
  final int? capacidadEstimada;
  final String? descripcion;

  const ActualizarLoteDTO({
    this.nombre,
    this.especieId,
    this.fechaCreacion,
    this.capacidadEstimada,
    this.descripcion,
  });

  Map<String, dynamic> toJson() => {
        if (nombre != null) 'nombre': nombre,
        if (especieId != null) 'especie_id': especieId,
        if (fechaCreacion != null)
          'fecha_creacion': fechaCreacion!.toIso8601String().split('T').first,
        if (capacidadEstimada != null) 'capacidad_estimada': capacidadEstimada,
        if (descripcion != null) 'descripcion': descripcion,
      };
}
