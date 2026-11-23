import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/financiera/gasto.dart';
import '../../models/financiera/venta.dart';
import '../../repositories/financiera/financiera_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_dia.dart';
import '../../utils/formato_cop.dart';
import 'gasto_form_screen.dart';
import 'venta_form_screen.dart';

enum _FiltroVentas { todas, pagadas, pendientes }

/// Pantalla "Gastos y Ventas" del módulo Financiera.
///
/// - Tarjetas del mes: Ventas (solo dinero ya cobrado, por fecha de pago),
///   Gastos (por fecha del gasto) y Balance (ventas cobradas - gastos).
///   Es la misma regla que usa el balance del backend.
/// - Pestañas Gastos / Ventas con la lista del mes seleccionado. La lista
///   de ventas muestra TODAS las ventas del mes por fecha de venta (pagadas
///   y pendientes), con filtro Todas / Pagadas / Pendientes. El filtro
///   "Pendientes" muestra las pendientes de cualquier mes, porque son plata
///   por cobrar que no debe esconderse al cambiar de mes.
/// - Acciones: registrar, editar, eliminar (con confirmación) y "Marcar
///   como pagada".
///
/// Los formularios de gasto y de venta se abren desde acá (registrar y
/// editar) y devuelven `true` cuando guardan, para recargar las listas.
class GastosVentasScreen extends StatefulWidget {
  final FinancieraRepository repository;

  const GastosVentasScreen({super.key, required this.repository});

  @override
  State<GastosVentasScreen> createState() => _GastosVentasScreenState();
}

class _GastosVentasScreenState extends State<GastosVentasScreen> {
  bool _cargando = true;
  String? _error;
  List<Gasto> _gastos = [];
  List<Venta> _ventas = [];

  late DateTime _mes; // siempre el día 1 del mes seleccionado
  int _pestana = 0; // 0 = Gastos, 1 = Ventas
  _FiltroVentas _filtro = _FiltroVentas.todas;

  @override
  void initState() {
    super.initState();
    final hoy = FechaDia.hoy();
    _mes = DateTime(hoy.year, hoy.month);
    _cargar();
  }

