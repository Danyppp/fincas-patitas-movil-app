import '../animal.dart';

/// Tipos de evento válidos según `eventoSanitario.service.ts`
/// (`TIPOS_EVENTO_VALIDOS`) -- no cambiar sin revisar el backend primero.
const List<String> tiposEventoSanitarioValidos = [
  'Vacunación',
  'Desparasitación',
  'Tratamiento Médico',
  'Cirugía',
  'Chequeo General',
];

/// Estados válidos del seguimiento de un evento (`ESTADOS_VALIDOS` en el
/// backend). Todo evento nace en "Abierto".
const List<String> estadosEventoSanitarioValidos = [
  'Abierto',
  'En tratamiento',
  'Resuelto',
];

/// Una fila del "Flujo de registro" (punto 4.9 de la nota de Dany,
/// 2026-10-31): quién hizo cada acción (Creado / Editado / Resuelto) sobre
/// el evento, y cuándo. Viene del arreglo `eventos_sanitarios_historial`
/// que el backend ya incluye en `GET /eventos-sanitarios` y
/// `GET /eventos-sanitarios/:id` -- ver
/// decisiones-diseno-vs-backend-salud.md sección 4.1.
class HistorialEventoSanitario {
  final String accion;
  final DateTime fecha;
  final String? usuarioNombre;

  const HistorialEventoSanitario({
    required this.accion,
    required this.fecha,
    this.usuarioNombre,
  });

  factory HistorialEventoSanitario.fromJson(Map<String, dynamic> json) {
    final usuario = json['usuarios'];
    return HistorialEventoSanitario(
      accion: json['accion'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      usuarioNombre: usuario is Map<String, dynamic>
          ? usuario['nombre_usuario'] as String?
          : null,
    );
  }
}

/// Modelo de un evento sanitario, según la tabla real `eventos_sanitarios`
/// (más los 5 campos clínicos agregados el 2026-10-26 -- ver
/// decisiones-diseno-vs-backend-salud.md): via_administracion,
/// unidad_dosis, profesional_responsable, medicamento,
/// fecha_proximo_refuerzo. Todos opcionales. Más `historial` (2026-10-31,
/// ver arriba).
///
/// El backend serializa `dosis_aplicada` (columna `Decimal`) como String en
/// el JSON, no como número -- mismo caso ya conocido de `litros` en
/// Producción. Se usa el mismo parser defensivo (`_parseDouble`).
class EventoSanitario {
  final int id;
  final int animalId;
  final String tipoEvento;
  final double? dosisAplicada;
  final String? descripcionTratamiento;
  final DateTime? fechaEvento;
  final String estado;
  final String? viaAdministracion;
  final String? unidadDosis;
  final String? profesionalResponsable;
  final String? medicamento;
  final DateTime? fechaProximoRefuerzo;
  final Animal? animal;
  final List<HistorialEventoSanitario> historial;
  // 2026-11-01 (punto nuevo de Dany: "Historial" con eliminados, mismo
  // estilo de Producción/Reproducción): auditoría de creación/borrado
  // lógico. `eliminadoEn` no nulo = el evento está "eliminado" (sigue en
  // la base de datos, pero ya no aparece en el listado normal salvo que se
  // pida explícitamente con el filtro "Eliminados").
  final String? creadoPorNombre;
  final DateTime? eliminadoEn;
  final String? eliminadoPorNombre;

  const EventoSanitario({
    required this.id,
    required this.animalId,
    required this.tipoEvento,
    required this.estado,
    this.dosisAplicada,
    this.descripcionTratamiento,
    this.fechaEvento,
    this.viaAdministracion,
    this.unidadDosis,
    this.profesionalResponsable,
    this.medicamento,
    this.fechaProximoRefuerzo,
    this.animal,
    this.historial = const [],
    this.creadoPorNombre,
    this.eliminadoEn,
    this.eliminadoPorNombre,
  });

