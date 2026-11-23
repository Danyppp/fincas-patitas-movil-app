import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/financiera/producto_stock.dart';
import '../../models/inventario/movimiento_stock.dart';
import '../../repositories/inventario/stock_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato_cop.dart';
import '../financiera/widgets_formulario.dart';
import 'ajuste_stock_screen.dart';

/// Productos de finca (Huevos y Leche) dentro de Inventario.
///
/// Muestra el stock actual de cada producto y el historial de movimientos
/// (producción, ventas y ajustes manuales). El stock lo mueve el backend:
/// sube con la producción, baja con las ventas, y aquí además se puede
/// ajustar a mano (por ejemplo, para cargar el stock inicial).
class ProductosFincaScreen extends StatefulWidget {
  final StockRepository repository;

  const ProductosFincaScreen({super.key, required this.repository});

  @override
  State<ProductosFincaScreen> createState() => _ProductosFincaScreenState();
}

class _ProductosFincaScreenState extends State<ProductosFincaScreen> {
  bool _cargando = true;
  String? _error;
  List<ProductoStock> _stock = [];
  List<MovimientoStock> _movimientos = [];
  String? _filtro; // null = todos; 'Huevos' | 'Leche'

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final stock = await widget.repository.listarStock();
      final movimientos =
          await widget.repository.listarMovimientos(producto: _filtro);
      if (!mounted) return;
      setState(() {
        _stock = stock;
        _movimientos = movimientos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  Future<void> _abrirAjuste() async {
    final ajustado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AjusteStockScreen(
          repository: widget.repository,
          stock: _stock,
          productoInicial: _filtro,
        ),
      ),
    );
    if (ajustado == true) _cargar();
  }

  double _stockDe(String nombre) {
    for (final p in _stock) {
      if (p.nombre == nombre) return p.stockActual;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos de finca'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _TarjetaStock(
                              icono: Icons.egg_outlined,
                              nombre: 'Huevos',
                              valor: _stockDe('Huevos'),
                              unidad: 'unidades',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TarjetaStock(
                              icono: Icons.local_drink_outlined,
                              nombre: 'Leche',
                              valor: _stockDe('Leche'),
                              unidad: 'litros',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text('Historial de movimientos',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          FormChip(
                            texto: 'Todos',
                            seleccionado: _filtro == null,
                            onTap: () {
                              setState(() => _filtro = null);
                              _cargar();
                            },
                          ),
                          FormChip(
                            texto: 'Huevos',
                            icono: Icons.egg_outlined,
                            seleccionado: _filtro == 'Huevos',
                            onTap: () {
                              setState(() => _filtro = 'Huevos');
                              _cargar();
                            },
                          ),
                          FormChip(
                            texto: 'Leche',
                            icono: Icons.local_drink_outlined,
                            seleccionado: _filtro == 'Leche',
                            onTap: () {
                              setState(() => _filtro = 'Leche');
                              _cargar();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_movimientos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                              child: Text('Aún no hay movimientos de stock.')),
                        )
                      else
                        for (final m in _movimientos)
                          _TileMovimiento(movimiento: m),
                    ],
                  ),
                ),
      floatingActionButton: SizedBox(
        height: 40,
        child: FloatingActionButton.extended(
          onPressed: _cargando ? null : _abrirAjuste,
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Ajustar stock', style: TextStyle(fontSize: 13)),
          extendedPadding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}

class _TarjetaStock extends StatelessWidget {
  final IconData icono;
  final String nombre;
  final double valor;
  final String unidad;

  const _TarjetaStock({
    required this.icono,
    required this.nombre,
    required this.valor,
    required this.unidad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 20, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(nombre,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(FormatoCOP.cantidad(valor),
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary)),
          Text(unidad,
              style: const TextStyle(fontSize: 12, color: AppTheme.outline)),
        ],
      ),
    );
  }
}

class _TileMovimiento extends StatelessWidget {
  final MovimientoStock movimiento;

  const _TileMovimiento({required this.movimiento});

  @override
  Widget build(BuildContext context) {
    final m = movimiento;
    // Entrada siempre suma y Salida siempre resta, sin importar cómo venga
    // guardado el signo; el Ajuste conserva el signo que se le puso.
    final valor = m.tipo == 'Entrada'
        ? m.cantidad.abs()
        : m.tipo == 'Salida'
            ? -m.cantidad.abs()
            : m.cantidad;
    final suma = valor > 0;
    final color = suma ? AppTheme.primary : AppTheme.tertiary;
    final signo = suma ? '+' : '';
    final unidad = FormatoCOP.unidadDeProducto(m.producto);
    final fecha = DateFormat('d MMM yyyy, h:mm a', 'es').format(m.fecha);
    final detalle = <String>[
      m.producto,
      if (m.motivo != null && m.motivo!.isNotEmpty) m.motivo!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(suma ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.origenTexto,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                  Text(detalle,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                  Text(m.usuario == null ? fecha : '$fecha · ${m.usuario}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppTheme.outline)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('$signo${FormatoCOP.cantidad(valor)} $unidad',
                style: TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
