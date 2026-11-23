import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/financiera/balance.dart';
import '../../models/financiera/filtro_balances.dart';
import '../../models/financiera/valor_estimado.dart';
import '../../repositories/financiera/financiera_repository.dart';
import '../../repositories/produccion/produccion_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_dia.dart';
import '../../utils/formato_cop.dart';
import 'generar_balance_screen.dart';

/// Pantalla "Balance" del módulo Financiera.
///
/// Tiene dos partes, igual que la web:
/// - Valor estimado de la producción de hoy (leche en litros y huevos
///   buenos, por el último precio de mercado). Es solo una estimación: no
///   es una venta. Si falla la carga de producción o de precios, solo esta
///   parte avisa; los balances se siguen mostrando.
/// - Balances generados: fotos fijas del momento (no se recalculan), con
///   ventas cobradas, gastos y neto. "Generar balance" abre la pantalla
///   para crear uno nuevo.
class BalanceScreen extends StatefulWidget {
  final FinancieraRepository repository;
  final ProduccionRepository produccionRepository;

  const BalanceScreen({
    super.key,
    required this.repository,
    required this.produccionRepository,
  });

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  bool _cargando = true;
  String? _error;
  List<Balance> _balances = [];
  ValorEstimadoHoy? _estimado;
  String? _errorEstimado;

