/// Modelo de la tabla real `produccion_huevos` (`/api/produccion-huevos`).
///
/// Importante (verificado en `produccionHuevos.service.ts`): el DTO de
/// creación/actualización que expone el backend SOLO acepta `cantidad`
/// (y `lote_id` opcional). El repositorio Prisma sí soporta un campo
/// `cantidad_rotos`, pero el servicio nunca lo recibe del controlador, así
/// que en la práctica no hay manera de registrar huevos rotos/dañados
/// todavía — a diferencia del módulo anterior (basado en el esquema web)
/// que sí tenía `damagedQuantity`. Se elimina ese campo en este rebuild.
class ProduccionHuevos {
  final int id;
  final int? loteId;
  final int cantidad;
  final DateTime registradoEn;
  final String? loteNombre;

  const ProduccionHuevos({
    required this.id,
    required this.cantidad,
    required this.registradoEn,
    this.loteId,
    this.loteNombre,
  });

  factory ProduccionHuevos.fromJson(Map<String, dynamic> json) {
    return ProduccionHuevos(
      id: json['id'] as int,
      loteId: json['lote_id'] as int?,
      cantidad: json['cantidad'] as int,
      registradoEn: DateTime.parse(json['registrado_en'] as String),
      loteNombre: (json['lotes_animales'] is Map<String, dynamic>)
          ? (json['lotes_animales'] as Map<String, dynamic>)['nombre'] as String?
          : null,
    );
  }
}

class CrearProduccionHuevosDTO {
  final int? loteId;
  final int cantidad;
  final DateTime? registradoEn;

  const CrearProduccionHuevosDTO({required this.cantidad, this.loteId, this.registradoEn});

  Map<String, dynamic> toJson() => {
        if (loteId != null) 'lote_id': loteId,
        'cantidad': cantidad,
        if (registradoEn != null) 'registrado_en': registradoEn!.toIso8601String(),
      };
}

class ActualizarProduccionHuevosDTO {
  final int? cantidad;
  final DateTime? registradoEn;

  const ActualizarProduccionHuevosDTO({this.cantidad, this.registradoEn});

  Map<String, dynamic> toJson() => {
        if (cantidad != null) 'cantidad': cantidad,
        if (registradoEn != null) 'registrado_en': registradoEn!.toIso8601String(),
      };
}
