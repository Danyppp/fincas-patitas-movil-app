import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/inventario/insumo.dart';
import '../../repositories/inventario/insumo_repository.dart';

/// Registro de Movimiento de Inventario (HU-17). Se abre desde una
/// tarjeta del listado, para un insumo puntual — coincide con el diseño
/// original (no hay una pantalla de detalle aparte para Inventario, se
/// va directo de la tarjeta al registro de movimiento).
///
/// Campos que el diseño pedía y que NO están acá, por decisión de Dany
/// (ver decisiones-diseno-vs-backend-inventario.md, sección 2):
///  - Número de factura: no existe en el backend.
///  - Responsable: se completa solo, automáticamente, del lado del
///    backend (usuario_id desde el token) — no hay nada que el usuario
///    tenga que llenar aquí.
///  - Fecha editable: el backend siempre usa su propia fecha/hora; solo
///    se muestra la de hoy como referencia, no se puede cambiar.
///  - Turno operativo / Observaciones y notas / banner de notificación:
///    descartados por completo, no existen en el backend.
class MovimientoFormScreen extends StatefulWidget {
  final Insumo insumo;
  final InsumoRepository repository;

  const MovimientoFormScreen({
    super.key,
    required this.insumo,
    required this.repository,
  });

  @override
  State<MovimientoFormScreen> createState() => _MovimientoFormScreenState();
}

class _MovimientoFormScreenState extends State<MovimientoFormScreen> {
  /// Motivos válidos según el tipo (ayuda de UX del lado del cliente; el
  /// backend real acepta Compra/Consumo/Merma sin importar el tipo, pero
  /// Dany pidió filtrar en la UI para que tenga sentido).
  static const _motivosPorTipo = {
    'Entrada': ['Compra'],
    'Salida': ['Consumo', 'Merma'],
  };

  String _tipo = 'Entrada';
  String? _motivo = 'Compra';
  double _cantidad = 1;
  bool _guardando = false;
  String? _error;

  double get _stockProyectado =>
      _tipo == 'Entrada' ? widget.insumo.stockActual + _cantidad : widget.insumo.stockActual - _cantidad;

  bool get _proyeccionInvalida => _tipo == 'Salida' && _stockProyectado < 0;

  void _cambiarTipo(String tipo) {
    setState(() {
      _tipo = tipo;
      _motivo = _motivosPorTipo[tipo]!.first;
      _error = null;
    });
  }

  void _ajustarCantidad(double delta) {
    final nueva = _cantidad + delta;
    setState(() => _cantidad = nueva < 0 ? 0 : nueva);
  }

  void _fijarCantidad(double valor) => setState(() => _cantidad = valor);

  Future<void> _guardar() async {
    if (_motivo == null) {
      setState(() => _error = 'Selecciona un motivo');
      return;
    }
    if (_cantidad <= 0) {
      setState(() => _error = 'La cantidad debe ser mayor a 0');
      return;
    }
    if (_proyeccionInvalida) {
      setState(() => _error = 'El stock actual es insuficiente para esta salida');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repository.registrarMovimiento(
        widget.insumo.id,
        tipo: _tipo,
        cantidad: _cantidad,
        motivo: _motivo!,
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
    final motivosDisponibles = _motivosPorTipo[_tipo]!;
    final hoy = DateFormat('dd/MM/yyyy', 'es').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Movimiento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.insumo.nombre, style: Theme.of(context).textTheme.titleLarge),
            if (widget.insumo.descripcion != null && widget.insumo.descripcion!.isNotEmpty)
              Text(widget.insumo.descripcion!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),

            const Text('Tipo de Operación'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Entrada', label: Text('Entrada'), icon: Icon(Icons.add)),
                ButtonSegment(value: 'Salida', label: Text('Salida'), icon: Icon(Icons.remove)),
              ],
              selected: {_tipo},
              onSelectionChanged: (seleccion) => _cambiarTipo(seleccion.first),
            ),
            const SizedBox(height: 16),

            const Text('Motivo'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _motivo,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              items: motivosDisponibles
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (valor) => setState(() => _motivo = valor),
            ),
            const SizedBox(height: 16),

            const Text('Cantidad'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  onPressed: () => _ajustarCantidad(-5),
                  icon: const Text('-5'),
                ),
                IconButton.filledTonal(
                  onPressed: () => _ajustarCantidad(-1),
                  icon: const Text('-1'),
                ),
                Text(
                  '${_cantidad.toStringAsFixed(0)} ${widget.insumo.unidadMedida}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton.filledTonal(
                  onPressed: () => _ajustarCantidad(1),
                  icon: const Text('+1'),
                ),
                IconButton.filledTonal(
                  onPressed: () => _ajustarCantidad(5),
                  icon: const Text('+5'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [5, 10, 20, 50]
                  .map((atajo) => ActionChip(
                        label: Text('$atajo'),
                        onPressed: () => _fijarCantidad(atajo.toDouble()),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),

            Card(
              color: _proyeccionInvalida
                  ? Colors.red.withValues(alpha: 0.08)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Stock hoy: ${widget.insumo.stockActual.toStringAsFixed(0)}'),
                    const Icon(Icons.arrow_forward, size: 16),
                    Text(
                      'Proyectado: ${_stockProyectado.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: _proyeccionInvalida ? Colors.red.shade700 : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16),
                const SizedBox(width: 6),
                Text('Fecha: $hoy (se asigna automáticamente)'),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Registrar Movimiento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
