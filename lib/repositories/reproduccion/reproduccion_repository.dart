import '../../models/reproduccion/seguimiento_gestacion.dart';

/// Contrato del módulo Reproducción contra `/api/reproduccion`
/// (tabla `seguimiento_gestacion`).
///
/// Flujo de 3 pasos (auditoría agregada 2026-10-15): [crear] deja el
/// registro en "Pendiente"; [confirmar] lo pasa a "Gestante"; [cerrar] lo
/// cierra con su resultado final ("Parida" o "Abortada"). Cualquier usuario
/// autenticado puede ejecutar cualquier paso, sin importar quién hizo el
/// anterior.
abstract class ReproduccionRepository {
  Future<List<SeguimientoGestacion>> listar({int? animalId, String? estado});

  Future<SeguimientoGestacion?> obtenerPorId(int id);

  Future<SeguimientoGestacion> crear(CrearSeguimientoDTO dto);

  Future<SeguimientoGestacion> actualizar(int id, ActualizarSeguimientoDTO dto);

  /// Paso 2: confirma la gestación (Pendiente -> Gestante). `notas` es la
  /// observación obligatoria que pide la pantalla "Registrar Seguimiento"
  /// (2026-10-19) -- en el backend sigue siendo opcional para no romper
  /// otros llamadores, pero esta app siempre la manda.
  Future<SeguimientoGestacion> confirmar(int id, {String? notas});

  /// Paso 3: cierra el seguimiento con su resultado final.
  Future<SeguimientoGestacion> cerrar(int id, CerrarSeguimientoDTO dto);

  Future<void> eliminar(int id);
}
