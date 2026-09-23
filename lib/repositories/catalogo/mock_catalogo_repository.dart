import '../../models/catalogo/especie.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';
import '../../models/catalogo/raza.dart';
import '../../models/inventario/categoria_bodega.dart';
import '../../models/inventario/lote_inventario.dart';
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

  final _lotes = const [
    LoteAnimal(id: 1, nombre: 'Lote Lechero 1', potreroId: 1),
    LoteAnimal(id: 2, nombre: 'Lote Maternidad', potreroId: 2),
    LoteAnimal(id: 3, nombre: 'Lote Engorde'),
  ];

  final _potreros = const [
    Potrero(id: 1, nombre: 'Potrero Norte', capacidadAnimales: 20, estado: 'Disponible'),
    Potrero(id: 2, nombre: 'Potrero Sur', capacidadAnimales: 15, estado: 'Disponible'),
  ];

  final _categoriasBodega = const [
    CategoriaBodega(id: 1, nombre: 'Medicamentos'),
    CategoriaBodega(id: 2, nombre: 'Alimentos'),
  ];

  final List<LoteInventario> _lotesInventario = [
    LoteInventario(
      id: 1,
      insumoId: 1,
      numeroLote: 'L-2026-01',
      fechaVencimiento: DateTime.now().add(const Duration(days: 45)),
      cantidadDisponible: 40,
      costoUnitario: 12000,
    ),
    LoteInventario(
      id: 2,
      insumoId: 2,
      numeroLote: 'L-2026-02',
      fechaVencimiento: DateTime.now().add(const Duration(days: 10)),
      cantidadDisponible: 3,
      costoUnitario: 85000,
    ),
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

  @override
  Future<List<LoteAnimal>> listarLotes() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _lotes;
  }

  @override
  Future<List<Potrero>> listarPotreros() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _potreros;
  }

  @override
  Future<List<CategoriaBodega>> listarCategoriasBodega() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _categoriasBodega;
  }

  @override
  Future<List<LoteInventario>> listarLotesInventario({
    int? insumoId,
    int? venceEnDias,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var filtrados = _lotesInventario.where((l) {
      if (insumoId != null && l.insumoId != insumoId) return false;
      if (venceEnDias != null) {
        final limite = DateTime.now().add(Duration(days: venceEnDias));
        if (l.fechaVencimiento.isAfter(limite)) return false;
      }
      return true;
    }).toList();
    filtrados.sort((a, b) => a.fechaVencimiento.compareTo(b.fechaVencimiento));
    return filtrados;
  }
}
