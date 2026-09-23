import '../../models/inventario/insumo.dart';

/// Contrato del módulo Inventario contra `/api/bodega` (recordar: `bodega`
/// en el backend es cada insumo individual, no una bodega física — ver
/// nota en `models/inventario/insumo.dart`).
abstract class InsumoRepository {
  Future<List<Insumo>> listar({int? categoriaId, bool soloStockBajo});

  Future<Insumo?> obtenerPorId(int id);

  Future<Insumo> crear(CrearInsumoDTO dto);

  Future<Insumo> actualizar(int id, ActualizarInsumoDTO dto);

  Future<void> eliminar(int id);

  /// Registra una entrada o salida de stock (`POST /bodega/:id/movimientos`,
  /// HU-17). Devuelve el insumo ya con el stock actualizado.
  ///
  /// OJO: el backend en realidad devuelve el registro del movimiento (con
  /// el insumo anidado en `.bodega`), no el insumo directamente — el
  /// repositorio ya se encarga de esa extracción, así que quien llama esto
  /// siempre recibe un [Insumo] limpio.
  Future<Insumo> registrarMovimiento(
    int insumoId, {
    required String tipo,
    required double cantidad,
    required String motivo,
  });
}
