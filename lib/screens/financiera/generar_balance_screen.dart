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
import 'widgets_formulario.dart';

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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        title: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E6), shape: BoxShape.circle),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.secondary, size: 28),
            ),
            const SizedBox(height: 12),
            const Text('Ya existe un balance para este periodo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
            'Si continúas, se guardará otro registro más. ¿Generarlo de todas formas?',
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.calculate_outlined, color: AppTheme.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cálculo del periodo',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text(
                        'Elige el rango de fechas. Se sumarán las ventas cobradas y los gastos de esos días.',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FormTarjeta(
            children: [
              const FormTitulo(
                  icono: Icons.event_outlined, texto: 'Fecha de inicio'),
              FormSelector(
                icono: Icons.calendar_today_outlined,
                texto: _formato.format(_inicio),
                iconoDerecho: Icons.edit_calendar_outlined,
                onTap: () => _elegir(esInicio: true),
              ),
              const SizedBox(height: 18),
              const FormTitulo(
                  icono: Icons.event_available_outlined, texto: 'Fecha de fin'),
              FormSelector(
                icono: Icons.calendar_today_outlined,
                texto: _formato.format(_fin),
                iconoDerecho: Icons.edit_calendar_outlined,
                onTap: () => _elegir(esInicio: false),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _estimacion(),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.error)),
          ],
          const SizedBox(height: 24),
          FormBotones(
            textoGuardar: 'Generar balance',
            guardando: _guardando,
            onGuardar: () {
              if (_cargando) return;
              _generar();
            },
            onCancelar: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  static final DateFormat _formato = DateFormat("d 'de' MMMM, yyyy", 'es');

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
    return FormTarjeta(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Estimación preliminar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(e.dias == 1 ? '1 DÍA' : '${e.dias} DÍAS',
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _fila('Ventas cobradas', FormatoCOP.pesos(e.ventas), AppTheme.primary),
        const SizedBox(height: 8),
        _fila('Gastos', FormatoCOP.pesos(e.gastos), AppTheme.tertiary),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: negativo
                ? AppTheme.errorContainer.withValues(alpha: 0.5)
                : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Balance neto',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(
                  negativo
                      ? '-${FormatoCOP.pesos(e.neto.abs())}'
                      : FormatoCOP.pesos(e.neto),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: negativo ? AppTheme.error : AppTheme.primary)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Solo cuentan las ventas ya pagadas (por su fecha de pago) y los gastos del rango. El valor final lo calcula el servidor al generar.',
          style: TextStyle(fontSize: 12, color: AppTheme.outline),
        ),
      ],
    );
  }

  Widget _fila(String etiqueta, String valor, Color punto) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(etiqueta,
              style: const TextStyle(
                  fontSize: 13.5, color: AppTheme.onSurfaceVariant)),
        ),
        Text(valor,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
