import 'package:flutter/material.dart';

import '../../repositories/animal_repository.dart';
import '../../repositories/reproduction_repository.dart';
import '../animales/animales_list_screen.dart';
import '../placeholder/proximamente_screen.dart';
import '../reproduccion/reproduccion_list_screen.dart';

/// Navegación base de la app: una barra inferior con los 4 módulos del
/// proyecto (Animales, Reproducción, Producción, Inventario). Animales y
/// Reproducción ya tienen pantalla real; Producción e Inventario siguen
/// como [ProximamenteScreen] hasta que les toque en el cronograma.
class HomeShell extends StatefulWidget {
  final AnimalRepository animalRepository;
  final ReproductionRepository reproductionRepository;

  const HomeShell({
    super.key,
    required this.animalRepository,
    required this.reproductionRepository,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final paginas = [
      AnimalesListScreen(repository: widget.animalRepository),
      ReproduccionListScreen(repository: widget.reproductionRepository),
      const ProximamenteScreen(titulo: 'Producción', icono: Icons.bar_chart_outlined),
      const ProximamenteScreen(titulo: 'Inventario', icono: Icons.inventory_2_outlined),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets), label: 'Animales'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Reproducción'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Producción'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventario'),
        ],
      ),
    );
  }
}
