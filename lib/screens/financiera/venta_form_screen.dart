import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/financiera/precio_mercado.dart';
import '../../models/financiera/venta.dart';
import '../../repositories/financiera/financiera_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_dia.dart';
import '../../utils/formato_cop.dart';

/// Formulario para registrar o editar una venta (módulo Financiera).
///
/// - Producto: solo Huevos o Leche (decisión de Dany, 2026-11-23: no existe
///   la opción "Otro"). Al backend llega solo el nombre del producto.
/// - Cantidad (con la unidad del producto: L o unid.), obligatoria.
/// - Precio unitario: BLOQUEADO, no se puede escribir (decisión de Dany,
///   2026-11-23). Al elegir Huevos o Leche toma el precio de mercado vigente
///   de ese producto (el más reciente, el mismo de la pastilla "Vigente" de
///   Precios de mercado). Si el producto no tiene precio, no se puede
///   guardar la venta hasta registrarlo. Al editar una venta se conserva el
///   precio con el que se registró, salvo que se cambie de producto.
/// - Total estimado en vivo (cantidad x precio). El total real lo calcula
///   siempre el servidor.
/// - Comprador (opcional).
/// - Fecha de la venta: solo días del mes que se está viendo en la pantalla
///   de Gastos y Ventas (hoy por defecto, o el día 1 si ese mes no es el
///   actual).
/// - Estado de pago: Pagado o Pendiente. Una venta pendiente lleva fecha
///   límite de pago: solo se puede elegir entre 1 y 7 días después de hoy
///   (sugerida: a 7 días); los demás días están deshabilitados.
///
/// Al editar solo se envían los campos que cambiaron. Si una venta
/// pendiente pasa a Pagado, se envía la fecha de pago de hoy (día local).
/// Devuelve `true` al guardar, para que la lista se recargue.
class VentaFormScreen extends StatefulWidget {
  final FinancieraRepository repository;
  final Venta? venta; // null = registrar una nueva

  /// Mes que se está viendo en la pantalla de Gastos y Ventas (cualquier
  /// día de ese mes). Al editar se usa el mes de la propia venta.
  final DateTime mes;

  const VentaFormScreen({
    super.key,
    required this.repository,
    required this.mes,
    this.venta,
  });

  @override
  State<VentaFormScreen> createState() => _VentaFormScreenState();
}

class _VentaFormScreenState extends State<VentaFormScreen> {
  static const _huevos = 'Huevos';
  static const _leche = 'Leche';
  static const _maxComprador = 100;
  static const _maxTotal = 99999999; // columna Decimal(10, 2)
  static const _diasPlazoSugerido = 7;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cantidadCtrl;
  late final TextEditingController _precioCtrl; // solo muestra el precio
  late final TextEditingController _compradorCtrl;
  late DateTime _fecha;
  late DateTime _fechaLimite;
  String? _producto; // Huevos | Leche
  String? _productoOriginal; // al editar: el producto con el que se guardó
  double? _precioValor; // precio unitario (bloqueado)
  List<PrecioMercado> _precios = [];
  String _estado = estadoPagado;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.venta != null;

  DateTime get _mesBase => widget.venta?.fecha ?? widget.mes;
  DateTime get _primerDia => DateTime(_mesBase.year, _mesBase.month, 1);
  DateTime get _ultimoDia => DateTime(_mesBase.year, _mesBase.month + 1, 0);

  /// Fecha límite de pago: de 1 a 7 días después de hoy.
  DateTime get _limiteMinimo => FechaDia.sumarDias(FechaDia.hoy(), 1);
  DateTime get _limiteMaximo =>
      FechaDia.sumarDias(FechaDia.hoy(), _diasPlazoSugerido);

  @override
  void initState() {
    super.initState();
    final v = widget.venta;
    final nombre = v?.producto ?? '';
    final minuscula = nombre.trim().toLowerCase();
    if (v != null) {
      if (minuscula == 'huevos') {
        _producto = _huevos;
      } else if (minuscula == 'leche') {
        _producto = _leche;
      }
      // Un producto distinto (ventas antiguas) queda sin elegir: hay que
      // escoger Huevos o Leche para poder guardar.
      _productoOriginal = _producto;
      _precioValor = v.precioUnitario;
    }
    _cantidadCtrl = TextEditingController(
        text: v == null ? '' : _textoCantidad(v.cantidad));
    _precioCtrl = TextEditingController(
        text: v == null ? '' : _textoPrecio(v.precioUnitario));
    _compradorCtrl = TextEditingController(text: v?.comprador ?? '');
    final hoy = FechaDia.hoy();
    final hoyEnMes = hoy.year == _mesBase.year && hoy.month == _mesBase.month;
    _fecha = v?.fecha ?? (hoyEnMes ? hoy : _primerDia);
    _estado = v?.estadoPago ?? estadoPagado;
    _fechaLimite = v?.fechaLimitePago ??
        FechaDia.sumarDias(FechaDia.hoy(), _diasPlazoSugerido);
    _cargarPrecios();
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    _compradorCtrl.dispose();
    super.dispose();
  }

