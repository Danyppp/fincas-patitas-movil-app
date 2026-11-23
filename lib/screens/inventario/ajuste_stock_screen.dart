import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../models/financiera/producto_stock.dart';
import '../../repositories/inventario/stock_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato_cop.dart';
import '../financiera/widgets_formulario.dart';

/// Ajuste manual del stock de Huevos o Leche (por ejemplo, para cargar el
/// stock inicial). Se elige el producto, si se suma o se resta, la cantidad
/// y el motivo (obligatorio). Los huevos solo admiten números enteros y el
/// stock nunca puede quedar en negativo. Devuelve `true` al guardar.
class AjusteStockScreen extends StatefulWidget {
  final StockRepository repository;
  final List<ProductoStock> stock;
  final String? productoInicial;

  const AjusteStockScreen({
    super.key,
    required this.repository,
    required this.stock,
    this.productoInicial,
  });

  @override
  State<AjusteStockScreen> createState() => _AjusteStockScreenState();
}

class _AjusteStockScreenState extends State<AjusteStockScreen> {
  static const _maxMotivo = 255;

  final _formKey = GlobalKey<FormState>();
  final _cantidadCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  late String _producto;
  bool _suma = true;
  bool _guardando = false;
  String? _error;

  bool get _esHuevos => _producto == 'Huevos';

  double get _stockActual {
    for (final p in widget.stock) {
      if (p.nombre == _producto) return p.stockActual;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _producto = widget.productoInicial ?? 'Huevos';
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  double? _leerCantidad() =>
      double.tryParse(_cantidadCtrl.text.trim().replaceAll(',', '.'));

  String? _validarCantidad(String? texto) {
    final valor = _leerCantidad();
    if (valor == null || valor <= 0) return 'Escribe una cantidad mayor a 0';
    if (_esHuevos && valor != valor.truncateToDouble()) {
      return 'Solo números enteros';
    }
    if (!_suma && valor > _stockActual) {
      return 'No puede quedar en negativo';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final valor = _leerCantidad()!;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repository.ajustar(
        producto: _producto,
        cantidad: _suma ? valor : -valor,
        motivo: _motivoCtrl.text.trim(),
      );
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
    final unidad = _esHuevos ? 'unidades' : 'litros';
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustar stock')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            FormTarjeta(
              children: [
                const FormTitulo(
                    icono: Icons.inventory_2_outlined,
                    texto: 'Producto',
                    etiqueta: 'Requerido'),
                Wrap(
                  spacing: 8,
                  children: [
                    FormChip(
                      texto: 'Huevos',
                      icono: Icons.egg_outlined,
                      seleccionado: _producto == 'Huevos',
                      onTap: () => setState(() {
                        _producto = 'Huevos';
                        _cantidadCtrl.clear();
                      }),
                    ),
                    FormChip(
                      texto: 'Leche',
                      icono: Icons.local_drink_outlined,
                      seleccionado: _producto == 'Leche',
                      onTap: () => setState(() {
                        _producto = 'Leche';
                        _cantidadCtrl.clear();
                      }),
                    ),
                  ],
                ),
                FormAyuda(
                    'Stock actual: ${FormatoCOP.cantidad(_stockActual)} $unidad'),
              ],
            ),
            const SizedBox(height: 14),
            FormTarjeta(
              children: [
                const FormTitulo(
                    icono: Icons.swap_vert,
                    texto: 'Tipo de ajuste',
                    etiqueta: 'Requerido'),
                Wrap(
                  spacing: 8,
                  children: [
                    FormChip(
                      texto: 'Sumar',
                      icono: Icons.add,
                      seleccionado: _suma,
                      onTap: () => setState(() => _suma = true),
                    ),
                    FormChip(
                      texto: 'Restar',
                      icono: Icons.remove,
                      seleccionado: !_suma,
                      onTap: () => setState(() => _suma = false),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const FormTitulo(
                    icono: Icons.pin_outlined,
                    texto: 'Cantidad',
                    etiqueta: 'Requerido'),
                TextFormField(
                  controller: _cantidadCtrl,
                  keyboardType:
                      TextInputType.numberWithOptions(decimal: !_esHuevos),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        _esHuevos ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    hintText: _esHuevos ? 'Ej. 100' : 'Ej. 12,5',
                    suffixText: unidad,
                    errorMaxLines: 2,
                  ),
                  validator: _validarCantidad,
                ),
              ],
            ),
            const SizedBox(height: 14),
            FormTarjeta(
              children: [
                const FormTitulo(
                    icono: Icons.notes_outlined,
                    texto: 'Motivo',
                    etiqueta: 'Requerido'),
                TextFormField(
                  controller: _motivoCtrl,
                  maxLength: _maxMotivo,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(hintText: 'Ej. Stock inicial'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El motivo es obligatorio'
                      : null,
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: AppTheme.error, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 18),
            FormBotones(
              textoGuardar: 'Guardar ajuste',
              guardando: _guardando,
              onGuardar: _guardar,
              onCancelar: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
