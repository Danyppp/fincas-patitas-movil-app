import '../../models/financiera/balance.dart';
import '../../models/financiera/gasto.dart';
import '../../models/financiera/precio_mercado.dart';
import '../../models/financiera/venta.dart';
import '../../utils/fecha_dia.dart';
import 'financiera_repository.dart';

/// Repositorio en memoria para desarrollar sin backend (`AppConfig.useRealApi
/// == false`). Imita las reglas del backend real: el total de la venta lo
/// calcula el repositorio, la fecha de pago se asigna según el estado, y el
/// balance suma solo ventas Pagadas por fecha de pago y gastos por fecha.
/// Los datos de ejemplo se arman a partir de "hoy" para que los filtros por
/// mes tengan algo que mostrar.
class MockFinancieraRepository implements FinancieraRepository {
  final List<Gasto> _gastos = [
    Gasto(
      id: 1,
      categoria: 'Alimento',
      descripcion: 'Concentrado para gallinas',
      monto: 180000,
      fecha: FechaDia.sumarDias(FechaDia.hoy(), -3),
      metodoPago: 'Efectivo',
    ),
    Gasto(
      id: 2,
      categoria: 'Medicamentos',
      descripcion: 'Desparasitante',
      monto: 65000,
      fecha: FechaDia.sumarDias(FechaDia.hoy(), -10),
      metodoPago: 'Transferencia',
    ),
  ];

  final List<Venta> _ventas = [
    Venta(
      id: 1,
      producto: 'Leche',
      cantidad: 50,
      precioUnitario: 2000,
      total: 100000,
      comprador: 'Cooperativa local',
      fecha: FechaDia.sumarDias(FechaDia.hoy(), -2),
      estadoPago: estadoPagado,
      fechaPago: FechaDia.sumarDias(FechaDia.hoy(), -2),
    ),
    Venta(
      id: 2,
      producto: 'Huevos',
      cantidad: 120,
      precioUnitario: 500,
      total: 60000,
      comprador: 'Tienda La Esquina',
      fecha: FechaDia.sumarDias(FechaDia.hoy(), -5),
      estadoPago: estadoPendiente,
      fechaLimitePago: FechaDia.sumarDias(FechaDia.hoy(), 2),
    ),
  ];

  final List<PrecioMercado> _precios = [
    PrecioMercado(
      id: 1,
      producto: 'Leche',
      precio: 2000,
      fecha: FechaDia.sumarDias(FechaDia.hoy(), -30),
    ),
    PrecioMercado(
      id: 2,
      producto: 'Leche',
      precio: 2200,
      fecha: FechaDia.sumarDias(FechaDia.hoy(), -4),
    ),
    PrecioMercado(
      id: 3,
      producto: 'Huevos',
      precio: 500,
      fecha: FechaDia.sumarDias(FechaDia.hoy(), -4),
    ),
  ];

  final List<Balance> _balances = [];

  int _correlativoGasto = 3;
  int _correlativoVenta = 3;
  int _correlativoPrecio = 4;
  int _correlativoBalance = 1;

  static double _redondear2(double valor) => (valor * 100).round() / 100;

  Future<void> _espera() => Future.delayed(const Duration(milliseconds: 200));

  // ── Gastos ────────────────────────────────────────────────────────────

  @override
  Future<List<Gasto>> listarGastos() async {
    await _espera();
    final copia = [..._gastos];
    copia.sort((a, b) => b.fecha.compareTo(a.fecha));
    return copia;
  }

  @override
  Future<Gasto> crearGasto(CrearGastoDTO dto) async {
    await _espera();
    if (dto.monto <= 0) throw StateError('monto debe ser mayor a 0');
    if (dto.metodoPago != null &&
        !metodosPagoValidos.contains(dto.metodoPago)) {
      throw StateError(
          'metodo_pago debe ser uno de: ${metodosPagoValidos.join(', ')}');
    }
    final nuevo = Gasto(
      id: _correlativoGasto++,
      categoria: dto.categoria,
      descripcion: dto.descripcion,
      monto: dto.monto,
      fecha: dto.fecha,
      metodoPago: dto.metodoPago,
    );
    _gastos.add(nuevo);
    return nuevo;
  }

