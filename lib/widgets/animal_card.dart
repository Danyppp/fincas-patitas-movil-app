import 'package:flutter/material.dart';

import '../models/animal.dart';

/// Tarjeta de un animal en el listado. Widget "tonto": no llama al
/// repositorio ni conoce de dónde vienen los datos — solo pinta lo que
/// recibe y avisa cuando lo tocan.
class AnimalCard extends StatelessWidget {
  final Animal animal;
  final VoidCallback onTap;

  const AnimalCard({super.key, required this.animal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            animal.sex.etiqueta == 'Macho' ? Icons.male : Icons.female,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(animal.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${animal.code} · ${animal.species?.displayName ?? animal.speciesId}'),
        trailing: _EstadoChip(status: animal.status),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String status;
  const _EstadoChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final activo = status == 'activo';
    final color = activo ? Colors.green : Colors.orange;
    return Chip(
      label: Text(
        activo ? 'Activo' : status,
        style: TextStyle(color: color.shade900, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      backgroundColor: color.shade50,
      side: BorderSide(color: color.shade200),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}
