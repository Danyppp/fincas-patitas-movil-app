import '../../models/animal.dart';
import '../../models/catalogo/especie.dart';
import '../../models/catalogo/raza.dart';
import '../../models/salud/evento_sanitario.dart';
import 'evento_sanitario_repository.dart';

/// Mismos 2 animales de ejemplo que usa `MockAnimalRepository` (ids 1 y
/// 2), para que un evento sanitario de prueba se pueda ver también desde
/// la ficha de ese animal en modo mock.
class MockEventoSanitarioRepository implements EventoSanitarioRepository {
  static const _lucera = Animal(
    id: 1,
    codigo: 'ANI-0001',
    nombre: 'Lucera',
    genero: 'Hembra',
    estado: 'Activo',
    especieId: 1,
    razaId: 1,
    especie: Especie(id: 1, nombre: 'Vaca'),
    raza: Raza(id: 1, especieId: 1, nombre: 'Holstein'),
  );

  static const _pinto = Animal(
    id: 2,
    codigo: 'ANI-0002',
    nombre: 'Pinto',
    genero: 'Macho',
    estado: 'Activo',
    especieId: 2,
    razaId: 3,
    especie: Especie(id: 2, nombre: 'Cerdo'),
    raza: Raza(id: 3, especieId: 2, nombre: 'Yorkshire'),
  );

  late final List<EventoSanitario> _eventos = [
    EventoSanitario(
      id: 1,
      animalId: 1,
      tipoEvento: 'Vacunación',
      estado: 'Resuelto',
      dosisAplicada: 2.0,
      descripcionTratamiento: 'Fiebre Aftosa (Ciclo Oficial ICA)',
      fechaEvento: DateTime.now().subtract(const Duration(days: 20)),
      viaAdministracion: 'Subcutánea',
      unidadDosis: 'ml',
      profesionalResponsable: 'Dr. Diego Castro',
      medicamento: 'Vacuna Aftogan 100ml',
      fechaProximoRefuerzo: DateTime.now().add(const Duration(days: 45)),
      animal: _lucera,
    ),
    EventoSanitario(
      id: 2,
      animalId: 2,
      tipoEvento: 'Desparasitación',
      estado: 'Abierto',
      dosisAplicada: 15.0,
      descripcionTratamiento: 'Desparasitación preventiva',
      fechaEvento: DateTime.now().subtract(const Duration(days: 3)),
      viaAdministracion: 'Oral',
      unidadDosis: 'g/peso',
      medicamento: 'Fenbendazol',
      animal: _pinto,
    ),
  ];
  int _correlativo = 3;

