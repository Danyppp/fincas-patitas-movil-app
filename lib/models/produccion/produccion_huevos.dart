import '../reproduccion/seguimiento_gestacion.dart' show AnimalReferencia;

/// Modelo de la tabla real `produccion_huevos` (`/api/produccion-huevos`).
///
/// Desde el cambio de backend del 2026-09-29, además de `lote_id` (el
/// original) ahora también acepta `animal_id` como modalidad alterna
/// (nunca ambos a la vez), `cantidad_rotos` (ya existía en el esquema
/// Prisma pero el controller no lo recibía; ahora sí) y `observaciones`
/// (texto libre opcional, nuevo).
///
/// Desde el cambio de backend del 2026-10-01 (PR #14), también acepta
/// `jornada` ("Mañana"/"Tarde"), igual que ya existía en producción de
/// leche.
///
/// Desde el cambio de backend del 2026-10-02 (auditoría + borrado lógico):
/// ver comentario equivalente en `produccion_leche.dart`.
class ProduccionHuevos {
  final int id;
  final int? loteId;
  final int? animalId;
  final int cantidad;
  final int cantidadRotos;
  final String? jornada;
  final String? observaciones;
  final DateTime registradoEn;
  final String? loteNombre;
  final AnimalReferencia? animal;
  final String? creadoPorNombre;
  final DateTime? eliminadoEn;
  final String? eliminadoPorNombre;

  const ProduccionHuevos({
    required this.id,
    required this.cantidad,
    required this.registradoEn,
    this.loteId,
    this.animalId,
    this.cantidadRotos = 0,
    this.jornada,
    this.observaciones,
    this.loteNombre,
    this.animal,
    this.creadoPorNombre,
    this.eliminadoEn,
    this.eliminadoPorNombre,
  });

  /// true si este registro se hizo "por lote" en vez de "por animal".
  bool get esPorLote => loteId != null;

  int get cantidadBuenos => cantidad - cantidadRotos;

  /// Ver comentario equivalente en `produccion_leche.dart`.
  bool get estaEliminado => eliminadoEn != null;

  factory ProduccionHuevos.fromJson(Map<String, dynamic> json) {
    return ProduccionHuevos(
      id: json['id'] as int,
      loteId: json['lote_id'] as int?,
      animalId: json['animal_id'] as int?,
      cantidad: json['cantidad'] as int,
      cantidadRotos: (json['cantidad_rotos'] as int?) ?? 0,
      jornada: json['jornada'] as String?,
      observaciones: json['observaciones'] as String?,
      registradoEn: DateTime.parse(json['registrado_en'] as String),
      loteNombre: (json['lotes_animales'] is Map<String, dynamic>)
          ? (json['lotes_animales'] as Map<String, dynamic>)['nombre']
              as String?
          : null,
      animal: json['animales'] is Map<String, dynamic>
          ? AnimalReferencia.fromJson(json['animales'] as Map<String, dynamic>)
          : null,
      creadoPorNombre: (json['creado_por'] is Map<String, dynamic>)
          ? (json['creado_por'] as Map<String, dynamic>)['nombre_usuario']
              as String?
          : null,
      eliminadoEn: json['eliminado_en'] != null
          ? DateTime.parse(json['eliminado_en'] as String)
          : null,
      eliminadoPorNombre: (json['eliminado_por'] is Map<String, dynamic>)
          ? (json['eliminado_por'] as Map<String, dynamic>)['nombre_usuario']
              as String?
          : null,
    );
  }
}

/// Exactamente uno de `loteId`/`animalId` puede venir con valor (los dos a
/// la vez son rechazados con 400); ninguno de los dos es válido también
/// (a diferencia de leche, aquí sigue siendo opcional del todo).
class CrearProduccionHuevosDTO {
  final int? loteId;
  final int? animalId;
  final int cantidad;
  final int? cantidadRotos;
  final String? jornada;
  final String? observaciones;
  final DateTime? registradoEn;

  const CrearProduccionHuevosDTO({
    required this.cantidad,
    this.loteId,
    this.animalId,
    this.cantidadRotos,
    this.jornada,
    this.observaciones,
    this.registradoEn,
  });

  Map<String, dynamic> toJson() => {
        if (loteId != null) 'lote_id': loteId,
        if (animalId != null) 'animal_id': animalId,
        'cantidad': cantidad,
        if (cantidadRotos != null) 'cantidad_rotos': cantidadRotos,
        if (jornada != null) 'jornada': jornada,
        if (observaciones != null && observaciones!.trim().isNotEmpty)
          'observaciones': observaciones!.trim(),
        // Ver comentario en CrearProduccionLecheDTO (produccion_leche.dart):
        // `.toUtc()` evita que el backend confunda la hora local con UTC y
        // desplace el registro a otro día cerca de la medianoche.
        if (registradoEn != null)
          'registrado_en': registradoEn!.toUtc().toIso8601String(),
      };
}

class ActualizarProduccionHuevosDTO {
  final int? cantidad;
  final int? cantidadRotos;
  final String? jornada;
  final String? observaciones;
  final DateTime? registradoEn;

  const ActualizarProduccionHuevosDTO({
    this.cantidad,
    this.cantidadRotos,
    this.jornada,
    this.observaciones,
    this.registradoEn,
  });

  Map<String, dynamic> toJson() => {
        if (cantidad != null) 'cantidad': cantidad,
        if (cantidadRotos != null) 'cantidad_rotos': cantidadRotos,
        if (jornada != null) 'jornada': jornada,
        if (observaciones != null) 'observaciones': observaciones!.trim(),
        // Mismo fix — ver arriba.
        if (registradoEn != null)
          'registrado_en': registradoEn!.toUtc().toIso8601String(),
      };
}
