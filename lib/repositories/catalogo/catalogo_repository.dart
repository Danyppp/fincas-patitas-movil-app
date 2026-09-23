import '../../models/catalogo/especie.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';
import '../../models/catalogo/raza.dart';
import '../../models/inventario/categoria_bodega.dart';
import '../../models/inventario/lote_inventario.dart';

/// Catálogos de apoyo (especies/razas/lotes/potreros de Animales, y ahora
/// categorías/lotes de Inventario) usados en los formularios y listados.
/// Son de solo lectura desde la app móvil por ahora (el CRUD de estos
/// catálogos existe en el backend, pero no es prioridad de este sprint).
abstract class CatalogoRepository {
  Future<List<Especie>> listarEspecies();
  Future<List<Raza>> listarRazas({int? especieId});
  Future<List<LoteAnimal>> listarLotes();
  Future<List<Potrero>> listarPotreros();

  /// Categorías de insumo de bodega (`GET /categorias-bodega`).
  Future<List<CategoriaBodega>> listarCategoriasBodega();

  /// Lotes de inventario, opcionalmente filtrados por insumo o por
  /// vencimiento próximo. Usado en el listado de Inventario para mostrar
  /// el vencimiento más próximo de cada insumo (segunda consulta, igual
  /// que la genealogía en Animales).
  Future<List<LoteInventario>> listarLotesInventario({
    int? insumoId,
    int? venceEnDias,
  });
}
