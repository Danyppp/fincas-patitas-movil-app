import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/financiera/gasto.dart';
import '../../repositories/financiera/financiera_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_dia.dart';

/// Formulario para registrar o editar un gasto (módulo Financiera).
///
/// TODOS los campos son obligatorios (decisión de Dany, 2026-11-23):
/// - Categoría: texto libre de máximo 30 caracteres (límite de la columna
///   `gastos.categoria`), con atajos para las cuatro categorías de la web:
///   Alimentación, Medicamentos, Mantenimiento y Mano de obra. No se
///   acepta "Otro" (ni "Otros").
/// - Monto: pesos enteros, mayor a 0.
/// - Fecha: solo se pueden elegir días del mes que se está viendo en la
///   pantalla de Gastos y Ventas; por defecto hoy (o el día 1 si el mes
///   visto no es el actual).
/// - Descripción: obligatoria.
/// - Medio de pago: Efectivo o Transferencia.
///
/// La obligatoriedad se exige solo en la app: el backend sigue aceptando
/// gastos sin descripción ni medio de pago (los datos anteriores).
///
/// Al editar solo se envían los campos que cambiaron. Devuelve `true` al
/// guardar, para que la lista se recargue.
class GastoFormScreen extends StatefulWidget {
  final FinancieraRepository repository;
  final Gasto? gasto; // null = registrar uno nuevo

  /// Mes que se está viendo en la pantalla de Gastos y Ventas (cualquier
  /// día de ese mes). Al editar se usa el mes del propio gasto.
  final DateTime mes;

  const GastoFormScreen({
    super.key,
    required this.repository,
    required this.mes,
    this.gasto,
  });

  @override
  State<GastoFormScreen> createState() => _GastoFormScreenState();
}

class _GastoFormScreenState extends State<GastoFormScreen> {
  static const _categoriasSugeridas = [
    'Alimentación',
    'Medicamentos',
    'Mantenimiento',
    'Mano de obra',
  ];
  static const _maxCategoria = 30;
  static const _categoriasNoPermitidas = ['otro', 'otros', 'otra', 'otras'];
  static const _montoMaximo = 99999999; // columna Decimal(10, 2)

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _categoriaCtrl;
  late final TextEditingController _montoCtrl;
  late final TextEditingController _descripcionCtrl;
  late DateTime _fecha;
  String? _metodoPago;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.gasto != null;

  DateTime get _mesBase => widget.gasto?.fecha ?? widget.mes;
  DateTime get _primerDia => DateTime(_mesBase.year, _mesBase.month, 1);
  DateTime get _ultimoDia => DateTime(_mesBase.year, _mesBase.month + 1, 0);

  @override
  void initState() {
    super.initState();
    final g = widget.gasto;
    _categoriaCtrl = TextEditingController(text: g?.categoria ?? '');
    _montoCtrl = TextEditingController(
        text: g == null ? '' : g.monto.round().toString());
    _descripcionCtrl = TextEditingController(text: g?.descripcion ?? '');
    final hoy = FechaDia.hoy();
    final hoyEnMes = hoy.year == _mesBase.year && hoy.month == _mesBase.month;
    _fecha = g?.fecha ?? (hoyEnMes ? hoy : _primerDia);
    _metodoPago = g?.metodoPago;
  }

