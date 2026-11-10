import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../models/catalogo/especie.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';

/// Formulario de Crear/Editar Lote, contra `UbicacionRepository`.
///
/// Fase 1 (funcional, pocos estilos): sin tarjetas grandes de especie ni
/// diseño del mockup todavía -- un `Form` simple con los campos reales que
/// acepta el backend (`nombre` y `especie_id` obligatorios, el resto
/// opcional). Asignar encargado NO está acá -- queda para la pantalla
/// "Asignar Personal — Lote" (ver decisiones-diseno-vs-backend-ubicacion.md,
/// sección 7), que todavía no existe.
class LoteFormScreen extends StatefulWidget {
  final UbicacionRepository repository;
  final CatalogoRepository catalogoRepository;
  final LoteAnimal? loteExistente;

  const LoteFormScreen({
    super.key,
    required this.repository,
    required this.catalogoRepository,
    this.loteExistente,
  });

  @override
  State<LoteFormScreen> createState() => _LoteFormScreenState();
}

class _LoteFormScreenState extends State<LoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  List<Especie> _especies = [];
  Especie? _especieSeleccionada;
  DateTime? _fechaCreacion;

  bool _cargandoEspecies = true;
  bool _guardando = false;
  bool _eliminando = false;
  String? _error;

  bool get _esEdicion => widget.loteExistente != null;

  @override
  void initState() {
    super.initState();
    final actual = widget.loteExistente;
    if (actual != null) {
      _nombreCtrl.text = actual.nombre;
      _capacidadCtrl.text = actual.capacidadEstimada?.toString() ?? '';
      _descripcionCtrl.text = actual.descripcion ?? '';
      _fechaCreacion = actual.fechaCreacion;
    }
    _cargarEspecies();
  }

  Future<void> _cargarEspecies() async {
    try {
      final especies = await widget.catalogoRepository.listarEspecies();
      if (!mounted) return;
      setState(() {
        _especies = especies;
        final actual = widget.loteExistente;
        if (actual?.especieId != null) {
          try {
            _especieSeleccionada =
                especies.firstWhere((e) => e.id == actual!.especieId);
          } catch (_) {
            _especieSeleccionada = null;
          }
        }
      });
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar las especies: $e');
    } finally {
      if (mounted) setState(() => _cargandoEspecies = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _capacidadCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final resultado = await showDatePicker(
      context: context,
      initialDate: _fechaCreacion ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (resultado != null) setState(() => _fechaCreacion = resultado);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_especieSeleccionada == null) {
      setState(() => _error = 'Selecciona la especie');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final capacidad = _capacidadCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(_capacidadCtrl.text.trim());
    final descripcion = _descripcionCtrl.text.trim().isEmpty
        ? null
        : _descripcionCtrl.text.trim();

    try {
      if (_esEdicion) {
        await widget.repository.actualizarLote(
          widget.loteExistente!.id,
          ActualizarLoteDTO(
            nombre: _nombreCtrl.text.trim(),
            especieId: _especieSeleccionada!.id,
            fechaCreacion: _fechaCreacion,
            capacidadEstimada: capacidad,
            descripcion: descripcion,
          ),
        );
      } else {
        await widget.repository.crearLote(
          CrearLoteDTO(
            nombre: _nombreCtrl.text.trim(),
            especieId: _especieSeleccionada!.id,
            fechaCreacion: _fechaCreacion,
            capacidadEstimada: capacidad,
            descripcion: descripcion,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _confirmarEliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar lote'),
        content: Text(
            '¿Seguro que quieres eliminar "${widget.loteExistente!.nombre}"? '
            'Esto no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() {
      _eliminando = true;
      _error = null;
    });
    try {
      await widget.repository.eliminarLote(widget.loteExistente!.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Lote' : 'Crear Lote'),
        actions: [
          if (_esEdicion)
            IconButton(
              icon: _eliminando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline),
              onPressed: _eliminando ? null : _confirmarEliminar,
            ),
        ],
      ),
      body: _cargandoEspecies
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Especie>(
                    value: _especieSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Especie *',
                      border: OutlineInputBorder(),
                    ),
                    items: _especies
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text(e.nombre)))
                        .toList(),
                    onChanged: (v) => setState(() => _especieSeleccionada = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _capacidadCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Capacidad estimada',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha de creación'),
                    subtitle: Text(_fechaCreacion == null
                        ? 'Sin definir'
                        : '${_fechaCreacion!.day}/${_fechaCreacion!.month}/${_fechaCreacion!.year}'),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: _elegirFecha,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descripcionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_esEdicion ? 'Guardar cambios' : 'Crear Lote'),
                  ),
                ],
              ),
            ),
    );
  }
}
