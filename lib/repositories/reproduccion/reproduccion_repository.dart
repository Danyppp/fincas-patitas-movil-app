import '../../models/reproduccion/seguimiento_gestacion.dart';

/// Contrato del módulo Reproducción contra `/api/reproduccion`
/// (tabla `seguimiento_gestacion`).
abstract class ReproduccionRepository {
  Future<List<SeguimientoGestacion>> listar({int? animalId, String? estado});

  Future<SeguimientoGestacion?> obtenerPorId(int id);

  Future<SeguimientoGestacion> crear(CrearSeguimientoDTO dto);

  Future<SeguimientoGestacion> actualizar(int id, ActualizarSeguimientoDTO dto);

  Future<void> eliminar(int id);
}