  // ── Carga de datos ────────────────────────────────────────────────────

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final gastos = await widget.repository.listarGastos();
      final ventas = await widget.repository.listarVentas();
      if (!mounted) return;
      setState(() {
        _gastos = gastos;
        _ventas = ventas;
        _cargando = false;
        _error = null;
      });
    } on ApiException catch (e) {
      _falloCarga(e.message);
    } on NetworkException catch (e) {
      _falloCarga(e.message);
    }
  }

  void _falloCarga(String mensaje) {
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = mensaje;
    });
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // ── Cálculos del mes ──────────────────────────────────────────────────

  bool _enMes(DateTime fecha) =>
      fecha.year == _mes.year && fecha.month == _mes.month;

  bool get _esMesActual {
    final hoy = FechaDia.hoy();
    return _mes.year == hoy.year && _mes.month == hoy.month;
  }

  List<Gasto> get _gastosDelMes =>
      _gastos.where((g) => _enMes(g.fecha)).toList();

  /// Ventas pagadas cuya fecha de pago cae en el mes (si una venta pagada
  /// no trae fecha de pago, se usa la fecha de la venta).
  double get _totalVentasCobradas {
    var suma = 0.0;
    for (final v in _ventas) {
      if (!v.estaPagada) continue;
      if (_enMes(v.fechaPago ?? v.fecha)) suma += v.total;
    }
    return suma;
  }

  double get _totalGastos =>
      _gastosDelMes.fold(0.0, (suma, g) => suma + g.monto);

  List<Venta> get _ventasPendientes =>
      _ventas.where((v) => v.estaPendiente).toList();

  List<Venta> get _ventasVisibles {
    switch (_filtro) {
      case _FiltroVentas.todas:
        return _ventas.where((v) => _enMes(v.fecha)).toList();
      case _FiltroVentas.pagadas:
        return _ventas.where((v) => v.estaPagada && _enMes(v.fecha)).toList();
      case _FiltroVentas.pendientes:
        return _ventasPendientes;
    }
  }

  void _cambiarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta));
  }

  // ── Acciones ──────────────────────────────────────────────────────────

  Future<bool> _confirmar({
    required String titulo,
    required String contenido,
    required String accion,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(contenido),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(accion),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _ejecutar(
      Future<void> Function() accion, String mensajeExito) async {
    try {
      await accion();
      _mensaje(mensajeExito);
      await _cargar(silencioso: true);
    } on ApiException catch (e) {
      _mensaje(e.message);
    } on NetworkException catch (e) {
      _mensaje(e.message);
    }
  }

  Future<void> _eliminarGasto(Gasto g) async {
    final ok = await _confirmar(
      titulo: 'Eliminar gasto',
      contenido:
          '¿Eliminar el gasto de ${FormatoCOP.pesos(g.monto)} (${g.categoria})?',
      accion: 'Eliminar',
    );
    if (!ok) return;
    await _ejecutar(
        () => widget.repository.eliminarGasto(g.id), 'Gasto eliminado');
  }

  Future<void> _eliminarVenta(Venta v) async {
    final ok = await _confirmar(
      titulo: 'Eliminar venta',
      contenido:
          '¿Eliminar la venta de ${FormatoCOP.pesos(v.total)} (${v.producto})?',
      accion: 'Eliminar',
    );
    if (!ok) return;
    await _ejecutar(
        () => widget.repository.eliminarVenta(v.id), 'Venta eliminada');
  }

  Future<void> _marcarComoPagada(Venta v) async {
    final ok = await _confirmar(
      titulo: 'Marcar como pagada',
      contenido:
          '¿Registrar como pagada la venta de ${FormatoCOP.pesos(v.total)} (${v.producto}) con fecha de hoy?',
      accion: 'Marcar como pagada',
    );
    if (!ok) return;
    await _ejecutar(() async {
      await widget.repository.marcarVentaComoPagada(v.id);
    }, 'Venta marcada como pagada');
  }

  Future<void> _abrirFormularioGasto([Gasto? gasto]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GastoFormScreen(
          repository: widget.repository,
          mes: _mes,
          gasto: gasto,
        ),
      ),
    );
    if (guardado == true) {
      _mensaje(gasto == null ? 'Gasto registrado' : 'Gasto actualizado');
      await _cargar(silencioso: true);
    }
  }

  Future<void> _abrirFormularioVenta([Venta? venta]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VentaFormScreen(
          repository: widget.repository,
          mes: _mes,
          venta: venta,
        ),
      ),
    );
    if (guardado == true) {
      _mensaje(venta == null ? 'Venta registrada' : 'Venta actualizada');
      await _cargar(silencioso: true);
    }
  }

  // ── Construcción de la pantalla ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financiera'),
      ),
      body: _cuerpo(),
      floatingActionButton: (_cargando || _error != null)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _pestana == 0
                  ? _abrirFormularioGasto()
                  : _abrirFormularioVenta(),
              icon: const Icon(Icons.add),
              label:
                  Text(_pestana == 0 ? 'Registrar gasto' : 'Registrar venta'),
            ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _cargar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final ventasCobradas = _totalVentasCobradas;
    final gastos = _totalGastos;
    final pendientes = _ventasPendientes;
    final porCobrar = pendientes.fold(0.0, (suma, v) => suma + v.total);

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _selectorMes(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _tarjetaResumen(
                  icono: Icons.trending_up,
                  color: AppTheme.primary,
                  titulo: 'Ventas',
                  valor: FormatoCOP.pesos(ventasCobradas),
                  detalle: pendientes.isEmpty
                      ? 'Cobradas'
                      : '${pendientes.length} por cobrar · ${FormatoCOP.pesos(porCobrar)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tarjetaResumen(
                  icono: Icons.trending_down,
                  color: AppTheme.tertiary,
                  titulo: 'Gastos',
                  valor: FormatoCOP.pesos(gastos),
                  detalle: _gastosDelMes.length == 1
                      ? '1 registro'
                      : '${_gastosDelMes.length} registros',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _tarjetaResumen(
            icono: Icons.savings_outlined,
            color: ventasCobradas - gastos >= 0
                ? AppTheme.primary
                : AppTheme.error,
            titulo: 'Balance',
            valor: FormatoCOP.pesos(ventasCobradas - gastos),
            detalle: 'Ventas cobradas - gastos del mes',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Gastos')),
                ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.sell_outlined),
                    label: Text('Ventas')),
              ],
              selected: {_pestana},
              onSelectionChanged: (s) => setState(() => _pestana = s.first),
            ),
          ),
          const SizedBox(height: 16),
          if (_pestana == 0) ..._listaGastos() else ..._listaVentas(),
        ],
      ),
    );
  }

  Widget _selectorMes() {
    final etiqueta =
        toBeginningOfSentenceCase(DateFormat('MMMM yyyy', 'es').format(_mes));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Mes anterior',
          onPressed: () => _cambiarMes(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Column(
          children: [
            Text(etiqueta,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (_esMesActual)
              const Text('Mes en curso',
                  style: TextStyle(fontSize: 12, color: AppTheme.outline)),
          ],
        ),
        IconButton(
          tooltip: 'Mes siguiente',
          onPressed: _esMesActual ? null : () => _cambiarMes(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _tarjetaResumen({
    required IconData icono,
    required Color color,
    required String titulo,
    required String valor,
    required String detalle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 20),
              const SizedBox(width: 6),
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(height: 4),
          Text(detalle,
              style: const TextStyle(fontSize: 11.5, color: AppTheme.outline)),
        ],
      ),
    );
  }

  BoxDecoration _decoracionTarjeta() {
    return BoxDecoration(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      boxShadow: [
        BoxShadow(
          color: AppTheme.onSurface.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ── Gastos ────────────────────────────────────────────────────────────

  List<Widget> _listaGastos() {
    final lista = _gastosDelMes;
    if (lista.isEmpty) {
      return [_vacio('No hay gastos registrados en este mes')];
    }
    return [
      for (final g in lista) ...[
        _filaGasto(g),
        const SizedBox(height: 10),
      ],
    ];
  }

  IconData _iconoCategoria(String categoria) {
    switch (categoria.toLowerCase()) {
      case 'alimentación':
      case 'alimentacion':
        return Icons.restaurant_outlined;
      case 'medicamentos':
        return Icons.medication_outlined;
      case 'mantenimiento':
        return Icons.build_outlined;
      case 'mano de obra':
        return Icons.engineering_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Widget _filaGasto(Gasto g) {
    final fecha = DateFormat('d MMM', 'es').format(g.fecha);
    final partes = [fecha, if (g.metodoPago != null) g.metodoPago!];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: _decoracionTarjeta(),
      child: Row(
        children: [
          _iconoCircular(_iconoCategoria(g.categoria), AppTheme.tertiary,
              const Color(0xFFFFEDEA)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.categoria,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                if (g.descripcion != null && g.descripcion!.trim().isNotEmpty)
                  Text(g.descripcion!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                Text(partes.join(' · '),
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.outline)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(FormatoCOP.pesos(g.monto),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _botonIcono(Icons.edit_outlined, 'Editar',
                      () => _abrirFormularioGasto(g)),
                  _botonIcono(Icons.delete_outline, 'Eliminar',
                      () => _eliminarGasto(g)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Ventas ────────────────────────────────────────────────────────────

  List<Widget> _listaVentas() {
    final lista = _ventasVisibles;
    return [
      Wrap(
        spacing: 8,
        children: [
          for (final f in _FiltroVentas.values)
            ChoiceChip(
              label: Text(_nombreFiltro(f)),
              selected: _filtro == f,
              onSelected: (_) => setState(() => _filtro = f),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (lista.isEmpty)
        _vacio(_filtro == _FiltroVentas.pendientes
            ? 'No hay ventas pendientes de pago'
            : 'No hay ventas registradas en este mes')
      else
        for (final v in lista) ...[
          _filaVenta(v),
          const SizedBox(height: 10),
        ],
    ];
  }

  String _nombreFiltro(_FiltroVentas f) {
    switch (f) {
      case _FiltroVentas.todas:
        return 'Todas';
      case _FiltroVentas.pagadas:
        return 'Pagadas';
      case _FiltroVentas.pendientes:
        return 'Pendientes';
    }
  }

  IconData _iconoProducto(String producto) {
    final p = producto.toLowerCase();
    if (p.contains('leche')) return Icons.water_drop_outlined;
    if (p.contains('huevo')) return Icons.egg_outlined;
    return Icons.storefront_outlined;
  }

  Widget _filaVenta(Venta v) {
    final vencida = v.estaVencida();
    final unidad = FormatoCOP.unidadDeProducto(v.producto);
    final detalleCantidad =
        '${FormatoCOP.cantidad(v.cantidad)}${unidad.isEmpty ? '' : ' $unidad'} × ${FormatoCOP.pesos(v.precioUnitario)}';
    final fecha = DateFormat('d MMM', 'es').format(v.fecha);
    final comprador = (v.comprador != null && v.comprador!.trim().isNotEmpty)
        ? v.comprador!.trim()
        : null;

    String? aviso;
    if (v.estaPendiente && v.fechaLimitePago != null) {
      aviso = vencida
          ? 'Venció el ${DateFormat('d MMM', 'es').format(v.fechaLimitePago!)}'
          : 'Vence el ${DateFormat('d MMM', 'es').format(v.fechaLimitePago!)}';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconoCircular(_iconoProducto(v.producto), AppTheme.primary,
                  const Color(0xFFF0F7ED)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.producto,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700)),
                    Text(detalleCantidad,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                    Text(
                      [if (comprador != null) comprador, fecha].join(' · '),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.outline),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(FormatoCOP.pesos(v.total),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _pastillaEstado(v, vencida),
                  ),
                ],
              ),
            ],
          ),
          if (aviso != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 52),
              child: Text(aviso,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: vencida ? AppTheme.error : AppTheme.secondary)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (v.estaPendiente)
                TextButton.icon(
                  onPressed: () => _marcarComoPagada(v),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Marcar como pagada'),
                ),
              _botonIcono(Icons.edit_outlined, 'Editar',
                  () => _abrirFormularioVenta(v)),
              _botonIcono(
                  Icons.delete_outline, 'Eliminar', () => _eliminarVenta(v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pastillaEstado(Venta v, bool vencida) {
    final String texto;
    final Color fondo;
    final Color letra;
    if (v.estaPagada) {
      texto = 'Pagado';
      fondo = const Color(0xFFE8F5E9);
      letra = AppTheme.primary;
    } else if (vencida) {
      texto = 'Vencida';
      fondo = AppTheme.errorContainer;
      letra = AppTheme.onErrorContainer;
    } else {
      texto = 'Pendiente';
      fondo = const Color(0xFFFFF3CD);
      letra = AppTheme.secondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: letra)),
    );
  }

  // ── Piezas comunes ────────────────────────────────────────────────────

  Widget _iconoCircular(IconData icono, Color color, Color fondo) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
      child: Icon(icono, color: color, size: 21),
    );
  }

  Widget _botonIcono(IconData icono, String tooltip, VoidCallback onTap) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icono, size: 20, color: AppTheme.outline),
    );
  }

  Widget _vacio(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.outline)),
      ),
    );
  }
}
