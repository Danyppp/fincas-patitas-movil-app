import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reproduccion/event_type.dart';
import '../models/reproduccion/reproductive_event.dart';

/// Tarjeta de un evento reproductivo. Widget "tonto", igual que
/// [AnimalCard]: no conoce el repositorio, solo pinta lo que recibe.
class ReproductionEventCard extends StatelessWidget {
  final ReproductiveEvent evento;
  final VoidCallback? onTap;

  const ReproductionEventCard({super.key, required this.evento, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('d MMM y', 'es');
    final padre = evento.maleAnimal?.etiqueta ?? evento.fatherExternal ?? 'Sin registrar';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    evento.femaleAnimal?.etiqueta ?? evento.animalId,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                if (evento.gestationStatus != null) _EstadoChip(estado: evento.gestationStatus!),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${evento.eventType.etiqueta} · ${fecha.format(evento.eventDate)}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text('Padre: $padre', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            if (evento.estimatedDeliveryDate != null) ...[
              const SizedBox(height: 2),
              Text(
                'Parto estimado: ${fecha.format(evento.estimatedDeliveryDate!)}'
                '${evento.estimatedDeliveryDateTo != null ? ' – ${fecha.format(evento.estimatedDeliveryDateTo!)}' : ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final GestationStatus estado;
  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      GestationStatus.confirmada => Colors.blue,
      GestationStatus.partoExitoso => Colors.green,
      GestationStatus.fallida => Colors.red,
      GestationStatus.enSeguimiento => Colors.orange,
    };
    return Chip(
      label: Text(
        estado.etiqueta,
        style: TextStyle(color: color.shade900, fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
      backgroundColor: color.shade50,
      side: BorderSide(color: color.shade200),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
    );
  }
}
