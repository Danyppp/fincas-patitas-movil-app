import 'package:flutter/material.dart';

import '../../models/animal.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../widgets/animal_card.dart';
import 'animal_detail_screen.dart';
import 'animal_form_screen.dart';

class AnimalesListScreen extends StatefulWidget {
  final AnimalRepository repository;
  final CatalogoRepository catalogoRepository;

  const AnimalesListScreen({
    super.key,
    required this.repository,
    required this.catalogoRepository,
  });

  @override
  State<AnimalesListScreen> createState() => _AnimalesListScreenState();
}

class _AnimalesListScreenState extends State<AnimalesListScreen> {
  late Future<List<Animal>> _futuro;
  final _buscarCtrl = TextEditingController();
  String _estadoFiltro = 'Activo';

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  Future<List<Animal>> _cargar() async {
    final pagina = await widget.repository.listar(
      estado: _estadoFiltro,
      buscar: _buscarCtrl.text.trim().isEmpty ? null : _buscarCtrl.text.trim(),
      limite: 100,
    );
    return pagina.data;
  }

  void _recargar() {
    setState(() => _futuro = _cargar());
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _abrirFormularioCreacion() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AnimalFormScreen(
          repository: widget.repository,
          catalogoRepository: widget.catalogoRepository,
        ),
      ),
    );
    if (creado == true) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animales'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _recargar),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                TextField(
                  controller: _buscarCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o código...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (_) => _recargar(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'Activo', label: Text('Activos')),
                          ButtonSegment(value: 'Todos', label: Text('Todos')),
                        ],
                        selected: {_estadoFiltro},
                        onSelectionChanged: (s) {
                          setState(() => _estadoFiltro = s.first);
                          _recargar();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Animal>>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(mensaje: '${snapshot.error}', onReintentar: _recargar);
          }
          final animales = snapshot.data ?? [];
          if (animales.isEmpty) {
            return const Center(child: Text('No hay animales registrados todavía.'));
          }
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: animales.length,
              itemBuilder: (context, i) {
                final animal = animales[i];
                return AnimalCard(
                  animal: animal,
                  onTap: () async {
                    final cambio = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => AnimalDetailScreen(
                          animalId: animal.id,
                          repository: widget.repository,
                          catalogoRepository: widget.catalogoRepository,
                        ),
                      ),
                    );
                    if (cambio == true) _recargar();
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormularioCreacion,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo animal'),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const _ErrorState({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