  static String _textoCantidad(double cantidad) {
    return cantidad == cantidad.roundToDouble()
        ? cantidad.round().toString()
        : cantidad.toString();
  }

  static String _textoPrecio(double precio) => precio == precio.roundToDouble()
      ? precio.round().toString()
      : precio.toStringAsFixed(2);

  // ── Precio de mercado ─────────────────────────────────────────────────

  /// Si los precios no cargan, el producto queda "sin precio" y no se
  /// puede guardar la venta (se muestra el aviso en el campo).
  Future<void> _cargarPrecios() async {
    try {
      final lista = await widget.repository.listarPrecios();
      if (!mounted) return;
      _precios = lista;
      if (!_esEdicion) _aplicarPrecioVigente();
    } on ApiException {
      // Sin precios: el campo avisa que no hay precio de mercado.
    } on NetworkException {
      // Sin precios: el campo avisa que no hay precio de mercado.
    }
  }

  /// Precio de mercado más reciente del producto elegido (desempate por
  /// id), igual que la pastilla "Vigente" de Precios de mercado.
  PrecioMercado? get _precioVigente {
    final clave = _producto == _huevos
        ? 'huevo'
        : _producto == _leche
            ? 'leche'
            : null;
    if (clave == null) return null;
    PrecioMercado? mejor;
    for (final p in _precios) {
      if (!p.producto.toLowerCase().contains(clave)) continue;
      if (mejor == null ||
          p.fecha.isAfter(mejor.fecha) ||
          (p.fecha == mejor.fecha && p.id > mejor.id)) {
        mejor = p;
      }
    }
    return mejor;
  }

  void _aplicarPrecioVigente() {
    final vigente = _precioVigente;
    setState(() {
      _precioValor = vigente?.precio;
      _precioCtrl.text = vigente == null ? '' : _textoPrecio(vigente.precio);
    });
  }

  void _elegirProducto(String producto) {
    setState(() => _producto = producto);
    final original = widget.venta;
    if (original != null && producto == _productoOriginal) {
      // Vuelve al producto original: se restituye el precio de la venta.
      setState(() {
        _precioValor = original.precioUnitario;
        _precioCtrl.text = _textoPrecio(original.precioUnitario);
      });
    } else {
      _aplicarPrecioVigente();
    }
  }

  // ── Cálculos ──────────────────────────────────────────────────────────

  double? get _cantidad =>
      double.tryParse(_cantidadCtrl.text.trim().replaceAll(',', '.'));

  double? get _precio => _precioValor;

  double? get _total {
    final c = _cantidad;
    final p = _precio;
    if (c == null || p == null || c <= 0 || p <= 0) return null;
    return double.parse((c * p).toStringAsFixed(2));
  }

  String get _nombreProducto => _producto ?? '';

  // ── Fechas ────────────────────────────────────────────────────────────

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

