import '../../models/animal.dart';
import '../../models/catalogo/especie.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';
import 'ubicacion_repository.dart';

/// Datos de referencia en memoria, usados solo cuando
/// `AppConfig.useRealApi = false`. No persiste entre reinicios de la app.
class MockUbicacionRepository implements UbicacionRepository {
  final List<LoteAnimal> _lotes = [
    const LoteAnimal(
      id: 1,
      nombre: 'Lote de prueba (mock)',
      especieId: 1,
      especie: Especie(id: 1, nombre: 'Bovino'),
      capacidadEstimada: 15,
      cantidadAnimales: 3,
    ),
  ];

  final List<Potrero> _potreros = [
    const Potrero(
      id: 1,
      nombre: 'Potrero de prueba (mock)',
      capacidadAnimales: 20,
      estado: 'Disponible',
      tamanoHectareas: 2.5,
    ),
  ];

  int _siguienteLoteId = 2;
  int _siguientePotreroId = 2;

  // -- Lotes --

  @override
  Future<List<LoteAnimal>> listarLotes() async => List.unmodifiable(_lotes);

  @override
  Future<LoteAnimal?> obtenerLote(int id) async =>
      _lotes.where((l) => l.id == id).firstOrNull;

  @override
  Future<LoteAnimal> crearLote(CrearLoteDTO dto) async {
    final nuevo = LoteAnimal(
      id: _siguienteLoteId++,
      nombre: dto.nombre,
      especieId: dto.especieId,
      fechaCreacion: dto.fechaCreacion,
      capacidadEstimada: dto.capacidadEstimada,
      descripcion: dto.descripcion,
    );
    _lotes.add(nuevo);
    return nuevo;
  }

