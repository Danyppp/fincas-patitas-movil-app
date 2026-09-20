import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/animal.dart';
import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';

/// Formulario único para crear/actualizar un seguimiento de gestación.
///
/// Nota de negocio confirmada en el backend: no se valida que el animal
/// sea Hembra, así que la app tampoco filtra la lista por género.
class SeguimientoFormScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;
  final SeguimientoGestacion? registroExistente;

  const SeguimientoFormScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    this.registroExistente,
  });

  @override
  State<SeguimientoFormScreen> createState() => _SeguimientoFormScreenState();
}

class _SeguimientoFormScreenState extends State<SeguimientoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notasCtrl = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  List<Animal> _animales = [];
  Animal? _animalSeleccionado;
  Animal? _machoSeleccionado;
  String? _tipo;
  String _estado = 'Gestante';
  DateTime? _fechaInseminacion;
  DateTime? _fechaEstimadaParto;
  DateTime? _fechaRealParto;

  bool _cargandoAnimales = true;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.registroExistente != null;

  @override
  void initState() {
    super.initState();
    final actual = widget.registroExistente;
    if (actual != null) {
      _tipo = actual.tipo;
      _estado = actual.estado;
      _fechaInseminacion = actual.fechaInseminacion;
      _fechaEstimadaParto = actual.fechaEstimadaParto;
      _fechaRealParto = actual.fechaRealParto;
      _notasCtrl.text = actual.notas ?? '';
    } else {
      _fechaInseminacion = DateTime.now();
    }
    _cargarAnimales();
  }

  Future<void> _cargarAnimales() async {
    try {
      final pagina = await widget.animalRepository.listar(estado: 'Todos', limite: 200);
      setState(() {
        _animales = pagina.data;
        if (widget.registroExistente != null) {
          _animalSeleccionado = _buscarPorId(widget.registroExistente!.animalId);
          if (widget.registroExistente!.machoId != null) {
            _machoSeleccionado = _buscarPorId(widget.registroExistente!.machoId!);
          }
        }
      });
    } catch (e) {
      setState(() => _error = 'No se pudo cargar la lista de animales: $e');
    } finally {
      if (mounted) setState(() => _cargandoAnimales = false);
    }
  }

  Animal? _buscarPorId(int id) {
    try {
      return _animales.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha({
    required DateTime? actual,
    required void Function(DateTime) onSeleccionar,
  }) async {
    final resultado = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (resultado != null) setState(() => onSeleccionar(resultado));
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_animalSeleccionado == null) {
      setState(() => _error = 'Selecciona el animal');
      return;
    }
    if (_fechaInseminacion == null) {
      setState(() => _error = 'Selecciona la fecha de inseminación');
      return;
    }
    if (!_esEdicion && _fechaEstimadaParto == null) {
      setState(() => _error = 'Selecciona la fecha estimada de parto');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_esEdicion) {
        await widget.repository.actualizar(
          widget.registroExistente!.id,
          ActualizarSeguimientoDTO(
            machoId: _machoSeleccionado?.id,
            tipo: _tipo,
            fechaInseminacion: _fechaInseminacion,
            fechaEstimadaParto: _fechaEstimadaParto,
            fechaRealParto: _fechaRealParto,
            estado: _estado,
            notas: _notasCtrl.text.trim(),
          ),
        );
      } else {
        await widget.repository.crear(
          CrearSeguimientoDTO(
            animalId: _animalSeleccionado!.id,
            machoId: _machoSeleccionado?.id,
            tipo: _tipo,
            fechaInseminacion: _fechaInseminacion!,
            fechaEstimadaParto: _fechaEstimadaParto,
            estado: _estado,
            notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar seguimiento' : 'Nuevo seguimiento')),
      body: _cargandoAnimales
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Animal>(
                      initialValue: _animalSeleccionado,
                      decoration: const InputDecoration(labelText: 'Animal (hembra)', border: OutlineInputBorder()),
                      items: _animales
                          .map((a) => DropdownMenuItem(value: a, child: Text('${a.nombreVisible} (${a.codigo})')))
                          .toList(),
                      onChanged: _esEdicion ? null : (v) => setState(() => _animalSeleccionado = v),
                      validator: (v) => v == null ? 'Selecciona un animal' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Animal?>(
                      initialValue: _machoSeleccionado,
                      decoration: const InputDecoration(labelText: 'Macho (opcional)', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<Animal?>(value: null, child: Text('Sin especificar')),
                        ..._animales.map((a) => DropdownMenuItem<Animal?>(value: a, child: Text('${a.nombreVisible} (${a.codigo})'))),
                      ],
                      onChanged: (v) => setState(() => _machoSeleccionado = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      initialValue: _tipo,
                      decoration: const InputDecoration(labelText: 'Tipo (opcional)', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Sin especificar')),
                        ...tiposMontaValidos.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
                      ],
                      onChanged: (v) => setState(() => _tipo = v),
                    ),
                    const SizedBox(height: 16),
                    _SelectorFecha(
                      etiqueta: 'Fecha de inseminación',
                      fecha: _fechaInseminacion,
                      formato: _dateFormat,
                      onTap: () => _elegirFecha(
                        actual: _fechaInseminacion,
                        onSeleccionar: (f) => _fechaInseminacion = f,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SelectorFecha(
                      etiqueta: 'Fecha estimada de parto',
                      fecha: _fechaEstimadaParto,
                      formato: _dateFormat,
                      onTap: () => _elegirFecha(
                        actual: _fechaEstimadaParto,
                        onSeleccionar: (f) => _fechaEstimadaParto = f,
                      ),
                    ),
                    if (_esEdicion) ...[
                      const SizedBox(height: 16),
                      _SelectorFecha(
                        etiqueta: 'Fecha real de parto (si ya ocurrió)',
                        fecha: _fechaRealParto,
                        formato: _dateFormat,
                        onTap: () => _elegirFecha(
                          actual: _fechaRealParto,
                          onSeleccionar: (f) => _fechaRealParto = f,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _estado,
                        decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Gestante', child: Text('Gestante')),
                          DropdownMenuItem(value: 'Parida', child: Text('Parida')),
                          DropdownMenuItem(value: 'Abortada', child: Text('Abortada')),
                        ],
                        onChanged: (v) => setState(() => _estado = v ?? 'Gestante'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notasCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Notas (opcional)', border: OutlineInputBorder()),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_esEdicion ? 'Guardar cambios' : 'Crear seguimiento'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SelectorFecha extends StatelessWidget {
  final String etiqueta;
  final DateTime? fecha;
  final DateFormat formato;
  final VoidCallback onTap;

  const _SelectorFecha({
    required this.etiqueta,
    required this.fecha,
    required this.formato,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
        child: Text(fecha != null ? formato.format(fecha!) : 'Sin definir'),
      ),
    );
  }
}
