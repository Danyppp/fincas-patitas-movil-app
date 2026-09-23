import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/animal.dart';
import '../../models/catalogo/especie.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/especie_visual.dart';
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

/// Filtros de estado disponibles en la lista. La etiqueta es lo que ve el
/// usuario; `valor` es lo que de verdad se manda al backend. "Fallecidos"
/// se muestra así en la UI, pero el valor real guardado en la base sigue
/// siendo "Muerto" (mismo criterio que en el formulario de edición).
class _FiltroEstado {
  final String etiqueta;
  final String valor;
  const _FiltroEstado(this.etiqueta, this.valor);
}

const _filtrosEstado = [
  _FiltroEstado('Todos', 'Todos'),
  _FiltroEstado('Activos', 'Activo'),
  _FiltroEstado('Inactivos', 'Inactivo'),
  _FiltroEstado('Fallecidos', 'Muerto'),
  _FiltroEstado('Vendidos', 'Vendido'),
];

class _AnimalesListScreenState extends State<AnimalesListScreen> {
  final _buscarCtrl = TextEditingController();
  String _estadoFiltro = 'Activo';
  int? _especieFiltroId; // null = "Todos"
  Timer? _debounce;

  bool _cargando = true;
  String? _error;
  List<Animal> _animales = [];
  List<Especie> _especies = [];

  @override
  void initState() {
    super.initState();
    _cargarEspecies();
    _cargar();
  }

  /// Catálogo de especies para los chips con contador. Se carga una sola
  /// vez (no cambia con los filtros de estado/búsqueda). Si falla, los
  /// chips de especie simplemente no aparecen — el listado general sigue
  /// funcionando igual con el filtro de estado.
  Future<void> _cargarEspecies() async {
    try {
      final especies = await widget.catalogoRepository.listarEspecies();
      if (!mounted) return;
      setState(() => _especies = especies);
    } catch (_) {
      // silencioso a propósito: no es un dato crítico para poder listar.
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final pagina = await widget.repository.listar(
        estado: _estadoFiltro,
        buscar:
            _buscarCtrl.text.trim().isEmpty ? null : _buscarCtrl.text.trim(),
        limite: 100,
      );
      if (!mounted) return;
      setState(() {
        _animales = pagina.data;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  /// Lista ya filtrada por especie (filtro local, no requiere volver a
  /// pedirle al backend — el estado y la búsqueda sí van al backend).
  List<Animal> get _animalesFiltrados {
    if (_especieFiltroId == null) return _animales;
    return _animales.where((a) => a.especieId == _especieFiltroId).toList();
  }

  int _contarPorEspecie(int especieId) =>
      _animales.where((a) => a.especieId == especieId).length;

  /// Búsqueda en vivo: espera a que el usuario deje de escribir ~400ms
  /// antes de recargar, para no disparar una petición por cada letra.
  void _onBuscarCambia(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _cargar);
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
    if (creado == true) _cargar();
  }

  Widget _chip({
    required String etiqueta,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(
        etiqueta,
        style: TextStyle(
          color: seleccionado ? Colors.white : AppTheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      selected: seleccionado,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryContainer,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: StadiumBorder(
        side: BorderSide(
          color: seleccionado
              ? AppTheme.primaryContainer
              : AppTheme.outlineVariant,
          width: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animales'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(156),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                TextField(
                  controller: _buscarCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por arete (código) o nombre...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusDefault),
                      borderSide: BorderSide(color: AppTheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusDefault),
                      borderSide: BorderSide(color: AppTheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusDefault),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryContainer, width: 2),
                    ),
                  ),
                  onChanged: _onBuscarCambia,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _cargar();
                  },
                ),
                const SizedBox(height: 8),
                // Fila de especies (chips con contador real, calculado del
                // lado del cliente sobre los animales ya cargados con el
                // filtro de estado actual).
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip(
                        etiqueta: 'Todos (${_animales.length})',
                        seleccionado: _especieFiltroId == null,
                        onTap: () => setState(() => _especieFiltroId = null),
                      ),
                      for (final especie in _especies) ...[
                        const SizedBox(width: 8),
                        _chip(
                          etiqueta:
                              '${emojiEspecie(especie.nombre)} ${especie.nombre} (${_contarPorEspecie(especie.id)})',
                          seleccionado: _especieFiltroId == especie.id,
                          onTap: () =>
                              setState(() => _especieFiltroId = especie.id),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Fila de estado (llama al backend, ya que el filtro de
                // estado sí se resuelve en la consulta).
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filtrosEstado.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final filtro = _filtrosEstado[i];
                      final seleccionado = _estadoFiltro == filtro.valor;
                      return _chip(
                        etiqueta: filtro.etiqueta,
                        seleccionado: seleccionado,
                        onTap: () {
                          if (seleccionado) return;
                          setState(() => _estadoFiltro = filtro.valor);
                          _cargar();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(mensaje: _error!, onReintentar: _cargar)
              : _animalesFiltrados.isEmpty
                  ? Center(
                      child: Text(
                        _especieFiltroId != null || _buscarCtrl.text.isNotEmpty
                            ? 'No hay animales que coincidan con el filtro.'
                            : 'No hay animales registrados todavía.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _animalesFiltrados.length,
                        itemBuilder: (context, i) {
                          final animal = _animalesFiltrados[i];
                          return AnimalCard(
                            animal: animal,
                            onTap: () async {
                              final cambio =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => AnimalDetailScreen(
                                    animalId: animal.id,
                                    repository: widget.repository,
                                    catalogoRepository:
                                        widget.catalogoRepository,
                                  ),
                                ),
                              );
                              if (cambio == true) _cargar();
                            },
                          );
                        },
                      ),
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
            FilledButton(
                onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
