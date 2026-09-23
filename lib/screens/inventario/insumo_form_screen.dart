import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/inventario/categoria_bodega.dart';
import '../../models/inventario/insumo.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/inventario/insumo_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/categoria_visual.dart';

/// Registrar un insumo nuevo en la bodega (`POST /bodega`). Pantalla nueva,
/// pedida por Dany el 2026-09-23. El mockup de Stitch para esta pantalla
/// (`registrar_insumo_nuevo`) apareció después de construirla funcional,
/// así que esta es la ronda de estilos, comparada campo por campo:
///
/// Campos del diseño que NO están acá (decisión de Dany, 2026-09-23):
///  - Código de Barras / SKU + escáner: no existe ese campo en el backend.
///  - Ubicación en Bodega: no existe (no hay concepto de ubicaciones
///    físicas dentro de la bodega, ver nota en decisiones-diseno-vs-backend).
///  - Lote y Caducidad (Número de Lote, Vencimiento, Proveedor Habitual):
///    el backend sí soporta lotes (`POST /lotes-inventario`), pero es una
///    entidad separada del insumo. Se descartó por completo de este
///    formulario por simplicidad — si hace falta, se resuelve más
///    adelante con su propia pantalla.
class InsumoFormScreen extends StatefulWidget {
  final InsumoRepository repository;
  final CatalogoRepository catalogoRepository;

  const InsumoFormScreen({
    super.key,
    required this.repository,
    required this.catalogoRepository,
  });

  @override
  State<InsumoFormScreen> createState() => _InsumoFormScreenState();
}

class _InsumoFormScreenState extends State<InsumoFormScreen> {
  /// Mismo listado que `UNIDADES_VALIDAS` en `bodega.service.ts` del
  /// backend — si algún día cambia allá, hay que actualizarlo acá también.
  static const _unidadesValidas = [
    'ml',
    'Ltr',
    'g',
    'Kg',
    'Dosis',
    'Unidad',
    'Bulto',
    'Arroba',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _stockMinimoCtrl = TextEditingController(text: '0');

  bool _cargandoCategorias = true;
  String? _errorCategorias;
  List<CategoriaBodega> _categorias = [];
  int? _categoriaId;
  String? _unidadMedida;
  double _stockInicial = 0;

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    // Refresca la vista previa en vivo mientras se escribe.
    _nombreCtrl.addListener(_refrescar);
    _descripcionCtrl.addListener(_refrescar);
  }

  void _refrescar() => setState(() {});

