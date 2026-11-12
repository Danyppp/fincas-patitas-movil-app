import 'package:flutter/material.dart';

import '../../core/auth_session.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/boton_pill.dart';
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
///
/// 2026-11-10 (Fase 2, Estilos): se descartan de este listado la tarjeta
/// de "Finca" con fotos/certificación, la barra de estadísticas (Animales
/// totales/Lotes activos/Potreros) y el buscador + filtros por especie
/// del mockup de Stitch -- nada de eso se pidió ni está respaldado por el
/// backend en esta pantalla (ver decisiones-diseno-vs-backend-ubicacion.md,
/// sección 3). Se conserva la estructura de Entrega 2 (tabs + FAB), solo
/// con el look visual del tema: tarjetas con una etiqueta de especie,
/// ícono según el tipo de lugar, y la pestaña con pill de color.
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppTheme.onPrimary,
                unselectedLabelColor: AppTheme.onSurfaceVariant,
                labelStyle: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: 'Lotes (${_lotes.length})'),
                  Tab(text: 'Potreros (${_potreros.length})'),
                ],
              ),
            ),
          ),
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
        backgroundColor: AppTheme.primaryContainer,
        foregroundColor: AppTheme.onPrimary,
        shape: const StadiumBorder(),
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        itemCount: _lotes.length,
        itemBuilder: (_, i) {
          final lote = _lotes[i];
          return _filaLugar(
            onTap: () => _abrirLote(lote),
            icono: Icons.grid_view_outlined,
            colorIcono: AppTheme.primary,
            colorFondoIcono: AppTheme.primaryContainer,
            titulo: lote.nombre,
            etiqueta: lote.especie?.nombre,
            detalle: [
              if (lote.encargado != null)
                'Encargado: ${lote.encargado!.nombreUsuario}',
            ].join(' · '),
            cantidad: lote.cantidadAnimales,
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        itemCount: _potreros.length,
        itemBuilder: (_, i) {
          final potrero = _potreros[i];
          return _filaLugar(
            onTap: () => _abrirPotrero(potrero),
            icono: Icons.map_outlined,
            colorIcono: AppTheme.tertiary,
            colorFondoIcono: AppTheme.tertiaryContainer,
            fotoUrl: potrero.fotoUrl,
            titulo: potrero.nombre,
            etiqueta: potrero.estado,
            detalle: [
              if (potrero.capacidadAnimales != null)
                'Capacidad: ${potrero.capacidadAnimales}',
              if (potrero.encargados.isNotEmpty)
                '${potrero.encargados.length} encargado(s)',
            ].join(' · '),
            cantidad: null,
          );
        },
      ),
    );
  }

  // Fila compartida entre Lotes y Potreros: ícono (o foto, solo Potrero
  // la tiene) en círculo de color, nombre, etiqueta de especie/estado y
  // una línea de detalle. Card + InkWell (no ListTile con botón) -- acá
  // el trailing es solo un Icon, sin riesgo del bug de
  // ButtonStyleButton+Card documentado en el doc de decisiones.
  Widget _filaLugar({
    required VoidCallback onTap,
    required IconData icono,
    required Color colorIcono,
    required Color colorFondoIcono,
    required String titulo,
    required String detalle,
    String? etiqueta,
    String? fotoUrl,
    int? cantidad,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorFondoIcono.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  image: fotoUrl != null
                      ? DecorationImage(
                          image: NetworkImage(fotoUrl), fit: BoxFit.cover)
                      : null,
                ),
                child: fotoUrl == null
                    ? Icon(icono, color: colorIcono, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (etiqueta != null && etiqueta.isNotEmpty) ...[
                      EtiquetaPill(
                        texto: etiqueta,
                        color: colorFondoIcono.withValues(alpha: 0.5),
                        colorTexto: colorIcono,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(titulo,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (detalle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(detalle,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (cantidad != null) ...[
                const SizedBox(width: 8),
                Column(
                  children: [
                    Text('$cantidad',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: AppTheme.primary)),
                    Text('cabezas',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: AppTheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
