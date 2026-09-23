import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/inventario/categoria_bodega.dart';
import '../../models/inventario/insumo.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/inventario/insumo_repository.dart';
import 'movimiento_form_screen.dart';

/// Listado de Inventario (Control de Inventario). Primera versión
/// funcional, sin ronda de estilos todavía (eso va en el paso 6, igual
/// que se hizo con Animales) — el objetivo acá es que todo el flujo de
/// datos real contra el backend funcione: categorías, búsqueda local,
/// estados de stock derivados y vencimiento por insumo.
class InventarioListScreen extends StatefulWidget {
  final InsumoRepository repository;
  final CatalogoRepository catalogoRepository;

  const InventarioListScreen({
    super.key,
    required this.repository,
    required this.catalogoRepository,
  });

  @override
  State<InventarioListScreen> createState() => _InventarioListScreenState();
}

class _InventarioListScreenState extends State<InventarioListScreen> {
  final _buscarCtrl = TextEditingController();
  int? _categoriaFiltroId; // null = "Todos"

  bool _cargando = true;
  String? _error;
  List<Insumo> _insumos = [];
  List<CategoriaBodega> _categorias = [];

  /// Vencimiento más próximo por insumo (segunda consulta, una vez
  /// cargado el listado principal — mismo patrón que la genealogía en
  /// Animales). `null` si el insumo no tiene ningún lote registrado.
  final Map<int, DateTime?> _vencimientoPorInsumo = {};

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    _cargar();
  }

  Future<void> _cargarCategorias() async {
    try {
      final categorias = await widget.catalogoRepository.listarCategoriasBodega();
      if (!mounted) return;
      setState(() => _categorias = categorias);
    } catch (_) {
      // silencioso: los chips de categoría no son críticos para listar.
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final insumos = await widget.repository.listar(categoriaId: _categoriaFiltroId);
      if (!mounted) return;
      setState(() {
        _insumos = insumos;
        _cargando = false;
      });
      _cargarVencimientos(insumos);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  /// Trae el lote de vencimiento más próximo de cada insumo, en paralelo.
  /// Si una consulta individual falla, ese insumo simplemente no muestra
  /// vencimiento — no bloquea el resto del listado.
  Future<void> _cargarVencimientos(List<Insumo> insumos) async {
    await Future.wait(insumos.map((insumo) async {
      try {
        final lotes = await widget.catalogoRepository
            .listarLotesInventario(insumoId: insumo.id);
        if (!mounted) return;
        setState(() {
          _vencimientoPorInsumo[insumo.id] =
              lotes.isNotEmpty ? lotes.first.fechaVencimiento : null;
        });
      } catch (_) {
        // silencioso: no crítico para el listado principal.
      }
    }));
  }

  /// Filtro de búsqueda local (el backend no soporta `?buscar=` en
  /// `/bodega`) sobre la lista ya cargada con el filtro de categoría.
  List<Insumo> get _insumosFiltrados {
    final termino = _buscarCtrl.text.trim().toLowerCase();
    if (termino.isEmpty) return _insumos;
    return _insumos.where((i) => i.nombre.toLowerCase().contains(termino)).toList();
  }

  int get _totalItems => _insumos.length;
  int get _totalStockBajo => _insumos.where((i) => i.stockBajo).length;
  int get _totalEnNivel => _totalItems - _totalStockBajo;

  /// Igual que en el diseño original: tocar la tarjeta de un insumo lleva
  /// directo al registro de movimiento para ese insumo (no hay pantalla
  /// de detalle aparte en Inventario). Si se registró algo, se recarga
  /// el listado para reflejar el stock nuevo.
  Future<void> _abrirRegistroMovimiento(Insumo insumo) async {
    final registrado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MovimientoFormScreen(
          insumo: insumo,
          repository: widget.repository,
        ),
      ),
    );
    if (registrado == true) _cargar();
  }

  // La búsqueda es 100% local (no llama al backend), así que se filtra al
  // instante con cada letra — no hace falta debounce aquí.
  void _onBuscarCambia(String _) => setState(() {});

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Widget _chip({
    required String etiqueta,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(etiqueta),
      selected: seleccionado,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _estadisticaTile(String etiqueta, int valor) {
    return Expanded(
      child: Column(
        children: [
          Text('$valor', style: Theme.of(context).textTheme.headlineSmall),
          Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                TextField(
                  controller: _buscarCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Buscar insumo...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: _onBuscarCambia,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip(
                        etiqueta: 'Todos',
                        seleccionado: _categoriaFiltroId == null,
                        onTap: () {
                          setState(() => _categoriaFiltroId = null);
                          _cargar();
                        },
                      ),
                      for (final categoria in _categorias) ...[
                        const SizedBox(width: 8),
                        _chip(
                          etiqueta: categoria.nombre,
                          seleccionado: _categoriaFiltroId == categoria.id,
                          onTap: () {
                            setState(() => _categoriaFiltroId = categoria.id);
                            _cargar();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(mensaje: _error!, onReintentar: _cargar)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          _estadisticaTile('Total ítems', _totalItems),
                          _estadisticaTile('Stock bajo', _totalStockBajo),
                          _estadisticaTile('En nivel', _totalEnNivel),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _insumosFiltrados.isEmpty
                          ? const Center(child: Text('No hay insumos que coincidan.'))
                          : RefreshIndicator(
                              onRefresh: _cargar,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _insumosFiltrados.length,
                                itemBuilder: (context, i) {
                                  final insumo = _insumosFiltrados[i];
                                  return _InsumoTile(
                                    insumo: insumo,
                                    vencimiento: _vencimientoPorInsumo[insumo.id],
                                    onTap: () => _abrirRegistroMovimiento(insumo),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _InsumoTile extends StatelessWidget {
  final Insumo insumo;
  final DateTime? vencimiento;
  final VoidCallback onTap;

  const _InsumoTile({required this.insumo, required this.onTap, this.vencimiento});

  ({Color fondo, Color texto, String etiqueta}) get _estiloEstado {
    switch (insumo.estado) {
      case EstadoStock.agotado:
        return (fondo: Colors.red.withValues(alpha: 0.12), texto: Colors.red.shade700, etiqueta: 'Agotado');
      case EstadoStock.bajo:
        return (fondo: Colors.orange.withValues(alpha: 0.15), texto: Colors.orange.shade800, etiqueta: 'Bajo');
      case EstadoStock.normal:
        return (fondo: Colors.green.withValues(alpha: 0.12), texto: Colors.green.shade700, etiqueta: 'Normal');
    }
  }

  @override
  Widget build(BuildContext context) {
    final estilo = _estiloEstado;
    final textTheme = Theme.of(context).textTheme;
    final subtitulo = insumo.descripcion != null && insumo.descripcion!.isNotEmpty
        ? '${insumo.categoria?.nombre ?? ''} • ${insumo.descripcion}'
        : insumo.categoria?.nombre ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(insumo.nombre, style: textTheme.titleMedium),
                      if (subtitulo.isNotEmpty)
                        Text(subtitulo, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: estilo.fondo,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    estilo.etiqueta,
                    style: textTheme.labelMedium?.copyWith(color: estilo.texto),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Stock: ${insumo.stockActual.toStringAsFixed(0)} ${insumo.unidadMedida}'),
                const SizedBox(width: 12),
                Text('Mínimo: ${insumo.stockMinimo.toStringAsFixed(0)}',
                    style: textTheme.bodySmall),
              ],
            ),
            if (vencimiento != null) ...[
              const SizedBox(height: 4),
              Text(
                'Vence: ${DateFormat('dd/MM/yyyy', 'es').format(vencimiento!)}',
                style: textTheme.bodySmall,
              ),
            ],
            if (insumo.reposicionUrgente) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 4),
                  Text('Reposición urgente',
                      style: textTheme.labelSmall?.copyWith(color: Colors.red.shade700)),
                ],
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _ErrorState({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
