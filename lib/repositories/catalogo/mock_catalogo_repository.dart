import '../../models/catalogo/especie.dart';
import '../../models/catalogo/raza.dart';
import 'catalogo_repository.dart';

class MockCatalogoRepository implements CatalogoRepository {
  final _especies = const [
    Especie(id: 1, nombre: 'Vaca'),
    Especie(id: 2, nombre: 'Cerdo'),
    Especie(id: 3, nombre: 'Gallina'),
  ];

  final _razas = const [
    Raza(id: 1, especieId: 1, nombre: 'Holstein'),
    Raza(id: 2, especieId: 1, nombre: 'Normando'),
    Raza(id: 3, especieId: 2, nombre: 'Yorkshire'),
    Raza(id: 4, especieId: 3, nombre: 'Leghorn'),
  ];

  @override
  Future<List<Especie>> listarEspecies() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _especies;
  }

  @override
  Future<List<Raza>> listarRazas({int? especieId}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (especieId == null) return _razas;
    return _razas.where((r) => r.especieId == especieId).toList();
  }
}
