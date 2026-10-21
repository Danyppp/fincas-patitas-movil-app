import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';
import 'seguimiento_detalle_screen.dart';

/// Pantalla de "Fertilidad del mes" (2026-10-21, nuevo a pedido de la Parte
/// 1) -- la única de las 4 burbujas que no es solo una lista: compara
/// "Fallidos" (Fallida + Abortada, confirmado) vs "Exitosos" (Parida) del
/// mes actual contra el mes anterior, con un gráfico de torta por mes
/// (confirmado -- las otras opciones eran barras o lineal).
///
/// Un registro cuenta en un mes según `cerradoEn` (cuándo se cerró con ese
/// resultado), no `fechaInseminacion` -- es la fecha que de verdad importa
/// para "qué tan fértil fue este mes en resultados".
class FertilidadScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;

  const FertilidadScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
  });

  @override
  State<FertilidadScreen> createState() => _FertilidadScreenState();
}

class _FertilidadScreenState extends State<FertilidadScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  List<SeguimientoGestacion> _registros = [];
  bool _cargando = true;
  String? _error;

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
      final todos = await widget.repository.listar();
      if (mounted) setState(() => _registros = todos);
    } catch (e) {
      setState(() => _error = 'No se pudo cargar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  bool _enMes(DateTime? fecha, DateTime referencia) =>
      fecha != null &&
      fecha.year == referencia.year &&
      fecha.month == referencia.month;

  // 2026-10-21 (corregido a partir de la prueba de Dany): el mes de un
  // resultado se determina por la fecha REAL del evento (fechaRealParto --
  // lo que la persona capturó como "cuándo pasó de verdad"), no por
  // cerradoEn (cuándo se dio clic en el sistema). Un registro cerrado hoy
  // pero con fecha real de parto/aborto del mes pasado debe contar en "mes
  // anterior". cerradoEn queda como respaldo solo para el caso raro de un
  // registro cerrado sin fechaRealParto.
  DateTime? _fechaDeResultado(SeguimientoGestacion r) =>
      r.fechaRealParto ?? r.cerradoEn;

  List<SeguimientoGestacion> _exitososDe(DateTime referencia) => _registros
      .where((r) =>
          r.esResultadoExitoso && _enMes(_fechaDeResultado(r), referencia))
      .toList();

  List<SeguimientoGestacion> _fallidosDe(DateTime referencia) => _registros
      .where((r) =>
          r.esResultadoFallido && _enMes(_fechaDeResultado(r), referencia))
      .toList();

  Future<void> _abrirDetalle(SeguimientoGestacion registro) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SeguimientoDetalleScreen(
          repository: widget.repository,
          animalRepository: widget.animalRepository,
          registro: registro,
          permitirAcciones: true,
        ),
      ),
    );
    if (cambio == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final mesAnterior = DateTime(ahora.year, ahora.month - 1);

    final exitososActual = _exitososDe(ahora);
    final fallidosActual = _fallidosDe(ahora);
    final exitososAnterior = _exitososDe(mesAnterior);
    final fallidosAnterior = _fallidosDe(mesAnterior);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fertilidad del mes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)
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
                        const SizedBox(height: 16),
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
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Exitosos (Parida) vs Fallidos (Fallida + Abortada)',
                        style: TextStyle(fontSize: 13, color: AppTheme.outline),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TortaMes(
                              etiqueta: 'Mes actual',
                              exitosos: exitososActual.length,
                              fallidos: fallidosActual.length,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TortaMes(
                              etiqueta: 'Mes anterior',
                              exitosos: exitososAnterior.length,
                              fallidos: fallidosAnterior.length,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SeccionLista(
                        titulo: 'Exitosos este mes (${exitososActual.length})',
                        color: Colors.green[700]!,
                        registros: exitososActual,
                        dateFormat: _dateFormat,
                        onTap: _abrirDetalle,
                        mensajeVacio: 'Ningún cierre exitoso este mes todavía',
                      ),
                      const SizedBox(height: 16),
                      _SeccionLista(
                        titulo: 'Fallidos este mes (${fallidosActual.length})',
                        color: Colors.red[700]!,
                        registros: fallidosActual,
                        dateFormat: _dateFormat,
                        onTap: _abrirDetalle,
                        mensajeVacio: 'Ningún cierre fallido este mes todavía',
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _TortaMes extends StatelessWidget {
  final String etiqueta;
  final int exitosos;
  final int fallidos;

  const _TortaMes({
    required this.etiqueta,
    required this.exitosos,
    required this.fallidos,
  });

  @override
  Widget build(BuildContext context) {
    final total = exitosos + fallidos;
    final pct = total == 0 ? null : (exitosos / total) * 100;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Column(
        children: [
          Text(etiqueta,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: total == 0
                ? const Center(
                    child: Text('Sin datos',
                        style: TextStyle(color: AppTheme.outline)),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 28,
                      sections: [
                        if (exitosos > 0)
                          PieChartSectionData(
                            value: exitosos.toDouble(),
                            color: Colors.green[600],
                            title: '$exitosos',
                            radius: 42,
                            titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        if (fallidos > 0)
                          PieChartSectionData(
                            value: fallidos.toDouble(),
                            color: Colors.red[400],
                            title: '$fallidos',
                            radius: 42,
                            titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            pct == null
                ? 'Sin cierres aún'
                : '${pct.toStringAsFixed(0)}% exitoso',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: [
              _LeyendaColor(color: Colors.green[600]!, texto: 'Exitoso'),
              _LeyendaColor(color: Colors.red[400]!, texto: 'Fallido'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeyendaColor extends StatelessWidget {
  final Color color;
  final String texto;

  const _LeyendaColor({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(texto,
            style: const TextStyle(fontSize: 10, color: AppTheme.outline)),
      ],
    );
  }
}

class _SeccionLista extends StatelessWidget {
  final String titulo;
  final Color color;
  final List<SeguimientoGestacion> registros;
  final DateFormat dateFormat;
  final void Function(SeguimientoGestacion) onTap;
  final String mensajeVacio;

  const _SeccionLista({
    required this.titulo,
    required this.color,
    required this.registros,
    required this.dateFormat,
    required this.onTap,
    required this.mensajeVacio,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 8),
        if (registros.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(mensajeVacio,
                style: const TextStyle(color: AppTheme.outline, fontSize: 13)),
          )
        else
          for (final r in registros)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                onTap: () => onTap(r),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.pregnant_woman, color: color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                r.animal?.nombreVisible ??
                                    'Animal #${r.animalId}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (r.fechaRealParto != null || r.cerradoEn != null)
                              Text(
                                  'Fecha real: ${dateFormat.format(r.fechaRealParto ?? r.cerradoEn!)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.outline)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppTheme.outline),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
