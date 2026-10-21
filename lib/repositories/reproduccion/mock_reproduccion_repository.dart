import '../../models/reproduccion/seguimiento_gestacion.dart';
import 'reproduccion_repository.dart';

const _usuarioDemo =
    UsuarioReferencia(id: 1, nombreUsuario: 'Usuario de prueba');

class MockReproduccionRepository implements ReproduccionRepository {
  final List<SeguimientoGestacion> _registros = [
    SeguimientoGestacion(
      id: 1,
      animalId: 1,
      tipo: 'IA',
      fechaInseminacion: DateTime.now().subtract(const Duration(days: 30)),
      fechaEstimadaParto: DateTime.now().add(const Duration(days: 253)),
      estado: 'Gestante',
      creadoEn: DateTime.now().subtract(const Duration(days: 30)),
      animal:
          const AnimalReferencia(id: 1, codigo: 'ANI-0001', nombre: 'Lucera'),
      creadoPor: _usuarioDemo,
      confirmadoPor: _usuarioDemo,
      confirmadoEn: DateTime.now().subtract(const Duration(days: 28)),
    ),
    // 2026-10-20: datos de ejemplo extra -- para que las 4 pantallas nuevas
    // (Gestaciones / Partos pendientes / Partos este mes / Fertilidad del
    // mes) y el Historial se puedan probar en modo mock sin backend real.
    SeguimientoGestacion(
      id: 2,
      animalId: 2,
      tipo: 'Monta natural',
      fechaInseminacion: DateTime.now().subtract(const Duration(days: 5)),
      fechaEstimadaParto: DateTime.now().add(const Duration(days: 109)),
      estado: 'Pendiente',
      creadoEn: DateTime.now().subtract(const Duration(days: 5)),
      animal: const AnimalReferencia(id: 2, codigo: 'ANI-0002', nombre: 'Wawa'),
      creadoPor: _usuarioDemo,
    ),
    SeguimientoGestacion(
      id: 3,
      animalId: 3,
      tipo: 'IA',
      fechaInseminacion: DateTime.now().subtract(const Duration(days: 290)),
      fechaEstimadaParto: DateTime.now().subtract(const Duration(days: 7)),
      fechaRealParto: DateTime.now().subtract(const Duration(days: 6)),
      estado: 'Parida',
      creadoEn: DateTime.now().subtract(const Duration(days: 290)),
      animal: const AnimalReferencia(
          id: 3, codigo: 'ANI-0003', nombre: 'Lolito el Perrito'),
      creadoPor: _usuarioDemo,
      confirmadoPor: _usuarioDemo,
      confirmadoEn: DateTime.now().subtract(const Duration(days: 288)),
      cerradoPor: _usuarioDemo,
      cerradoEn: DateTime.now().subtract(const Duration(days: 6)),
    ),
    SeguimientoGestacion(
      id: 4,
      animalId: 4,
      tipo: 'IA',
      fechaInseminacion: DateTime.now().subtract(const Duration(days: 20)),
      fechaEstimadaParto: DateTime.now().add(const Duration(days: 94)),
      estado: 'Fallida',
      creadoEn: DateTime.now().subtract(const Duration(days: 20)),
      animal: const AnimalReferencia(id: 4, codigo: 'ANI-0028', nombre: 'WiWi'),
      creadoPor: _usuarioDemo,
      cerradoPor: _usuarioDemo,
      cerradoEn: DateTime.now().subtract(const Duration(days: 2)),
    ),
    // Ejemplo de registro con borrado lógico -- solo debe aparecer en
    // Historial (incluirEliminados: true), nunca en ninguna otra pantalla.
    SeguimientoGestacion(
      id: 5,
      animalId: 5,
      tipo: 'Monta natural',
      fechaInseminacion: DateTime.now().subtract(const Duration(days: 60)),
      fechaEstimadaParto: DateTime.now().add(const Duration(days: 54)),
      estado: 'Pendiente',
      creadoEn: DateTime.now().subtract(const Duration(days: 60)),
      animal: const AnimalReferencia(
          id: 5, codigo: 'ANI-0025', nombre: 'WeWe (PRUEBA 4)'),
      creadoPor: _usuarioDemo,
      eliminadoPor: _usuarioDemo,
      eliminadoEn: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
  int _correlativo = 6;

  @override
  Future<List<SeguimientoGestacion>> listar({
    int? animalId,
    String? estado,
    bool incluirEliminados = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _registros.where((r) {
      if (animalId != null && r.animalId != animalId) return false;
      if (estado != null && r.estado != estado) return false;
      if (!incluirEliminados && r.estaEliminado) return false;
      return true;
    }).toList();
  }

  @override
  Future<SeguimientoGestacion?> obtenerPorId(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _registros.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SeguimientoGestacion> crear(CrearSeguimientoDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final nuevo = SeguimientoGestacion(
      id: _correlativo++,
      animalId: dto.animalId,
      machoId: dto.machoId,
      tipo: dto.tipo,
      fechaInseminacion: dto.fechaInseminacion,
      fechaEstimadaParto: dto.fechaEstimadaParto,
      estado: 'Pendiente',
      notas: dto.notas,
      creadoEn: DateTime.now(),
      creadoPor: _usuarioDemo,
    );
    _registros.add(nuevo);
    return nuevo;
  }

  @override
  Future<SeguimientoGestacion> actualizar(
      int id, ActualizarSeguimientoDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _registros.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _registros[idx];
    if (actual.estaEliminado) {
      throw Exception('El registro ya fue eliminado (mock)');
    }
    if (actual.estaCerrado) {
      throw Exception(
          'El registro ya está cerrado y no se puede editar (mock)');
    }
    final actualizado = SeguimientoGestacion(
      id: actual.id,
      animalId: actual.animalId,
      machoId: dto.machoId ?? actual.machoId,
      tipo: dto.tipo ?? actual.tipo,
      fechaInseminacion: dto.fechaInseminacion ?? actual.fechaInseminacion,
      fechaEstimadaParto: dto.fechaEstimadaParto ?? actual.fechaEstimadaParto,
      estado: actual.estado,
      notas: dto.notas ?? actual.notas,
      creadoEn: actual.creadoEn,
      animal: actual.animal,
      macho: actual.macho,
      creadoPor: actual.creadoPor,
      confirmadoPor: actual.confirmadoPor,
      confirmadoEn: actual.confirmadoEn,
      cerradoPor: actual.cerradoPor,
      cerradoEn: actual.cerradoEn,
      // 2026-10-20: deja constancia de quién editó por última vez (mismo
      // comportamiento del backend real).
      editadoPor: _usuarioDemo,
      editadoEn: DateTime.now(),
    );
    _registros[idx] = actualizado;
    return actualizado;
  }

  @override
  Future<SeguimientoGestacion> confirmar(int id, {String? notas}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _registros.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _registros[idx];
    if (!actual.estaPendiente) {
      throw Exception(
          'Solo se puede confirmar un seguimiento en estado Pendiente (mock)');
    }
    final actualizado = SeguimientoGestacion(
      id: actual.id,
      animalId: actual.animalId,
      machoId: actual.machoId,
      tipo: actual.tipo,
      fechaInseminacion: actual.fechaInseminacion,
      fechaEstimadaParto: actual.fechaEstimadaParto,
      estado: 'Gestante',
      notas: notas ?? actual.notas,
      creadoEn: actual.creadoEn,
      animal: actual.animal,
      macho: actual.macho,
      creadoPor: actual.creadoPor,
      confirmadoPor: _usuarioDemo,
      confirmadoEn: DateTime.now(),
      editadoPor: actual.editadoPor,
      editadoEn: actual.editadoEn,
    );
    _registros[idx] = actualizado;
    return actualizado;
  }

  @override
  Future<SeguimientoGestacion> cerrar(int id, CerrarSeguimientoDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _registros.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _registros[idx];
    if (actual.estaCerrado) {
      throw Exception('El registro ya fue cerrado (mock)');
    }
    final actualizado = SeguimientoGestacion(
      id: actual.id,
      animalId: actual.animalId,
      machoId: actual.machoId,
      tipo: actual.tipo,
      fechaInseminacion: actual.fechaInseminacion,
      fechaEstimadaParto: actual.fechaEstimadaParto,
      fechaRealParto: dto.fechaRealParto ?? actual.fechaRealParto,
      estado: dto.resultado,
      notas: dto.notas ?? actual.notas,
      creadoEn: actual.creadoEn,
      animal: actual.animal,
      macho: actual.macho,
      creadoPor: actual.creadoPor,
      confirmadoPor: actual.confirmadoPor,
      confirmadoEn: actual.confirmadoEn,
      cerradoPor: _usuarioDemo,
      cerradoEn: DateTime.now(),
      editadoPor: actual.editadoPor,
      editadoEn: actual.editadoEn,
    );
    _registros[idx] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminar(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _registros.indexWhere((r) => r.id == id);
    if (idx == -1) throw Exception('Registro no encontrado (mock)');
    final actual = _registros[idx];
    if (actual.estaEliminado) {
      throw Exception('El registro ya fue eliminado (mock)');
    }
    // 2026-10-20: ya NO se quita de la lista -- borrado lógico, igual que
    // el backend real, para que siga apareciendo en el Historial.
    _registros[idx] = SeguimientoGestacion(
      id: actual.id,
      animalId: actual.animalId,
      machoId: actual.machoId,
      tipo: actual.tipo,
      fechaInseminacion: actual.fechaInseminacion,
      fechaEstimadaParto: actual.fechaEstimadaParto,
      fechaRealParto: actual.fechaRealParto,
      estado: actual.estado,
      notas: actual.notas,
      creadoEn: actual.creadoEn,
      animal: actual.animal,
      macho: actual.macho,
      creadoPor: actual.creadoPor,
      confirmadoPor: actual.confirmadoPor,
      confirmadoEn: actual.confirmadoEn,
      cerradoPor: actual.cerradoPor,
      cerradoEn: actual.cerradoEn,
      editadoPor: actual.editadoPor,
      editadoEn: actual.editadoEn,
      eliminadoPor: _usuarioDemo,
      eliminadoEn: DateTime.now(),
    );
  }
}
