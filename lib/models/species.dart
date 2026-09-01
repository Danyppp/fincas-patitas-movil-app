/// Especie del animal (bovino, porcino, aviar, etc.).
/// Traducido desde `Species` en `animal.schema.ts` (proyecto web, solo lectura).
class Species {
  final String id;
  final String name;
  final String displayName;
  final int? gestationDays;
  final bool? isProductiveMilk;

  const Species({
    required this.id,
    required this.name,
    required this.displayName,
    this.gestationDays,
    this.isProductiveMilk,
  });

  factory Species.fromJson(Map<String, dynamic> json) => Species(
        id: json['id'] as String,
        name: json['name'] as String,
        displayName: json['display_name'] as String,
        gestationDays: json['gestation_days'] as int?,
        isProductiveMilk: json['is_productive_milk'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'display_name': displayName,
        'gestation_days': gestationDays,
        'is_productive_milk': isProductiveMilk,
      };
}

/// Raza dentro de una especie. Traducido desde `Breed` en `animal.schema.ts`.
class Breed {
  final String id;
  final String name;
  final String speciesId;

  const Breed({
    required this.id,
    required this.name,
    required this.speciesId,
  });

  factory Breed.fromJson(Map<String, dynamic> json) => Breed(
        id: json['id'] as String,
        name: json['name'] as String,
        speciesId: json['species_id'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'species_id': speciesId,
      };
}