  // Búsqueda por fechas y página actual (empieza en 0) de Balances generados.
  DateTime? _desde;
  DateTime? _hasta;
  int _pagina = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    // La estimación se carga aparte: si falla, no tumba los balances.
    final estimacion = _cargarEstimado();
    try {
      final lista = await widget.repository.listarBalances();
      lista.sort((a, b) {
        final porPeriodo = b.periodo.compareTo(a.periodo);
        return porPeriodo != 0 ? porPeriodo : b.id.compareTo(a.id);
      });
      await estimacion;
      if (!mounted) return;
      setState(() {
        _balances = lista;
        _cargando = false;
        _error = null;
      });
    } on ApiException catch (e) {
      await estimacion;
      _falloCarga(e.message);
    } on NetworkException catch (e) {
      await estimacion;
      _falloCarga(e.message);
    }
  }

  Future<void> _cargarEstimado() async {
    try {
      final precios = await widget.repository.listarPrecios();
      final leche = await widget.produccionRepository.listarLeche();
      final huevos = await widget.produccionRepository.listarHuevos();
      final valor = ValorEstimadoHoy.calcular(
        leche: leche,
        huevos: huevos,
        precios: precios,
      );
      if (!mounted) return;
      setState(() {
        _estimado = valor;
        _errorEstimado = null;
      });
    } on ApiException catch (e) {
      _falloEstimado(e.message);
    } on NetworkException catch (e) {
      _falloEstimado(e.message);
    }
  }

  void _falloEstimado(String mensaje) {
    if (!mounted) return;
    setState(() {
      _estimado = null;
      _errorEstimado = mensaje;
    });
  }

  void _falloCarga(String mensaje) {
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = mensaje;
    });
  }

  Future<void> _generar() async {
    final generado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GenerarBalanceScreen(
          repository: widget.repository,
          balancesExistentes: _balances,
        ),
      ),
    );
    if (generado == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Balance generado')));
      await _cargar(silencioso: true);
    }
  }

  // ── Pantalla ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balance')),
      body: _cuerpo(),
      floatingActionButton: (_cargando || _error != null)
          ? null
          : FloatingActionButton.extended(
              onPressed: _generar,
              icon: const Icon(Icons.add_chart),
              label: const Text('Generar balance'),
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

    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _tarjetaEstimado(),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Balances generados',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          _buscador(),
          const SizedBox(height: 12),
          ..._listaBalances(),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'Cada balance es una foto del momento en que se generó: no se recalcula si después cambian las ventas o los gastos.',
              style: TextStyle(fontSize: 12, color: AppTheme.outline),
            ),
          ),
        ],
      ),
    );
  }

  // ── Búsqueda y páginas ────────────────────────────────────────────────

  bool get _rangoInvertido =>
      _desde != null && _hasta != null && _hasta!.isBefore(_desde!);

  bool get _hayFiltro => _desde != null || _hasta != null;

  Future<void> _elegirFecha({required bool esDesde}) async {
    final hoy = FechaDia.hoy();
    final actual = esDesde ? _desde : _hasta;
    final resultado = await showDatePicker(
      context: context,
      initialDate: (actual == null || actual.isAfter(hoy)) ? hoy : actual,
      firstDate: DateTime(2020),
      lastDate: hoy,
    );
    if (resultado == null) return;
    setState(() {
      if (esDesde) {
        _desde = FechaDia.soloDia(resultado);
      } else {
        _hasta = FechaDia.soloDia(resultado);
      }
      _pagina = 0;
    });
  }

  void _limpiarFiltro() {
    setState(() {
      _desde = null;
      _hasta = null;
      _pagina = 0;
    });
  }

  Widget _buscador() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _campoFecha(
                  'Desde', _desde, () => _elegirFecha(esDesde: true)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _campoFecha(
                  'Hasta', _hasta, () => _elegirFecha(esDesde: false)),
            ),
            if (_hayFiltro)
              IconButton(
                tooltip: 'Quitar filtro',
                onPressed: _limpiarFiltro,
                icon: const Icon(Icons.close, color: AppTheme.outline),
              ),
          ],
        ),
        if (_rangoInvertido)
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 6),
            child: Text(
              'La fecha final no puede ser anterior a la inicial',
              style: TextStyle(fontSize: 12, color: AppTheme.error),
            ),
          ),
      ],
    );
  }

  Widget _campoFecha(String etiqueta, DateTime? fecha, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          isDense: true,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          fecha == null
              ? 'Cualquiera'
              : DateFormat('d MMM yyyy', 'es').format(fecha),
          style: TextStyle(
              fontSize: 13,
              color: fecha == null ? AppTheme.outline : AppTheme.onSurface),
        ),
      ),
    );
  }

  List<Widget> _listaBalances() {
    if (_balances.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('Aún no hay balances generados',
                style: TextStyle(color: AppTheme.outline)),
          ),
        ),
      ];
    }

    final filtrados = _rangoInvertido
        ? <Balance>[]
        : FiltroBalances.filtrar(_balances, desde: _desde, hasta: _hasta);
    final paginas = FiltroBalances.totalPaginas(filtrados.length);
    final actual = _pagina.clamp(0, paginas - 1);
    final visibles = FiltroBalances.pagina(filtrados, actual);

    if (filtrados.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('No hay balances en ese rango de fechas',
                style: TextStyle(color: AppTheme.outline)),
          ),
        ),
      ];
    }

    return [
      for (final b in visibles) ...[
        _tarjetaBalance(b),
        const SizedBox(height: 10),
      ],
      if (paginas > 1)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: actual > 0
                  ? () => setState(() => _pagina = actual - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Anterior'),
            ),
            Text('Página ${actual + 1} de $paginas',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: actual < paginas - 1
                  ? () => setState(() => _pagina = actual + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Siguiente'),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
    ];
  }

  BoxDecoration get _decoracionTarjeta => BoxDecoration(
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

  // ── Valor estimado de hoy ─────────────────────────────────────────────

  Widget _tarjetaEstimado() {
    final e = _estimado;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _decoracionTarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Valor estimado de la producción de hoy',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (e == null)
            Text(
              _errorEstimado ?? 'No se pudo calcular el valor estimado.',
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            )
          else ...[
            _filaProducto(
              icono: Icons.water_drop_outlined,
              nombre: 'Leche',
              cantidad: '${FormatoCOP.cantidad(e.litrosHoy)} L',
              valor: e.valorLeche,
            ),
            const SizedBox(height: 10),
            _filaProducto(
              icono: Icons.egg_outlined,
              nombre: 'Huevos',
              cantidad: '${FormatoCOP.cantidad(e.huevosHoy.toDouble())} unid.',
              valor: e.valorHuevos,
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total estimado',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(FormatoCOP.pesos(e.total),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Es una estimación con el último precio de mercado; no es una venta.',
              style: TextStyle(fontSize: 12, color: AppTheme.outline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filaProducto({
    required IconData icono,
    required String nombre,
    required String cantidad,
    required double? valor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F7ED),
            shape: BoxShape.circle,
          ),
          child: Icon(icono, color: AppTheme.primary, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              if (valor == null)
                Text(
                  '$cantidad, pero no hay un precio de mercado registrado para $nombre.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.outline),
                )
              else
                Text(cantidad,
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.outline)),
            ],
          ),
        ),
        if (valor != null)
          Text(FormatoCOP.pesos(valor),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }

  // ── Balances generados ────────────────────────────────────────────────

  String _rango(Balance b) {
    final inicio = b.fechaInicio;
    final fin = b.fechaFin;
    final f = DateFormat('d MMM yyyy', 'es');
    if (inicio == null || fin == null) {
      return 'Periodo ${f.format(b.periodo)}';
    }
    return '${f.format(inicio)} – ${f.format(fin)}';
  }

  String _conSigno(double valor) {
    if (valor > 0) return '+${FormatoCOP.pesos(valor)}';
    if (valor < 0) return '-${FormatoCOP.pesos(valor.abs())}';
    return FormatoCOP.pesos(0);
  }

  Widget _tarjetaBalance(Balance b) {
    final estado = b.estado();
    final negativo = b.balanceNeto < 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _decoracionTarjeta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_rango(b),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              if (estado != EstadoBalance.sinRango)
                _pastilla(estado == EstadoBalance.enCurso),
            ],
          ),
          const SizedBox(height: 10),
          _fila('Ventas', FormatoCOP.pesos(b.totalVentas)),
          const SizedBox(height: 4),
          _fila('Gastos', FormatoCOP.pesos(b.totalGastos)),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Neto',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(_conSigno(b.balanceNeto),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: negativo ? AppTheme.error : AppTheme.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(etiqueta,
            style: const TextStyle(fontSize: 13, color: AppTheme.outline)),
        Text(valor,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _pastilla(bool enCurso) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: enCurso ? const Color(0xFFFFF4D6) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(enCurso ? 'En curso' : 'Cerrado',
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: enCurso ? AppTheme.secondary : AppTheme.primary)),
    );
  }
}