  factory EventoSanitario.fromJson(Map<String, dynamic> json) {
    return EventoSanitario(
      id: json['id'] as int,
      animalId: json['animal_id'] as int,
      tipoEvento: json['tipo_evento'] as String,
      estado: json['estado'] as String? ?? 'Abierto',
      dosisAplicada: _parseDouble(json['dosis_aplicada']),
      descripcionTratamiento: json['descripcion_tratamiento'] as String?,
      fechaEvento: _parseFecha(json['fecha_evento']),
      viaAdministracion: json['via_administracion'] as String?,
      unidadDosis: json['unidad_dosis'] as String?,
      profesionalResponsable: json['profesional_responsable'] as String?,
      medicamento: json['medicamento'] as String?,
      fechaProximoRefuerzo: _parseFecha(json['fecha_proximo_refuerzo']),
      animal: json['animales'] is Map<String, dynamic>
          ? Animal.fromJson(json['animales'] as Map<String, dynamic>)
          : null,
      historial: (json['eventos_sanitarios_historial'] as List<dynamic>?)
              ?.map((h) =>
                  HistorialEventoSanitario.fromJson(h as Map<String, dynamic>))
              .toList() ??
          const [],
      creadoPorNombre: _nombreUsuario(json['creado_por']),
      eliminadoEn: json['eliminado_en'] != null
          ? DateTime.tryParse(json['eliminado_en'] as String)
          : null,
      eliminadoPorNombre: _nombreUsuario(json['eliminado_por']),
    );
  }

  static String? _nombreUsuario(dynamic valor) {
    return valor is Map<String, dynamic>
        ? valor['nombre_usuario'] as String?
        : null;
  }

  bool get estaEliminado => eliminadoEn != null;

  static double? _parseDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }

  // 2026-11-01 (bug reportado por Dany): el backend guarda
  // fecha_evento/fecha_proximo_refuerzo como `@db.Date` (sin hora), pero
  // Prisma los serializa en el JSON como instante UTC con sufijo "Z"
  // (ej. "2026-11-01T00:00:00.000Z"). Si se usa ese valor tal cual
  // (DateTime.tryParse lo deja marcado como UTC) y se compara contra la
  // medianoche LOCAL de "hoy" (ver diasParaProximoRefuerzo), el desfase de
  // huso horario de Colombia (UTC-5) le resta horas a la diferencia real
  // -- un refuerzo para "mañana" terminaba calculando 0.79 días y
  // redondeando a "Hoy" en vez de "Mañana". La solución es quedarse solo
  // con año/mes/día (ignorando hora y zona) y reconstruir como fecha LOCAL
  // pura, igual que ya se hace al mandar fechas al backend (_soloFecha).
  static DateTime? _parseFecha(dynamic valor) {
    if (valor == null) return null;
    final parsed = DateTime.tryParse(valor as String);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Días que faltan para el próximo refuerzo (negativo si ya se pasó la
  /// fecha). Null si no hay fecha de refuerzo programada. Cálculo 100% en
  /// el cliente -- no hay sistema de notificaciones push real (ver
  /// decisiones-diseno-vs-backend-salud.md).
  int? get diasParaProximoRefuerzo {
    if (fechaProximoRefuerzo == null) return null;
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    return fechaProximoRefuerzo!.difference(hoySinHora).inDays;
  }

  bool get estaAbierto => estado == 'Abierto';
  bool get estaEnTratamiento => estado == 'En tratamiento';
  bool get estaResuelto => estado == 'Resuelto';
}

/// DTO para `POST /eventos-sanitarios`.
class CrearEventoSanitarioDTO {
  final int animalId;
  final String tipoEvento;
  final double? dosisAplicada;
  final String? descripcionTratamiento;
  final DateTime? fechaEvento;
  final String? viaAdministracion;
  final String? unidadDosis;
  final String? profesionalResponsable;
  final String? medicamento;
  final DateTime? fechaProximoRefuerzo;

  const CrearEventoSanitarioDTO({
    required this.animalId,
    required this.tipoEvento,
    this.dosisAplicada,
    this.descripcionTratamiento,
    this.fechaEvento,
    this.viaAdministracion,
    this.unidadDosis,
    this.profesionalResponsable,
    this.medicamento,
    this.fechaProximoRefuerzo,
  });

  Map<String, dynamic> toJson() => {
        'animal_id': animalId,
        'tipo_evento': tipoEvento,
        if (dosisAplicada != null) 'dosis_aplicada': dosisAplicada,
        if (descripcionTratamiento != null &&
            descripcionTratamiento!.isNotEmpty)
          'descripcion_tratamiento': descripcionTratamiento,
        if (fechaEvento != null) 'fecha_evento': _soloFecha(fechaEvento!),
        if (viaAdministracion != null && viaAdministracion!.isNotEmpty)
          'via_administracion': viaAdministracion,
        if (unidadDosis != null && unidadDosis!.isNotEmpty)
          'unidad_dosis': unidadDosis,
        if (profesionalResponsable != null &&
            profesionalResponsable!.isNotEmpty)
          'profesional_responsable': profesionalResponsable,
        if (medicamento != null && medicamento!.isNotEmpty)
          'medicamento': medicamento,
        if (fechaProximoRefuerzo != null)
          'fecha_proximo_refuerzo': _soloFecha(fechaProximoRefuerzo!),
      };
}

/// DTO para `PUT /eventos-sanitarios/:id`. Todo opcional (actualización
/// parcial) -- `animal_id` nunca se actualiza (el backend no lo acepta en
/// el PUT).
class ActualizarEventoSanitarioDTO {
  final String? tipoEvento;
  final double? dosisAplicada;
  final String? descripcionTratamiento;
  final DateTime? fechaEvento;
  final String? viaAdministracion;
  final String? unidadDosis;
  final String? profesionalResponsable;
  final String? medicamento;
  final DateTime? fechaProximoRefuerzo;
  // 2026-10-31 (bug reportado por Dany): cuando el usuario elige "No" en
  // "¿Próximo refuerzo?", `fechaProximoRefuerzo` queda en null -- pero un
  // DTO que simplemente OMITE un campo null no le dice nada al backend
  // ("no tocar"), así que la fecha vieja se quedaba guardada para
  // siempre. Esta bandera, cuando es true, manda `fecha_proximo_refuerzo:
  // null` EXPLÍCITO en el JSON para que el backend sí la borre.
  final bool limpiarProximoRefuerzo;

  const ActualizarEventoSanitarioDTO({
    this.tipoEvento,
    this.dosisAplicada,
    this.descripcionTratamiento,
    this.fechaEvento,
    this.viaAdministracion,
    this.unidadDosis,
    this.profesionalResponsable,
    this.medicamento,
    this.fechaProximoRefuerzo,
    this.limpiarProximoRefuerzo = false,
  });

  Map<String, dynamic> toJson() => {
        if (tipoEvento != null) 'tipo_evento': tipoEvento,
        if (dosisAplicada != null) 'dosis_aplicada': dosisAplicada,
        if (descripcionTratamiento != null)
          'descripcion_tratamiento': descripcionTratamiento,
        if (fechaEvento != null) 'fecha_evento': _soloFecha(fechaEvento!),
        if (viaAdministracion != null) 'via_administracion': viaAdministracion,
        if (unidadDosis != null) 'unidad_dosis': unidadDosis,
        if (profesionalResponsable != null)
          'profesional_responsable': profesionalResponsable,
        if (medicamento != null) 'medicamento': medicamento,
        if (fechaProximoRefuerzo != null)
          'fecha_proximo_refuerzo': _soloFecha(fechaProximoRefuerzo!)
        else if (limpiarProximoRefuerzo)
          'fecha_proximo_refuerzo': null,
      };
}

/// El backend guarda `fecha_evento`/`fecha_proximo_refuerzo` como
/// `@db.Date` (sin hora) -- se manda solo "yyyy-MM-dd" para evitar
/// ambigüedad de zona horaria (mismo tipo de bug ya documentado en
/// Producción).
String _soloFecha(DateTime fecha) {
  final y = fecha.year.toString().padLeft(4, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  final d = fecha.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
