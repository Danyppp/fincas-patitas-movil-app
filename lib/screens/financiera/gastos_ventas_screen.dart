import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/financiera/gasto.dart';
import '../../models/financiera/resumen_mes.dart';
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

  ResumenMes get _resumen =>
      ResumenMes.calcular(ventas: _ventas, gastos: _gastos, mes: _mes);

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
        title: const Text('Gastos y ventas'),
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

    final r = _resumen;
    final margen = r.margenPorcentaje;

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _tarjetaResumen(
                  icono: Icons.trending_up,
                  color: AppTheme.primary,
                  titulo: 'Ventas',
                  valor: FormatoCOP.pesos(r.ventasCobradas),
                  detalle: 'Cobradas',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tarjetaResumen(
                  icono: Icons.trending_down,
                  color: AppTheme.tertiaryContainer,
                  titulo: 'Gastos',
                  valor: FormatoCOP.pesos(r.gastos),
                  detalle: r.cantidadGastos == 1
                      ? '1 registro'
                      : '${r.cantidadGastos} registros',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _tarjetaResumen(
                  icono: Icons.account_balance_wallet_outlined,
                  color:
                      r.diferencia >= 0 ? AppTheme.secondary : AppTheme.error,
                  titulo: 'Diferencia',
                  valor: FormatoCOP.pesos(r.diferencia),
                  detalle: margen == null
                      ? 'Sin ventas cobradas'
                      : '${margen.round()}% margen',
                ),
              ),
            ],
          ),
          if (r.ventasPorCobrar > 0) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '${r.ventasPorCobrar} ${r.ventasPorCobrar == 1 ? 'venta por cobrar' : 'ventas por cobrar'} · ${FormatoCOP.pesos(r.montoPorCobrar)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondary),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _selectorMes(),
          const SizedBox(height: 12),
          _pestanas(),
          const SizedBox(height: 16),
          if (_pestana == 0) ..._listaGastos(r) else ..._listaVentas(),
        ],
      ),
    );
  }

  Widget _selectorMes() {
    final etiqueta =
        toBeginningOfSentenceCase(DateFormat('MMMM yyyy', 'es').format(_mes));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mes anterior',
            visualDensity: VisualDensity.compact,
            onPressed: () => _cambiarMes(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          const Icon(Icons.calendar_month_outlined,
              size: 18, color: AppTheme.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(etiqueta,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          if (_esMesActual)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: const Text('Mes en curso',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceVariant)),
            ),
          IconButton(
            tooltip: 'Mes siguiente',
            visualDensity: VisualDensity.compact,
            onPressed: _esMesActual ? null : () => _cambiarMes(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _pestanas() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        children: [
          Expanded(child: _botonPestana(0, Icons.payments_outlined, 'Gastos')),
          const SizedBox(width: 4),
          Expanded(child: _botonPestana(1, Icons.sell_outlined, 'Ventas')),
        ],
      ),
    );
  }

  Widget _botonPestana(int indice, IconData icono, String texto) {
    final activa = _pestana == indice;
    return Material(
      color:
          activa ? AppTheme.primaryContainer : AppTheme.surfaceContainerColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm * 1.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm * 1.5),
        onTap: () => setState(() => _pestana = indice),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(activa ? Icons.check : icono,
                  size: 18,
                  color: activa ? AppTheme.onPrimary : AppTheme.onSurface),
              const SizedBox(width: 8),
              Text(texto,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: activa ? AppTheme.onPrimary : AppTheme.onSurface)),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(titulo.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: AppTheme.onSurfaceVariant)),
              ),
              Icon(icono, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(detalle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5, color: AppTheme.onSurfaceVariant)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _decoracionTarjeta() {
    return BoxDecoration(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      boxShadow: [
        BoxShadow(
          color: AppTheme.onSurface.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _encabezadoLista(String titulo, String contador) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Flexible(
            child: Text(titulo,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(contador,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Gastos ────────────────────────────────────────────────────────────

  List<Widget> _listaGastos(ResumenMes resumen) {
    final lista = _gastosDelMes;
    if (lista.isEmpty) {
      return [_vacio('No hay gastos registrados en este mes')];
    }
    final proporcion = resumen.gastosSobreIngresos;
    return [
      _encabezadoLista('Historial de gastos',
          lista.length == 1 ? '1 registro' : '${lista.length} registros'),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        child: Column(
          children: [
            for (var i = 0; i < lista.length; i++)
              _filaGasto(lista[i], resaltada: i.isEven),
          ],
        ),
      ),
      if (proporcion != null) ...[
        const SizedBox(height: 16),
        _nota(
            'Los gastos representan un ${proporcion.round()}% de los ingresos cobrados de este mes.'),
      ],
    ];
  }

  Widget _nota(String texto) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3CD),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb_outline,
                size: 19, color: AppTheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto,
                style:
                    const TextStyle(fontSize: 12.5, color: AppTheme.onSurface)),
          ),
        ],
      ),
    );
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

  Widget _filaGasto(Gasto g, {required bool resaltada}) {
    final fecha = DateFormat('d MMM', 'es').format(g.fecha);
    return Container(
      color: resaltada
          ? AppTheme.surfaceContainerLow
          : AppTheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          _iconoCircular(
              _iconoCategoria(g.categoria),
              AppTheme.tertiaryContainer,
              AppTheme.tertiaryContainer.withValues(alpha: 0.15)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(g.categoria,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Text(fecha,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.onSurfaceVariant)),
                  ],
                ),
                if (g.descripcion != null && g.descripcion!.trim().isNotEmpty)
                  Text(g.descripcion!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                if (g.metodoPago != null)
                  Text(g.metodoPago!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.outline)),
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
      _encabezadoLista('Registros recientes',
          lista.length == 1 ? '1 venta' : '${lista.length} ventas'),
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
        for (var i = 0; i < lista.length; i++) ...[
          _filaVenta(lista[i]),
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

  bool _esLeche(String producto) => producto.toLowerCase().contains('leche');

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

    final colorProducto =
        _esLeche(v.producto) ? AppTheme.primary : AppTheme.secondary;
    final fondoProducto = _esLeche(v.producto)
        ? const Color(0xFFE3F1E4)
        : const Color(0xFFFFE9B0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
      decoration: _decoracionTarjeta(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconoCircular(
                  _iconoProducto(v.producto), colorProducto, fondoProducto),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(v.producto,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.tertiaryContainer
                                  .withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(detalleCantidad,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.onSurfaceVariant)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [if (comprador != null) comprador, fecha].join(' · '),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(FormatoCOP.pesos(v.total),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
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
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: _estadoVenta(v, vencida),
              ),
              const Spacer(),
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

  /// Estado de la venta como "● Pagado" (punto de color + texto).
  Widget _estadoVenta(Venta v, bool vencida) {
    final String texto;
    final Color color;
    if (v.estaPagada) {
      texto = 'Pagado';
      color = AppTheme.primary;
    } else if (vencida) {
      texto = 'Vencida';
      color = AppTheme.error;
    } else {
      texto = 'Pendiente';
      color = AppTheme.secondary;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(texto,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  // ── Piezas comunes ────────────────────────────────────────────────────

  Widget _iconoCircular(IconData icono, Color color, Color fondo) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
      child: Icon(icono, color: color, size: 22),
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
