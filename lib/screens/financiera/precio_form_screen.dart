import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/financiera/precio_mercado.dart';
import '../../repositories/financiera/financiera_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_dia.dart';
import 'widgets_formulario.dart';

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
    final esHoy = FechaDia.soloDia(_fecha) == FechaDia.hoy();

    return Scaffold(
      appBar:
          AppBar(title: Text(_esEdicion ? 'Editar precio' : 'Nuevo precio')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sell_outlined, color: AppTheme.secondary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Define el valor unitario de venta: se usa para estimar la producción y como precio de las ventas.',
                      style: TextStyle(
                          fontSize: 12.5, color: AppTheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FormTarjeta(
              children: [
                const FormTitulo(
                    icono: Icons.category_outlined,
                    texto: 'Producto',
                    etiqueta: 'Selecciona uno'),
                Row(
                  children: [
                    Expanded(
                      child: _tarjetaProducto(
                          _leche, Icons.water_drop_outlined, 'Litro'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _tarjetaProducto(
                          _huevos, Icons.egg_outlined, 'Unidad'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const FormTitulo(
                    icono: Icons.straighten,
                    texto: 'Unidad de medida (automática)',
                    etiqueta: 'Bloqueado'),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 19, color: AppTheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(unidadTexto,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600)),
                      ),
                      const Text('Fija',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const FormTitulo(
                    icono: Icons.payments_outlined,
                    texto: 'Precio de referencia',
                    etiqueta: 'COP',
                    etiquetaDestacada: true),
                TextFormField(
                  controller: _precioCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary),
                    suffixText: unidadCorta.isEmpty ? 'COP' : '/ $unidadCorta',
                    helperText:
                        'Valor en pesos colombianos, sin puntos ni comas',
                  ),
                  validator: (v) {
                    final valor = int.tryParse((v ?? '').trim());
                    if (valor == null || valor <= 0) {
                      return 'El precio debe ser mayor a 0';
                    }
                    if (valor > _precioMaximo) {
                      return 'El precio es demasiado alto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                const FormTitulo(
                    icono: Icons.calendar_today_outlined,
                    texto: 'Fecha de vigencia'),
                FormSelector(
                  icono: Icons.event_outlined,
                  etiquetaSuperior: esHoy ? 'A partir de hoy' : 'A partir del',
                  texto: DateFormat("d 'de' MMMM, yyyy", 'es').format(_fecha),
                  onTap: _elegirFecha,
                ),
                FormAyuda(
                    'Solo días de ${toBeginningOfSentenceCase(DateFormat('MMMM yyyy', 'es').format(_primerDia))}'),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppTheme.error)),
            ],
            const SizedBox(height: 20),
            FormBotones(
              textoGuardar: 'Guardar precio',
              guardando: _guardando,
              onGuardar: _guardar,
              onCancelar: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta grande para elegir el producto (Leche o Huevos).
  Widget _tarjetaProducto(String producto, IconData icono, String unidad) {
    final activo = _producto == producto;
    return Material(
      color: activo ? const Color(0xFFE8F5E9) : AppTheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        onTap: () => setState(() {
          _producto = producto;
          _error = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
            border: Border.all(
                color: activo ? AppTheme.primaryContainer : Colors.transparent,
                width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icono,
                  color: activo ? AppTheme.primary : AppTheme.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(producto,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800)),
              Text(unidad,
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
