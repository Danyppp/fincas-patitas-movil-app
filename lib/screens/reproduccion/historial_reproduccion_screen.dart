import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';
import 'seguimiento_detalle_screen.dart';

/// Historial completo de Reproducción (2026-10-21, nuevo a pedido de la
/// Parte 1): "al final del inicio aparezca el Historial de todos los
/// registros hechos y eliminados (para la auditoria)". Es la ÚNICA
/// pantalla que pide `incluirEliminados: true` al repositorio -- ningún
/// otro lugar de la app debe hacerlo.
///
/// A diferencia de las 4 pantallas de las burbujas, aquí el detalle se abre
/// en modo SOLO LECTURA (`permitirAcciones: false`) -- el Historial es para
/// auditar, no para seguir operando sobre los registros; editar/eliminar
/// vive en las pantallas de Gestaciones/Partos pendientes/Partos este
/// mes/Fertilidad.
class HistorialReproduccionScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;

  const HistorialReproduccionScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
  });

  @override
  State<HistorialReproduccionScreen> createState() =>
      _HistorialReproduccionScreenState();
}

class _HistorialReproduccionScreenState
    extends State<HistorialReproduccionScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _busquedaController = TextEditingController();

  List<SeguimientoGestacion> _registros = [];
  bool _cargando = true;
  String? _error;

  // Todos | Activos | Eliminados -- ayuda a no perderse entre tantos
  // registros una vez que el historial crece.
  String _filtro = 'Todos';
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargar();
    _busquedaController.addListener(() {
      setState(() => _busqueda = _busquedaController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final todos = await widget.repository.listar(incluirEliminados: true);
      if (mounted) setState(() => _registros = todos);
    } catch (e) {
      setState(() => _error = 'No se pudo cargar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<SeguimientoGestacion> get _registrosFiltrados {
    Iterable<SeguimientoGestacion> base = _registros;
    switch (_filtro) {
      case 'Activos':
        base = base.where((r) => !r.estaEliminado);
        break;
      case 'Eliminados':
        base = base.where((r) => r.estaEliminado);
        break;
    }
    if (_busqueda.isNotEmpty) {
      base = base.where((r) {
        final nombre = (r.animal?.nombreVisible ?? '').toLowerCase();
        final codigo = (r.animal?.codigo ?? '').toLowerCase();
        return nombre.contains(_busqueda) || codigo.contains(_busqueda);
      });
    }
    return base.toList();
  }

  void _abrirDetalle(SeguimientoGestacion registro) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeguimientoDetalleScreen(
          repository: widget.repository,
          animalRepository: widget.animalRepository,
          registro: registro,
          permitirAcciones: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalRegistros = _registros.length;

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Historial de Reproducción',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Fincas y Patitas · Hacienda',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.green[800],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar / recargar',
            onPressed: _cargar,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _busquedaController,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o arete...',
                hintStyle: TextStyle(
                  color: AppTheme.outline,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: AppTheme.outline),
                filled: true,
                fillColor: AppTheme.surfaceContainerLowest,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  borderSide: BorderSide(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  borderSide: BorderSide(
                      color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _ChipFiltro(
                                texto: 'Todos',
                                contador: totalRegistros,
                                seleccionado: _filtro == 'Todos',
                                colorSeleccionado: AppTheme.primary,
                                onTap: () => setState(() => _filtro = 'Todos'),
                              ),
                              const SizedBox(width: 10),
                              _ChipFiltro(
                                texto: 'Activos',
                                seleccionado: _filtro == 'Activos',
                                colorSeleccionado: AppTheme.primary,
                                onTap: () =>
                                    setState(() => _filtro = 'Activos'),
                              ),
                              const SizedBox(width: 10),
                              _ChipFiltro(
                                texto: 'Eliminados',
                                seleccionado: _filtro == 'Eliminados',
                                colorSeleccionado: AppTheme.error,
                                onTap: () =>
                                    setState(() => _filtro = 'Eliminados'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            if (_registrosFiltrados.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 60),
                                child: Center(
                                  child: Text(
                                    'No hay registros con este filtro',
                                    style: TextStyle(color: AppTheme.outline),
                                  ),
                                ),
                              )
                            else
                              for (final r in _registrosFiltrados)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _TarjetaHistorial(
                                    registro: r,
                                    dateFormat: _dateFormat,
                                    onTap: () => _abrirDetalle(r),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

/// Chip de filtro estilo "píldora" tal como en el mockup: "Todos" lleva un
/// contador pequeño, las demás son solo texto. Seleccionado = relleno de
/// color; sin seleccionar = borde fino sobre fondo blanco.
class _ChipFiltro extends StatelessWidget {
  final String texto;
  final int? contador;
  final bool seleccionado;
  final Color colorSeleccionado;
  final VoidCallback onTap;

  const _ChipFiltro({
    required this.texto,
    this.contador,
    required this.seleccionado,
    required this.colorSeleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: seleccionado
                ? colorSeleccionado
                : AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: seleccionado
                ? null
                : Border.all(color: AppTheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                texto,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: seleccionado ? FontWeight.w800 : FontWeight.w600,
                  color:
                      seleccionado ? Colors.white : AppTheme.onSurfaceVariant,
                ),
              ),
              if (contador != null) ...[
                const SizedBox(width: 5),
                Text(
                  '$contador',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: seleccionado
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppTheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Colores de la píldora de estado, tomados tal cual del mockup
/// (`Pantalla_historial_reproductivo`) -- cada estado tiene su propio
/// trío fondo/texto/borde, igual para registros activos o eliminados.
class _ColoresEstado {
  final Color fondo;
  final Color texto;
  final Color borde;

  const _ColoresEstado(this.fondo, this.texto, this.borde);
}

_ColoresEstado _coloresDeEstado(String estado) {
  switch (estado) {
    case 'Gestante':
      return const _ColoresEstado(
          Color(0xFFE2F0D9), Color(0xFF2E6B34), Color(0xFFC5E1B5));
    case 'Parida':
      return const _ColoresEstado(
          Color(0xFFE4F2E4), Color(0xFF246B28), Color(0xFFC6E6C7));
    case 'Abortada':
    case 'Fallida':
      return const _ColoresEstado(
          Color(0xFFFCE8E8), Color(0xFFB72B2B), Color(0xFFF8BABA));
    default: // Pendiente
      return const _ColoresEstado(
          Color(0xFFEFE9DF), Color(0xFF57534E), Color(0xFFD6D3D1));
  }
}

class _TarjetaHistorial extends StatelessWidget {
  final SeguimientoGestacion registro;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _TarjetaHistorial({
    required this.registro,
    required this.dateFormat,
    required this.onTap,
  });

  /// Color del ícono/avatar cuando el registro está activo (no eliminado):
  /// ocre cálido para "Pendiente", rojo coral para resultados fallidos,
  /// verde para resultados exitosos o en curso.
  Color get _colorIcono {
    switch (registro.estado) {
      case 'Gestante':
        return AppTheme.primary;
      case 'Parida':
        return const Color(0xFF43A047);
      case 'Abortada':
      case 'Fallida':
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF8B6E3F);
    }
  }

  Color get _fondoIcono {
    switch (registro.estado) {
      case 'Gestante':
        return AppTheme.primaryContainer.withValues(alpha: 0.35);
      case 'Parida':
        return const Color(0xFFDCF0DC);
      case 'Abortada':
      case 'Fallida':
        return const Color(0xFFFFE0E0);
      default:
        return const Color(0xFFEFEBE1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eliminado = registro.estaEliminado;
    final colores = _coloresDeEstado(registro.estado);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: eliminado
                ? const Color(0xFFFFF4F4)
                : AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
            border: Border.all(
              color: eliminado
                  ? const Color(0xFFFFDADA)
                  : AppTheme.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: (eliminado ? const Color(0xFFF05252) : Colors.black)
                    .withValues(alpha: eliminado ? 0.06 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: eliminado ? const Color(0xFFFFDADA) : _fondoIcono,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  eliminado ? Icons.delete_outline : Icons.pregnant_woman,
                  color: eliminado ? const Color(0xFFD32F2F) : _colorIcono,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      registro.animal?.nombreVisible ??
                          'Animal #${registro.animalId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Creado: ${registro.creadoEn != null ? dateFormat.format(registro.creadoEn!) : "—"}'
                      '${registro.creadoPor != null ? " · ${registro.creadoPor!.nombreUsuario}" : ""}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.outline,
                      ),
                    ),
                    if (eliminado)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Eliminado'
                          '${registro.eliminadoPor != null ? " por ${registro.eliminadoPor!.nombreUsuario}" : ""}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFD32F2F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: colores.fondo,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: colores.borde),
                ),
                child: Text(
                  registro.estado,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: colores.texto,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
