import 'event_type.dart';

/// Versión mínima de un animal, solo para mostrar en selects y listas de
/// reproducción. Traducido desde `ReproductiveAnimalMini`.
class ReproductiveAnimalMini {
  final String id;
  final String code;
  final String? name;

  const ReproductiveAnimalMini({required this.id, required this.code, this.name});

  factory ReproductiveAnimalMini.fromJson(Map<String, dynamic> json) =>
      ReproductiveAnimalMini(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String?,
      );

  /// Equivalente a `labelAnimal()` del proyecto web: "CER-2026-00002 · Lola".
  String get etiqueta {
    final apodo = name?.trim();
    return (apodo != null && apodo.isNotEmpty) ? '$code · $apodo' : code;
  }
}

/// Evento reproductivo (monta o inseminación) de un animal.
///
/// Traducido 1:1 desde `ReproductiveEventSchema` en
/// `src/types/domain/reproduction.schema.ts` del proyecto web (repos
/// ostiosmaily39/Granja_Fincas_Patitas y
/// Laura-Sanabria/granja-fincas-patitas-frontend — solo referencia de
/// lectura, no se tocan).
class ReproductiveEvent {
  final String id;
  final String animalId;
  final String? fatherId;
  final String? fatherExternal;
  final EventType eventType;
  final DateTime eventDate;
  final GestationStatus? gestationStatus;
  final DateTime? estimatedDeliveryDate;
  final DateTime? estimatedDeliveryDateTo;
  final String? responsible;
  final String? notes;

  /// Relaciones opcionales resueltas (equivalente a
  /// `ReproductiveEventWithRelations`).
  final ReproductiveAnimalMini? femaleAnimal;
  final ReproductiveAnimalMini? maleAnimal;

  const ReproductiveEvent({
    required this.id,
    required this.animalId,
    this.fatherId,
    this.fatherExternal,
    required this.eventType,
    required this.eventDate,
    this.gestationStatus,
    this.estimatedDeliveryDate,
    this.estimatedDeliveryDateTo,
    this.responsible,
    this.notes,
    this.femaleAnimal,
    this.maleAnimal,
  });

  factory ReproductiveEvent.fromJson(Map<String, dynamic> json) => ReproductiveEvent(
        id: json['id'] as String,
        animalId: json['animal_id'] as String,
        fatherId: json['father_id'] as String?,
        fatherExternal: json['father_external'] as String?,
        eventType: EventType.fromJson(json['event_type'] as String),
        eventDate: DateTime.parse(json['event_date'] as String),
        gestationStatus: json['gestation_status'] != null
            ? GestationStatus.fromJson(json['gestation_status'] as String)
            : null,
        estimatedDeliveryDate: _parseDate(json['estimated_delivery_date']),
        estimatedDeliveryDateTo: _parseDate(json['estimated_delivery_date_to']),
        responsible: json['responsible'] as String?,
        notes: json['notes'] as String?,
        femaleAnimal: json['female_animal'] != null
            ? ReproductiveAnimalMini.fromJson(json['female_animal'] as Map<String, dynamic>)
            : null,
        maleAnimal: json['male_animal'] != null
            ? ReproductiveAnimalMini.fromJson(json['male_animal'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'animal_id': animalId,
        'father_id': fatherId,
        'father_external': fatherExternal,
        'event_type': eventType.toJson(),
        'event_date': eventDate.toIso8601String(),
        'gestation_status': gestationStatus?.toJson(),
        'estimated_delivery_date': estimatedDeliveryDate?.toIso8601String(),
        'estimated_delivery_date_to': estimatedDeliveryDateTo?.toIso8601String(),
        'responsible': responsible,
        'notes': notes,
      };

  static DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);
}

/// DTO de creación — equivalente a `CreateReproductiveEventDTO`. La regla
/// "solo macho registrado o padre externo, no ambos" (`.refine()` en el
/// schema web) se valida en la pantalla del formulario, no aquí.
class CreateReproductiveEventDTO {
  final String animalId;
  final EventType eventType;
  final DateTime eventDate;
  final String? fatherId;
  final String? fatherExternal;
  final String responsible;
  final String? notes;

  const CreateReproductiveEventDTO({
    required this.animalId,
    required this.eventType,
    required this.eventDate,
    this.fatherId,
    this.fatherExternal,
    required this.responsible,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'animal_id': animalId,
        'event_type': eventType.toJson(),
        'event_date': eventDate.toIso8601String(),
        'father_id': fatherId,
        'father_external': fatherExternal,
        'responsible': responsible,
        'notes': notes,
      };
}
