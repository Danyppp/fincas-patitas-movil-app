import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';

/// Contrato del módulo Producción: agrupa los dos sub-recursos reales del
/// backend, `/api/produccion-leche` y `/api/produccion-huevos` (son
/// endpoints independientes, no un solo "produccion" genérico). Ambos
/// soportan filtrar por animal o por lote desde el cambio de backend del
/// 2026-09-29.
abstract class ProduccionRepository {
  Future<List<ProduccionLeche>> listarLeche({int? animalId, int? loteId});
  Future<ProduccionLeche> crearLeche(CrearProduccionLecheDTO dto);
  Future<ProduccionLeche> actualizarLeche(int id, ActualizarProduccionLecheDTO dto);
  Future<void> eliminarLeche(int id);

  Future<List<ProduccionHuevos>> listarHuevos({int? loteId, int? animalId});
  Future<ProduccionHuevos> crearHuevos(CrearProduccionHuevosDTO dto);
  Future<ProduccionHuevos> actualizarHuevos(int id, ActualizarProduccionHuevosDTO dto);
  Future<void> eliminarHuevos(int id);
}
