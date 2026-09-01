import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/animal.dart';

/// Detalle de un animal. Por ahora recibe el [Animal] ya cargado desde
/// la lista (no vuelve a pedirlo al repositorio) — cuando exista el
/// endpoint `GET /animales/:id` real, este es el lugar natural para
/// refrescar contra la API si se navega aquí desde una notificación o
/// un deep link en vez de la lista.
class AnimalDetailScreen extends StatelessWidget {
  final Animal animal;

  const AnimalDetailScreen({super.key, required this.animal});

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('d MMM y', 'es');
    return Scaffold(
      appBar: AppBar(title: Text(animal.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  animal.sex.etiqueta == 'Macho' ? Icons.male : Icons.female,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(animal.name, style: Theme.of(context).textTheme.titleLarge),
                    Text(animal.code, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _Seccion(
            titulo: 'Identificación',
            filas: {
              'Especie': animal.species?.displayName ?? animal.speciesId,
              'Sexo': animal.sex.etiqueta,
              'Origen': animal.origin ?? '—',
              'Nacimiento': animal.birthDate != null ? fecha.format(animal.birthDate!) : '—',
            },
          ),
          _Seccion(
            titulo: 'Peso',
            filas: {
              'Peso inicial': animal.initialWeightKg != null ? '${animal.initialWeightKg} kg' : '—',
              'Peso actual': animal.currentWeightKg != null ? '${animal.currentWeightKg} kg' : '—',
            },
          ),
          _Seccion(
            titulo: 'Estado',
            filas: {
              'Salud': animal.healthStatus,
              'Vacunación': animal.vaccinationStatus,
              'Estado reproductivo': animal.reproductiveStatus,
              'Estado general': animal.status,
            },
          ),
          if (animal.notes != null && animal.notes!.isNotEmpty)
            _Seccion(titulo: 'Notas', filas: {'': animal.notes!}),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final Map<String, String> filas;

  const _Seccion({required this.titulo, required this.filas});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            ...filas.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: e.key.isEmpty
                    ? Text(e.value)
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 140,
                            child: Text(e.key, style: const TextStyle(color: Colors.grey)),
                          ),
                          Expanded(child: Text(e.value)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
