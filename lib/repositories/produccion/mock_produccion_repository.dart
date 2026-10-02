import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../models/produccion/resumen_produccion.dart';
import '../../models/reproduccion/seguimiento_gestacion.dart'
    show AnimalReferencia;
import 'produccion_repository.dart';

class MockProduccionRepository implements ProduccionRepository {
  final List<ProduccionLeche> _leche = [
    ProduccionLeche(
      id: 1,
      animalId: 1,
      litros: 12.5,
      jornada: 'Mañana',
      registradoEn: DateTime.now(),
      animal:
          const AnimalReferencia(id: 1, codigo: 'ANI-0001', nombre: 'Lucera'),
      creadoPorNombre: 'Usuario de prueba',
    ),
    ProduccionLeche(
      id: 2,
      loteId: 1,
      litros: 40,
      jornada: 'Tarde',
      observaciones: 'Registro de ejemplo por lote',
      registradoEn: DateTime.now(),
      loteNombre: 'Lote 01',
      creadoPorNombre: 'Usuario de prueba',
    ),
  ];
  final List<ProduccionHuevos> _huevos = [
    ProduccionHuevos(
      id: 1,
      loteId: 1,
      cantidad: 24,
      cantidadRotos: 2,
      jornada: 'Mañana',
      loteNombre: 'Lote 01',
      registradoEn: DateTime.now(),
      creadoPorNombre: 'Usuario de prueba',
    ),
  ];
  int _correlativoLeche = 3;
  int _correlativoHuevos = 2;

