import '../../models/financiera/balance.dart';
import '../../models/financiera/gasto.dart';
import '../../models/financiera/precio_mercado.dart';
import '../../models/financiera/venta.dart';

/// Contrato del módulo Financiera: agrupa los cuatro recursos reales del
/// backend (`/api/gastos`, `/api/ventas`, `/api/precios-mercado` y
/// `/api/balance`) en un solo repositorio, igual que Producción agrupa leche
/// y huevos y Ubicación agrupa lotes y potreros.
///
/// Las listas llegan ordenadas por el backend (gastos y ventas por fecha
/// descendente, balances por período descendente). Los filtros por mes,
/// por estado de pago y los totales se calculan en el cliente.
abstract class FinancieraRepository {
  // ── Gastos ────────────────────────────────────────────────────────────
  Future<List<Gasto>> listarGastos();
  Future<Gasto> crearGasto(CrearGastoDTO dto);
  Future<Gasto> actualizarGasto(int id, ActualizarGastoDTO dto);
  Future<void> eliminarGasto(int id);

  // ── Ventas ────────────────────────────────────────────────────────────
  Future<List<Venta>> listarVentas();
  Future<Venta> crearVenta(CrearVentaDTO dto);
  Future<Venta> actualizarVenta(int id, ActualizarVentaDTO dto);
  Future<void> eliminarVenta(int id);

  /// Acción rápida "Marcar como pagada": pasa la venta a `Pagado` con
  /// [fechaPago] (por defecto, hoy según el día local del teléfono). La
  /// fecha se envía SIEMPRE explícita, porque la que usaría el servidor si
  /// faltara es la de su reloj UTC.
  Future<Venta> marcarVentaComoPagada(int id, {DateTime? fechaPago});

  // ── Precios de mercado ────────────────────────────────────────────────
  Future<List<PrecioMercado>> listarPrecios();
  Future<PrecioMercado> crearPrecio(CrearPrecioMercadoDTO dto);
  Future<PrecioMercado> actualizarPrecio(
      int id, ActualizarPrecioMercadoDTO dto);
  Future<void> eliminarPrecio(int id);

  // ── Balance ───────────────────────────────────────────────────────────
  /// Balances ya generados. No se pueden editar ni eliminar: son fotos
  /// fijas (el backend no tiene endpoints para eso).
  Future<List<Balance>> listarBalances();

  /// Calcula y guarda un balance (`POST /balance/generar`): suma las
  /// ventas Pagadas por fecha de pago y los gastos por fecha dentro del
  /// rango, y devuelve el balance ya guardado.
  Future<Balance> generarBalance(GenerarBalanceDTO dto);
}
