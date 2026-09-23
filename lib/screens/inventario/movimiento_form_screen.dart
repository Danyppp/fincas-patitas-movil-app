import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/auth_session.dart';
import '../../models/inventario/insumo.dart';
import '../../repositories/inventario/insumo_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/categoria_visual.dart';

/// Registro de Movimiento de Inventario (HU-17), siguiendo el mockup de
/// Stitch (`registro_de_movimiento_de_inventario_fincas_y_patitas/screen.png`).
/// Se abre desde una tarjeta del listado, para un insumo puntual — coincide
/// con el diseño (no hay pantalla de detalle aparte en Inventario).
///
/// Campos que el diseño pedía y que NO están acá, por decisión de Dany
/// (ver decisiones-diseno-vs-backend-inventario.md, sección 2):
///  - Número de factura: no existe en el backend.
///  - Responsable: se muestra en modo solo-lectura (quién tiene la sesión
///    activa), tomado de [AuthSession] — no hay forma de asignárselo a
///    otra persona, porque el backend siempre usa el `usuario_id` del
///    token de quien hace la petición, sin importar lo que mande el
///    formulario.
///  - Fecha editable / Turno operativo: el backend siempre usa su propia
///    fecha/hora; solo se muestra la de hoy como referencia.
///  - Observaciones y notas / banner de notificación: descartados por
///    completo, no existen en el backend.
class MovimientoFormScreen extends StatefulWidget {
  final Insumo insumo;
  final InsumoRepository repository;
  final AuthSession session;

  const MovimientoFormScreen({
    super.key,
    required this.insumo,
    required this.repository,
    required this.session,
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
  bool _eliminando = false;
  String? _error;

  bool get _esEntrada => _tipo == 'Entrada';

  double get _stockProyectado =>
      _esEntrada ? widget.insumo.stockActual + _cantidad : widget.insumo.stockActual - _cantidad;

  bool get _proyeccionInvalida => !_esEntrada && _stockProyectado < 0;

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

  /// Pide confirmación antes de eliminar el insumo por completo
  /// (`DELETE /bodega/:id`). Se pone acá y no en el listado porque
  /// Inventario no tiene una pantalla de detalle aparte — este formulario,
  /// al abrirse ya con el insumo puntual, es el único lugar natural para
  /// esa acción.
  Future<void> _confirmarEliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar insumo'),
        content: Text(
          '¿Seguro que quieres eliminar "${widget.insumo.nombre}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await _eliminar();
  }

  Future<void> _eliminar() async {
    setState(() {
      _eliminando = true;
      _error = null;
    });
    try {
      await widget.repository.eliminar(widget.insumo.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  Widget _botonCantidad(String etiqueta, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Text(etiqueta,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.onSurface)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final motivosDisponibles = _motivosPorTipo[_tipo]!;
    final hoy = DateFormat('dd/MM/yyyy', 'es').format(DateTime.now());
    final coloresCategoria = colorCategoriaBodega(widget.insumo.categoria?.nombre);
    final textTheme = Theme.of(context).textTheme;
    final colorImpacto = _proyeccionInvalida
        ? AppTheme.error
        : (_esEntrada ? const Color(0xFF2E7D32) : AppTheme.tertiary);

    return Scaffold(
      // "BODEGA PRINCIPAL" se movió al body (ver más abajo): un título de
      // 2 líneas en el AppBar seguía viéndose cortado arriba en pantallas
      // reales aun fijando `toolbarHeight`, así que se evita ese patrón.
      appBar: AppBar(
        title: const Text('Registrar Movimiento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar insumo',
            onPressed: _guardando || _eliminando ? null : _confirmarEliminar,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BODEGA PRINCIPAL',
                style: textTheme.labelSmall
                    ?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            // Insumo (fijo — viene de la tarjeta que se tocó en el listado).
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: coloresCategoria.fondo,
                    child: Icon(iconoCategoriaBodega(widget.insumo.categoria?.nombre),
                        color: coloresCategoria.icono, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.insumo.nombre, style: textTheme.titleMedium),
                        Text(
                          'Stock disponible: ${widget.insumo.stockActual.toStringAsFixed(0)} ${widget.insumo.unidadMedida}',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (widget.insumo.categoria != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(widget.insumo.categoria!.nombre, style: textTheme.labelSmall),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text('Tipo de Operación', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _botonTipo(
                    etiqueta: 'Entrada',
                    icono: Icons.arrow_downward_rounded,
                    seleccionado: _esEntrada,
                    onTap: () => _cambiarTipo('Entrada'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _botonTipo(
                    etiqueta: 'Salida',
                    icono: Icons.arrow_upward_rounded,
                    seleccionado: !_esEntrada,
                    onTap: () => _cambiarTipo('Salida'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text('Motivo', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _motivo,
              items: motivosDisponibles
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (valor) => setState(() => _motivo = valor),
            ),
            const SizedBox(height: 20),

            Text('Cantidad a Registrar', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _botonCantidad('-5', () => _ajustarCantidad(-5)),
                _botonCantidad('-1', () => _ajustarCantidad(-1)),
                Column(
                  children: [
                    Text(_cantidad.toStringAsFixed(0), style: textTheme.headlineLarge),
                    Text(widget.insumo.unidadMedida, style: textTheme.bodySmall),
                  ],
                ),
                _botonCantidad('+1', () => _ajustarCantidad(1)),
                _botonCantidad('+5', () => _ajustarCantidad(5)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Frecuentes: ', style: textTheme.bodySmall),
                const SizedBox(width: 4),
                Wrap(
                  spacing: 8,
                  children: [5, 10, 20, 50]
                      .map((atajo) => ActionChip(
                            label: Text('$atajo'),
                            onPressed: () => _fijarCantidad(atajo.toDouble()),
                          ))
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorImpacto.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.show_chart_rounded, size: 16, color: colorImpacto),
                      const SizedBox(width: 6),
                      Text('IMPACTO PROYECTADO EN INVENTARIO',
                          style: textTheme.labelSmall?.copyWith(color: colorImpacto)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text('Stock Hoy', style: textTheme.bodySmall),
                          Text(widget.insumo.stockActual.toStringAsFixed(0),
                              style: textTheme.headlineSmall),
                        ],
                      ),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: colorImpacto,
                        child: Icon(_esEntrada ? Icons.add : Icons.remove,
                            color: Colors.white, size: 18),
                      ),
                      Column(
                        children: [
                          Text('Proyectado', style: textTheme.bodySmall),
                          Text(_stockProyectado.toStringAsFixed(0),
                              style: textTheme.headlineSmall?.copyWith(color: colorImpacto)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.outline),
                const SizedBox(width: 6),
                Text('Fecha: $hoy (se asigna automáticamente)', style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            // Solo lectura: quién queda registrado como responsable del
            // movimiento es siempre quien tiene la sesión activa — no se
            // puede asignar a otra persona desde este formulario.
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppTheme.outline),
                const SizedBox(width: 6),
                Text(
                  'Registrado por: ${widget.session.usuario?.nombreUsuario ?? 'Usuario actual'}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: AppTheme.error)),
            ],

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _guardando || _eliminando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text('Confirmar y Guardar Movimiento'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _guardando || _eliminando
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonTipo({
    required String etiqueta,
    required IconData icono,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: seleccionado ? AppTheme.primaryContainer : AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: seleccionado ? null : Border.all(color: AppTheme.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 18, color: seleccionado ? Colors.white : AppTheme.onSurface),
            const SizedBox(width: 6),
            Text(
              etiqueta,
              style: TextStyle(
                color: seleccionado ? Colors.white : AppTheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