  @override
  Future<Gasto> actualizarGasto(int id, ActualizarGastoDTO dto) async {
    await _espera();
    final indice = _gastos.indexWhere((g) => g.id == id);
    if (indice == -1) throw StateError('Gasto no encontrado');
    if (dto.metodoPago != null &&
        !metodosPagoValidos.contains(dto.metodoPago)) {
      throw StateError(
          'metodo_pago debe ser uno de: ${metodosPagoValidos.join(', ')}');
    }
    final actual = _gastos[indice];
    final actualizado = Gasto(
      id: actual.id,
      categoria: dto.categoria ?? actual.categoria,
      descripcion: dto.descripcion ?? actual.descripcion,
      monto: dto.monto ?? actual.monto,
      fecha: dto.fecha ?? actual.fecha,
      metodoPago: dto.metodoPago ?? actual.metodoPago,
    );
    _gastos[indice] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminarGasto(int id) async {
    await _espera();
    _gastos.removeWhere((g) => g.id == id);
  }

  // ── Ventas ────────────────────────────────────────────────────────────

  @override
  Future<List<Venta>> listarVentas() async {
    await _espera();
    final copia = [..._ventas];
    copia.sort((a, b) => b.fecha.compareTo(a.fecha));
    return copia;
  }

  @override
  Future<Venta> crearVenta(CrearVentaDTO dto) async {
    await _espera();
    if (dto.cantidad <= 0 || dto.precioUnitario <= 0) {
      throw StateError('cantidad y precio_unitario deben ser mayores a 0');
    }
    final estado = dto.estadoPago ?? estadoPagado;
    if (!estadosPagoValidos.contains(estado)) {
      throw StateError(
          'estado_pago debe ser uno de: ${estadosPagoValidos.join(', ')}');
    }

    DateTime? fechaPago;
    DateTime? fechaLimite;
    if (estado == estadoPagado) {
      // Pagada: sin fecha de pago explícita se usa la fecha de la venta.
      fechaPago = dto.fechaPago ?? dto.fecha;
    } else {
      if (dto.fechaPago != null) {
        throw StateError('Una venta Pendiente no puede tener fecha_pago');
      }
      fechaLimite = dto.fechaLimitePago;
      if (fechaLimite != null && fechaLimite.isBefore(dto.fecha)) {
        throw StateError(
            'fecha_limite_pago no puede ser anterior a la fecha de la venta');
      }
    }

    final nueva = Venta(
      id: _correlativoVenta++,
      producto: dto.producto,
      cantidad: dto.cantidad,
      precioUnitario: dto.precioUnitario,
      total: _redondear2(dto.cantidad * dto.precioUnitario),
      comprador: dto.comprador,
      fecha: dto.fecha,
      estadoPago: estado,
      fechaPago: fechaPago,
      fechaLimitePago: fechaLimite,
    );
    _ventas.add(nueva);
    return nueva;
  }

  @override
  Future<Venta> actualizarVenta(int id, ActualizarVentaDTO dto) async {
    await _espera();
    final indice = _ventas.indexWhere((v) => v.id == id);
    if (indice == -1) throw StateError('Venta no encontrada');
    final actual = _ventas[indice];

    final estadoFinal = dto.estadoPago ?? actual.estadoPago;
    if (!estadosPagoValidos.contains(estadoFinal)) {
      throw StateError(
          'estado_pago debe ser uno de: ${estadosPagoValidos.join(', ')}');
    }
    final fecha = dto.fecha ?? actual.fecha;
    DateTime? fechaPago = actual.fechaPago;
    DateTime? fechaLimite = actual.fechaLimitePago;

    if (estadoFinal == estadoPagado) {
      if (!actual.estaPagada) {
        // Pendiente -> Pagado: se registra el pago y se descarta el límite.
        fechaPago = dto.fechaPago ?? FechaDia.hoy();
        fechaLimite = null;
      } else if (dto.fechaPago != null) {
        fechaPago = dto.fechaPago;
      }
    } else {
      if (dto.fechaPago != null) {
        throw StateError('Una venta Pendiente no puede tener fecha_pago');
      }
      if (actual.estaPagada) {
        // Pagado -> Pendiente: se anula la fecha de pago.
        fechaPago = null;
      }
      if (dto.fechaLimitePago != null) {
        if (dto.fechaLimitePago!.isBefore(fecha)) {
          throw StateError(
              'fecha_limite_pago no puede ser anterior a la fecha de la venta');
        }
        fechaLimite = dto.fechaLimitePago;
      }
    }

    final cantidad = dto.cantidad ?? actual.cantidad;
    final precio = dto.precioUnitario ?? actual.precioUnitario;
    final actualizada = Venta(
      id: actual.id,
      producto: dto.producto ?? actual.producto,
      cantidad: cantidad,
      precioUnitario: precio,
      total: _redondear2(cantidad * precio),
      comprador: dto.comprador ?? actual.comprador,
      fecha: fecha,
      estadoPago: estadoFinal,
      fechaPago: fechaPago,
      fechaLimitePago: fechaLimite,
    );
    _ventas[indice] = actualizada;
    return actualizada;
  }

  @override
  Future<void> eliminarVenta(int id) async {
    await _espera();
    _ventas.removeWhere((v) => v.id == id);
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
    await _espera();
    final copia = [..._precios];
    copia.sort((a, b) => b.fecha.compareTo(a.fecha));
    return copia;
  }

  @override
  Future<PrecioMercado> crearPrecio(CrearPrecioMercadoDTO dto) async {
    await _espera();
    if (dto.precio <= 0) throw StateError('precio debe ser mayor a 0');
    final nuevo = PrecioMercado(
      id: _correlativoPrecio++,
      producto: dto.producto,
      precio: dto.precio,
      fecha: dto.fecha,
    );
    _precios.add(nuevo);
    return nuevo;
  }

  @override
  Future<PrecioMercado> actualizarPrecio(
      int id, ActualizarPrecioMercadoDTO dto) async {
    await _espera();
    final indice = _precios.indexWhere((p) => p.id == id);
    if (indice == -1) throw StateError('Precio de mercado no encontrado');
    final actual = _precios[indice];
    final actualizado = PrecioMercado(
      id: actual.id,
      producto: dto.producto ?? actual.producto,
      precio: dto.precio ?? actual.precio,
      fecha: dto.fecha ?? actual.fecha,
    );
    _precios[indice] = actualizado;
    return actualizado;
  }

  @override
  Future<void> eliminarPrecio(int id) async {
    await _espera();
    _precios.removeWhere((p) => p.id == id);
  }

  // ── Balance ───────────────────────────────────────────────────────────

  @override
  Future<List<Balance>> listarBalances() async {
    await _espera();
    final copia = [..._balances];
    copia.sort((a, b) => b.periodo.compareTo(a.periodo));
    return copia;
  }

  @override
  Future<Balance> generarBalance(GenerarBalanceDTO dto) async {
    await _espera();
    if (dto.fechaFin.isBefore(dto.fechaInicio)) {
      throw StateError('fecha_fin no puede ser anterior a fecha_inicio');
    }

    bool dentroDelRango(DateTime dia) =>
        !dia.isBefore(dto.fechaInicio) && !dia.isAfter(dto.fechaFin);

    // Solo ventas Pagadas, por fecha de pago (igual que el backend real).
    final totalVentas = _redondear2(_ventas
        .where((v) =>
            v.estaPagada && v.fechaPago != null && dentroDelRango(v.fechaPago!))
        .fold<double>(0, (suma, v) => suma + v.total));
    final totalGastos = _redondear2(_gastos
        .where((g) => dentroDelRango(g.fecha))
        .fold<double>(0, (suma, g) => suma + g.monto));

    final nuevo = Balance(
      id: _correlativoBalance++,
      periodo: dto.periodo,
      totalVentas: totalVentas,
      totalGastos: totalGastos,
      balanceNeto: _redondear2(totalVentas - totalGastos),
      fechaInicio: dto.fechaInicio,
      fechaFin: dto.fechaFin,
    );
    _balances.add(nuevo);
    return nuevo;
  }
}
