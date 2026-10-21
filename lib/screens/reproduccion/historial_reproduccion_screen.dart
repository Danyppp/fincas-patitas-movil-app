import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';
import 'seguimiento_detalle_screen.dart';

/// Historial completo de Reproducción (2026-10-21, nuevo a pedido de la
/// Parte 1): "al final del inicio aparezca el Historial de todos los
/// registros hechos y eliminados (para la auditoria)". Es la ÚNICA
/// pantalla que pide `incluirEliminados: true` al repositorio -- ningún
/// otro lugar de la app debe hacerlo.
///
/// A diferencia de las 4 pantallas de las burbujas, aquí el detalle se abre
/// en modo SOLO LECTURA (`permitirAcciones: false`) -- el Historial es para
/// auditar, no para seguir operando sobre los registros; editar/eliminar
/// vive en las pantallas de Gestaciones/Partos pendientes/Partos este
/// mes/Fertilidad.
class HistorialReproduccionScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;

  const HistorialReproduccionScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
  });

  @override
  State<HistorialReproduccionScreen> createState() =>
      _HistorialReproduccionScreenState();
}

class _HistorialReproduccionScreenState
    extends State<HistorialReproduccionScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  List<SeguimientoGestacion> _registros = [];
  bool _cargando = true;
  String? _error;

  // Todos | Activos | Eliminados -- ayuda a no perderse entre tantos
  // registros una vez que el historial crece.
  String _filtro = 'Todos';

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
      final todos = await widget.repository.listar(incluirEliminados: true);
      if (mounted) setState(() => _registros = todos);
    } catch (e) {
      setState(() => _error = 'No se pudo cargar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<SeguimientoGestacion> get _registrosFiltrados {
    switch (_filtro) {
      case 'Activos':
        return _registros.where((r) => !r.estaEliminado).toList();
      case 'Eliminados':
        return _registros.where((r) => r.estaEliminado).toList();
      default:
        return _registros;
    }
  }

  void _abrirDetalle(SeguimientoGestacion registro) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeguimientoDetalleScreen(
          repository: widget.repository,
          animalRepository: widget.animalRepository,
          registro: registro,
          permitirAcciones: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Reproducción'),
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
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final opcion in [
                            'Todos',
                            'Activos',
                            'Eliminados'
                          ])
                            ChoiceChip(
                              label: Text(opcion),
                              selected: _filtro == opcion,
                              onSelected: (_) =>
                                  setState(() => _filtro = opcion),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_registrosFiltrados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                              child: Text('No hay registros con este filtro')),
                        )
                      else
                        for (final r in _registrosFiltrados)
                          _TarjetaHistorial(
                            registro: r,
                            dateFormat: _dateFormat,
                            onTap: () => _abrirDetalle(r),
                          ),
                    ],
                  ),
                ),
    );
  }
}

class _TarjetaHistorial extends StatelessWidget {
  final SeguimientoGestacion registro;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _TarjetaHistorial({
    required this.registro,
    required this.dateFormat,
    required this.onTap,
  });

  Color get _colorEstado {
    switch (registro.estado) {
      case 'Gestante':
        return AppTheme.primary;
      case 'Parida':
        return Colors.green[700]!;
      case 'Abortada':
        return AppTheme.tertiary;
      case 'Fallida':
        return Colors.red[700]!;
      default:
        return AppTheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eliminado = registro.estaEliminado;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: eliminado ? Colors.red.withValues(alpha: 0.04) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: eliminado
                    ? Colors.red.withValues(alpha: 0.12)
                    : _colorEstado.withValues(alpha: 0.15),
                child: Icon(
                  eliminado ? Icons.delete_outline : Icons.pregnant_woman,
                  color: eliminado ? Colors.red[700] : _colorEstado,
                ),
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
                      'Creado: ${registro.creadoEn != null ? dateFormat.format(registro.creadoEn!) : "—"}'
                      '${registro.creadoPor != null ? " · ${registro.creadoPor!.nombreUsuario}" : ""}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (eliminado)
                      Text(
                        'Eliminado'
                        '${registro.eliminadoPor != null ? " por ${registro.eliminadoPor!.nombreUsuario}" : ""}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              Chip(
                label:
                    Text(registro.estado, style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                backgroundColor: _colorEstado.withValues(alpha: 0.12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
