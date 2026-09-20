import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/produccion/produccion_repository.dart';
import 'huevos_form_screen.dart';
import 'leche_form_screen.dart';

class ProduccionListScreen extends StatefulWidget {
  final ProduccionRepository repository;
  final AnimalRepository animalRepository;

  const ProduccionListScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
  });

  @override
  State<ProduccionListScreen> createState() => _ProduccionListScreenState();
}

class _ProduccionListScreenState extends State<ProduccionListScreen> {
  late Future<List<ProduccionLeche>> _futuroLeche;
  late Future<List<ProduccionHuevos>> _futuroHuevos;

  @override
  void initState() {
    super.initState();
    _futuroLeche = widget.repository.listarLeche();
    _futuroHuevos = widget.repository.listarHuevos();
  }

  void _recargar() {
    setState(() {
      _futuroLeche = widget.repository.listarLeche();
      _futuroHuevos = widget.repository.listarHuevos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Producción'),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _recargar)],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.water_drop_outlined), text: 'Leche'),
              Tab(icon: Icon(Icons.egg_outlined), text: 'Huevos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ListaLeche(
              futuro: _futuroLeche,
              onRecargar: _recargar,
              repository: widget.repository,
              animalRepository: widget.animalRepository,
            ),
            _ListaHuevos(
              futuro: _futuroHuevos,
              onRecargar: _recargar,
              repository: widget.repository,
            ),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) {
            final tabIndex = DefaultTabController.of(context).index;
            return FloatingActionButton.extended(
              onPressed: () async {
                final cambio = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => tabIndex == 0
                        ? LecheFormScreen(
                            repository: widget.repository,
                            animalRepository: widget.animalRepository,
                          )
                        : HuevosFormScreen(repository: widget.repository),
                  ),
                );
                if (cambio == true) _recargar();
              },
              icon: const Icon(Icons.add),
              label: Text(tabIndex == 0 ? 'Registrar ordeña' : 'Registrar recolección'),
            );
          },
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

  const _ListaLeche({
    required this.futuro,
    required this.onRecargar,
    required this.repository,
    required this.animalRepository,
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
        if (registros.isEmpty) return const Center(child: Text('No hay registros de leche todavía.'));
        return RefreshIndicator(
          onRefresh: () async => onRecargar(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: registros.length,
            itemBuilder: (context, i) {
              final r = registros[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () async {
                    final cambio = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => LecheFormScreen(
                          repository: repository,
                          animalRepository: animalRepository,
                          registroExistente: r,
                        ),
                      ),
                    );
                    if (cambio == true) onRecargar();
                  },
                  leading: const Icon(Icons.water_drop, color: Color(0xFF3F6B4A)),
                  title: Text('${r.litros} L · ${r.animal?.nombreVisible ?? 'Animal #${r.animalId}'}'),
                  subtitle: Text('${r.jornada ?? 'Sin jornada'} · ${formato.format(r.registradoEn)}'),
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

  const _ListaHuevos({required this.futuro, required this.onRecargar, required this.repository});

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
        if (registros.isEmpty) return const Center(child: Text('No hay registros de huevos todavía.'));
        return RefreshIndicator(
          onRefresh: () async => onRecargar(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: registros.length,
            itemBuilder: (context, i) {
              final r = registros[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: () async {
                    final cambio = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => HuevosFormScreen(repository: repository, registroExistente: r),
                      ),
                    );
                    if (cambio == true) onRecargar();
                  },
                  leading: const Icon(Icons.egg, color: Color(0xFF3F6B4A)),
                  title: Text('${r.cantidad} huevos'),
                  subtitle: Text(
                    '${r.loteNombre != null ? 'Lote: ${r.loteNombre} · ' : ''}${formato.format(r.registradoEn)}',
                  ),
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
