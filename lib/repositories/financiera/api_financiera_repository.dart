import '../../core/api_client.dart';
import '../../models/financiera/balance.dart';
import '../../models/financiera/gasto.dart';
import '../../models/financiera/precio_mercado.dart';
import '../../models/financiera/producto_stock.dart';
import '../../models/financiera/venta.dart';
import '../../utils/fecha_dia.dart';
import 'financiera_repository.dart';

class ApiFinancieraRepository implements FinancieraRepository {
  final ApiClient client;

  ApiFinancieraRepository({required this.client});

  // ── Gastos ────────────────────────────────────────────────────────────

  @override
  Future<List<Gasto>> listarGastos() async {
    final data = await client.get('/gastos') as List<dynamic>;
    return data.map((e) => Gasto.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Gasto> crearGasto(CrearGastoDTO dto) async {
    final data = await client.post('/gastos', body: dto.toJson());
    return Gasto.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Gasto> actualizarGasto(int id, ActualizarGastoDTO dto) async {
    final data = await client.put('/gastos/$id', body: dto.toJson());
    return Gasto.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> eliminarGasto(int id) async {
    await client.delete('/gastos/$id');
  }

  // ── Ventas ────────────────────────────────────────────────────────────

  @override
  Future<List<Venta>> listarVentas() async {
    final data = await client.get('/ventas') as List<dynamic>;
    return data.map((e) => Venta.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Venta> crearVenta(CrearVentaDTO dto) async {
    final data = await client.post('/ventas', body: dto.toJson());
    return Venta.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Venta> actualizarVenta(int id, ActualizarVentaDTO dto) async {
    final data = await client.put('/ventas/$id', body: dto.toJson());
    return Venta.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> eliminarVenta(int id) async {
    await client.delete('/ventas/$id');
  }

  @override
  Future<Venta> marcarVentaComoPagada(int id, {DateTime? fechaPago}) {
    return actualizarVenta(
      id,
      ActualizarVentaDTO(
        estadoPago: estadoPagado,
        fechaPago: fechaPago ?? FechaDia.hoy(),
      ),
    );
  }

  // ── Precios de mercado ────────────────────────────────────────────────

  @override
  Future<List<PrecioMercado>> listarPrecios() async {
    final data = await client.get('/precios-mercado') as List<dynamic>;
    return data
        .map((e) => PrecioMercado.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PrecioMercado> crearPrecio(CrearPrecioMercadoDTO dto) async {
    final data = await client.post('/precios-mercado', body: dto.toJson());
    return PrecioMercado.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<PrecioMercado> actualizarPrecio(
      int id, ActualizarPrecioMercadoDTO dto) async {
    final data = await client.put('/precios-mercado/$id', body: dto.toJson());
    return PrecioMercado.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> eliminarPrecio(int id) async {
    await client.delete('/precios-mercado/$id');
  }

  // ── Stock ─────────────────────────────────────────────────────────────

  @override
  Future<List<ProductoStock>> listarStock() async {
    final data = await client.get('/stock') as List<dynamic>;
    return data
        .map((e) => ProductoStock.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Balance ───────────────────────────────────────────────────────────

  @override
  Future<List<Balance>> listarBalances() async {
    final data = await client.get('/balance') as List<dynamic>;
    return data
        .map((e) => Balance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Balance> generarBalance(GenerarBalanceDTO dto) async {
    final data = await client.post('/balance/generar', body: dto.toJson());
    return Balance.fromJson(data as Map<String, dynamic>);
  }
}
