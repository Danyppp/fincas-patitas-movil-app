import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';

/// Contrato del módulo Producción: agrupa los dos sub-recursos reales del
/// backend, `/api/produccion-leche` y `/api/produccion-huevos` (son
/// endpoints independientes, no un solo "produccion" genérico).
abstract class ProduccionRepository {
  Future<List<ProduccionLeche>> listarLeche({int? animalId});
  Future<ProduccionLeche> crearLeche(CrearProduccionLecheDTO dto);
  Future<ProduccionLeche> actualizarLeche(int id, ActualizarProduccionLecheDTO dto);
  Future<void> eliminarLeche(int id);

  Future<List<ProduccionHuevos>> listarHuevos({int? loteId});
  Future<ProduccionHuevos> crearHuevos(CrearProduccionHuevosDTO dto);
  Future<ProduccionHuevos> actualizarHuevos(int id, ActualizarProduccionHuevosDTO dto);
  Future<void> eliminarHuevos(int id);
}