  Future<void> _elegirFechaLimite() async {
    // Si la fecha límite guardada queda fuera de la ventana permitida (una
    // venta pendiente antigua), el calendario abre en el límite más cercano.
    var inicial = _fechaLimite;
    if (inicial.isBefore(_limiteMinimo)) inicial = _limiteMinimo;
    if (inicial.isAfter(_limiteMaximo)) inicial = _limiteMaximo;
    final resultado = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: _limiteMinimo,
      lastDate: _limiteMaximo,
    );
    if (resultado != null) {
      setState(() => _fechaLimite = FechaDia.soloDia(resultado));
    }
  }

  // ── Guardado ──────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (_producto == null) {
      setState(() => _error = 'Selecciona el producto');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_estado == estadoPendiente &&
        FechaDia.soloDia(_fechaLimite).isBefore(FechaDia.soloDia(_fecha))) {
      setState(() => _error =
          'La fecha límite no puede ser anterior a la fecha de la venta');
      return;
    }

    final producto = _nombreProducto;
    final cantidad = _cantidad!;
    final precio = _precio!;
    final comprador = _compradorCtrl.text.trim();

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final original = widget.venta;
      if (original == null) {
        await widget.repository.crearVenta(CrearVentaDTO(
          producto: producto,
          cantidad: cantidad,
          precioUnitario: precio,
          fecha: _fecha,
          comprador: comprador.isEmpty ? null : comprador,
          estadoPago: _estado,
          fechaLimitePago: _estado == estadoPendiente ? _fechaLimite : null,
        ));
      } else {
        // Solo se envía lo que cambió, para no alterar datos que la
        // persona no tocó.
        String? estadoEnviar;
        DateTime? fechaPagoEnviar;
        DateTime? limiteEnviar;
        if (_estado != original.estadoPago) {
          estadoEnviar = _estado;
          if (_estado == estadoPagado) {
            // Pendiente -> Pagado: fecha de pago explícita (día local de
            // hoy); el servidor además borra la fecha límite.
            fechaPagoEnviar = FechaDia.hoy();
          } else {
            limiteEnviar = _fechaLimite;
          }
        } else if (_estado == estadoPendiente) {
          final actual = original.fechaLimitePago;
          if (actual == null ||
              FechaDia.soloDia(_fechaLimite) != FechaDia.soloDia(actual)) {
            limiteEnviar = _fechaLimite;
          }
        }

        final dto = ActualizarVentaDTO(
          producto:
              producto.toLowerCase() != original.producto.trim().toLowerCase()
                  ? producto
                  : null,
          cantidad:
              (cantidad - original.cantidad).abs() > 0.0001 ? cantidad : null,
          precioUnitario:
              (precio - original.precioUnitario).abs() > 0.0001 ? precio : null,
          comprador:
              comprador != (original.comprador ?? '').trim() ? comprador : null,
          fecha: FechaDia.soloDia(_fecha) != FechaDia.soloDia(original.fecha)
              ? _fecha
              : null,
          estadoPago: estadoEnviar,
          fechaPago: fechaPagoEnviar,
          fechaLimitePago: limiteEnviar,
        );
        if (dto.toJson().isEmpty) {
          if (!mounted) return;
          Navigator.of(context).pop(false);
          return;
        }
        await widget.repository.actualizarVenta(original.id, dto);
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

  String _ayudaPrecio() {
    if (_producto == null) {
      return 'Se toma del precio de mercado del producto (no editable)';
    }
    if (_esEdicion && _producto == _productoOriginal) {
      return 'Precio con el que se registró la venta (no editable)';
    }
    final vigente = _precioVigente;
    if (vigente == null) return 'Sin precio de mercado para $_producto';
    return 'Precio de mercado vigente desde ${DateFormat('d MMM yyyy', 'es').format(vigente.fecha)} (no editable)';
  }

  // ── Pantalla ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unidad = FormatoCOP.unidadDeProducto(_nombreProducto);
    final total = _total;
    final formatoFecha = DateFormat("d 'de' MMMM, yyyy", 'es');

    return Scaffold(
      appBar:
          AppBar(title: Text(_esEdicion ? 'Editar venta' : 'Registrar venta')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _titulo('Producto a vender'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.egg_outlined, size: 18),
                  label: const Text(_huevos),
                  selected: _producto == _huevos,
                  onSelected: (_) => _elegirProducto(_huevos),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.water_drop_outlined, size: 18),
                  label: const Text(_leche),
                  selected: _producto == _leche,
                  onSelected: (_) => _elegirProducto(_leche),
                ),
              ],
            ),
            if (_esEdicion && _producto == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Esta venta tiene el producto "${widget.venta!.producto}", que ya no está disponible. Elige Huevos o Leche.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.error),
                ),
              ),
            const SizedBox(height: 20),
            _titulo(unidad.isEmpty
                ? 'Cantidad vendida'
                : 'Cantidad vendida ($unidad)'),
            TextFormField(
              controller: _cantidadCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                hintText: '0',
                suffixText: unidad.isEmpty ? null : unidad,
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final valor =
                    double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                if (valor == null || valor <= 0) {
                  return 'La cantidad debe ser mayor a 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _titulo('Precio unitario'),
            TextFormField(
              controller: _precioCtrl,
              readOnly: true,
              enableInteractiveSelection: false,
              decoration: InputDecoration(
                hintText: '0',
                prefixText: '\$ ',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixText: unidad.isEmpty ? 'COP' : 'COP / $unidad',
                helperText: _ayudaPrecio(),
              ),
              validator: (_) {
                if (_producto == null) return 'Selecciona primero el producto';
                final valor = _precioValor;
                if (valor == null || valor <= 0) {
                  return 'No hay precio de mercado para $_producto. Regístralo en Precios de mercado';
                }
                final t = _total;
                if (t != null && t > _maxTotal) {
                  return 'El total es demasiado alto';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      color: AppTheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total estimado',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        Text('El total final lo calcula el sistema',
                            style: TextStyle(
                                fontSize: 11.5, color: AppTheme.outline)),
                      ],
                    ),
                  ),
                  Text(
                    total == null ? '\$ 0' : FormatoCOP.pesos(total),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _titulo('Comprador (opcional)'),
            TextFormField(
              controller: _compradorCtrl,
              maxLength: _maxComprador,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Nombre del comprador',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 12),
            _titulo('Fecha de la venta'),
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              onTap: _elegirFecha,
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.edit_calendar_outlined),
                ),
                child: Text(formatoFecha.format(_fecha)),
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
            _titulo('Estado del pago'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text(estadoPagado),
                  selected: _estado == estadoPagado,
                  onSelected: (_) => setState(() => _estado = estadoPagado),
                ),
                ChoiceChip(
                  label: const Text(estadoPendiente),
                  selected: _estado == estadoPendiente,
                  onSelected: (_) => setState(() => _estado = estadoPendiente),
                ),
              ],
            ),
            if (_estado == estadoPendiente) ...[
              const SizedBox(height: 16),
              _titulo('Fecha límite de pago'),
              InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                onTap: _elegirFechaLimite,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.event_outlined),
                    suffixIcon: Icon(Icons.edit_calendar_outlined),
                  ),
                  child: Text(formatoFecha.format(_fechaLimite)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 12, top: 6),
                child: Text(
                  'Solo se puede elegir entre 1 y 7 días después de hoy',
                  style: TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
              ),
            ],
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
              label: const Text('Guardar venta'),
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
