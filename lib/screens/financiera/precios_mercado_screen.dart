import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/financiera/precio_mercado.dart';
import '../../repositories/financiera/financiera_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato_cop.dart';
import 'precio_form_screen.dart';

/// Pantalla "Precios de mercado" del módulo Financiera.
///
/// Muestra el historial de precios de Leche y Huevos (los únicos productos
/// con precio en la app; los precios de otros productos que pudieran existir
/// en la base de datos se ocultan, decisión de Dany 2026-11-23), ordenado
/// por fecha descendente. El precio más reciente de cada producto lleva la
/// pastilla "Vigente" (desempate por id, igual que en la web). Permite
/// registrar, editar y eliminar (con confirmación).
class PreciosMercadoScreen extends StatefulWidget {
  final FinancieraRepository repository;

  /// Mes seleccionado en la pantalla de Financiera: limita las fechas que
  /// se pueden elegir al registrar o editar un precio.
  final DateTime mes;

  const PreciosMercadoScreen({
    super.key,
    required this.repository,
    required this.mes,
  });

  @override
  State<PreciosMercadoScreen> createState() => _PreciosMercadoScreenState();
}

class _PreciosMercadoScreenState extends State<PreciosMercadoScreen> {
  bool _cargando = true;
  String? _error;
  List<PrecioMercado> _precios = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final lista = await widget.repository.listarPrecios();
      if (!mounted) return;
      setState(() {
        _precios = lista;
        _cargando = false;
        _error = null;
      });
    } on ApiException catch (e) {
      _falloCarga(e.message);
    } on NetworkException catch (e) {
      _falloCarga(e.message);
    }
  }

  void _falloCarga(String mensaje) {
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = mensaje;
    });
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // ── Datos a mostrar ───────────────────────────────────────────────────

  static String? _clave(String producto) {
    final p = producto.toLowerCase();
    if (p.contains('leche')) return 'leche';
    if (p.contains('huevo')) return 'huevo';
    return null;
  }

  /// Solo Leche y Huevos, de la fecha más reciente a la más antigua
  /// (desempate por id, el más nuevo primero).
  List<PrecioMercado> get _visibles {
    final lista = _precios.where((p) => _clave(p.producto) != null).toList();
    lista.sort((a, b) {
      final porFecha = b.fecha.compareTo(a.fecha);
      return porFecha != 0 ? porFecha : b.id.compareTo(a.id);
    });
    return lista;
  }

  /// Ids de los precios vigentes: el primero de cada producto en la lista
  /// ya ordenada.
  Set<int> _idsVigentes(List<PrecioMercado> ordenados) {
    final vistos = <String>{};
    final ids = <int>{};
    for (final p in ordenados) {
      final clave = _clave(p.producto)!;
      if (vistos.add(clave)) ids.add(p.id);
    }
    return ids;
  }

  // ── Acciones ──────────────────────────────────────────────────────────

  Future<void> _abrirFormulario([PrecioMercado? precio]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PrecioFormScreen(
          repository: widget.repository,
          mes: widget.mes,
          precio: precio,
        ),
      ),
    );
    if (guardado == true) {
      _mensaje(precio == null ? 'Precio registrado' : 'Precio actualizado');
      await _cargar(silencioso: true);
    }
  }

  Future<void> _eliminar(PrecioMercado p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar precio'),
        content: Text(
            '¿Eliminar el precio de ${p.producto} (${FormatoCOP.pesos(p.precio)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repository.eliminarPrecio(p.id);
      _mensaje('Precio eliminado');
      await _cargar(silencioso: true);
    } on ApiException catch (e) {
      _mensaje(e.message);
    } on NetworkException catch (e) {
      _mensaje(e.message);
    }
  }

  // ── Pantalla ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Precios de mercado')),
      body: _cuerpo(),
      floatingActionButton: (_cargando || _error != null)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo precio'),
            ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _cargar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final lista = _visibles;
    final vigentes = _idsVigentes(lista);
    return RefreshIndicator(
      onRefresh: () => _cargar(silencioso: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              children: [
                const Flexible(
                  child: Text('Precios registrados',
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text('${lista.length}',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Precios de referencia de Leche y Huevos. El más reciente de cada producto es el vigente.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.outline),
            ),
          ),
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No hay precios registrados',
                    style: TextStyle(color: AppTheme.outline)),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Column(
                children: [
                  for (var i = 0; i < lista.length; i++)
                    _filaPrecio(lista[i], vigentes.contains(lista[i].id),
                        resaltada: i.isEven),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _filaPrecio(PrecioMercado p, bool vigente, {required bool resaltada}) {
    final esLeche = _clave(p.producto) == 'leche';
    final unidad = FormatoCOP.unidadDeProducto(p.producto);
    return Container(
      color: resaltada
          ? AppTheme.surfaceContainerLow
          : AppTheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppTheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              esLeche ? Icons.water_drop_outlined : Icons.egg_outlined,
              color: AppTheme.onSecondaryContainer,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(p.producto,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ),
                    if (vigente) ...[
                      const SizedBox(width: 8),
                      _pastillaVigente(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.history,
                        size: 14, color: AppTheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Actualizado: ${DateFormat('d MMM', 'es').format(p.fecha)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(FormatoCOP.pesos(p.precio),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              if (unidad.isNotEmpty)
                Text('/ $unidad',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(width: 4),
          Column(
            children: [
              IconButton(
                tooltip: 'Editar',
                visualDensity: VisualDensity.compact,
                onPressed: () => _abrirFormulario(p),
                icon: const Icon(Icons.edit_outlined,
                    size: 20, color: AppTheme.onSurfaceVariant),
              ),
              IconButton(
                tooltip: 'Eliminar',
                visualDensity: VisualDensity.compact,
                onPressed: () => _eliminar(p),
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppTheme.tertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pastillaVigente() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: const Text('Vigente',
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary)),
    );
  }
}
