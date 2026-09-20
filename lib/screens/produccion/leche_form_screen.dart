import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/animal.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/produccion/produccion_repository.dart';

class LecheFormScreen extends StatefulWidget {
  final ProduccionRepository repository;
  final AnimalRepository animalRepository;
  final ProduccionLeche? registroExistente;

  const LecheFormScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    this.registroExistente,
  });

  @override
  State<LecheFormScreen> createState() => _LecheFormScreenState();
}

class _LecheFormScreenState extends State<LecheFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _litrosCtrl = TextEditingController();

  List<Animal> _animales = [];
  Animal? _animalSeleccionado;
  String _jornada = 'Mañana';

  bool _cargandoAnimales = true;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.registroExistente != null;

  @override
  void initState() {
    super.initState();
    final actual = widget.registroExistente;
    if (actual != null) {
      _litrosCtrl.text = actual.litros.toString();
      _jornada = actual.jornada ?? 'Mañana';
    }
    _cargarAnimales();
  }

  Future<void> _cargarAnimales() async {
    try {
      final pagina = await widget.animalRepository.listar(estado: 'Todos', limite: 200);
      setState(() {
        _animales = pagina.data;
        if (widget.registroExistente != null) {
          try {
            _animalSeleccionado =
                pagina.data.firstWhere((a) => a.id == widget.registroExistente!.animalId);
          } catch (_) {}
        }
      });
    } catch (e) {
      setState(() => _error = 'No se pudo cargar la lista de animales: $e');
    } finally {
      if (mounted) setState(() => _cargandoAnimales = false);
    }
  }

  @override
  void dispose() {
    _litrosCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_esEdicion && _animalSeleccionado == null) {
      setState(() => _error = 'Selecciona el animal');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final litros = double.parse(_litrosCtrl.text.trim());
      if (_esEdicion) {
        await widget.repository.actualizarLeche(
          widget.registroExistente!.id,
          ActualizarProduccionLecheDTO(litros: litros, jornada: _jornada),
        );
      } else {
        await widget.repository.crearLeche(
          CrearProduccionLecheDTO(
            animalId: _animalSeleccionado!.id,
            litros: litros,
            jornada: _jornada,
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
      appBar: AppBar(title: Text(_esEdicion ? 'Editar ordeña' : 'Registrar ordeña')),
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
                      decoration: const InputDecoration(labelText: 'Animal', border: OutlineInputBorder()),
                      items: _animales
                          .map((a) => DropdownMenuItem(value: a, child: Text('${a.nombreVisible} (${a.codigo})')))
                          .toList(),
                      onChanged: _esEdicion ? null : (v) => setState(() => _animalSeleccionado = v),
                      validator: (v) => (!_esEdicion && v == null) ? 'Selecciona un animal' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _litrosCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Litros', border: OutlineInputBorder()),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa los litros';
                        if (double.tryParse(v.trim()) == null) return 'Debe ser un número';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _jornada,
                      decoration: const InputDecoration(labelText: 'Jornada', border: OutlineInputBorder()),
                      items: jornadasValidas
                          .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                          .toList(),
                      onChanged: (v) => setState(() => _jornada = v ?? 'Mañana'),
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
                          : Text(_esEdicion ? 'Guardar cambios' : 'Registrar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
