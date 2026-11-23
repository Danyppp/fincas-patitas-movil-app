import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/financiera/balance.dart';
import '../../models/financiera/estimacion_balance.dart';
import '../../models/financiera/gasto.dart';
import '../../models/financiera/venta.dart';
import '../../repositories/financiera/financiera_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_dia.dart';
import '../../utils/formato_cop.dart';

/// Pantalla para generar un balance de un rango de fechas.
///
/// - Fecha inicial y final: cualquier día pasado o de hoy (no futuras).
///   Por defecto, del día 1 del mes actual hasta hoy.
/// - Muestra una estimación previa con la misma regla del backend (ventas
///   Pagadas por su fecha de pago + gastos por su fecha). El balance real lo
///   calcula y guarda el servidor.
/// - La fecha final no puede ser anterior a la inicial.
/// - Si ya existe un balance con ese mismo periodo, pregunta antes de
///   guardar otro registro.
///
/// Devuelve `true` al generar, para que la lista se recargue.
class GenerarBalanceScreen extends StatefulWidget {
  final FinancieraRepository repository;
  final List<Balance> balancesExistentes;

  const GenerarBalanceScreen({
    super.key,
    required this.repository,
    required this.balancesExistentes,
  });

  @override
  State<GenerarBalanceScreen> createState() => _GenerarBalanceScreenState();
}

class _GenerarBalanceScreenState extends State<GenerarBalanceScreen> {
  late DateTime _inicio;
  late DateTime _fin;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  String? _errorCarga;
  List<Venta> _ventas = [];
  List<Gasto> _gastos = [];

  @override
  void initState() {
    super.initState();
    final hoy = FechaDia.hoy();
    _inicio = DateTime(hoy.year, hoy.month, 1);
    _fin = hoy;
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final ventas = await widget.repository.listarVentas();
      final gastos = await widget.repository.listarGastos();
      if (!mounted) return;
      setState(() {
        _ventas = ventas;
        _gastos = gastos;
        _cargando = false;
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
      _errorCarga = mensaje;
    });
  }

  bool get _rangoValido => !_fin.isBefore(_inicio);

  Future<void> _elegir({required bool esInicio}) async {
    final hoy = FechaDia.hoy();
    final actual = esInicio ? _inicio : _fin;
    final resultado = await showDatePicker(
      context: context,
      initialDate: actual.isAfter(hoy) ? hoy : actual,
      firstDate: DateTime(2020),
      lastDate: hoy,
    );
    if (resultado == null) return;
    setState(() {
      if (esInicio) {
        _inicio = FechaDia.soloDia(resultado);
      } else {
        _fin = FechaDia.soloDia(resultado);
      }
      _error = null;
    });
  }

  Future<bool> _confirmarDuplicado() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Balance duplicado'),
        content: const Text(
            'Ya existe un balance con ese periodo. Si continúas, se guardará otro registro más. ¿Generarlo de todas formas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _generar() async {
    if (!_rangoValido) {
      setState(
          () => _error = 'La fecha final no puede ser anterior a la inicial');
      return;
    }
    final duplicado = widget.balancesExistentes
        .any((b) => FechaDia.soloDia(b.periodo) == FechaDia.soloDia(_inicio));
    if (duplicado && !await _confirmarDuplicado()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repository.generarBalance(GenerarBalanceDTO(
        periodo: _inicio,
        fechaInicio: _inicio,
        fechaFin: _fin,
      ));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generar balance')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _titulo('Fecha inicial'),
          _campoFecha(_inicio, () => _elegir(esInicio: true)),
          const SizedBox(height: 20),
          _titulo('Fecha final'),
          _campoFecha(_fin, () => _elegir(esInicio: false)),
          const SizedBox(height: 20),
          _estimacion(),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: (_guardando || _cargando) ? null : _generar,
            icon: _guardando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Generar balance'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed:
                  _guardando ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoFecha(DateTime fecha, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.calendar_today_outlined),
          suffixIcon: Icon(Icons.edit_calendar_outlined),
        ),
        child: Text(DateFormat("d 'de' MMMM, yyyy", 'es').format(fecha)),
      ),
    );
  }

  Widget _estimacion() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorCarga != null) {
      return Column(
        children: [
          Text(_errorCarga!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.error)),
          const SizedBox(height: 8),
          OutlinedButton(
              onPressed: _cargarDatos, child: const Text('Reintentar')),
        ],
      );
    }
    if (!_rangoValido) {
      return const Text(
        'La fecha final no puede ser anterior a la inicial',
        style: TextStyle(color: AppTheme.error, fontSize: 13),
      );
    }
    final e = EstimacionBalance.calcular(
      ventas: _ventas,
      gastos: _gastos,
      inicio: _inicio,
      fin: _fin,
    );
    final negativo = e.neto < 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estimación previa',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _fila('Días del periodo', '${e.dias}'),
          const SizedBox(height: 4),
          _fila('Ventas cobradas', FormatoCOP.pesos(e.ventas)),
          const SizedBox(height: 4),
          _fila('Gastos', FormatoCOP.pesos(e.gastos)),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Neto',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(
                  negativo
                      ? '-${FormatoCOP.pesos(e.neto.abs())}'
                      : FormatoCOP.pesos(e.neto),
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: negativo ? AppTheme.error : AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Solo cuentan las ventas ya pagadas (por su fecha de pago) y los gastos del rango. El valor final lo calcula el servidor al generar.',
            style: TextStyle(fontSize: 12, color: AppTheme.outline),
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

  Widget _titulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(texto,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurfaceVariant)),
    );
  }
}
