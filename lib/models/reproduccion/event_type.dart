/// Tipo de evento reproductivo. Traducido desde `EventTypeEnum` en
/// `reproduction.schema.ts` del proyecto web (solo referencia de lectura).
enum EventType {
  montaNatural,
  inseminacionArtificial;

  static EventType fromJson(String value) {
    switch (value) {
      case 'monta_natural':
        return EventType.montaNatural;
      case 'inseminacion_artificial':
        return EventType.inseminacionArtificial;
      default:
        throw ArgumentError('Tipo de evento desconocido: $value');
    }
  }

  String toJson() =>
      this == EventType.montaNatural ? 'monta_natural' : 'inseminacion_artificial';

  String get etiqueta =>
      this == EventType.montaNatural ? 'Monta natural' : 'Inseminación artificial';
}

/// Estado de gestación. Traducido desde `GestationStatusEnum`.
enum GestationStatus {
  enSeguimiento,
  confirmada,
  fallida,
  partoExitoso;

  static GestationStatus fromJson(String value) {
    switch (value) {
      case 'en_seguimiento':
        return GestationStatus.enSeguimiento;
      case 'confirmada':
        return GestationStatus.confirmada;
      case 'fallida':
        return GestationStatus.fallida;
      case 'parto_exitoso':
        return GestationStatus.partoExitoso;
      default:
        throw ArgumentError('Estado de gestación desconocido: $value');
    }
  }

  String toJson() {
    switch (this) {
      case GestationStatus.enSeguimiento:
        return 'en_seguimiento';
      case GestationStatus.confirmada:
        return 'confirmada';
      case GestationStatus.fallida:
        return 'fallida';
      case GestationStatus.partoExitoso:
        return 'parto_exitoso';
    }
  }

  String get etiqueta {
    switch (this) {
      case GestationStatus.enSeguimiento:
        return 'En seguimiento';
      case GestationStatus.confirmada:
        return 'Confirmada';
      case GestationStatus.fallida:
        return 'Fallida';
      case GestationStatus.partoExitoso:
        return 'Parto exitoso';
    }
  }
}