  Future<void> _cargarCategorias() async {
    setState(() {
      _cargandoCategorias = true;
      _errorCategorias = null;
    });
    try {
      final categorias = await widget.catalogoRepository.listarCategoriasBodega();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _cargandoCategorias = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCategorias = '$e';
        _cargandoCategorias = false;
      });
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _stockMinimoCtrl.dispose();
    super.dispose();
  }

  void _ajustarStockInicial(double delta) {
    final nuevo = _stockInicial + delta;
    setState(() => _stockInicial = nuevo < 0 ? 0 : nuevo);
  }

  CategoriaBodega? get _categoriaSeleccionada {
    if (_categoriaId == null) return null;
    try {
      return _categorias.firstWhere((c) => c.id == _categoriaId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaId == null) {
      setState(() => _error = 'Selecciona una categoría');
      return;
    }
    if (_unidadMedida == null) {
      setState(() => _error = 'Selecciona una unidad de medida');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final nuevo = await widget.repository.crear(
        CrearInsumoDTO(
          categoriaId: _categoriaId!,
          nombre: _nombreCtrl.text.trim(),
          descripcion: _descripcionCtrl.text.trim().isEmpty
              ? null
              : _descripcionCtrl.text.trim(),
          unidadMedida: _unidadMedida!,
          stockInicial: _stockInicial,
          stockMinimo: double.tryParse(_stockMinimoCtrl.text.trim()) ?? 0,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop<Insumo>(nuevo);
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

  String? _validarNumeroNoNegativo(String? valor) {
    if (valor == null || valor.trim().isEmpty) return null; // opcional
    final n = double.tryParse(valor.trim());
    if (n == null) return 'Debe ser un número';
    if (n < 0) return 'No puede ser negativo';
    return null;
  }

  Widget _tarjetaCategoria(CategoriaBodega categoria) {
    final seleccionada = _categoriaId == categoria.id;
    final colores = colorCategoriaBodega(categoria.nombre);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => setState(() => _categoriaId = categoria.id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: seleccionada
                ? AppTheme.primaryContainer.withValues(alpha: 0.12)
                : AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: seleccionada ? AppTheme.primaryContainer : AppTheme.outlineVariant,
              width: seleccionada ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: colores.fondo,
                child: Icon(iconoCategoriaBodega(categoria.nombre),
                    color: colores.icono, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(categoria.nombre,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(etiquetaCategoriaBodega(categoria.nombre),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.outline)),
                  ],
                ),
              ),
              if (seleccionada)
                const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final stockMinimo = double.tryParse(_stockMinimoCtrl.text.trim());
    final alertaActiva = stockMinimo != null && stockMinimo > 0;
    final categoria = _categoriaSeleccionada;
    final coloresPreview = colorCategoriaBodega(categoria?.nombre);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Insumo')),
      body: _cargandoCategorias
          ? const Center(child: CircularProgressIndicator())
          : _errorCategorias != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorCategorias!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _cargarCategorias,
                            child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Categoría de Bodega', style: textTheme.labelLarge),
                      const SizedBox(height: 8),
                      ..._categorias.map(_tarjetaCategoria),
                      const SizedBox(height: 8),
                      Text('Identificación del Insumo', style: textTheme.labelLarge),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Nombre Comercial / Producto'),
                        textCapitalization: TextCapitalization.sentences,
                        validator: (valor) => (valor == null || valor.trim().isEmpty)
                            ? 'El nombre es obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descripcionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Descripción / Composición (opcional)',
                          hintText: 'Ej. Frasco multidosis, maíz amarillo + torta de soya',
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _unidadMedida,
                        decoration:
                            const InputDecoration(labelText: 'Presentación / Unidad de medida'),
                        items: _unidadesValidas
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (valor) => setState(() => _unidadMedida = valor),
                      ),
                      const SizedBox(height: 20),
                      Text('Gestión de Stock y Alertas', style: textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Column(
                          children: [
                            Text('Stock Inicial en Bodega', style: textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton.filledTonal(
                                  onPressed: () => _ajustarStockInicial(-1),
                                  icon: const Icon(Icons.remove),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: Column(
                                    children: [
                                      Text(_stockInicial.toStringAsFixed(0),
                                          style: textTheme.headlineMedium),
                                      Text(
                                        _unidadMedida ?? 'unidades',
                                        style: textTheme.bodySmall
                                            ?.copyWith(color: AppTheme.outline),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton.filledTonal(
                                  onPressed: () => _ajustarStockInicial(1),
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              alignment: WrapAlignment.center,
                              children: [5, 10, 20, 50]
                                  .map((atajo) => ActionChip(
                                        label: Text('+$atajo'),
                                        onPressed: () =>
                                            _ajustarStockInicial(atajo.toDouble()),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _stockMinimoCtrl,
                        decoration: InputDecoration(
                          labelText: 'Stock Mínimo de Alerta (Punto de Reorden)',
                          suffixIcon: alertaActiva
                              ? const Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: Center(
                                    widthFactor: 1,
                                    child: _BadgeAlertaActiva(),
                                  ),
                                )
                              : null,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _validarNumeroNoNegativo,
                        onChanged: (_) => setState(() {}),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Cuando el stock disponible llegue a este nivel, el insumo se marcará como "Stock Bajo" en el listado.',
                          style: textTheme.bodySmall?.copyWith(color: AppTheme.outline),
                        ),
                      ),
                      if (_nombreCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text('Vista previa en Bodega', style: textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: coloresPreview.fondo,
                                child: Icon(iconoCategoriaBodega(categoria?.nombre),
                                    color: coloresPreview.icono, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_nombreCtrl.text.trim(),
                                        style: textTheme.titleSmall),
                                    if (_descripcionCtrl.text.trim().isNotEmpty)
                                      Text(_descripcionCtrl.text.trim(),
                                          style: textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              Text(
                                '${_stockInicial.toStringAsFixed(0)} ${_unidadMedida ?? ''}',
                                style: textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
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
                        label: const Text('Guardar en Catálogo de Insumos'),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                          child: const Text('Cancelar y Volver'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _BadgeAlertaActiva extends StatelessWidget {
  const _BadgeAlertaActiva();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.tertiaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        'Alerta Activa',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppTheme.tertiary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
