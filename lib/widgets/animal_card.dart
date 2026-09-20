import 'package:flutter/material.dart';

import '../models/animal.dart';

class AnimalCard extends StatelessWidget {
  final Animal animal;
  final VoidCallback onTap;

  const AnimalCard({super.key, required this.animal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final especie = animal.especie?.nombre ?? 'Especie #${animal.especieId}';
    final raza = animal.raza?.nombre ?? 'Raza #${animal.razaId}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: animal.estado == 'Activo'
              ? const Color(0xFF3F6B4A).withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.2),
          child: Icon(
            animal.genero.toLowerCase().startsWith('h') ? Icons.female : Icons.male,
            color: animal.estado == 'Activo' ? const Color(0xFF3F6B4A) : Colors.grey,
          ),
        ),
        title: Text(animal.nombreVisible),
        subtitle: Text('$especie · $raza · ${animal.codigo}'),
        trailing: Chip(
          label: Text(animal.estado, style: const TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
