import 'package:flutter/material.dart';

import '../../core/auth_session.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/inventario/insumo_repository.dart';
import '../../repositories/produccion/produccion_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../animales/animales_list_screen.dart';
import '../inventario/inventario_list_screen.dart';
import '../produccion/produccion_dashboard_screen.dart';
import '../reproduccion/reproduccion_list_screen.dart';
import 'cuenta_screen.dart';

/// Navegación base de la app: barra inferior con los módulos priorizados
/// de este sprint (Animales, Reproducción, Producción, Inventario) y
/// Cuenta (perfil + cerrar sesión).
///
/// Desde el 2026-10-01, "Producción" abre primero el Dashboard (resumen de
/// hoy, comparativo vs ayer, desglose por lote, historial e historial
/// reciente) en vez de ir directo a la lista de Leche/Huevos — esa lista
/// sigue existiendo tal cual, pero ahora se llega a ella desde el botón
/// "Registrar producción de hoy" del Dashboard.
class HomeShell extends StatefulWidget {
  final AnimalRepository animalRepository;
  final CatalogoRepository catalogoRepository;
  final ReproduccionRepository reproduccionRepository;
  final ProduccionRepository produccionRepository;
  final InsumoRepository insumoRepository;
  final AuthSession session;

  const HomeShell({
    super.key,
    required this.animalRepository,
    required this.catalogoRepository,
    required this.reproduccionRepository,
    required this.produccionRepository,
    required this.insumoRepository,
    required this.session,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final paginas = [
      AnimalesListScreen(
        repository: widget.animalRepository,
        catalogoRepository: widget.catalogoRepository,
      ),
      ReproduccionListScreen(
        repository: widget.reproduccionRepository,
        animalRepository: widget.animalRepository,
      ),
      ProduccionDashboardScreen(
        repository: widget.produccionRepository,
        animalRepository: widget.animalRepository,
        catalogoRepository: widget.catalogoRepository,
        session: widget.session,
      ),
      InventarioListScreen(
        repository: widget.insumoRepository,
        catalogoRepository: widget.catalogoRepository,
        session: widget.session,
      ),
      CuentaScreen(session: widget.session),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.pets_outlined),
              selectedIcon: Icon(Icons.pets),
              label: 'Animales'),
          NavigationDestination(
              icon: Icon(Icons.favorite_outline),
              selectedIcon: Icon(Icons.favorite),
              label: 'Reproducción'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Producción'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Inventario'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Cuenta'),
        ],
      ),
    );
  }
}
