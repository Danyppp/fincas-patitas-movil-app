import '../reproduccion/seguimiento_gestacion.dart' show AnimalReferencia;

/// Jornadas válidas confirmadas en `produccionLeche.service.ts`
/// (JORNADAS_VALIDAS) — solo estas dos, no un enum de 4 valores como en
/// el esquema web anterior.
const jornadasValidas = ['Mañana', 'Tarde'];

/// Modelo de la tabla real `produccion_leche` (`/api/produccion-leche`).
///
/// Desde el cambio de backend del 2026-09-29, el registro se hace **por
/// animal o por lote** (nunca ambos, nunca ninguno). También se agregó
/// `observaciones` (texto libre opcional).
class ProduccionLeche {
  final int id;
  final int? animalId;
  final int? loteId;
  final double litros;
  final String? jornada;
  final String? observaciones;
  final DateTime registradoEn;
  final AnimalReferencia? animal;
  final String? loteNombre;

  const ProduccionLeche({
    required this.id,
    required this.litros,
    required this.registradoEn,
    this.animalId,
    this.loteId,
    this.jornada,
    this.observaciones,
    this.animal,
    this.loteNombre,
  });

  /// true si este registro se hizo "por lote" en vez de "por animal".
  bool get esPorLote => loteId != null;

  factory ProduccionLeche.fromJson(Map<String, dynamic> json) {
    return ProduccionLeche(
      id: json['id'] as int,
      animalId: json['animal_id'] as int?,
      loteId: json['lote_id'] as int?,
      // `litros` es Decimal en Prisma — el backend lo serializa como
      // STRING en el JSON (ej. "10.0"), no como número. Si se castea
      // directo con `as num` revienta con
      // "TypeError: '10': type 'String' is not a subtype of type 'num'".
      // Mismo problema ya resuelto en `insumo.dart` (_parseDouble).
      litros: _parseDouble(json['litros']) ?? 0,
      jornada: json['jornada'] as String?,
      observaciones: json['observaciones'] as String?,
      registradoEn: DateTime.parse(json['registrado_en'] as String),
      animal: json['animales'] is Map<String, dynamic>
          ? AnimalReferencia.fromJson(json['animales'] as Map<String, dynamic>)
          : null,
      loteNombre: (json['lotes_animales'] is Map<String, dynamic>)
          ? (json['lotes_animales'] as Map<String, dynamic>)['nombre']
              as String?
          : null,
    );
  }

  static double? _parseDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }
}

/// Exactamente uno de `animalId`/`loteId` debe venir con valor — el
/// backend rechaza con 400 si vienen los dos o ninguno.
class CrearProduccionLecheDTO {
  final int? animalId;
  final int? loteId;
  final double litros;
  final String? jornada;
  final String? observaciones;
  final DateTime? registradoEn;

  const CrearProduccionLecheDTO({
    required this.litros,
    this.animalId,
    this.loteId,
    this.jornada,
    this.observaciones,
    this.registradoEn,
  });

  Map<String, dynamic> toJson() => {
        if (animalId != null) 'animal_id': animalId,
        if (loteId != null) 'lote_id': loteId,
        'litros': litros,
        if (jornada != null) 'jornada': jornada,
        if (observaciones != null && observaciones!.trim().isNotEmpty)
          'observaciones': observaciones!.trim(),
        if (registradoEn != null)
          'registrado_en': registradoEn!.toIso8601String(),
      };
}

/// La modalidad (animal/lote) no se puede cambiar al editar — solo litros,
/// jornada, observaciones y fecha.
class ActualizarProduccionLecheDTO {
  final double? litros;
  final String? jornada;
  final String? observaciones;
  final DateTime? registradoEn;

  const ActualizarProduccionLecheDTO({
    this.litros,
    this.jornada,
    this.observaciones,
    this.registradoEn,
  });

  Map<String, dynamic> toJson() => {
        if (litros != null) 'litros': litros,
        if (jornada != null) 'jornada': jornada,
        if (observaciones != null) 'observaciones': observaciones!.trim(),
        if (registradoEn != null)
          'registrado_en': registradoEn!.toIso8601String(),
      };
}
