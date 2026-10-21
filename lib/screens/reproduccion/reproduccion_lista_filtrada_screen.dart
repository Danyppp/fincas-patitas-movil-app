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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(Icons.pregnant_woman, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      registro.animal?.nombreVisible ??
                          'Animal #${registro.animalId}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Inseminación: ${dateFormat.format(registro.fechaInseminacion)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Chip(
                label:
                    Text(registro.estado, style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                backgroundColor: color.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppTheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
