import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import 'seguimiento_form_screen.dart';

/// Lista de seguimientos de gestación (`/api/reproduccion`).
class ReproduccionListScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;

  const ReproduccionListScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
  });

  @override
  State<ReproduccionListScreen> createState() => _ReproduccionListScreenState();
}

class _ReproduccionListScreenState extends State<ReproduccionListScreen> {
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
      final registros = await widget.repository.listar();
      setState(() => _registros = registros);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _crear() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SeguimientoFormScreen(
          repository: widget.repository,
          animalRepository: widget.animalRepository,
        ),
      ),
    );
    if (resultado == true) _cargar();
  }

  Future<void> _editar(SeguimientoGestacion registro) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SeguimientoFormScreen(
          repository: widget.repository,
          animalRepository: widget.animalRepository,
          registroExistente: registro,
        ),
      ),
    );
    if (resultado == true) _cargar();
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Parida':
        return Colors.green;
      case 'Abortada':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reproducción')),
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
                        FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : _registros.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pregnant_woman, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No hay seguimientos de gestación registrados'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _registros.length,
                        itemBuilder: (context, index) {
                          final registro = _registros[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () => _editar(registro),
                              leading: CircleAvatar(
                                backgroundColor: _colorEstado(registro.estado).withValues(alpha: 0.15),
                                child: Icon(Icons.pregnant_woman, color: _colorEstado(registro.estado)),
                              ),
                              title: Text(registro.animal?.nombreVisible ?? 'Animal #${registro.animalId}'),
                              subtitle: Text(
                                'Inseminación: ${_dateFormat.format(registro.fechaInseminacion)}'
                                '${registro.fechaEstimadaParto != null ? ' · Parto est.: ${_dateFormat.format(registro.fechaEstimadaParto!)}' : ''}',
                              ),
                              trailing: Chip(
                                label: Text(registro.estado, style: const TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _crear,
        child: const Icon(Icons.add),
      ),
    );
  }
}
