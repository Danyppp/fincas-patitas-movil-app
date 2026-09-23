import '../../core/api_client.dart';
import '../../models/catalogo/especie.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';
import '../../models/catalogo/raza.dart';
import '../../models/inventario/categoria_bodega.dart';
import '../../models/inventario/lote_inventario.dart';
import 'catalogo_repository.dart';

class ApiCatalogoRepository implements CatalogoRepository {
  final ApiClient client;

  ApiCatalogoRepository({required this.client});

  @override
  Future<List<Especie>> listarEspecies() async {
    final data = await client.get('/especies') as List<dynamic>;
    return data.map((e) => Especie.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Raza>> listarRazas({int? especieId}) async {
    final data = await client.get(
      '/razas',
      query: {if (especieId != null) 'especie_id': especieId},
    ) as List<dynamic>;
    return data.map((r) => Raza.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<LoteAnimal>> listarLotes() async {
    final data = await client.get('/lotes-animales') as List<dynamic>;
    return data.map((l) => LoteAnimal.fromJson(l as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Potrero>> listarPotreros() async {
    // El comentario @openapi de potrero.routes.ts dice '/potreros', pero
    // el montaje real en routes/index.ts es '/ubicaciones-potreros'
    // (confirmado leyendo el código fuente del backend). El swagger está
    // desactualizado en este punto.
    final data = await client.get('/ubicaciones-potreros') as List<dynamic>;
    return data.map((p) => Potrero.fromJson(p as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<CategoriaBodega>> listarCategoriasBodega() async {
    final data = await client.get('/categorias-bodega') as List<dynamic>;
    return data
        .map((c) => CategoriaBodega.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<LoteInventario>> listarLotesInventario({
    int? insumoId,
    int? venceEnDias,
  }) async {
    final data = await client.get('/lotes-inventario', query: {
      if (insumoId != null) 'insumo_id': insumoId,
      if (venceEnDias != null) 'vence_en_dias': venceEnDias,
    }) as List<dynamic>;
    return data
        .map((l) => LoteInventario.fromJson(l as Map<String, dynamic>))
        .toList();
  }
}
