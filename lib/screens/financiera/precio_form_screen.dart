import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/financiera/precio_mercado.dart';
import '../../repositories/financiera/financiera_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_dia.dart';

/// Formulario para registrar o editar un precio de mercado.
///
/// - Producto: solo Leche o Huevos (decisión de Dany). La unidad es
///   automática y no se puede cambiar: litros para la leche, unidades para
///   los huevos.
/// - Precio: pesos enteros, obligatorio y mayor a 0.
/// - Fecha de vigencia: obligatoria; solo se pueden elegir días del mes
///   seleccionado en la pantalla de Financiera (decisión de Dany,
///   2026-11-23; aplica también al editar). Por defecto hoy, o el día 1 si
///   ese mes no es el actual.
///
/// Cada precio nuevo es una fila nueva con su fecha (el historial se
/// conserva). Al editar solo se envían los campos que cambiaron. Devuelve
/// `true` al guardar, para que la lista se recargue.
class PrecioFormScreen extends StatefulWidget {
  final FinancieraRepository repository;
  final PrecioMercado? precio; // null = registrar uno nuevo

  /// Mes seleccionado en la pantalla de Financiera (cualquier día de ese
  /// mes): las fechas de vigencia solo se pueden elegir dentro de él.
  final DateTime mes;

  const PrecioFormScreen({
    super.key,
    required this.repository,
    required this.mes,
    this.precio,
  });

  @override
  State<PrecioFormScreen> createState() => _PrecioFormScreenState();
}

class _PrecioFormScreenState extends State<PrecioFormScreen> {
  static const _leche = 'Leche';
  static const _huevos = 'Huevos';
  static const _precioMaximo = 99999999; // columna Decimal(10, 2)

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _precioCtrl;
  late DateTime _fecha;
  String? _producto; // Leche | Huevos
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.precio != null;

  DateTime get _primerDia => DateTime(widget.mes.year, widget.mes.month, 1);
  DateTime get _ultimoDia => DateTime(widget.mes.year, widget.mes.month + 1, 0);

  bool _enMes(DateTime f) =>
      f.year == widget.mes.year && f.month == widget.mes.month;

  /// Producto de un precio ya guardado, por coincidencia parcial (igual
  /// que en la web): "Leche fresca" cuenta como Leche.
  static String? _productoDe(String nombre) {
    final n = nombre.toLowerCase();
    if (n.contains('leche')) return _leche;
    if (n.contains('huevo')) return _huevos;
    return null;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.precio;
    _producto = p == null ? null : _productoDe(p.producto);
    _precioCtrl = TextEditingController(
        text: p == null ? '' : p.precio.round().toString());
    final hoy = FechaDia.hoy();
    // Al editar se conserva la fecha del precio hasta que se cambie (puede
    // ser de otro mes); un precio nuevo parte de hoy o del día 1 del mes.
    _fecha = p?.fecha ?? (_enMes(hoy) ? hoy : _primerDia);
  }

  @override
  void dispose() {
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final resultado = await showDatePicker(
      context: context,
      // Si la fecha actual cae fuera del mes (precio de otro mes), el
      // calendario abre en el primer día del mes permitido.
      initialDate: _enMes(_fecha) ? _fecha : _primerDia,
      firstDate: _primerDia,
      lastDate: _ultimoDia,
    );
    if (resultado != null) {
      setState(() => _fecha = FechaDia.soloDia(resultado));
    }
  }

  Future<void> _guardar() async {
    final formularioValido = _formKey.currentState!.validate();
    if (_producto == null) {
      setState(() => _error = 'Selecciona el producto');
      return;
    }
    if (!formularioValido) {
      setState(() => _error = null);
      return;
    }

    final precio = double.parse(_precioCtrl.text.trim());
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final original = widget.precio;
      if (original == null) {
        await widget.repository.crearPrecio(CrearPrecioMercadoDTO(
          producto: _producto!,
          precio: precio,
          fecha: _fecha,
        ));
      } else {
        // Solo se envía lo que cambió. El producto solo se envía si cambió
        // de Leche a Huevos (o al revés), para no renombrar un precio como
        // "Leche fresca" sin necesidad.
        final dto = ActualizarPrecioMercadoDTO(
          producto:
              _producto != _productoDe(original.producto) ? _producto : null,
          precio: _precioCtrl.text.trim() != original.precio.round().toString()
              ? precio
              : null,
          fecha: FechaDia.soloDia(_fecha) != FechaDia.soloDia(original.fecha)
              ? _fecha
              : null,
        );
        if (dto.toJson().isEmpty) {
          if (!mounted) return;
          Navigator.of(context).pop(false);
          return;
        }
        await widget.repository.actualizarPrecio(original.id, dto);
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
    final unidadTexto = _producto == _leche
        ? 'Litro (L)'
        : _producto == _huevos
            ? 'Unidad'
            : 'Se asigna al elegir el producto';
    final unidadCorta = _producto == _leche
        ? 'L'
        : _producto == _huevos
            ? 'unid.'
            : '';

    return Scaffold(
      appBar:
          AppBar(title: Text(_esEdicion ? 'Editar precio' : 'Nuevo precio')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _titulo('Producto'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.water_drop_outlined, size: 18),
                  label: const Text(_leche),
                  selected: _producto == _leche,
                  onSelected: (_) => setState(() {
                    _producto = _leche;
                    _error = null;
                  }),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.egg_outlined, size: 18),
                  label: const Text(_huevos),
                  selected: _producto == _huevos,
                  onSelected: (_) => setState(() {
                    _producto = _huevos;
                    _error = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _titulo('Unidad de medida (automática)'),
            InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.lock_outline),
              ),
              child: Text(unidadTexto,
                  style: const TextStyle(color: AppTheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 20),
            _titulo('Precio de referencia'),
            TextFormField(
              controller: _precioCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '0',
                prefixText: '\$ ',
                suffixText: unidadCorta.isEmpty ? 'COP' : 'COP / $unidadCorta',
                helperText: 'Valor en pesos colombianos, sin puntos ni comas',
              ),
              validator: (v) {
                final valor = int.tryParse((v ?? '').trim());
                if (valor == null || valor <= 0) {
                  return 'El precio debe ser mayor a 0';
                }
                if (valor > _precioMaximo) return 'El precio es demasiado alto';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _titulo('Fecha de vigencia'),
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              onTap: _elegirFecha,
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.edit_calendar_outlined),
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
              label: const Text('Guardar precio'),
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
