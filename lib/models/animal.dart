import 'sexo.dart';
import 'species.dart';

/// Modelo de dominio Animal.
///
/// Traducido 1:1 desde `Animal` en
/// `src/types/domain/animal.schema.ts` del proyecto web (repos
/// ostiosmaily39/Granja_Fincas_Patitas y
/// Laura-Sanabria/granja-fincas-patitas-frontend — solo referencia de
/// lectura, no se tocan). Cuando el backend de Milena defina el
/// contrato final de la API, este modelo es el punto donde se ajusta.
class Animal {
  final String id;
  final String code;
  final String name;
  final Sexo sex;
  final String speciesId;
  final String? breedId;
  final DateTime? birthDate;
  final DateTime? acquisitionDate;
  final String? origin;
  final double? initialWeightKg;
  final double? currentWeightKg;
  final String healthStatus;
  final String vaccinationStatus;
  final String reproductiveStatus;
  final String status;
  final String? egressReason;
  final String? notes;
  final String? motherId;
  final String? fatherId;
  final String? fatherExternal;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Relaciones opcionales resueltas (equivalente a `AnimalWithRelations`).
  final Species? species;
  final Breed? breed;

  const Animal({
    required this.id,
    required this.code,
    required this.name,
    required this.sex,
    required this.speciesId,
    this.breedId,
    this.birthDate,
    this.acquisitionDate,
    this.origin,
    this.initialWeightKg,
    this.currentWeightKg,
    required this.healthStatus,
    required this.vaccinationStatus,
    required this.reproductiveStatus,
    required this.status,
    this.egressReason,
    this.notes,
    this.motherId,
    this.fatherId,
    this.fatherExternal,
    required this.createdAt,
    required this.updatedAt,
    this.species,
    this.breed,
  });

  factory Animal.fromJson(Map<String, dynamic> json) => Animal(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        sex: Sexo.fromJson(json['sex'] as String),
        speciesId: json['species_id'] as String,
        breedId: json['breed_id'] as String?,
        birthDate: _parseDate(json['birth_date']),
        acquisitionDate: _parseDate(json['acquisition_date']),
        origin: json['origin'] as String?,
        initialWeightKg: (json['initial_weight_kg'] as num?)?.toDouble(),
        currentWeightKg: (json['current_weight_kg'] as num?)?.toDouble(),
        healthStatus: json['health_status'] as String,
        vaccinationStatus: json['vaccination_status'] as String,
        reproductiveStatus: json['reproductive_status'] as String,
        status: json['status'] as String,
        egressReason: json['egress_reason'] as String?,
        notes: json['notes'] as String?,
        motherId: json['mother_id'] as String?,
        fatherId: json['father_id'] as String?,
        fatherExternal: json['father_external'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        species: json['species'] != null
            ? Species.fromJson(json['species'] as Map<String, dynamic>)
            : null,
        breed: json['breed'] != null
            ? Breed.fromJson(json['breed'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'sex': sex.toJson(),
        'species_id': speciesId,
        'breed_id': breedId,
        'birth_date': birthDate?.toIso8601String(),
        'acquisition_date': acquisitionDate?.toIso8601String(),
        'origin': origin,
        'initial_weight_kg': initialWeightKg,
        'current_weight_kg': currentWeightKg,
        'health_status': healthStatus,
        'vaccination_status': vaccinationStatus,
        'reproductive_status': reproductiveStatus,
        'status': status,
        'egress_reason': egressReason,
        'notes': notes,
        'mother_id': motherId,
        'father_id': fatherId,
        'father_external': fatherExternal,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);
}

/// DTO para crear un animal — equivalente a `CreateAnimalDTO` en el proyecto web.
class CreateAnimalDTO {
  final String name;
  final Sexo sex;
  final String speciesId;
  final String? breedId;
  final DateTime? birthDate;
  final String? notes;

  const CreateAnimalDTO({
    required this.name,
    required this.sex,
    required this.speciesId,
    this.breedId,
    this.birthDate,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'sex': sex.toJson(),
        'species_id': speciesId,
        'breed_id': breedId,
        'birth_date': birthDate?.toIso8601String(),
        'notes': notes,
      };
}
