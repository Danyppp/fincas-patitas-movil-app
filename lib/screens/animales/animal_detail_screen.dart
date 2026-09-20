import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/animal.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import 'animal_form_screen.dart';

class AnimalDetailScreen extends StatefulWidget {
  final int animalId;
  final AnimalRepository repository;
  final CatalogoRepository catalogoRepository;

  const AnimalDetailScreen({
    super.key,
    required this.animalId,
    required this.repository,
    required this.catalogoRepository,
  });

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  Animal? _animal;
  bool _cargando = true;
  String? _error;
  bool _huboCambios = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final animal = await widget.repository.obtenerPorId(widget.animalId);
      setState(() {
        _animal = animal;
        _error = animal == null ? 'Animal no encontrado' : null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar() async {
    final actualizado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AnimalFormScreen(
          repository: widget.repository,
          catalogoRepository: widget.catalogoRepository,
          animalExistente: _animal,
        ),
      ),
    );
    if (actualizado == true) {
      _huboCambios = true;
      _cargar();
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar animal'),
        content: Text('¿Eliminar a ${_animal?.nombreVisible}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await widget.repository.eliminar(widget.animalId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_huboCambios);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_animal?.nombreVisible ?? 'Animal'),
          actions: [
            if (_animal != null) ...[
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: _editar),
              IconButton(icon: const Icon(Icons.delete_outline), onPressed: _eliminar),
            ],
          ],
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _DetalleAnimal(animal: _animal!),
      ),
    );
  }
}

class _DetalleAnimal extends StatelessWidget {
  final Animal animal;

  const _DetalleAnimal({required this.animal});

  @override
  Widget build(BuildContext context) {
    final formato = DateFormat('yyyy-MM-dd');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _fila('Código', animal.codigo),
        _fila('Especie', animal.especie?.nombre ?? '#${animal.especieId}'),
        _fila('Raza', animal.raza?.nombre ?? '#${animal.razaId}'),
        _fila('Género', animal.genero),
        _fila('Estado', animal.estado),
        if (animal.fechaNacimiento != null)
          _fila('Fecha de nacimiento', formato.format(animal.fechaNacimiento!)),
        if (animal.fechaIngreso != null)
          _fila('Fecha de ingreso', formato.format(animal.fechaIngreso!)),
        if (animal.origen != null && animal.origen!.isNotEmpty) _fila('Origen', animal.origen!),
        if (animal.loteNombre != null) _fila('Lote', animal.loteNombre!),
      ],
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(etiqueta, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
