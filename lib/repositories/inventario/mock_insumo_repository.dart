import '../../models/inventario/categoria_bodega.dart';
import '../../models/inventario/insumo.dart';
import 'insumo_repository.dart';

class MockInsumoRepository implements InsumoRepository {
  final List<Insumo> _insumos = [
    const Insumo(
      id: 1,
      categoriaId: 1,
      nombre: 'Aftogan',
      descripcion: 'Frasco multidosis',
      unidadMedida: 'ml',
      stockActual: 40,
      stockMinimo: 20,
      stockBajo: false,
      categoria: CategoriaBodega(id: 1, nombre: 'Medicamentos'),
    ),
    const Insumo(
      id: 2,
      categoriaId: 2,
      nombre: 'Concentrado engorde',
      descripcion: 'Bulto 40kg',
      unidadMedida: 'Bulto',
      stockActual: 3,
      stockMinimo: 5,
      stockBajo: true,
      categoria: CategoriaBodega(id: 2, nombre: 'Alimentos'),
    ),
    const Insumo(
      id: 3,
      categoriaId: 1,
      nombre: 'Ivermectina',
      unidadMedida: 'ml',
      stockActual: 0,
      stockMinimo: 10,
      stockBajo: true,
      categoria: CategoriaBodega(id: 1, nombre: 'Medicamentos'),
    ),
  ];
  int _correlativo = 4;

  @override
  Future<List<Insumo>> listar({int? categoriaId, bool soloStockBajo = false}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var filtrados = _insumos.where((i) {
      if (categoriaId != null && i.categoriaId != categoriaId) return false;
      if (soloStockBajo && !i.stockBajo) return false;
      return true;
    }).toList();
    return filtrados;
  }

  @override
  Future<Insumo?> obtenerPorId(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _insumos.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Insumo> crear(CrearInsumoDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final nuevo = Insumo(
      id: _correlativo++,
      categoriaId: dto.categoriaId,
      nombre: dto.nombre,
      descripcion: dto.descripcion,
      unidadMedida: dto.unidadMedida,
      stockActual: dto.stockInicial ?? 0,
      stockMinimo: dto.stockMinimo ?? 0,
      stockBajo: (dto.stockInicial ?? 0) <= (dto.stockMinimo ?? 0),
    );
    _insumos.add(nuevo);
    return nuevo;
  }

  @override
  Future<Insumo> actualizar(int id, ActualizarInsumoDTO dto) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final indice = _insumos.indexWhere((i) => i.id == id);
    if (indice == -1) throw StateError('Insumo no encontrado');
    final actualizado = _insumos[indice].copyWith(
      nombre: dto.nombre,
      descripcion: dto.descripcion,
      stockMinimo: dto.stockMinimo,
    );
    _insumos[indice] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminar(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _insumos.removeWhere((i) => i.id == id);
  }

  @override
  Future<Insumo> registrarMovimiento(
    int insumoId, {
    required String tipo,
    required double cantidad,
    required String motivo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final indice = _insumos.indexWhere((i) => i.id == insumoId);
    if (indice == -1) throw StateError('Insumo no encontrado');
    final actual = _insumos[indice];
    final nuevoStock =
        tipo == 'Entrada' ? actual.stockActual + cantidad : actual.stockActual - cantidad;
    if (nuevoStock < 0) {
      throw StateError('El stock actual es insuficiente para esta salida');
    }
    final actualizado = actual.copyWith(stockActual: nuevoStock);
    _insumos[indice] = actualizado;
    return actualizado;
  }
}
