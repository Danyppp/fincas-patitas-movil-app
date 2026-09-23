import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/auth_session.dart';
import '../../models/inventario/categoria_bodega.dart';
import '../../models/inventario/insumo.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/inventario/insumo_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/categoria_visual.dart';
import 'movimiento_form_screen.dart';

/// Listado de Inventario (Control de Inventario), siguiendo el mockup de
/// Stitch (`inventario_y_stock_de_bodega_fincas_y_patitas/screen.png`):
/// estadísticas resumen, chips de categoría con ícono, tarjetas con
/// avatar por categoría, pill de estado, barra de stock cuando está bajo,
/// y vencimiento por insumo (segunda consulta, igual que la genealogía
/// en Animales).
class InventarioListScreen extends StatefulWidget {
  final InsumoRepository repository;
  final CatalogoRepository catalogoRepository;
  final AuthSession session;

  const InventarioListScreen({
    super.key,
    required this.repository,
    required this.catalogoRepository,
    required this.session,
  });

  @override
  State<InventarioListScreen> createState() => _InventarioListScreenState();
}

class _InventarioListScreenState extends State<InventarioListScreen> {
  final _buscarCtrl = TextEditingController();
  int? _categoriaFiltroId; // null = "Todos"
  Timer? _debounceBusqueda;

  bool _cargando = true;
  // Búsqueda 100% local e instantánea (ver `_onBuscarCambia`), pero se
  // muestra este breve "recargando" para que la experiencia visual sea
  // igual que en Animales (donde sí espera una respuesta del backend).
  bool _buscando = false;
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
          session: widget.session,
        ),
      ),
    );
    if (registrado == true) _cargar();
  }

  /// El filtrado en sí es local e instantáneo (el backend no soporta
  /// `?buscar=` en `/bodega`), pero se replica el mismo debounce visual de
  /// 400ms que usa Animales, para que la sensación de "recargando" sea
  /// consistente entre módulos aunque acá no haya una petición real.
  void _onBuscarCambia(String _) {
    _debounceBusqueda?.cancel();
    setState(() => _buscando = true);
    _debounceBusqueda = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _buscando = false);
    });
  }

  @override
  void dispose() {
    _debounceBusqueda?.cancel();
    _buscarCtrl.dispose();
    super.dispose();
  }

  Widget _chipCategoria({
    required String etiqueta,
    required IconData icono,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      avatar: Icon(icono, size: 16, color: seleccionado ? AppTheme.onPrimary : AppTheme.onSurface),
      label: Text(etiqueta),
      selected: seleccionado,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(color: seleccionado ? AppTheme.onPrimary : AppTheme.onSurface),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _estadisticaTile(String etiqueta, int valor, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        ),
        child: Column(
          children: [
            Text('$valor',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // El título ocupa 2 líneas ("BODEGA PRINCIPAL" + "Control de
        // Inventario"), y el alto por defecto del AppBar (56) solo alcanza
        // para una — por eso la primera línea se veía cortada arriba. Se
        // sube el alto para que el título quepa completo y con aire.
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('BODEGA PRINCIPAL',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w800)),
            const Text('Control de Inventario'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(148),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    _estadisticaTile('Total Ítems', _totalItems, AppTheme.onSurface),
                    _estadisticaTile('Stock Bajo', _totalStockBajo, AppTheme.tertiary),
                    _estadisticaTile('En Nivel', _totalEnNivel, AppTheme.secondary),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _buscarCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar insumo...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                      borderSide: BorderSide(color: AppTheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                      borderSide: BorderSide(color: AppTheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryContainer, width: 2),
                    ),
                  ),
                  onChanged: _onBuscarCambia,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chipCategoria(
                        etiqueta: 'Todos',
                        icono: Icons.grid_view_rounded,
                        seleccionado: _categoriaFiltroId == null,
                        onTap: () {
                          setState(() => _categoriaFiltroId = null);
                          _cargar();
                        },
                      ),
                      for (final categoria in _categorias) ...[
                        const SizedBox(width: 8),
                        _chipCategoria(
                          etiqueta: categoria.nombre,
                          icono: iconoCategoriaBodega(categoria.nombre),
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
      body: _cargando || _buscando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(mensaje: _error!, onReintentar: _cargar)
              : _insumosFiltrados.isEmpty
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
    );
  }
}

class _InsumoTile extends StatelessWidget {
  final Insumo insumo;
  final DateTime? vencimiento;
  final VoidCallback onTap;

  const _InsumoTile({required this.insumo, required this.onTap, this.vencimiento});

  @override
  Widget build(BuildContext context) {
    final agotado = insumo.estado == EstadoStock.agotado;
    final bajo = insumo.estado == EstadoStock.bajo;
    final estilo = estiloEstadoStock(agotado, bajo);
    final coloresCategoria = colorCategoriaBodega(insumo.categoria?.nombre);
    final textTheme = Theme.of(context).textTheme;

    // Barra de nivel de stock: solo se muestra cuando el stock ya está en
    // Bajo o Agotado (igual que en el diseño), como referencia visual de
    // qué tan cerca está del mínimo configurado.
    final proporcion = insumo.stockMinimo > 0
        ? (insumo.stockActual / (insumo.stockMinimo * 2)).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: coloresCategoria.fondo,
                    child: Icon(iconoCategoriaBodega(insumo.categoria?.nombre),
                        color: coloresCategoria.icono, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(insumo.nombre, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (insumo.descripcion != null && insumo.descripcion!.isNotEmpty)
                          Text(insumo.descripcion!, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: estilo.fondo,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(estilo.etiqueta,
                        style: textTheme.labelMedium?.copyWith(color: estilo.texto)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stock Disponible', style: textTheme.labelSmall),
                        Text('${insumo.stockActual.toStringAsFixed(0)} ${insumo.unidadMedida}',
                            style: textTheme.headlineSmall?.copyWith(
                              color: agotado || bajo ? estilo.texto : AppTheme.onSurface,
                            )),
                      ],
                    ),
                  ),
                  if (vencimiento != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Vencimiento', style: textTheme.labelSmall),
                        Row(
                          children: [
                            const Icon(Icons.event_outlined, size: 14, color: AppTheme.outline),
                            const SizedBox(width: 4),
                            Text(DateFormat('MM/yyyy').format(vencimiento!),
                                style: textTheme.bodyMedium),
                          ],
                        ),
                      ],
                    )
                  else
                    Text('Mínimo: ${insumo.stockMinimo.toStringAsFixed(0)}',
                        style: textTheme.bodySmall),
                ],
              ),
              if (bajo || agotado) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  child: LinearProgressIndicator(
                    value: proporcion,
                    minHeight: 6,
                    backgroundColor: AppTheme.surfaceContainerHigh,
                    color: estilo.texto,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      insumo.categoria?.nombre ?? 'Sin categoría',
                      style: textTheme.labelSmall?.copyWith(color: AppTheme.onSurface, letterSpacing: 0),
                    ),
                  ),
                  if (insumo.reposicionUrgente)
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.tertiary),
                        const SizedBox(width: 4),
                        Text('Reposición urgente',
                            style: textTheme.labelSmall?.copyWith(color: AppTheme.tertiary)),
                      ],
                    ),
                ],
              ),
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