  @override
  Future<List<ProduccionLeche>> listarLeche({
    int? animalId,
    int? loteId,
    bool incluirEliminados = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _leche
        .where((r) =>
            (animalId == null || r.animalId == animalId) &&
            (loteId == null || r.loteId == loteId) &&
            (incluirEliminados || !r.estaEliminado))
        .toList();
  }

  @override
  Future<ProduccionLeche> crearLeche(CrearProduccionLecheDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final nuevo = ProduccionLeche(
      id: _correlativoLeche++,
      animalId: dto.animalId,
      loteId: dto.loteId,
      litros: dto.litros,
      jornada: dto.jornada,
      observaciones: dto.observaciones,
      registradoEn: dto.registradoEn ?? DateTime.now(),
      creadoPorNombre: 'Usuario de prueba',
    );
    _leche.add(nuevo);
    return nuevo;
  }

  @override
  Future<ProduccionLeche> actualizarLeche(
      int id, ActualizarProduccionLecheDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _leche.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _leche[idx];
    final actualizado = ProduccionLeche(
      id: actual.id,
      animalId: actual.animalId,
      loteId: actual.loteId,
      litros: dto.litros ?? actual.litros,
      jornada: dto.jornada ?? actual.jornada,
      observaciones: dto.observaciones ?? actual.observaciones,
      registradoEn: dto.registradoEn ?? actual.registradoEn,
      animal: actual.animal,
      loteNombre: actual.loteNombre,
      creadoPorNombre: actual.creadoPorNombre,
    );
    _leche[idx] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminarLeche(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    // Borrado lógico (2026-10-02): el registro se conserva en la lista
    // interna, solo se marca — igual que ahora hace el backend real.
    final idx = _leche.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final actual = _leche[idx];
    _leche[idx] = ProduccionLeche(
      id: actual.id,
      animalId: actual.animalId,
      loteId: actual.loteId,
      litros: actual.litros,
      jornada: actual.jornada,
      observaciones: actual.observaciones,
      registradoEn: actual.registradoEn,
      animal: actual.animal,
      loteNombre: actual.loteNombre,
      creadoPorNombre: actual.creadoPorNombre,
      eliminadoEn: DateTime.now(),
      eliminadoPorNombre: 'Usuario de prueba',
    );
  }

  @override
  Future<List<ProduccionHuevos>> listarHuevos({
    int? loteId,
    int? animalId,
    bool incluirEliminados = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _huevos
        .where((r) =>
            (loteId == null || r.loteId == loteId) &&
            (animalId == null || r.animalId == animalId) &&
            (incluirEliminados || !r.estaEliminado))
        .toList();
  }

  @override
  Future<ProduccionHuevos> crearHuevos(CrearProduccionHuevosDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final nuevo = ProduccionHuevos(
      id: _correlativoHuevos++,
      loteId: dto.loteId,
      animalId: dto.animalId,
      cantidad: dto.cantidad,
      cantidadRotos: dto.cantidadRotos ?? 0,
      jornada: dto.jornada,
      observaciones: dto.observaciones,
      registradoEn: dto.registradoEn ?? DateTime.now(),
      creadoPorNombre: 'Usuario de prueba',
    );
    _huevos.add(nuevo);
    return nuevo;
  }

  @override
  Future<ProduccionHuevos> actualizarHuevos(
      int id, ActualizarProduccionHuevosDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _huevos.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _huevos[idx];
    final actualizado = ProduccionHuevos(
      id: actual.id,
      loteId: actual.loteId,
      animalId: actual.animalId,
      cantidad: dto.cantidad ?? actual.cantidad,
      cantidadRotos: dto.cantidadRotos ?? actual.cantidadRotos,
      jornada: dto.jornada ?? actual.jornada,
      observaciones: dto.observaciones ?? actual.observaciones,
      registradoEn: dto.registradoEn ?? actual.registradoEn,
      loteNombre: actual.loteNombre,
      animal: actual.animal,
      creadoPorNombre: actual.creadoPorNombre,
    );
    _huevos[idx] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminarHuevos(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _huevos.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final actual = _huevos[idx];
    _huevos[idx] = ProduccionHuevos(
      id: actual.id,
      loteId: actual.loteId,
      animalId: actual.animalId,
      cantidad: actual.cantidad,
      cantidadRotos: actual.cantidadRotos,
      jornada: actual.jornada,
      observaciones: actual.observaciones,
      registradoEn: actual.registradoEn,
      loteNombre: actual.loteNombre,
      animal: actual.animal,
      creadoPorNombre: actual.creadoPorNombre,
      eliminadoEn: DateTime.now(),
      eliminadoPorNombre: 'Usuario de prueba',
    );
  }

  bool _esMismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Future<ResumenProduccionHoy> resumenHoy() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final hoy = DateTime.now();
    final lecheHoy = _leche
        .where((r) => !r.estaEliminado && _esMismoDia(r.registradoEn, hoy))
        .toList();
    final huevosHoy = _huevos
        .where((r) => !r.estaEliminado && _esMismoDia(r.registradoEn, hoy))
        .toList();
    final totalLitros = lecheHoy.fold<double>(0, (s, r) => s + r.litros);
    final totalBuenos = huevosHoy.fold<int>(0, (s, r) => s + r.cantidadBuenos);
    final totalRotos = huevosHoy.fold<int>(0, (s, r) => s + r.cantidadRotos);
    return ResumenProduccionHoy(
      totalLitrosLeche: totalLitros,
      totalHuevosBuenos: totalBuenos,
      totalHuevosRotos: totalRotos,
      registrosLeche: lecheHoy,
      registrosHuevos: huevosHoy,
      mensaje: (lecheHoy.isEmpty && huevosHoy.isEmpty)
          ? 'Aún no hay producción registrada hoy'
          : null,
    );
  }

  @override
  Future<IndicadoresProduccion> indicadores(
      {DateTime? fechaInicio, DateTime? fechaFin}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    bool enRango(DateTime d) =>
        (fechaInicio == null || !d.isBefore(fechaInicio)) &&
        (fechaFin == null || !d.isAfter(fechaFin));
    final lecheRango = _leche
        .where((r) => !r.estaEliminado && enRango(r.registradoEn))
        .toList();
    final huevosRango = _huevos
        .where((r) => !r.estaEliminado && enRango(r.registradoEn))
        .toList();
    final totalLitros = lecheRango.fold<double>(0, (s, r) => s + r.litros);
    final animalesProductivos = lecheRango
        .where((r) => r.animalId != null)
        .map((r) => r.animalId)
        .toSet()
        .length;
    final totalUnidades = huevosRango.fold<int>(0, (s, r) => s + r.cantidad);
    return IndicadoresProduccion(
      periodoInicio: fechaInicio,
      periodoFin: fechaFin,
      leche: IndicadoresLeche(
        totalLitros: totalLitros,
        promedioLitrosPorRegistro:
            lecheRango.isEmpty ? 0 : totalLitros / lecheRango.length,
        cantidadRegistros: lecheRango.length,
        animalesProductivos: animalesProductivos,
      ),
      huevos: IndicadoresHuevos(
        totalUnidades: totalUnidades,
        promedioUnidadesPorRegistro:
            huevosRango.isEmpty ? 0 : totalUnidades / huevosRango.length,
        cantidadRegistros: huevosRango.length,
      ),
    );
  }
}
