import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/animal.dart';
import '../../models/sexo.dart';
import '../../models/species.dart';
import '../../repositories/animal_repository.dart';

/// Formulario de registro de un nuevo animal.
///
/// Al guardar, devuelve el [Animal] creado con `Navigator.pop` para que
/// [AnimalesListScreen] pueda refrescar su lista — la pantalla de lista
/// no necesita saber cómo se crea un animal, solo que al volver de aquí
/// puede haber uno nuevo.
class AnimalFormScreen extends StatefulWidget {
  final AnimalRepository repository;

  const AnimalFormScreen({super.key, required this.repository});

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  Sexo _sexo = Sexo.hembra;
  Species? _especieSeleccionada;
  DateTime? _fechaNacimiento;

  late Future<List<Species>> _futureEspecies;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _futureEspecies = widget.repository.getSpecies();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(ahora.year - 1),
      firstDate: DateTime(2000),
      lastDate: ahora,
    );
    if (elegida != null) {
      setState(() => _fechaNacimiento = elegida);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_especieSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una especie.')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final creado = await widget.repository.create(
        CreateAnimalDTO(
          name: _nameController.text.trim(),
          sex: _sexo,
          speciesId: _especieSeleccionada!.id,
          birthDate: _fechaNacimiento,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(creado);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el animal: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fechaFormato = DateFormat('d MMM y', 'es');

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo animal')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              textCapitalization: TextCapitalization.words,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Escribe un nombre'
                  : null,
            ),
            const SizedBox(height: 16),
            Text('Sexo', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<Sexo>(
              segments: const [
                ButtonSegment(
                    value: Sexo.hembra,
                    label: Text('Hembra'),
                    icon: Icon(Icons.female)),
                ButtonSegment(
                    value: Sexo.macho,
                    label: Text('Macho'),
                    icon: Icon(Icons.male)),
              ],
              selected: {_sexo},
              onSelectionChanged: (seleccion) =>
                  setState(() => _sexo = seleccion.first),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Species>>(
              future: _futureEspecies,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text(
                    'No se pudieron cargar las especies: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  );
                }
                final especies = snapshot.data ?? const [];
                return DropdownButtonFormField<Species>(
                  initialValue: _especieSeleccionada,
                  decoration: const InputDecoration(labelText: 'Especie'),
                  items: especies
                      .map((e) => DropdownMenuItem(
                          value: e, child: Text(e.displayName)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _especieSeleccionada = value),
                  validator: (value) =>
                      value == null ? 'Selecciona una especie' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de nacimiento'),
              subtitle: Text(
                _fechaNacimiento != null
                    ? fechaFormato.format(_fechaNacimiento!)
                    : 'No indicada',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _elegirFecha,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar animal'),
            ),
          ],
        ),
      ),
    );
  }
}
