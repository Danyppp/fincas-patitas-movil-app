import '../../models/catalogo/especie.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';
import '../../models/catalogo/raza.dart';

/// Catálogos de apoyo (especies/razas/lotes/potreros) usados en los
/// formularios de Animales. Son de solo lectura desde la app móvil por
/// ahora (el CRUD de cada uno existe en el backend, pero no es prioridad
/// de este sprint).
abstract class CatalogoRepository {
  Future<List<Especie>> listarEspecies();
  Future<List<Raza>> listarRazas({int? especieId});
  Future<List<LoteAnimal>> listarLotes();
  Future<List<Potrero>> listarPotreros();
}
