import 'package:flutter/material.dart';

import '../../core/auth_session.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import 'lote_detalle_screen.dart';
import 'lote_form_screen.dart';
import 'potrero_detalle_screen.dart';
import 'potrero_form_screen.dart';

/// Pantalla "vista_lotes_y_potreros" del mockup -- lista de Lotes y
/// Potreros en dos pestañas, a la que se llega desde el atajo "Lotes y
/// Potreros" del Inicio de Ubicación.
///
/// Fase 1 (funcional, pocos estilos): trae los datos reales del backend;
/// tocar una fila abre su pantalla de Detalle propia (con Editar/Eliminar
/// y, en Potrero, la foto); el FAB "Crear" abre el formulario en modo
/// creación. Al volver de cualquiera de los dos, la lista se recarga sola
/// (no hace falta revisar qué devolvió la navegación -- recargar siempre
/// es barato y evita que se quede desactualizada).
class LotesPotrerosListScreen extends StatefulWidget {
  final UbicacionRepository repository;
  final CatalogoRepository catalogoRepository;
  final AnimalRepository animalRepository;
  final AuthSession session;

  const LotesPotrerosListScreen({
    super.key,
    required this.repository,
    required this.catalogoRepository,
    required this.animalRepository,
    required this.session,
  });

  @override
  State<LotesPotrerosListScreen> createState() =>
      _LotesPotrerosListScreenState();
}

class _LotesPotrerosListScreenState extends State<LotesPotrerosListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<LoteAnimal> _lotes = [];
  List<Potrero> _potreros = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Sin esto, el FAB ("Crear Lote"/"Crear Potrero") se queda con el
    // texto de la pestaña con la que arrancó la pantalla -- TabBarView sí
    // cambia de contenido solo, pero nada más en este widget se reconstruye
    // automáticamente al cambiar de pestaña.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lotes = await widget.repository.listarLotes();
      final potreros = await widget.repository.listarPotreros();
      if (!mounted) return;
      setState(() {
        _lotes = lotes;
        _potreros = potreros;
      });
    } catch (e) {
      setState(() => _error = 'No se pudo cargar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _crear() async {
    final esLote = _tabController.index == 0;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => esLote
            ? LoteFormScreen(
                repository: widget.repository,
                catalogoRepository: widget.catalogoRepository,
              )
            : PotreroFormScreen(repository: widget.repository),
      ),
    );
    _cargar();
  }

  Future<void> _abrirLote(LoteAnimal lote) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoteDetalleScreen(
          loteId: lote.id,
          repository: widget.repository,
          catalogoRepository: widget.catalogoRepository,
          animalRepository: widget.animalRepository,
        ),
      ),
    );
    _cargar();
  }

  Future<void> _abrirPotrero(Potrero potrero) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PotreroDetalleScreen(
          potreroId: potrero.id,
          repository: widget.repository,
          animalRepository: widget.animalRepository,
        ),
      ),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes y Potreros'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Lotes (${_lotes.length})'),
            Tab(text: 'Potreros (${_potreros.length})'),
          ],
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _listaLotes(),
                    _listaPotreros(),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Crear Lote' : 'Crear Potrero'),
      ),
    );
  }

  Widget _listaLotes() {
    if (_lotes.isEmpty) {
      return const Center(child: Text('No hay lotes todavía'));
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _lotes.length,
        itemBuilder: (_, i) {
          final lote = _lotes[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.grid_view_outlined),
              title: Text(lote.nombre),
              subtitle: Text([
                if (lote.especie != null) lote.especie!.nombre,
                '${lote.cantidadAnimales} animal(es)',
                if (lote.encargado != null)
                  'Encargado: ${lote.encargado!.nombreUsuario}',
              ].join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _abrirLote(lote),
            ),
          );
        },
      ),
    );
  }

  Widget _listaPotreros() {
    if (_potreros.isEmpty) {
      return const Center(child: Text('No hay potreros todavía'));
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _potreros.length,
        itemBuilder: (_, i) {
          final potrero = _potreros[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: potrero.fotoUrl != null
                  ? CircleAvatar(
                      backgroundImage: NetworkImage(potrero.fotoUrl!))
                  : const CircleAvatar(child: Icon(Icons.map_outlined)),
              title: Text(potrero.nombre),
              subtitle: Text([
                potrero.estado ?? 'Sin estado',
                if (potrero.capacidadAnimales != null)
                  'Capacidad: ${potrero.capacidadAnimales}',
                if (potrero.encargados.isNotEmpty)
                  '${potrero.encargados.length} encargado(s)',
              ].join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _abrirPotrero(potrero),
            ),
          );
        },
      ),
    );
  }
}