  @override
  void dispose() {
    _categoriaCtrl.dispose();
    _montoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final resultado = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: _primerDia,
      lastDate: _ultimoDia,
    );
    if (resultado != null) {
      setState(() => _fecha = FechaDia.soloDia(resultado));
    }
  }

  Future<void> _guardar() async {
    final formularioValido = _formKey.currentState!.validate();
    if (_metodoPago == null) {
      setState(() => _error = 'Selecciona el medio de pago');
      return;
    }
    if (!formularioValido) {
      setState(() => _error = null);
      return;
    }

    final categoria = _categoriaCtrl.text.trim();
    final monto = double.parse(_montoCtrl.text.trim());
    final descripcion = _descripcionCtrl.text.trim();

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final original = widget.gasto;
      if (original == null) {
        await widget.repository.crearGasto(CrearGastoDTO(
          categoria: categoria,
          monto: monto,
          fecha: _fecha,
          descripcion: descripcion.isEmpty ? null : descripcion,
          metodoPago: _metodoPago,
        ));
      } else {
        // Solo se envía lo que cambió, para no alterar datos que la
        // persona no tocó (por ejemplo, un monto con centavos).
        final cambioMonto =
            _montoCtrl.text.trim() != original.monto.round().toString();
        final dto = ActualizarGastoDTO(
          categoria: categoria != original.categoria ? categoria : null,
          monto: cambioMonto ? monto : null,
          fecha: FechaDia.soloDia(_fecha) != FechaDia.soloDia(original.fecha)
              ? _fecha
              : null,
          descripcion: descripcion != (original.descripcion ?? '').trim()
              ? descripcion
              : null,
          metodoPago: _metodoPago != original.metodoPago ? _metodoPago : null,
        );
        if (dto.toJson().isEmpty) {
          if (!mounted) return;
          Navigator.of(context).pop(false);
          return;
        }
        await widget.repository.actualizarGasto(original.id, dto);
      }
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
    final categoriaActual = _categoriaCtrl.text.trim().toLowerCase();
    return Scaffold(
      appBar:
          AppBar(title: Text(_esEdicion ? 'Editar gasto' : 'Registrar gasto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _titulo('Categoría'),
            TextFormField(
              controller: _categoriaCtrl,
              maxLength: _maxCategoria,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ej. Alimentación',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final texto = (v ?? '').trim();
                if (texto.isEmpty) return 'La categoría es obligatoria';
                if (_categoriasNoPermitidas.contains(texto.toLowerCase())) {
                  return 'Otro no está permitido, seleccione una o describa una opción real';
                }
                if (texto.length > _maxCategoria) {
                  return 'Máximo $_maxCategoria caracteres';
                }
                return null;
              },
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in _categoriasSugeridas)
                  ChoiceChip(
                    label: Text(c),
                    selected: categoriaActual == c.toLowerCase(),
                    onSelected: (_) => setState(() => _categoriaCtrl.text = c),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _titulo('Monto'),
            TextFormField(
              controller: _montoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '0',
                prefixText: '\$ ',
                suffixText: 'COP',
                helperText: 'Valor en pesos colombianos, sin puntos ni comas',
              ),
              validator: (v) {
                final valor = int.tryParse((v ?? '').trim());
                if (valor == null || valor <= 0) {
                  return 'El monto debe ser mayor a 0';
                }
                if (valor > _montoMaximo) return 'El monto es demasiado alto';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _titulo('Fecha del registro'),
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              onTap: _elegirFecha,
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.expand_more),
                ),
                child:
                    Text(DateFormat("d 'de' MMMM, yyyy", 'es').format(_fecha)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: Text(
                'Solo días de ${toBeginningOfSentenceCase(DateFormat('MMMM yyyy', 'es').format(_primerDia))}',
                style: const TextStyle(fontSize: 12, color: AppTheme.outline),
              ),
            ),
            const SizedBox(height: 20),
            _titulo('Descripción'),
            TextFormField(
              controller: _descripcionCtrl,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Detalle del gasto',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'La descripción es obligatoria'
                  : null,
            ),
            const SizedBox(height: 20),
            _titulo('Medio de pago'),
            Wrap(
              spacing: 8,
              children: [
                for (final m in metodosPagoValidos)
                  ChoiceChip(
                    label: Text(m),
                    selected: _metodoPago == m,
                    onSelected: (_) => setState(() {
                      _metodoPago = m;
                      _error = null;
                    }),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppTheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Guardar gasto'),
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
      ),
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
