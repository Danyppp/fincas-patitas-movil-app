/// Referencia mínima a un animal, tal como viene anidada en los registros
/// de reproducción (`include: { animales: { include: { especies: true } },
/// macho: { include: { especies: true } } }` en el repositorio del backend
/// -- trae especie (nombre), pero a propósito NO trae raza (decisión
/// confirmada 2026-10-21: el detalle de un seguimiento muestra especie,
/// nombre y código, nunca raza).
class AnimalReferencia {
  final int id;
  final String codigo;
  final String? nombre;
  final String? especieNombre;

  const AnimalReferencia({
    required this.id,
    required this.codigo,
    this.nombre,
    this.especieNombre,
  });

  factory AnimalReferencia.fromJson(Map<String, dynamic> json) {
    return AnimalReferencia(
      id: json['id'] as int,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String?,
      especieNombre: json['especies'] is Map<String, dynamic>
          ? (json['especies'] as Map<String, dynamic>)['nombre'] as String?
          : null,
    );
  }

  String get nombreVisible =>
      (nombre != null && nombre!.isNotEmpty) ? nombre! : codigo;
}

/// Referencia mínima a un usuario, tal como viene anidada en `creado_por`,
/// `confirmado_por` y `cerrado_por` (auditoría agregada 2026-10-15,
/// `select: { id, nombre_usuario }` en el repositorio del backend).
class UsuarioReferencia {
  final int id;
  final String nombreUsuario;

  const UsuarioReferencia({required this.id, required this.nombreUsuario});

  factory UsuarioReferencia.fromJson(Map<String, dynamic> json) {
    return UsuarioReferencia(
      id: json['id'] as int,
      nombreUsuario: json['nombre_usuario'] as String,
    );
  }
}

/// Modelo de la tabla real `seguimiento_gestacion`, expuesta en
/// `/api/reproduccion`. Confirmado leyendo
/// `seguimientoGestacion.service.ts` / `.repository.ts` / `.controller.ts`
/// (los archivos NO se llaman `reproduccion.*` a pesar de que la ruta sí
/// es `/reproduccion`).
///
/// Flujo de estados (auditoría agregada 2026-10-15, ampliado 2026-10-20):
/// Pendiente --(PATCH /reproduccion/:id/confirmar)--> Gestante
///           --(PATCH /reproduccion/:id/cerrar)-->    Parida | Abortada
/// Pendiente --(PATCH /reproduccion/:id/cerrar, resultado=Fallida)--> Fallida
///   (cierre directo cuando la IA/monta no resultó en preñez -- no pasa
///   por Gestante).
/// Cualquier usuario autenticado puede ejecutar cualquier paso -- no hay
/// restricción por rol, solo queda constancia de quién hizo cada uno.
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
  // 2026-10-20: cuándo se creó el registro en sí (distinto de
  // fechaInseminacion, que es la fecha del evento reproductivo y puede
  // registrarse días después de que ocurrió).
  final DateTime? creadoEn;
  final AnimalReferencia? animal;
  final AnimalReferencia? macho;
  final UsuarioReferencia? creadoPor;
  final UsuarioReferencia? confirmadoPor;
  final DateTime? confirmadoEn;
  final UsuarioReferencia? cerradoPor;
  final DateTime? cerradoEn;
  // 2026-10-20: auditoría de edición/eliminación (ver Historial).
  final UsuarioReferencia? editadoPor;
  final DateTime? editadoEn;
  final UsuarioReferencia? eliminadoPor;
  final DateTime? eliminadoEn;

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
    this.creadoEn,
    this.animal,
    this.macho,
    this.creadoPor,
    this.confirmadoPor,
    this.confirmadoEn,
    this.cerradoPor,
    this.cerradoEn,
    this.editadoPor,
    this.editadoEn,
    this.eliminadoPor,
    this.eliminadoEn,
  });

  bool get estaPendiente => estado == 'Pendiente';
  bool get estaGestante => estado == 'Gestante';
  bool get estaParida => estado == 'Parida';
  bool get estaAbortada => estado == 'Abortada';
  // 2026-10-20: nuevo estado terminal, alcanzable directo desde Pendiente
  // (ver comentario de la clase) -- no requiere haber pasado por Gestante.
  bool get estaFallida => estado == 'Fallida';
  bool get estaCerrado => estaParida || estaAbortada || estaFallida;
  // 2026-10-20: borrado lógico -- el registro NUNCA se borra físicamente,
  // solo se marca. Solo lo usa la pantalla de Historial (el resto de
  // pantallas no debe mostrar nunca un registro con esto en true, porque
  // el backend ya los excluye por defecto).
  bool get estaEliminado => eliminadoEn != null;
  // "Exitoso vs Fallido" para la métrica de Fertilidad (2026-10-20,
  // confirmado): Parida = exitoso; Fallida o Abortada = fallido.
  bool get esResultadoExitoso => estaParida;
  bool get esResultadoFallido => estaFallida || estaAbortada;

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
      estado: json['estado'] as String? ?? 'Pendiente',
      notas: json['notas'] as String?,
      creadoEn: json['creado_en'] != null
          ? DateTime.tryParse(json['creado_en'] as String)
          : null,
      animal: json['animales'] is Map<String, dynamic>
          ? AnimalReferencia.fromJson(json['animales'] as Map<String, dynamic>)
          : null,
      macho: json['macho'] is Map<String, dynamic>
          ? AnimalReferencia.fromJson(json['macho'] as Map<String, dynamic>)
          : null,
      creadoPor: json['creado_por'] is Map<String, dynamic>
          ? UsuarioReferencia.fromJson(
              json['creado_por'] as Map<String, dynamic>)
          : null,
      confirmadoPor: json['confirmado_por'] is Map<String, dynamic>
          ? UsuarioReferencia.fromJson(
              json['confirmado_por'] as Map<String, dynamic>)
          : null,
      confirmadoEn: json['confirmado_en'] != null
          ? DateTime.tryParse(json['confirmado_en'] as String)
          : null,
      cerradoPor: json['cerrado_por'] is Map<String, dynamic>
          ? UsuarioReferencia.fromJson(
              json['cerrado_por'] as Map<String, dynamic>)
          : null,
      cerradoEn: json['cerrado_en'] != null
          ? DateTime.tryParse(json['cerrado_en'] as String)
          : null,
      editadoPor: json['editado_por'] is Map<String, dynamic>
          ? UsuarioReferencia.fromJson(
              json['editado_por'] as Map<String, dynamic>)
          : null,
      editadoEn: json['editado_en'] != null
          ? DateTime.tryParse(json['editado_en'] as String)
          : null,
      eliminadoPor: json['eliminado_por'] is Map<String, dynamic>
          ? UsuarioReferencia.fromJson(
              json['eliminado_por'] as Map<String, dynamic>)
          : null,
      eliminadoEn: json['eliminado_en'] != null
          ? DateTime.tryParse(json['eliminado_en'] as String)
          : null,
    );
  }
}

