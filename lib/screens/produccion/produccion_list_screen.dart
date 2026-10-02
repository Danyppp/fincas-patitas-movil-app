import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/auth_session.dart';
import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/produccion/produccion_repository.dart';
import '../../theme/app_theme.dart';
import 'huevos_form_screen.dart';
import 'leche_form_screen.dart';
import 'produccion_detalle_dialog.dart';

/// Confirmación antes de eliminar (punto 5 del reporte de pruebas,
/// 2026-10-02) — el borrado ahora es lógico en el backend (el registro
/// queda marcado, no desaparece), pero sigue siendo una acción que no se
/// debe disparar por accidente con un solo toque.
Future<bool> _confirmarEliminar(
    BuildContext context, String descripcion) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Eliminar registro?'),
      content: Text(
          'Se eliminará "$descripcion". Esta acción queda registrada en el historial.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}

/// Pantalla "Registrar Producción Nueva" — reemplaza las pestañas
/// Leche/Huevos (TabBar) por los dos bloques seleccionables estilo Stitch
/// (ícono + unidad + check), con el botón de registrar en píldora debajo
/// de los bloques y el historial ("Historial producción") debajo de eso
/// (pedido de estilos, 2026-10-02, "Sección de registros").
///
/// El `TabController` se conserva tal cual estaba — sigue siendo lo que
/// decide qué lista se ve y qué formulario abre el botón — solo que ahora
/// se controla tocando los bloques en vez de una `TabBar` visible.
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

class _ProduccionListScreenState extends State<ProduccionListScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<ProduccionLeche>> _futuroLeche;
  late Future<List<ProduccionHuevos>> _futuroHuevos;

  // Controller explícito: su listener llama a setState() cada vez que
  // cambia de pestaña (incluso a mitad del swipe), así que el bloque
  // seleccionado y el botón se reconstruyen al instante.
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

  Future<void> _abrirFormulario(int tabIndex) async {
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
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = _tabController.index;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Producción Nueva'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _recargar),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _BloqueTipoProduccion(
                    icono: Icons.water_drop,
                    etiqueta: 'Leche',
                    unidad: 'Litros (L)',
                    seleccionado: tabIndex == 0,
                    onTap: () => _tabController.animateTo(0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BloqueTipoProduccion(
                    icono: Icons.egg,
                    etiqueta: 'Huevos',
                    unidad: 'Unidades',
                    seleccionado: tabIndex == 1,
                    onTap: () => _tabController.animateTo(1),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _BotonRegistrar(
              etiqueta:
                  tabIndex == 0 ? 'Registrar ordeña' : 'Registrar recolección',
              onPressed: () => _abrirFormulario(tabIndex),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Historial producción',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.outline),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
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
          ),
        ],
      ),
    );
  }
}

/// Bloque seleccionable de "Tipo de producción" (ícono + unidad + check al
/// seleccionar) — reemplaza la `TabBar` de Leche/Huevos, estilo del paso
/// "1. Tipo de Producción" del mockup de Stitch.
class _BloqueTipoProduccion extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String unidad;
  final bool seleccionado;
  final VoidCallback onTap;

  const _BloqueTipoProduccion({
    required this.icono,
    required this.etiqueta,
    required this.unidad,
    required this.seleccionado,
    required this.onTap,
  });

  // Paleta ampliada (2026-10-02, ajuste de estilos): sin seleccionar, el
  // ícono va en tono piel/pastel (mismo espíritu cálido del resto de la
  // app); al seleccionar, pasa a verde — así los dos bloques no se ven
  // "todo verde" cuando ninguno está activo.
  static const _pielFondo = Color(0xFFF6DFCB);
  static const _pielIcono = Color(0xFFB9784A);
  static const _pielBorde = Color(0xFFEAD0B4);

  @override
  Widget build(BuildContext context) {
    final colorFondoIcono = seleccionado
        ? AppTheme.primaryContainer.withValues(alpha: 0.5)
        : _pielFondo;
    final colorIcono = seleccionado ? AppTheme.primary : _pielIcono;
    final colorBorde = seleccionado ? AppTheme.primary : _pielBorde;

    return Material(
      color: seleccionado
          ? AppTheme.primaryContainer.withValues(alpha: 0.12)
          : Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: colorBorde, width: seleccionado ? 2 : 1),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: colorFondoIcono, shape: BoxShape.circle),
                    child: Icon(icono, color: colorIcono, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(etiqueta,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(unidad,
                      style: TextStyle(color: AppTheme.outline, fontSize: 12)),
                ],
              ),
              // Check más pequeño y dentro del borde de la tarjeta (antes
              // se veía cortado por quedar justo encima de la esquina).
              if (seleccionado)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle,
                        color: AppTheme.primary, size: 15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón de registrar, estilo píldora igual al del Dashboard ("Registrar
/// Producción de Hoy"), pero un 5% más grande y ubicado debajo de los
/// bloques de Leche/Huevos en vez de flotante (punto 3 del pedido de
/// estilos, 2026-10-02).
class _BotonRegistrar extends StatelessWidget {
  final String etiqueta;
  final VoidCallback onPressed;

  const _BotonRegistrar({required this.etiqueta, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF8BC98F),
      borderRadius: BorderRadius.circular(34),
      child: InkWell(
        borderRadius: BorderRadius.circular(34),
        onTap: onPressed,
        child: Padding(
          // +5% sobre el padding del botón del Dashboard (16/12 -> ~17/13).
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                    color: Color(0xFF3F6B4A), shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                etiqueta,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ],
          ),
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
                    '${r.jornada ?? 'Sin jornada'} · ${formato.format(r.registradoEn.toLocal())}'
                    '${(r.observaciones != null && r.observaciones!.isNotEmpty) ? '\n${r.observaciones}' : ''}',
                  ),
                  isThreeLine:
                      r.observaciones != null && r.observaciones!.isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        tooltip: 'Ver detalles',
                        onPressed: () => mostrarDetalleLeche(context, r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirmado = await _confirmarEliminar(
                            context,
                            '${r.litros} L de leche del ${formato.format(r.registradoEn.toLocal())}',
                          );
                          if (!confirmado) return;
                          await repository.eliminarLeche(r.id);
                          onRecargar();
                        },
                      ),
                    ],
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
                    '${origen != null ? '$origen · ' : ''}${formato.format(r.registradoEn.toLocal())}'
                    '${(r.observaciones != null && r.observaciones!.isNotEmpty) ? '\n${r.observaciones}' : ''}',
                  ),
                  isThreeLine:
                      r.observaciones != null && r.observaciones!.isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.info_outline),
                        tooltip: 'Ver detalles',
                        onPressed: () => mostrarDetalleHuevos(context, r),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirmado = await _confirmarEliminar(
                            context,
                            '${r.cantidad} huevos del ${formato.format(r.registradoEn.toLocal())}',
                          );
                          if (!confirmado) return;
                          await repository.eliminarHuevos(r.id);
                          onRecargar();
                        },
                      ),
                    ],
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
