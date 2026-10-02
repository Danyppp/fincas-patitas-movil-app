import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../models/produccion/resumen_produccion.dart';

/// Contrato del módulo Producción: agrupa los dos sub-recursos reales del
/// backend, `/api/produccion-leche` y `/api/produccion-huevos` (son
/// endpoints independientes, no un solo "produccion" genérico). Ambos
/// soportan filtrar por animal o por lote desde el cambio de backend del
/// 2026-09-29.
///
/// `resumenHoy` e `indicadores` se agregaron el 2026-10-01 para el
/// Dashboard de Producción: consumen `/produccion/summary/today` y
/// `/produccion/indicadores` respectivamente, dos endpoints agregados que
/// ya existían en el backend pero que el frontend no usaba todavía.
abstract class ProduccionRepository {
  // `incluirEliminados` (2026-10-02): por defecto false, igual que antes
  // (oculta los registros borrados lógicamente). La pantalla de "Historial
  // completo" lo pone en true para traer también los eliminados.
  Future<List<ProduccionLeche>> listarLeche({
    int? animalId,
    int? loteId,
    bool incluirEliminados = false,
  });
  Future<ProduccionLeche> crearLeche(CrearProduccionLecheDTO dto);
  Future<ProduccionLeche> actualizarLeche(
      int id, ActualizarProduccionLecheDTO dto);
  // El DELETE real ahora es un borrado lógico en el backend (el registro
  // se conserva, marcado) — la firma del método no cambia, solo su
  // significado (2026-10-02).
  Future<void> eliminarLeche(int id);

  Future<List<ProduccionHuevos>> listarHuevos({
    int? loteId,
    int? animalId,
    bool incluirEliminados = false,
  });
  Future<ProduccionHuevos> crearHuevos(CrearProduccionHuevosDTO dto);
  Future<ProduccionHuevos> actualizarHuevos(
      int id, ActualizarProduccionHuevosDTO dto);
  Future<void> eliminarHuevos(int id);

  /// Resumen del día actual (litros de leche, huevos buenos/rotos, y los
  /// registros completos de hoy de ambos tipos).
  Future<ResumenProduccionHoy> resumenHoy();

  /// Indicadores agregados en un rango de fechas (ambos límites inclusive,
  /// igual que el backend). Se usa principalmente para comparar "hoy" con
  /// "ayer" en el Dashboard.
  Future<IndicadoresProduccion> indicadores(
      {DateTime? fechaInicio, DateTime? fechaFin});
}
