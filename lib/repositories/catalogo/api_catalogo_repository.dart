import '../../core/api_client.dart';
import '../../models/catalogo/especie.dart';
import '../../models/catalogo/raza.dart';
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
}
