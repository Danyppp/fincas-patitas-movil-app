import '../../models/salud/evento_sanitario.dart';

/// Contrato del módulo Salud contra `/api/eventos-sanitarios`.
///
/// El backend no pagina este endpoint (a diferencia de `/animales`) ni
/// permite filtrar por especie directamente -- la paginación de 10 por
/// página y el filtro por especie (vaca/cerdo/gallina) que pidió Dany para
/// "Eventos de salud registrados" se resuelven en el cliente, sobre la
/// lista completa que devuelve `listar()`.
abstract class EventoSanitarioRepository {
  // 2026-11-01 (punto nuevo de Dany: "Historial" con eliminados, mismo
  // estilo de Producción/Reproducción): `incluirEliminados` trae también
  // los eventos con borrado lógico (false por defecto, mismo
  // comportamiento de siempre si no se pide explícitamente).
  Future<List<EventoSanitario>> listar({
    int? animalId,
    String? tipoEvento,
    bool incluirEliminados = false,
  });

  Future<EventoSanitario?> obtenerPorId(int id);

  Future<EventoSanitario> crear(CrearEventoSanitarioDTO dto);

  Future<EventoSanitario> actualizar(int id, ActualizarEventoSanitarioDTO dto);

  Future<EventoSanitario> cambiarEstado(int id, String estado);

  Future<void> eliminar(int id);
}
