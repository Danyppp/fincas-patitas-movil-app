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
  });

  /// true si este registro se hizo "por lote" en vez de "por animal".
  bool get esPorLote => loteId != null;

  int get cantidadBuenos => cantidad - cantidadRotos;

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
        if (registradoEn != null)
          'registrado_en': registradoEn!.toIso8601String(),
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
        if (registradoEn != null)
          'registrado_en': registradoEn!.toIso8601String(),
      };
}
