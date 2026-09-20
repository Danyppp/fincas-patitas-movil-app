/// Referencia mínima a un animal, tal como viene anidada en los registros
/// de reproducción (`include: { animales: true, macho: true }` en el
/// repositorio del backend — no trae especie/raza anidada aquí).
class AnimalReferencia {
  final int id;
  final String codigo;
  final String? nombre;

  const AnimalReferencia({required this.id, required this.codigo, this.nombre});

  factory AnimalReferencia.fromJson(Map<String, dynamic> json) {
    return AnimalReferencia(
      id: json['id'] as int,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String?,
    );
  }

  String get nombreVisible => (nombre != null && nombre!.isNotEmpty) ? nombre! : codigo;
}

/// Modelo de la tabla real `seguimiento_gestacion`, expuesta en
/// `/api/reproduccion`. Confirmado leyendo
/// `seguimientoGestacion.service.ts` / `.repository.ts` / `.controller.ts`
/// (los archivos NO se llaman `reproduccion.*` a pesar de que la ruta sí
/// es `/reproduccion`).
class SeguimientoGestacion {
  final int id;
  final int animalId;
  final int? machoId;
  final String? tipo;
  final DateTime fechaInseminacion;
  final DateTime? fechaEstimadaParto;
  final DateTime? fechaRealParto;
  final String estado;
  final String? notas;
  final AnimalReferencia? animal;
  final AnimalReferencia? macho;

  const SeguimientoGestacion({
    required this.id,
    required this.animalId,
    required this.fechaInseminacion,
    required this.estado,
    this.machoId,
    this.tipo,
    this.fechaEstimadaParto,
    this.fechaRealParto,
    this.notas,
    this.animal,
    this.macho,
  });

  factory SeguimientoGestacion.fromJson(Map<String, dynamic> json) {
    return SeguimientoGestacion(
      id: json['id'] as int,
      animalId: json['animal_id'] as int,
      machoId: json['macho_id'] as int?,
      tipo: json['tipo'] as String?,
      fechaInseminacion: DateTime.parse(json['fecha_inseminacion'] as String),
      fechaEstimadaParto: json['fecha_estimada_parto'] != null
          ? DateTime.tryParse(json['fecha_estimada_parto'] as String)
          : null,
      fechaRealParto: json['fecha_real_parto'] != null
          ? DateTime.tryParse(json['fecha_real_parto'] as String)
          : null,
      estado: json['estado'] as String? ?? 'Gestante',
      notas: json['notas'] as String?,
      animal: json['animales'] is Map<String, dynamic>
          ? AnimalReferencia.fromJson(json['animales'] as Map<String, dynamic>)
          : null,
      macho: json['macho'] is Map<String, dynamic>
          ? AnimalReferencia.fromJson(json['macho'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Tipos válidos de monta, validados también en el backend
/// (`seguimientoGestacion.service.ts`, TIPOS_VALIDOS).
const tiposMontaValidos = ['Monta natural', 'IA'];

/// DTO para `POST /api/reproduccion`. `fecha_estimada_parto` es
/// obligatoria salvo que la especie del animal sea vaca o cerdo (el
/// backend la calcula solo, comentado ahí como "días de gestación por
/// especie"); para no invocar esa lógica desde el cliente, la pantalla
/// SIEMPRE pide fecha_estimada_parto y la envía.
class CrearSeguimientoDTO {
  final int animalId;
  final int? machoId;
  final String? tipo;
  final DateTime fechaInseminacion;
  final DateTime? fechaEstimadaParto;
  final String? estado;
  final String? notas;

  const CrearSeguimientoDTO({
    required this.animalId,
    required this.fechaInseminacion,
    this.machoId,
    this.tipo,
    this.fechaEstimadaParto,
    this.estado,
    this.notas,
  });

  Map<String, dynamic> toJson() => {
        'animal_id': animalId,
        if (machoId != null) 'macho_id': machoId,
        if (tipo != null) 'tipo': tipo,
        'fecha_inseminacion': _soloFecha(fechaInseminacion),
        if (fechaEstimadaParto != null) 'fecha_estimada_parto': _soloFecha(fechaEstimadaParto!),
        if (estado != null) 'estado': estado,
        if (notas != null && notas!.isNotEmpty) 'notas': notas,
      };
}

/// DTO para `PUT /api/reproduccion/:id`.
class ActualizarSeguimientoDTO {
  final int? machoId;
  final String? tipo;
  final DateTime? fechaInseminacion;
  final DateTime? fechaEstimadaParto;
  final DateTime? fechaRealParto;
  final String? estado;
  final String? notas;

  const ActualizarSeguimientoDTO({
    this.machoId,
    this.tipo,
    this.fechaInseminacion,
    this.fechaEstimadaParto,
    this.fechaRealParto,
    this.estado,
    this.notas,
  });

  Map<String, dynamic> toJson() => {
        if (machoId != null) 'macho_id': machoId,
        if (tipo != null) 'tipo': tipo,
        if (fechaInseminacion != null) 'fecha_inseminacion': _soloFecha(fechaInseminacion!),
        if (fechaEstimadaParto != null) 'fecha_estimada_parto': _soloFecha(fechaEstimadaParto!),
        if (fechaRealParto != null) 'fecha_real_parto': _soloFecha(fechaRealParto!),
        if (estado != null) 'estado': estado,
        if (notas != null) 'notas': notas,
      };
}

String _soloFecha(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
