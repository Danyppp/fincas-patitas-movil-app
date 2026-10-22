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
///
/// 2026-10-22 (Tarea 5, última pantalla, mockup "Metricas_de_fertilidad"):
/// restyle calcado del mockup -- las donas quedan dentro de tarjetas
/// blancas con sombra y con el total en el centro (antes el total se veía
/// como etiqueta sobre cada porción, no en el centro de la dona), la pill
/// de porcentaje y la leyenda con los conteos. Las tarjetas de la lista de
/// abajo también se restylearon con el mismo lenguaje ya usado en el resto
/// del módulo. La lógica de cálculo (fechaRealParto con respaldo en
/// cerradoEn, Parida = éxito, Fallida/Abortada = fallo) no se tocó.
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
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('Fertilidad Del Mes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: _cargar),
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
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Exitosos (Parida) vs Fallidos (Fallida + Abortada)',
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                        titulo: 'Exitosos este mes',
                        colorPrincipal: AppTheme.primary,
                        colorChip: AppTheme.primaryContainer,
                        colorAvatar: AppTheme.primaryContainer,
                        registros: exitososActual,
                        dateFormat: _dateFormat,
                        onTap: _abrirDetalle,
                        mensajeVacio: 'Ningún cierre exitoso este mes todavía',
                      ),
                      const SizedBox(height: 18),
                      _SeccionLista(
                        titulo: 'Fallidos este mes',
                        colorPrincipal: AppTheme.tertiary,
                        colorChip: AppTheme.tertiaryContainer,
                        colorAvatar: AppTheme.tertiaryContainer,
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

/// Tarjeta "Mes actual"/"Mes anterior" con la dona (total en el centro),
/// la pill de porcentaje y la leyenda de conteos -- calcada del mockup.
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
    final colorPct =
        (pct == null || pct == 0) ? AppTheme.tertiary : AppTheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(etiqueta,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 10),
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                total == 0
                    ? Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.surfaceContainerColor, width: 9),
                        ),
                      )
                    : PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 37,
                          startDegreeOffset: -90,
                          sections: [
                            if (fallidos > 0)
                              PieChartSectionData(
                                value: fallidos.toDouble(),
                                color: AppTheme.tertiaryContainer,
                                title: '',
                                radius: 18,
                                showTitle: false,
                              ),
                            if (exitosos > 0)
                              PieChartSectionData(
                                value: exitosos.toDouble(),
                                color: AppTheme.primaryContainer,
                                title: '',
                                radius: 18,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    Text(total == 1 ? 'SERVICIO' : 'SERVICIOS',
                        style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: AppTheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pct == null
                  ? 'Sin cierres'
                  : '${pct.toStringAsFixed(0)}% exitoso',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: colorPct),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: [
              _LeyendaColor(
                  colorLleno: AppTheme.primaryContainer,
                  activo: exitosos > 0,
                  texto: '$exitosos Éxito${exitosos == 1 ? '' : 's'}'),
              _LeyendaColor(
                  colorLleno: AppTheme.tertiaryContainer,
                  activo: fallidos > 0,
                  texto: '$fallidos Fallo${fallidos == 1 ? '' : 's'}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeyendaColor extends StatelessWidget {
  final Color colorLleno;
  final bool activo;
  final String texto;

  const _LeyendaColor(
      {required this.colorLleno, required this.activo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: activo ? colorLleno : AppTheme.outlineVariant,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(texto,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color:
                    activo ? AppTheme.onSurface : AppTheme.onSurfaceVariant)),
      ],
    );
  }
}

class _SeccionLista extends StatelessWidget {
  final String titulo;
  final Color colorPrincipal;
  final Color colorChip;
  final Color colorAvatar;
  final List<SeguimientoGestacion> registros;
  final DateFormat dateFormat;
  final void Function(SeguimientoGestacion) onTap;
  final String mensajeVacio;

  const _SeccionLista({
    required this.titulo,
    required this.colorPrincipal,
    required this.colorChip,
    required this.colorAvatar,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration:
                        BoxDecoration(color: colorChip, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(titulo,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colorPrincipal)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: colorChip,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${registros.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (registros.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(mensajeVacio,
                style: const TextStyle(
                    color: AppTheme.onSurfaceVariant, fontSize: 13)),
          )
        else
          for (final r in registros)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  onTap: () => onTap(r),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorAvatar.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child:
                              Icon(Icons.pets, color: colorPrincipal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 2,
                                children: [
                                  Text(
                                      r.animal?.nombreVisible ??
                                          'Animal #${r.animalId}',
                                      style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorChip,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(r.estado,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.onSurface)),
                                  ),
                                ],
                              ),
                              if (r.fechaRealParto != null ||
                                  r.cerradoEn != null) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.event,
                                        size: 14, color: AppTheme.outline),
                                    const SizedBox(width: 4),
                                    Text.rich(
                                      TextSpan(
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppTheme.onSurfaceVariant),
                                        children: [
                                          const TextSpan(text: 'Fecha real: '),
                                          TextSpan(
                                            text: dateFormat.format(
                                                r.fechaRealParto ??
                                                    r.cerradoEn!),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.onSurface),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chevron_right,
                              color: AppTheme.onSurface, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