/// Tipos válidos de monta, validados también en el backend
/// (`seguimientoGestacion.service.ts`, TIPOS_VALIDOS).
const tiposMontaValidos = ['Monta natural', 'IA'];

/// Resultados válidos para cerrar() un seguimiento, validados también en el
/// backend (`seguimientoGestacion.service.ts`, RESULTADOS_VALIDOS).
/// 'Fallida' agregado 2026-10-20 -- único resultado que se puede aplicar
/// tanto desde "Gestante" como directo desde "Pendiente".
const resultadosCierreValidos = ['Parida', 'Abortada', 'Fallida'];

/// DTO para `POST /api/reproduccion` (paso 1: crear, siempre queda en
/// Pendiente). Ya NO se manda `estado` -- el backend decide siempre.
///
/// `fecha_estimada_parto` es obligatoria salvo que la especie del animal sea
/// Bovino o Cerdo (el backend la calcula solo); para no invocar esa lógica
/// desde el cliente, la pantalla SIEMPRE pide fecha_estimada_parto y la envía.
class CrearSeguimientoDTO {
  final int animalId;
  final int? machoId;
  final String? tipo;
  final DateTime fechaInseminacion;
  final DateTime? fechaEstimadaParto;
  final String? notas;

  const CrearSeguimientoDTO({
    required this.animalId,
    required this.fechaInseminacion,
    this.machoId,
    this.tipo,
    this.fechaEstimadaParto,
    this.notas,
  });

  Map<String, dynamic> toJson() => {
        'animal_id': animalId,
        if (machoId != null) 'macho_id': machoId,
        if (tipo != null) 'tipo': tipo,
        'fecha_inseminacion': _soloFecha(fechaInseminacion),
        if (fechaEstimadaParto != null)
          'fecha_estimada_parto': _soloFecha(fechaEstimadaParto!),
        if (notas != null && notas!.isNotEmpty) 'notas': notas,
      };
}

/// DTO para `PUT /api/reproduccion/:id`. Edita solo los campos que no son del
/// flujo de estados -- el backend rechaza esta llamada si el registro ya
/// está cerrado (Parida/Abortada/Fallida). `fechaRealParto`/`estado` ya NO
/// se mandan aquí: eso ahora vive en [CerrarSeguimientoDTO].
class ActualizarSeguimientoDTO {
  final int? machoId;
  final String? tipo;
  final DateTime? fechaInseminacion;
  final DateTime? fechaEstimadaParto;
  final String? notas;

  const ActualizarSeguimientoDTO({
    this.machoId,
    this.tipo,
    this.fechaInseminacion,
    this.fechaEstimadaParto,
    this.notas,
  });

  Map<String, dynamic> toJson() => {
        if (machoId != null) 'macho_id': machoId,
        if (tipo != null) 'tipo': tipo,
        if (fechaInseminacion != null)
          'fecha_inseminacion': _soloFecha(fechaInseminacion!),
        if (fechaEstimadaParto != null)
          'fecha_estimada_parto': _soloFecha(fechaEstimadaParto!),
        if (notas != null) 'notas': notas,
      };
}

/// DTO para `PATCH /api/reproduccion/:id/cerrar` (paso 3 -- cierra con el
/// resultado final). `fechaRealParto` es obligatoria cuando `resultado` es
/// "Parida" (el backend la exige), opcional si es "Abortada" o "Fallida".
/// Este mismo endpoint se usa para cerrar directo desde "Pendiente" con
/// resultado "Fallida" (2026-10-20) -- el backend ya lo permitía, solo
/// faltaba el valor en la lista de resultados válidos.
class CerrarSeguimientoDTO {
  final String resultado;
  final DateTime? fechaRealParto;
  final String? notas;

  const CerrarSeguimientoDTO({
    required this.resultado,
    this.fechaRealParto,
    this.notas,
  });

  Map<String, dynamic> toJson() => {
        'resultado': resultado,
        if (fechaRealParto != null)
          'fecha_real_parto': _soloFecha(fechaRealParto!),
        if (notas != null && notas!.isNotEmpty) 'notas': notas,
      };
}

String _soloFecha(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
