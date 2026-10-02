import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../repositories/produccion/produccion_repository.dart';
import '../../theme/app_theme.dart';
import 'produccion_detalle_dialog.dart';

/// Pantalla de "Historial completo" (punto 2 del reporte de pruebas,
/// 2026-10-02) — separada del Dashboard (que solo muestra "hoy"). Trae
/// TODOS los registros (incluyendo los eliminados lógicamente, para poder
/// mostrarlos marcados) con `incluir_eliminados=true`, y el rango de
/// fechas se filtra en el cliente — mismo patrón que ya se usa en el
/// Dashboard para "hoy".
class ProduccionHistorialScreen extends StatefulWidget {
  final ProduccionRepository repository;

  const ProduccionHistorialScreen({super.key, required this.repository});

  @override
  State<ProduccionHistorialScreen> createState() =>
      _ProduccionHistorialScreenState();
}

class _ProduccionHistorialScreenState extends State<ProduccionHistorialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _cargando = true;
  String? _error;
  List<ProduccionLeche> _todaLeche = [];
  List<ProduccionHuevos> _todosHuevos = [];
  DateTimeRange? _rango;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final leche =
          await widget.repository.listarLeche(incluirEliminados: true);
      final huevos =
          await widget.repository.listarHuevos(incluirEliminados: true);
      setState(() {
        _todaLeche = leche;
        _todosHuevos = huevos;
      });
    } catch (e) {
      setState(() => _error = 'No se pudo cargar el historial: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  bool _enRango(DateTime fecha) {
    if (_rango == null) return true;
    final local = fecha.toLocal();
    final dia = DateTime(local.year, local.month, local.day);
    final desde =
        DateTime(_rango!.start.year, _rango!.start.month, _rango!.start.day);
    final hasta =
        DateTime(_rango!.end.year, _rango!.end.month, _rango!.end.day);
    return !dia.isBefore(desde) && !dia.isAfter(hasta);
  }

  Future<void> _elegirRango() async {
    final ahora = DateTime.now();
    final elegido = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year - 2),
      lastDate: ahora,
      initialDateRange: _rango,
      helpText: 'Selecciona el rango de fechas',
    );
    if (elegido != null) setState(() => _rango = elegido);
  }

  @override
  Widget build(BuildContext context) {
    final formatoRango = DateFormat('d MMM yyyy', 'es');
    String textoRango;
    try {
      textoRango = _rango == null
          ? 'Todo el historial'
          : '${formatoRango.format(_rango!.start)} - ${formatoRango.format(_rango!.end)}';
    } catch (_) {
      // Si la data de locale 'es' no está inicializada en main.dart, cae a
      // un formato neutro en vez de reventar la pantalla.
      final f = DateFormat('yyyy-MM-dd');
      textoRango = _rango == null
          ? 'Todo el historial'
          : '${f.format(_rango!.start)} a ${f.format(_rango!.end)}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial completo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.water_drop_outlined), text: 'Leche'),
            Tab(icon: Icon(Icons.egg_outlined), text: 'Huevos'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _elegirRango,
                    icon: const Icon(Icons.date_range),
                    label: Text(textoRango, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (_rango != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Quitar filtro',
                    onPressed: () => setState(() => _rango = null),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, textAlign: TextAlign.center))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _ListaHistorialLeche(
                            registros: _todaLeche
                                .where((r) => _enRango(r.registradoEn))
                                .toList(),
                          ),
                          _ListaHistorialHuevos(
                            registros: _todosHuevos
                                .where((r) => _enRango(r.registradoEn))
                                .toList(),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _ChipEliminado extends StatelessWidget {
  final DateTime eliminadoEn;
  final String? eliminadoPorNombre;

  const _ChipEliminado({required this.eliminadoEn, this.eliminadoPorNombre});

  @override
  Widget build(BuildContext context) {
    final formato = DateFormat('yyyy-MM-dd');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Eliminado el ${formato.format(eliminadoEn.toLocal())} · ${eliminadoPorNombre ?? 'desconocido'}',
        style: TextStyle(
            color: Colors.red[700], fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ListaHistorialLeche extends StatelessWidget {
  final List<ProduccionLeche> registros;

  const _ListaHistorialLeche({required this.registros});

  @override
  Widget build(BuildContext context) {
    if (registros.isEmpty) {
      return const Center(child: Text('Sin registros de leche en este rango.'));
    }
    final formato = DateFormat('yyyy-MM-dd HH:mm');
    final ordenados = [...registros]
      ..sort((a, b) => b.registradoEn.compareTo(a.registradoEn));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ordenados.length,
      itemBuilder: (context, i) {
        final r = ordenados[i];
        final origen = r.esPorLote
            ? (r.loteNombre ?? 'Lote #${r.loteId}')
            : (r.animal?.nombreVisible ?? 'Animal #${r.animalId}');
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: r.estaEliminado ? AppTheme.surfaceContainerHigh : null,
          child: ListTile(
            onTap: () => mostrarDetalleLeche(context, r),
            leading: Icon(
              r.esPorLote ? Icons.groups : Icons.pets,
              color:
                  r.estaEliminado ? AppTheme.outline : const Color(0xFF3F6B4A),
            ),
            title: Text(
              '${r.litros} L · $origen',
              style: r.estaEliminado
                  ? const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: AppTheme.outline)
                  : null,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${r.jornada ?? 'Sin jornada'} · ${formato.format(r.registradoEn.toLocal())}'),
                if (r.estaEliminado)
                  _ChipEliminado(
                      eliminadoEn: r.eliminadoEn!,
                      eliminadoPorNombre: r.eliminadoPorNombre),
              ],
            ),
            // Indica que la fila se puede tocar para ver el detalle
            // (2026-10-02: antes no había ninguna señal visual de esto).
            trailing: const Icon(Icons.chevron_right, color: AppTheme.outline),
            isThreeLine: r.estaEliminado,
          ),
        );
      },
    );
  }
}

class _ListaHistorialHuevos extends StatelessWidget {
  final List<ProduccionHuevos> registros;

  const _ListaHistorialHuevos({required this.registros});

  @override
  Widget build(BuildContext context) {
    if (registros.isEmpty) {
      return const Center(
          child: Text('Sin registros de huevos en este rango.'));
    }
    final formato = DateFormat('yyyy-MM-dd HH:mm');
    final ordenados = [...registros]
      ..sort((a, b) => b.registradoEn.compareTo(a.registradoEn));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: ordenados.length,
      itemBuilder: (context, i) {
        final r = ordenados[i];
        final origen = r.esPorLote
            ? (r.loteNombre ?? 'Lote #${r.loteId}')
            : (r.animalId != null
                ? (r.animal?.nombreVisible ?? 'Animal #${r.animalId}')
                : null);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: r.estaEliminado ? AppTheme.surfaceContainerHigh : null,
          child: ListTile(
            onTap: () => mostrarDetalleHuevos(context, r),
            leading: Icon(
              r.esPorLote ? Icons.groups : Icons.egg,
              color:
                  r.estaEliminado ? AppTheme.outline : const Color(0xFF3F6B4A),
            ),
            title: Text(
              r.cantidadRotos > 0
                  ? '${r.cantidad} huevos (${r.cantidadRotos} rotos)'
                  : '${r.cantidad} huevos',
              style: r.estaEliminado
                  ? const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: AppTheme.outline)
                  : null,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${origen != null ? '$origen · ' : ''}${formato.format(r.registradoEn.toLocal())}'),
                if (r.estaEliminado)
                  _ChipEliminado(
                      eliminadoEn: r.eliminadoEn!,
                      eliminadoPorNombre: r.eliminadoPorNombre),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.outline),
            isThreeLine: r.estaEliminado,
          ),
        );
      },
    );
  }
}
