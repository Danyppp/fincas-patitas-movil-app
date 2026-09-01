/// Sexo del animal. Traducido 1:1 desde `sex: 'macho' | 'hembra'`
/// en `animal.schema.ts` del proyecto web (solo como referencia de lectura).
enum Sexo {
  macho,
  hembra;

  static Sexo fromJson(String value) {
    switch (value) {
      case 'macho':
        return Sexo.macho;
      case 'hembra':
        return Sexo.hembra;
      default:
        throw ArgumentError('Sexo desconocido: $value');
    }
  }

  String toJson() => name;

  String get etiqueta => this == Sexo.macho ? 'Macho' : 'Hembra';
}
