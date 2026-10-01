import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/auth_session.dart';
import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/produccion/produccion_repository.dart';
import 'huevos_form_screen.dart';
import 'leche_form_screen.dart';

class ProduccionListScreen extends StatefulWidget {
  final ProduccionRepository repository;
  final AnimalRepository animalRepository;
  final CatalogoRepository catalogoRepository;
  final AuthSession session;

  const ProduccionListScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    required this.catalogoRepository,
    required this.session,
  });

  @override
  State<ProduccionListScreen> createState() => _ProduccionListScreenState();
}

// "with SingleTickerProviderStateMixin" es necesario para poder crear el
// TabController nosotros mismos (en vez de depender de DefaultTabController,
// que es justo lo que causaba que el FAB no se actualizara en tiempo real).
class _ProduccionListScreenState extends State<ProduccionListScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<ProduccionLeche>> _futuroLeche;
  late Future<List<ProduccionHuevos>> _futuroHuevos;

  // Controller explícito: su listener llama a setState() cada vez que
  // cambia de pestaña (incluso a mitad del swipe), así que el FAB se
  // reconstruye al instante, sin necesidad de refrescar la pantalla.
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _futuroLeche = widget.repository.listarLeche();
    _futuroHuevos = widget.repository.listarHuevos();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _recargar() {
    setState(() {
      _futuroLeche = widget.repository.listarLeche();
      _futuroHuevos = widget.repository.listarHuevos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = _tabController.index;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Producción'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _recargar)
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.water_drop_outlined), text: 'Leche'),
            Tab(icon: Icon(Icons.egg_outlined), text: 'Huevos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ListaLeche(
            futuro: _futuroLeche,
            onRecargar: _recargar,
            repository: widget.repository,
            animalRepository: widget.animalRepository,
            catalogoRepository: widget.catalogoRepository,
            session: widget.session,
          ),
          _ListaHuevos(
            futuro: _futuroHuevos,
            onRecargar: _recargar,
            repository: widget.repository,
            animalRepository: widget.animalRepository,
            catalogoRepository: widget.catalogoRepository,
            session: widget.session,
          ),
        ],
      ),
      // Transform.scale(0.7) reduce el botón un 30% (corrección 2026-10-01)
      // manteniendo su forma y comportamiento intactos — sigue siendo el
      // mismo FloatingActionButton.extended, solo dibujado más pequeño.
      floatingActionButton: Transform.scale(
        scale: 0.7,
        alignment: Alignment.bottomRight,
        child: FloatingActionButton.extended(
          onPressed: () async {
            final cambio = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => tabIndex == 0
                    ? LecheFormScreen(
                        repository: widget.repository,
                        animalRepository: widget.animalRepository,
                        catalogoRepository: widget.catalogoRepository,
                        session: widget.session,
                      )
                    : HuevosFormScreen(
                        repository: widget.repository,
                        animalRepository: widget.animalRepository,
                        catalogoRepository: widget.catalogoRepository,
                        session: widget.session,
                      ),
              ),
            );
            if (cambio == true) _recargar();
          },
          icon: const Icon(Icons.add),
          label: Text(
              tabIndex == 0 ? 'Registrar ordeña' : 'Registrar recolección'),
        ),
      ),
    );
  }
}

class _ListaLeche extends StatelessWidget {
  final Future<List<ProduccionLeche>> futuro;
  final VoidCallback onRecargar;
  final ProduccionRepository repository;
  final AnimalRepository animalRepository;
  final CatalogoRepository catalogoRepository;
  final AuthSession session;

  const _ListaLeche({
    required this.futuro,
    required this.onRecargar,
    required this.repository,
    required this.animalRepository,
    required this.catalogoRepository,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final formato = DateFormat('yyyy-MM-dd HH:mm');
    return FutureBuilder<List<ProduccionLeche>>(
      future: futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final registros = snapshot.data ?? [];
        if (registros.isEmpty)
          return const Center(
              child: Text('No hay registros de leche todavía.'));
        return RefreshIndicator(
          onRefresh: () async => onRecargar(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: registros.length,
            itemBuilder: (context, i) {
              final r = registros[i];
              final origen = r.esPorLote
                  ? (r.loteNombre ?? 'Lote #${r.loteId}')
                  : (r.animal?.nombreVisible ?? 'Animal #${r.animalId}');
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () async {
                    final cambio = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => LecheFormScreen(
                          repository: repository,
                          animalRepository: animalRepository,
                          catalogoRepository: catalogoRepository,
                          session: session,
                          registroExistente: r,
                        ),
                      ),
                    );
                    if (cambio == true) onRecargar();
                  },
                  leading: Icon(r.esPorLote ? Icons.groups : Icons.pets,
                      color: const Color(0xFF3F6B4A)),
                  title: Text('${r.litros} L · $origen'),
                  subtitle: Text(
                    '${r.jornada ?? 'Sin jornada'} · ${formato.format(r.registradoEn)}'
                    '${(r.observaciones != null && r.observaciones!.isNotEmpty) ? '\n${r.observaciones}' : ''}',
                  ),
                  isThreeLine:
                      r.observaciones != null && r.observaciones!.isNotEmpty,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await repository.eliminarLeche(r.id);
                      onRecargar();
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ListaHuevos extends StatelessWidget {
  final Future<List<ProduccionHuevos>> futuro;
  final VoidCallback onRecargar;
  final ProduccionRepository repository;
  final AnimalRepository animalRepository;
  final CatalogoRepository catalogoRepository;
  final AuthSession session;

  const _ListaHuevos({
    required this.futuro,
    required this.onRecargar,
    required this.repository,
    required this.animalRepository,
    required this.catalogoRepository,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final formato = DateFormat('yyyy-MM-dd HH:mm');
    return FutureBuilder<List<ProduccionHuevos>>(
      future: futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final registros = snapshot.data ?? [];
        if (registros.isEmpty)
          return const Center(
              child: Text('No hay registros de huevos todavía.'));
        return RefreshIndicator(
          onRefresh: () async => onRecargar(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: registros.length,
            itemBuilder: (context, i) {
              final r = registros[i];
              final origen = r.esPorLote
                  ? (r.loteNombre ?? 'Lote #${r.loteId}')
                  : (r.animalId != null
                      ? (r.animal?.nombreVisible ?? 'Animal #${r.animalId}')
                      : null);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () async {
                    final cambio = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => HuevosFormScreen(
                          repository: repository,
                          animalRepository: animalRepository,
                          catalogoRepository: catalogoRepository,
                          session: session,
                          registroExistente: r,
                        ),
                      ),
                    );
                    if (cambio == true) onRecargar();
                  },
                  leading: Icon(r.esPorLote ? Icons.groups : Icons.egg,
                      color: const Color(0xFF3F6B4A)),
                  title: Text(
                    r.cantidadRotos > 0
                        ? '${r.cantidad} huevos (${r.cantidadRotos} rotos)'
                        : '${r.cantidad} huevos',
                  ),
                  subtitle: Text(
                    '${origen != null ? '$origen · ' : ''}${formato.format(r.registradoEn)}'
                    '${(r.observaciones != null && r.observaciones!.isNotEmpty) ? '\n${r.observaciones}' : ''}',
                  ),
                  isThreeLine:
                      r.observaciones != null && r.observaciones!.isNotEmpty,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await repository.eliminarHuevos(r.id);
                      onRecargar();
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
