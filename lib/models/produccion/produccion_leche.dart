import '../reproduccion/seguimiento_gestacion.dart' show AnimalReferencia;

/// Jornadas válidas confirmadas en `produccionLeche.service.ts`
/// (JORNADAS_VALIDAS) — solo estas dos, no un enum de 4 valores como en
/// el esquema web anterior.
const jornadasValidas = ['Mañana', 'Tarde'];

/// Modelo de la tabla real `produccion_leche` (`/api/produccion-leche`).
class ProduccionLeche {
  final int id;
  final int animalId;
  final double litros;
  final String? jornada;
  final DateTime registradoEn;
  final AnimalReferencia? animal;

  const ProduccionLeche({
    required this.id,
    required this.animalId,
    required this.litros,
    required this.registradoEn,
    this.jornada,
    this.animal,
  });

  factory ProduccionLeche.fromJson(Map<String, dynamic> json) {
    return ProduccionLeche(
      id: json['id'] as int,
      animalId: json['animal_id'] as int,
      litros: (json['litros'] as num).toDouble(),
      jornada: json['jornada'] as String?,
      registradoEn: DateTime.parse(json['registrado_en'] as String),
      animal: json['animales'] is Map<String, dynamic>
          ? AnimalReferencia.fromJson(json['animales'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CrearProduccionLecheDTO {
  final int animalId;
  final double litros;
  final String? jornada;
  final DateTime? registradoEn;

  const CrearProduccionLecheDTO({
    required this.animalId,
    required this.litros,
    this.jornada,
    this.registradoEn,
  });

  Map<String, dynamic> toJson() => {
        'animal_id': animalId,
        'litros': litros,
        if (jornada != null) 'jornada': jornada,
        if (registradoEn != null) 'registrado_en': registradoEn!.toIso8601String(),
      };
}

class ActualizarProduccionLecheDTO {
  final double? litros;
  final String? jornada;
  final DateTime? registradoEn;

  const ActualizarProduccionLecheDTO({this.litros, this.jornada, this.registradoEn});

  Map<String, dynamic> toJson() => {
        if (litros != null) 'litros': litros,
        if (jornada != null) 'jornada': jornada,
        if (registradoEn != null) 'registrado_en': registradoEn!.toIso8601String(),
      };
}
