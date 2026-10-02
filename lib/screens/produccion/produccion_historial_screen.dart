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
///
/// 2026-10-02 (ajuste de estilos, última ronda): la `TabBar` de Leche/
/// Huevos se reemplaza por los mismos bloques seleccionables (ícono +
/// unidad + check) que ya se usan en "Registrar Producción Nueva", para que
/// toda la sección de Producción se vea consistente. Las filas del
/// historial pasan de ser tarjetas separadas a una lista continua con
/// fondo alternado rosita/blanco — igual estética que el "Historial
/// reciente" del Dashboard, pero SIN el efecto de hover: aquí el color de
/// cada fila es fijo, no cambia al pasar el cursor (pedido explícito del
/// usuario, para diferenciar esta vista de la del Dashboard).
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
    final tabIndex = _tabController.index;
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
      appBar: AppBar(title: const Text('Historial completo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _BloqueTipoProduccion(
                    icono: Icons.water_drop,
                    etiqueta: 'Leche',
                    unidad: 'Litros (L)',
                    seleccionado: tabIndex == 0,
                    onTap: () => _tabController.animateTo(0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BloqueTipoProduccion(
                    icono: Icons.egg,
                    etiqueta: 'Huevos',
                    unidad: 'Unidades',
                    seleccionado: tabIndex == 1,
                    onTap: () => _tabController.animateTo(1),
                  ),
                ),
              ],
            ),
          ),
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

/// Bloque seleccionable de "Tipo de producción" — idéntico en espíritu al
/// de `produccion_list_screen.dart` (ícono + unidad + check, piel sin
/// seleccionar / verde seleccionado); se duplica a propósito porque es una
/// pantalla independiente.
class _BloqueTipoProduccion extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String unidad;
  final bool seleccionado;
  final VoidCallback onTap;

  const _BloqueTipoProduccion({
    required this.icono,
    required this.etiqueta,
    required this.unidad,
    required this.seleccionado,
    required this.onTap,
  });

  static const _pielFondo = Color(0xFFF6DFCB);
  static const _pielIcono = Color(0xFFB9784A);
  static const _pielBorde = Color(0xFFEAD0B4);

  @override
  Widget build(BuildContext context) {
    final colorFondoIcono = seleccionado
        ? AppTheme.primaryContainer.withValues(alpha: 0.5)
        : _pielFondo;
    final colorIcono = seleccionado ? AppTheme.primary : _pielIcono;
    final colorBorde = seleccionado ? AppTheme.primary : _pielBorde;

    return Material(
      color: seleccionado
          ? AppTheme.primaryContainer.withValues(alpha: 0.12)
          : Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: colorBorde, width: seleccionado ? 2 : 1),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: colorFondoIcono, shape: BoxShape.circle),
                    child: Icon(icono, color: colorIcono, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(etiqueta,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(unidad,
                      style: TextStyle(color: AppTheme.outline, fontSize: 12)),
                ],
              ),
              if (seleccionado)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle,
                        color: AppTheme.primary, size: 15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colores de fila alternados (rosita/blanco) — iguales a los del
/// "Historial reciente" del Dashboard, pero aquí NO cambian al pasar el
/// cursor (pedido explícito, 2026-10-02): son fijos por posición.
const _colorFilaRosa = Color(0xFFFCEEEF);
const _colorFilaBlanca = Colors.white;

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

/// Fila plana de historial con fondo alternado fijo (sin Card, sin hover) —
/// estilo del mockup de Stitch del historial de hoy aplicado aquí al
/// historial completo.
class _FilaHistorialPlana extends StatelessWidget {
  final bool filaRosa;
  final IconData icono;
  final Color colorIconoFondo;
  final Color colorIcono;
  final String titulo;
  final TextStyle? estiloTitulo;
  final Widget subtitulo;
  final VoidCallback onTap;
  final bool isThreeLine;

  const _FilaHistorialPlana({
    required this.filaRosa,
    required this.icono,
    required this.colorIconoFondo,
    required this.colorIcono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.estiloTitulo,
    this.isThreeLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: filaRosa ? _colorFilaRosa : _colorFilaBlanca,
      child: ListTile(
        onTap: onTap,
        isThreeLine: isThreeLine,
        leading: CircleAvatar(
          backgroundColor: colorIconoFondo,
          child: Icon(icono, color: colorIcono, size: 20),
        ),
        title: Text(titulo, style: estiloTitulo),
        subtitle: subtitulo,
        trailing:
            const Icon(Icons.chevron_right, color: AppTheme.outline, size: 18),
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
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: ordenados.length,
      itemBuilder: (context, i) {
        final r = ordenados[i];
        final origen = r.esPorLote
            ? (r.loteNombre ?? 'Lote #${r.loteId}')
            : (r.animal?.nombreVisible ?? 'Animal #${r.animalId}');
        return _FilaHistorialPlana(
          filaRosa: i.isEven,
          icono: r.esPorLote ? Icons.groups : Icons.pets,
          colorIconoFondo: r.estaEliminado
              ? AppTheme.surfaceContainerHigh
              : AppTheme.primaryContainer.withValues(alpha: 0.5),
          colorIcono: r.estaEliminado ? AppTheme.outline : AppTheme.primary,
          titulo: '${r.litros} L · $origen',
          estiloTitulo: r.estaEliminado
              ? const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: AppTheme.outline)
              : null,
          subtitulo: Column(
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
          isThreeLine: r.estaEliminado,
          onTap: () => mostrarDetalleLeche(context, r),
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
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: ordenados.length,
      itemBuilder: (context, i) {
        final r = ordenados[i];
        final origen = r.esPorLote
            ? (r.loteNombre ?? 'Lote #${r.loteId}')
            : (r.animalId != null
                ? (r.animal?.nombreVisible ?? 'Animal #${r.animalId}')
                : null);
        return _FilaHistorialPlana(
          filaRosa: i.isEven,
          icono: r.esPorLote ? Icons.groups : Icons.egg,
          colorIconoFondo: r.estaEliminado
              ? AppTheme.surfaceContainerHigh
              : const Color(0xFFF6DFCB),
          colorIcono:
              r.estaEliminado ? AppTheme.outline : const Color(0xFFB9784A),
          titulo: r.cantidadRotos > 0
              ? '${r.cantidad} huevos (${r.cantidadRotos} rotos)'
              : '${r.cantidad} huevos',
          estiloTitulo: r.estaEliminado
              ? const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: AppTheme.outline)
              : null,
          subtitulo: Column(
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
          isThreeLine: r.estaEliminado,
          onTap: () => mostrarDetalleHuevos(context, r),
        );
      },
    );
  }
}