  @override
  Future<List<EventoSanitario>> listar({
    int? animalId,
    String? tipoEvento,
    bool incluirEliminados = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _eventos.where((e) {
      if (animalId != null && e.animalId != animalId) return false;
      if (tipoEvento != null && e.tipoEvento != tipoEvento) return false;
      // 2026-11-01: mismo comportamiento del backend real -- los
      // eliminados (borrado lógico) quedan fuera salvo que se pidan.
      if (!incluirEliminados && e.estaEliminado) return false;
      return true;
    }).toList()
      ..sort((a, b) => (b.fechaEvento ?? DateTime(0))
          .compareTo(a.fechaEvento ?? DateTime(0)));
  }

  @override
  Future<EventoSanitario?> obtenerPorId(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _eventos.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Animal? _animalDe(int animalId) {
    if (animalId == _lucera.id) return _lucera;
    if (animalId == _pinto.id) return _pinto;
    return null;
  }

  @override
  Future<EventoSanitario> crear(CrearEventoSanitarioDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final nuevo = EventoSanitario(
      id: _correlativo++,
      animalId: dto.animalId,
      tipoEvento: dto.tipoEvento,
      estado: 'Abierto',
      dosisAplicada: dto.dosisAplicada,
      descripcionTratamiento: dto.descripcionTratamiento,
      fechaEvento: dto.fechaEvento ?? DateTime.now(),
      viaAdministracion: dto.viaAdministracion,
      unidadDosis: dto.unidadDosis,
      profesionalResponsable: dto.profesionalResponsable,
      medicamento: dto.medicamento,
      fechaProximoRefuerzo: dto.fechaProximoRefuerzo,
      animal: _animalDe(dto.animalId),
      creadoPorNombre: 'Usuario de prueba',
    );
    _eventos.add(nuevo);
    return nuevo;
  }

  @override
  Future<EventoSanitario> actualizar(
      int id, ActualizarEventoSanitarioDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final i = _eventos.indexWhere((e) => e.id == id);
    if (i == -1) throw Exception('Evento no encontrado');
    final actual = _eventos[i];
    final actualizado = EventoSanitario(
      id: actual.id,
      animalId: actual.animalId,
      tipoEvento: dto.tipoEvento ?? actual.tipoEvento,
      estado: actual.estado,
      dosisAplicada: dto.dosisAplicada ?? actual.dosisAplicada,
      descripcionTratamiento:
          dto.descripcionTratamiento ?? actual.descripcionTratamiento,
      fechaEvento: dto.fechaEvento ?? actual.fechaEvento,
      viaAdministracion: dto.viaAdministracion ?? actual.viaAdministracion,
      unidadDosis: dto.unidadDosis ?? actual.unidadDosis,
      profesionalResponsable:
          dto.profesionalResponsable ?? actual.profesionalResponsable,
      medicamento: dto.medicamento ?? actual.medicamento,
      fechaProximoRefuerzo:
          dto.fechaProximoRefuerzo ?? actual.fechaProximoRefuerzo,
      animal: actual.animal,
      creadoPorNombre: actual.creadoPorNombre,
    );
    _eventos[i] = actualizado;
    return actualizado;
  }

  @override
  Future<EventoSanitario> cambiarEstado(int id, String estado) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final i = _eventos.indexWhere((e) => e.id == id);
    if (i == -1) throw Exception('Evento no encontrado');
    final actual = _eventos[i];
    final actualizado = EventoSanitario(
      id: actual.id,
      animalId: actual.animalId,
      tipoEvento: actual.tipoEvento,
      estado: estado,
      dosisAplicada: actual.dosisAplicada,
      descripcionTratamiento: actual.descripcionTratamiento,
      fechaEvento: actual.fechaEvento,
      viaAdministracion: actual.viaAdministracion,
      unidadDosis: actual.unidadDosis,
      profesionalResponsable: actual.profesionalResponsable,
      medicamento: actual.medicamento,
      fechaProximoRefuerzo: actual.fechaProximoRefuerzo,
      animal: actual.animal,
      creadoPorNombre: actual.creadoPorNombre,
    );
    _eventos[i] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminar(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    // 2026-11-01: borrado lógico, igual que el backend real -- el evento
    // se queda en la lista interna, solo se marca eliminado, para que el
    // filtro "Eliminados" de "Eventos de salud registrados" también
    // funcione en modo mock (sin backend real).
    final i = _eventos.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final actual = _eventos[i];
    _eventos[i] = EventoSanitario(
      id: actual.id,
      animalId: actual.animalId,
      tipoEvento: actual.tipoEvento,
      estado: actual.estado,
      dosisAplicada: actual.dosisAplicada,
      descripcionTratamiento: actual.descripcionTratamiento,
      fechaEvento: actual.fechaEvento,
      viaAdministracion: actual.viaAdministracion,
      unidadDosis: actual.unidadDosis,
      profesionalResponsable: actual.profesionalResponsable,
      medicamento: actual.medicamento,
      fechaProximoRefuerzo: actual.fechaProximoRefuerzo,
      animal: actual.animal,
      creadoPorNombre: actual.creadoPorNombre,
      eliminadoEn: DateTime.now(),
      eliminadoPorNombre: 'Usuario de prueba',
    );
  }
}
