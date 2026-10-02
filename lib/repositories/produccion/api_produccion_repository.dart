import '../../core/api_client.dart';
import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../models/produccion/resumen_produccion.dart';
import 'produccion_repository.dart';

class ApiProduccionRepository implements ProduccionRepository {
  final ApiClient client;

  ApiProduccionRepository({required this.client});

  @override
  Future<List<ProduccionLeche>> listarLeche({
    int? animalId,
    int? loteId,
    bool incluirEliminados = false,
  }) async {
    final data = await client.get('/produccion-leche', query: {
      if (animalId != null) 'animal_id': animalId,
      if (loteId != null) 'lote_id': loteId,
      if (incluirEliminados) 'incluir_eliminados': 'true',
    }) as List<dynamic>;
    return data
        .map((e) => ProduccionLeche.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProduccionLeche> crearLeche(CrearProduccionLecheDTO dto) async {
    final data = await client.post('/produccion-leche', body: dto.toJson());
    return ProduccionLeche.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<ProduccionLeche> actualizarLeche(
      int id, ActualizarProduccionLecheDTO dto) async {
    final data = await client.put('/produccion-leche/$id', body: dto.toJson());
    return ProduccionLeche.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> eliminarLeche(int id) async {
    await client.delete('/produccion-leche/$id');
  }

  @override
  Future<List<ProduccionHuevos>> listarHuevos({
    int? loteId,
    int? animalId,
    bool incluirEliminados = false,
  }) async {
    final data = await client.get('/produccion-huevos', query: {
      if (loteId != null) 'lote_id': loteId,
      if (animalId != null) 'animal_id': animalId,
      if (incluirEliminados) 'incluir_eliminados': 'true',
    }) as List<dynamic>;
    return data
        .map((e) => ProduccionHuevos.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProduccionHuevos> crearHuevos(CrearProduccionHuevosDTO dto) async {
    final data = await client.post('/produccion-huevos', body: dto.toJson());
    return ProduccionHuevos.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<ProduccionHuevos> actualizarHuevos(
      int id, ActualizarProduccionHuevosDTO dto) async {
    final data = await client.put('/produccion-huevos/$id', body: dto.toJson());
    return ProduccionHuevos.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> eliminarHuevos(int id) async {
    await client.delete('/produccion-huevos/$id');
  }

  @override
  Future<ResumenProduccionHoy> resumenHoy() async {
    final data = await client.get('/produccion/summary/today');
    return ResumenProduccionHoy.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<IndicadoresProduccion> indicadores(
      {DateTime? fechaInicio, DateTime? fechaFin}) async {
    // `.toUtc()` antes de serializar: igual que con `registrado_en` en los
    // DTOs de Crear/Actualizar, una hora local sin 'Z' se presta a que el
    // backend (que corre en UTC) la interprete mal y compare contra el
    // rango de fechas equivocado (corrección 2026-10-01).
    final data = await client.get('/produccion/indicadores', query: {
      if (fechaInicio != null)
        'fecha_inicio': fechaInicio.toUtc().toIso8601String(),
      if (fechaFin != null) 'fecha_fin': fechaFin.toUtc().toIso8601String(),
    });
    return IndicadoresProduccion.fromJson(data as Map<String, dynamic>);
  }
}
