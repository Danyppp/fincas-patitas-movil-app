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
///
/// Desde el cambio de backend del 2026-10-02 (auditoría + borrado lógico):
/// cada registro ahora trae quién lo creó (`creado_por`) y, si fue
/// eliminado, cuándo y por quién (`eliminado_en`/`eliminado_por`). El
/// registro NUNCA desaparece de la base — un registro "eliminado" sigue
/// existiendo con esos dos campos poblados, y solo se incluye en la
/// respuesta cuando se pide explícitamente `incluir_eliminados=true`.
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
  final String? creadoPorNombre;
  final DateTime? eliminadoEn;
  final String? eliminadoPorNombre;

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
    this.creadoPorNombre,
    this.eliminadoEn,
    this.eliminadoPorNombre,
  });

  /// true si este registro se hizo "por lote" en vez de "por animal".
  bool get esPorLote => loteId != null;

  /// true si este registro fue borrado lógicamente (sigue existiendo en la
  /// base, pero no debe contar en totales ni aparecer en las listas
  /// normales — solo en el historial, marcado como eliminado).
  bool get estaEliminado => eliminadoEn != null;

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
        // IMPORTANTE (corrección 2026-10-01): `DateTime.now()` es una hora
        // LOCAL. `.toIso8601String()` de una hora local NO incluye 'Z' ni
        // offset, así que el backend (que corre en UTC) la interpretaba
        // como si YA fuera UTC — desplazando el registro de día cerca de
        // la medianoche y haciendo que el Dashboard no lo contara como
        // "de hoy". `.toUtc()` convierte primero a la hora UTC real antes
        // de serializar, eliminando la ambigüedad.
        if (registradoEn != null)
          'registrado_en': registradoEn!.toUtc().toIso8601String(),
        // Nota: `creado_por_id` NUNCA se manda desde el cliente — el
        // backend lo toma del token de sesión (2026-10-02).
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
        // Mismo fix que en CrearProduccionLecheDTO — ver comentario arriba.
        if (registradoEn != null)
          'registrado_en': registradoEn!.toUtc().toIso8601String(),
      };
}
