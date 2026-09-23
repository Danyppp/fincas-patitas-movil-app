import 'package:flutter/material.dart';

import '../models/animal.dart';
import '../theme/app_theme.dart';
import '../utils/especie_visual.dart';

/// Tarjeta de animal en el listado, siguiendo el mockup de Stitch
/// (`listado_de_animales/screen.png`): avatar por especie, código en pill,
/// raza como subtítulo, pill de estado a la derecha y una fila inferior
/// con el lote (si tiene). Como el backend no soporta fotos de animales,
/// el "avatar" es un ícono/emoji según la especie en vez de una foto real
/// (decisión tomada con Dany durante la etapa de estilos).
class AnimalCard extends StatelessWidget {
  final Animal animal;
  final VoidCallback onTap;

  const AnimalCard({super.key, required this.animal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final especie = animal.especie?.nombre ?? 'Especie #${animal.especieId}';
    final raza = animal.raza?.nombre ?? 'Raza #${animal.razaId}';
    final esHembra = animal.genero.toLowerCase().startsWith('h');
    final colores = colorEstado(animal.estado);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor:
                    AppTheme.primaryContainer.withValues(alpha: 0.15),
                child: Text(emojiEspecie(animal.especie?.nombre),
                    style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            animal.nombreVisible,
                            style: textTheme.headlineSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          esHembra ? Icons.female : Icons.male,
                          size: 18,
                          color: esHembra
                              ? const Color(0xFFAE2F34)
                              : const Color(0xFF006E1C),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerHigh,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            '#${animal.codigo}',
                            style: textTheme.labelSmall?.copyWith(
                                color: AppTheme.onSurface, letterSpacing: 0),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$especie · $raza',
                            style: textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (animal.loteNombre != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.grid_view_rounded,
                              size: 14, color: AppTheme.outline),
                          const SizedBox(width: 4),
                          Text(animal.loteNombre!, style: textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colores.fondo,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  animal.estado,
                  style: textTheme.labelMedium
                      ?.copyWith(color: colores.texto, letterSpacing: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
