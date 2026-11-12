import 'lote_animal.dart' show EncargadoResumen;

/// Fila de la tabla puente `potrero_encargados` (usuario + cuándo quedó
/// asignado).
class PotreroEncargado {
  final EncargadoResumen usuario;
  final DateTime? asignadoEn;

  const PotreroEncargado({required this.usuario, this.asignadoEn});

  factory PotreroEncargado.fromJson(Map<String, dynamic> json) {
    return PotreroEncargado(
      usuario:
          EncargadoResumen.fromJson(json['usuarios'] as Map<String, dynamic>),
      asignadoEn: json['asignado_en'] != null
          ? DateTime.tryParse(json['asignado_en'] as String)
          : null,
    );
  }
}

/// Catálogo de potreros (`GET /ubicaciones-potreros`).
///
/// 2026-11-05 (módulo Ubicación): el backend ahora incluye
/// `tamano_hectareas`, `fecha_creacion`, `descripcion`, `foto_url` y la
/// lista de `potrero_encargados` (varios usuarios, a diferencia de Lote
/// que solo tiene uno). Dejó de ser de solo lectura -- ahora tiene CRUD
/// completo desde la app.
class Potrero {
  final int id;
  final String nombre;
  final int? capacidadAnimales;
  final String? estado;
  final double? tamanoHectareas;
  final DateTime? fechaCreacion;
  final String? descripcion;
  final String? fotoUrl;
  final List<PotreroEncargado> encargados;

  const Potrero({
    required this.id,
    required this.nombre,
    this.capacidadAnimales,
    this.estado,
    this.tamanoHectareas,
    this.fechaCreacion,
    this.descripcion,
    this.fotoUrl,
    this.encargados = const [],
  });

  factory Potrero.fromJson(Map<String, dynamic> json) {
    return Potrero(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      capacidadAnimales: json['capacidad_animales'] as int?,
      estado: json['estado'] as String?,
      tamanoHectareas: json['tamano_hectareas'] != null
          ? double.tryParse(json['tamano_hectareas'].toString())
          : null,
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.tryParse(json['fecha_creacion'] as String)
          : null,
      descripcion: json['descripcion'] as String?,
      fotoUrl: json['foto_url'] as String?,
      encargados: (json['potrero_encargados'] as List<dynamic>?)
              ?.map((e) => PotreroEncargado.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  @override
  String toString() => nombre;
}

/// Datos para `POST /ubicaciones-potreros`. Solo `nombre` es obligatorio.
class CrearPotreroDTO {
  final String nombre;
  final int? capacidadAnimales;
  final String? estado;
  final double? tamanoHectareas;
  final DateTime? fechaCreacion;
  final String? descripcion;

  const CrearPotreroDTO({
    required this.nombre,
    this.capacidadAnimales,
    this.estado,
    this.tamanoHectareas,
    this.fechaCreacion,
    this.descripcion,
  });

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        if (capacidadAnimales != null) 'capacidad_animales': capacidadAnimales,
        if (estado != null) 'estado': estado,
        if (tamanoHectareas != null) 'tamano_hectareas': tamanoHectareas,
        if (fechaCreacion != null)
          'fecha_creacion': fechaCreacion!.toIso8601String().split('T').first,
        if (descripcion != null) 'descripcion': descripcion,
      };
}

/// Datos para `PUT /ubicaciones-potreros/:id`. Todos opcionales.
class ActualizarPotreroDTO {
  final String? nombre;
  final int? capacidadAnimales;
  final String? estado;
  final double? tamanoHectareas;
  final DateTime? fechaCreacion;
  final String? descripcion;

  const ActualizarPotreroDTO({
    this.nombre,
    this.capacidadAnimales,
    this.estado,
    this.tamanoHectareas,
    this.fechaCreacion,
    this.descripcion,
  });

  Map<String, dynamic> toJson() => {
        if (nombre != null) 'nombre': nombre,
        if (capacidadAnimales != null) 'capacidad_animales': capacidadAnimales,
        if (estado != null) 'estado': estado,
        if (tamanoHectareas != null) 'tamano_hectareas': tamanoHectareas,
        if (fechaCreacion != null)
          'fecha_creacion': fechaCreacion!.toIso8601String().split('T').first,
        if (descripcion != null) 'descripcion': descripcion,
      };
}
