import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';
import 'seguimiento_detalle_screen.dart';

/// Pantalla reutilizable para las 3 burbujas que son "una lista filtrada
/// simple" (Gestaciones, Partos pendientes, Partos este mes) -- la 4ta
/// burbuja (Fertilidad del mes) tiene su propia pantalla con gráfico
/// (FertilidadScreen), porque no es solo una lista.
///
/// 2026-10-21, nuevo a pedido de la Parte 1: "que lleven a una pantalla con
/// todos los registros de sus respectivos nombres" + "Ver detalles ->
/// Editarlos ó Eliminar". El filtro de cuáles registros mostrar lo decide
/// quien use esta pantalla (ver [filtro]), para no repetir la lógica de
/// "Gestante" / "Pendiente" / "Parida este mes" tres veces.
class ReproduccionListaFiltradaScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;
  final String titulo;
  final IconData icono;
  final Color color;
  final bool Function(SeguimientoGestacion) filtro;
  final String mensajeVacio;

  const ReproduccionListaFiltradaScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    required this.titulo,
    required this.icono,
    required this.color,
    required this.filtro,
    required this.mensajeVacio,
  });

  @override
  State<ReproduccionListaFiltradaScreen> createState() =>
      _ReproduccionListaFiltradaScreenState();
}

class _ReproduccionListaFiltradaScreenState
    extends State<ReproduccionListaFiltradaScreen> {
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
      // Siempre se trae la lista completa (sin incluirEliminados) y se
      // filtra en el cliente -- mismo patrón ya usado en las burbujas del
      // panorama (ver _BurbujasPanorama en reproduccion_list_screen.dart),
      // necesario porque algunos filtros (ej. "este mes") combinan estado +
      // fecha, algo que el backend no resuelve con un solo query param.
      final todos = await widget.repository.listar();
      if (mounted) {
        setState(() => _registros = todos.where(widget.filtro).toList());
      }
    } catch (e) {
      setState(() => _error = 'No se pudo cargar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
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
                  child: _registros.isEmpty
                      ? ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 60),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(widget.icono,
                                        size: 40, color: AppTheme.outline),
                                    const SizedBox(height: 10),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 32),
                                      child: Text(widget.mensajeVacio,
                                          textAlign: TextAlign.center),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _registros.length,
                          itemBuilder: (context, i) => _TarjetaFiltrada(
                            registro: _registros[i],
                            color: widget.color,
                            dateFormat: _dateFormat,
                            onTap: () => _abrirDetalle(_registros[i]),
                          ),
                        ),
                ),
    );
  }
}

/// 2026-10-22 (Tarea 5, sin mockup propio): restyle con el mismo lenguaje
/// visual ya calcado del mockup de "Confirmar" en registrar_seguimiento_
/// screen.dart -- tarjeta blanca redondeada con sombra suave, avatar
/// circular, pill de estado con punto de color.
class _TarjetaFiltrada extends StatelessWidget {
  final SeguimientoGestacion registro;
  final Color color;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _TarjetaFiltrada({
    required this.registro,
    required this.color,
    required this.dateFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.pregnant_woman, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        registro.animal?.nombreVisible ??
                            'Animal #${registro.animalId}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 13, color: AppTheme.outline),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Inseminación: ${dateFormat.format(registro.fechaInseminacion)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(registro.estado,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppTheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