  @override
  Future<LoteAnimal> actualizarLote(int id, ActualizarLoteDTO dto) async {
    final i = _lotes.indexWhere((l) => l.id == id);
    if (i == -1) throw Exception('Lote no encontrado');
    final actual = _lotes[i];
    final actualizado = LoteAnimal(
      id: actual.id,
      nombre: dto.nombre ?? actual.nombre,
      especieId: dto.especieId ?? actual.especieId,
      especie: actual.especie,
      fechaCreacion: dto.fechaCreacion ?? actual.fechaCreacion,
      capacidadEstimada: dto.capacidadEstimada ?? actual.capacidadEstimada,
      descripcion: dto.descripcion ?? actual.descripcion,
      encargadoId: actual.encargadoId,
      encargado: actual.encargado,
      cantidadAnimales: actual.cantidadAnimales,
    );
    _lotes[i] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminarLote(int id) async {
    _lotes.removeWhere((l) => l.id == id);
  }

  @override
  Future<LoteAnimal> asignarEncargadoLote(int id, int? encargadoId) async {
    final i = _lotes.indexWhere((l) => l.id == id);
    if (i == -1) throw Exception('Lote no encontrado');
    final actual = _lotes[i];
    final actualizado = LoteAnimal(
      id: actual.id,
      nombre: actual.nombre,
      especieId: actual.especieId,
      especie: actual.especie,
      fechaCreacion: actual.fechaCreacion,
      capacidadEstimada: actual.capacidadEstimada,
      descripcion: actual.descripcion,
      encargadoId: encargadoId,
      encargado: encargadoId != null
          ? const EncargadoResumen(
              id: 1,
              nombreUsuario: 'Encargado (mock)',
              correoElectronico: 'mock@mock.com')
          : null,
      cantidadAnimales: actual.cantidadAnimales,
    );
    _lotes[i] = actualizado;
    return actualizado;
  }

  // -- Potreros --

  @override
  Future<List<Potrero>> listarPotreros() async => List.unmodifiable(_potreros);

  @override
  Future<Potrero?> obtenerPotrero(int id) async =>
      _potreros.where((p) => p.id == id).firstOrNull;

  @override
  Future<Potrero> crearPotrero(CrearPotreroDTO dto) async {
    final nuevo = Potrero(
      id: _siguientePotreroId++,
      nombre: dto.nombre,
      capacidadAnimales: dto.capacidadAnimales,
      estado: dto.estado ?? 'Disponible',
      tamanoHectareas: dto.tamanoHectareas,
      fechaCreacion: dto.fechaCreacion,
      descripcion: dto.descripcion,
    );
    _potreros.add(nuevo);
    return nuevo;
  }

  @override
  Future<Potrero> actualizarPotrero(int id, ActualizarPotreroDTO dto) async {
    final i = _potreros.indexWhere((p) => p.id == id);
    if (i == -1) throw Exception('Potrero no encontrado');
    final actual = _potreros[i];
    final actualizado = Potrero(
      id: actual.id,
      nombre: dto.nombre ?? actual.nombre,
      capacidadAnimales: dto.capacidadAnimales ?? actual.capacidadAnimales,
      estado: dto.estado ?? actual.estado,
      tamanoHectareas: dto.tamanoHectareas ?? actual.tamanoHectareas,
      fechaCreacion: dto.fechaCreacion ?? actual.fechaCreacion,
      descripcion: dto.descripcion ?? actual.descripcion,
      fotoUrl: actual.fotoUrl,
      encargados: actual.encargados,
    );
    _potreros[i] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminarPotrero(int id) async {
    _potreros.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<Animal>> animalesDelPotrero(int id) async => const [];

  @override
  Future<Potrero> agregarEncargadoPotrero(int id, int usuarioId) async {
    final i = _potreros.indexWhere((p) => p.id == id);
    if (i == -1) throw Exception('Potrero no encontrado');
    final actual = _potreros[i];
    final nuevoEncargado = PotreroEncargado(
      usuario: EncargadoResumen(
        id: usuarioId,
        nombreUsuario: 'Encargado $usuarioId (mock)',
        correoElectronico: 'mock$usuarioId@mock.com',
      ),
    );
    final actualizado = Potrero(
      id: actual.id,
      nombre: actual.nombre,
      capacidadAnimales: actual.capacidadAnimales,
      estado: actual.estado,
      tamanoHectareas: actual.tamanoHectareas,
      fechaCreacion: actual.fechaCreacion,
      descripcion: actual.descripcion,
      fotoUrl: actual.fotoUrl,
      encargados: [...actual.encargados, nuevoEncargado],
    );
    _potreros[i] = actualizado;
    return actualizado;
  }

  @override
  Future<Potrero> quitarEncargadoPotrero(int id, int usuarioId) async {
    final i = _potreros.indexWhere((p) => p.id == id);
    if (i == -1) throw Exception('Potrero no encontrado');
    final actual = _potreros[i];
    final actualizado = Potrero(
      id: actual.id,
      nombre: actual.nombre,
      capacidadAnimales: actual.capacidadAnimales,
      estado: actual.estado,
      tamanoHectareas: actual.tamanoHectareas,
      fechaCreacion: actual.fechaCreacion,
      descripcion: actual.descripcion,
      fotoUrl: actual.fotoUrl,
      encargados:
          actual.encargados.where((e) => e.usuario.id != usuarioId).toList(),
    );
    _potreros[i] = actualizado;
    return actualizado;
  }

  @override
  Future<Potrero> subirFotoPotrero(
    int id, {
    required List<int> bytes,
    required String nombreArchivo,
  }) async {
    final i = _potreros.indexWhere((p) => p.id == id);
    if (i == -1) throw Exception('Potrero no encontrado');
    final actual = _potreros[i];
    final actualizado = Potrero(
      id: actual.id,
      nombre: actual.nombre,
      capacidadAnimales: actual.capacidadAnimales,
      estado: actual.estado,
      tamanoHectareas: actual.tamanoHectareas,
      fechaCreacion: actual.fechaCreacion,
      descripcion: actual.descripcion,
      fotoUrl: 'https://mock.local/$nombreArchivo',
      encargados: actual.encargados,
    );
    _potreros[i] = actualizado;
    return actualizado;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
