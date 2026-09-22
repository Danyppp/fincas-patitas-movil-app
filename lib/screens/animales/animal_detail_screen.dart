import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/animal.dart';
import '../../models/catalogo/potrero.dart';
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
  Animal? _madre;
  Animal? _padre;
  Potrero? _potrero;
  Map<String, dynamic>? _ultimoEventoSanitario;
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
      if (animal == null) {
        setState(() {
          _animal = null;
          _error = 'Animal no encontrado';
        });
        return;
      }

      // Cargas secundarias (genealogía, potrero, último evento sanitario).
      // Cada una se resuelve de forma independiente y no debe tumbar la
      // pantalla si falla: si algo sale mal, simplemente no se muestra
      // esa sección.
      final madre = animal.madreId == null
          ? null
          : await _intentar(() => widget.repository.obtenerPorId(animal.madreId!));
      final padre = animal.padreId == null
          ? null
          : await _intentar(() => widget.repository.obtenerPorId(animal.padreId!));
      final potrero = animal.potreroId == null
          ? null
          : await _buscarPotrero(animal.potreroId!);
      final ultimoEvento = await _obtenerUltimoEventoSanitario(animal.id);

      setState(() {
        _animal = animal;
        _madre = madre;
        _padre = padre;
        _potrero = potrero;
        _ultimoEventoSanitario = ultimoEvento;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<T?> _intentar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } catch (_) {
      return null;
    }
  }

  Future<Potrero?> _buscarPotrero(int potreroId) async {
    final potreros = await _intentar(() => widget.catalogoRepository.listarPotreros());
    if (potreros == null) return null;
    for (final p in potreros) {
      if (p.id == potreroId) return p;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _obtenerUltimoEventoSanitario(int animalId) async {
    final respuesta = await _intentar(() => widget.repository.obtenerHistorial(animalId));
    final historial = respuesta?['historial'] as Map<String, dynamic>?;
    final eventos = historial?['eventosSanitarios'] as List<dynamic>?;
    if (eventos == null || eventos.isEmpty) return null;
    return eventos.first as Map<String, dynamic>;
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
                : _DetalleAnimal(
                    animal: _animal!,
                    madre: _madre,
                    padre: _padre,
                    potrero: _potrero,
                    ultimoEventoSanitario: _ultimoEventoSanitario,
                  ),
      ),
    );
  }
}

class _DetalleAnimal extends StatelessWidget {
  final Animal animal;
  final Animal? madre;
  final Animal? padre;
  final Potrero? potrero;
  final Map<String, dynamic>? ultimoEventoSanitario;

  const _DetalleAnimal({
    required this.animal,
    this.madre,
    this.padre,
    this.potrero,
    this.ultimoEventoSanitario,
  });

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
        if (potrero != null) _fila('Potrero', potrero!.nombre),

        // -- Genealogía (solo si hay datos reales) --
        if (madre != null || padre != null) ...[
          const SizedBox(height: 24),
          const Text('Genealogía', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (madre != null) _fila('Madre', '${madre!.nombreVisible} (${madre!.codigo})'),
          if (padre != null) _fila('Padre', '${padre!.nombreVisible} (${padre!.codigo})'),
        ],

        // -- Estado de salud: solo datos reales del backend (sin
        // veterinario ni "próximo refuerzo", eso no existe en el modelo
        // de eventos_sanitarios). --
        const SizedBox(height: 24),
        const Text('Estado de salud', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (ultimoEventoSanitario == null)
          const Text('Sin eventos sanitarios registrados', style: TextStyle(color: Colors.black54))
        else ...[
          _fila('Último evento', ultimoEventoSanitario!['tipo_evento'] as String? ?? '-'),
          if (ultimoEventoSanitario!['fecha_evento'] != null)
            _fila(
              'Fecha',
              formato.format(DateTime.parse(ultimoEventoSanitario!['fecha_evento'] as String)),
            ),
          if ((ultimoEventoSanitario!['descripcion_tratamiento'] as String?)?.isNotEmpty == true)
            _fila('Descripción', ultimoEventoSanitario!['descripcion_tratamiento'] as String),
          if (ultimoEventoSanitario!['estado'] != null)
            _fila('Estado del evento', ultimoEventoSanitario!['estado'] as String),
        ],
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
