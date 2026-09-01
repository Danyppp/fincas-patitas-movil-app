import 'package:flutter/material.dart';

import '../../models/animal.dart';
import '../../repositories/animal_repository.dart';
import '../../widgets/animal_card.dart';
import 'animal_detail_screen.dart';

/// Pantalla principal del módulo de animales: lista todos los animales
/// de la finca. Recibe el repositorio por constructor (inyección de
/// dependencias simple) — no crea `MockAnimalRepository()` ni
/// `ApiAnimalRepository()` por su cuenta, así que no le importa cuál de
/// las dos implementaciones está usando.
class AnimalesListScreen extends StatefulWidget {
  final AnimalRepository repository;

  const AnimalesListScreen({super.key, required this.repository});

  @override
  State<AnimalesListScreen> createState() => _AnimalesListScreenState();
}

class _AnimalesListScreenState extends State<AnimalesListScreen> {
  late Future<List<Animal>> _futureAnimales;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _futureAnimales = widget.repository.getAll();
  }

  Future<void> _refrescar() async {
    setState(_cargar);
    await _futureAnimales;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animales')),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: FutureBuilder<List<Animal>>(
          future: _futureAnimales,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                mensaje: 'No se pudo cargar la lista de animales.',
                detalle: snapshot.error.toString(),
                onReintentar: _refrescar,
              );
            }
            final animales = snapshot.data ?? const [];
            if (animales.isEmpty) {
              return const _EmptyState();
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: animales.length,
              itemBuilder: (context, index) {
                final animal = animales[index];
                return AnimalCard(
                  animal: animal,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AnimalDetailScreen(animal: animal),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registrar animal — próximo paso del módulo')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo animal'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.pets, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('Todavía no hay animales registrados.'),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String mensaje;
  final String detalle;
  final VoidCallback onReintentar;

  const _ErrorState({
    required this.mensaje,
    required this.detalle,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
