import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/auth_session.dart';
import '../../models/catalogo/especie.dart';
import '../../models/salud/evento_sanitario.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/inventario/insumo_repository.dart';
import '../../repositories/salud/evento_sanitario_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/especie_visual.dart';
import 'evento_sanitario_detalle_screen.dart';

const int _kPorPagina = 10;

/// "Eventos de salud registrados" -- pestaña dentro de Cuenta (ver
/// decisiones-diseno-vs-backend-salud.md sección 3). Único lugar de la app
/// donde el detalle de un evento permite Editar/Eliminar/cambiar estado.
///
/// El backend (`GET /eventos-sanitarios`) no pagina ni filtra por especie
/// -- todo (filtro de especie, búsqueda por nombre de animal, paginado de
/// 10 en 10) se resuelve 100% del lado del cliente, sobre la lista
/// completa ya traída.
class HistorialSaludScreen extends StatefulWidget {
  final EventoSanitarioRepository repository;
  final CatalogoRepository catalogoRepository;
  final InsumoRepository insumoRepository;
  final AuthSession session;

  const HistorialSaludScreen({
    super.key,
    required this.repository,
    required this.catalogoRepository,
    required this.insumoRepository,
    required this.session,
  });

  @override
  State<HistorialSaludScreen> createState() => _HistorialSaludScreenState();
}

class _HistorialSaludScreenState extends State<HistorialSaludScreen> {
  final _buscarCtrl = TextEditingController();
  final _dateFormat = DateFormat('d MMM yyyy', 'es');
  final _dateTimeFormat = DateFormat('d MMM yyyy, h:mm a', 'es');

  List<EventoSanitario> _eventos = [];
  List<Especie> _especies = [];
  int? _especieFiltroId; // null = "Todos"
  // 2026-11-01 (punto 6.3 de la nota de Dany -- filtro tipo "Kardex"): rango
  // de fechas para filtrar por `fecha_evento`, null = sin filtro. Mismo
  // patrón 100% cliente que ya usan especie/búsqueda -- no hace falta
  // tocar el backend. Sirve igual para "entre dos fechas" o "por semana"
  // (una semana es solo un rango de 7 días elegido en el mismo selector).
  DateTimeRange? _rangoFechas;
  // 2026-11-01, a pedido de Dany ("el mismo estilo de Historial... que
  // muestra si algunos fueron eliminados, como el de producción y
  // reproducción"): false por defecto -- la pantalla se sigue viendo
  // exactamente igual que antes mientras no se active este filtro. Al
  // activarlo, se vuelve a pedir la lista al repositorio con
  // `incluirEliminados: true` (no es un filtro 100% de cliente como los
  // demás, porque el backend excluye los eliminados por defecto).
  bool _incluirEliminados = false;
  int _pagina = 0; // 0-indexada

  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarEspecies();
    _cargar();
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEspecies() async {
    try {
      final especies = await widget.catalogoRepository.listarEspecies();
      if (!mounted) return;
      setState(() => _especies = especies);
    } catch (_) {
      // Silencioso: si falla, simplemente no aparecen los chips de especie.
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final eventos =
          await widget.repository.listar(incluirEliminados: _incluirEliminados);
      if (!mounted) return;
      // Más recientes primero.
      eventos.sort((a, b) {
        final fa = a.fechaEvento;
        final fb = b.fechaEvento;
        if (fa == null && fb == null) return 0;
        if (fa == null) return 1;
        if (fb == null) return -1;
        return fb.compareTo(fa);
      });
      setState(() {
        _eventos = eventos;
        _pagina = 0;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<EventoSanitario> get _filtrados {
    final busqueda = _buscarCtrl.text.trim().toLowerCase();
    return _eventos.where((e) {
      // 2026-11-01, corrección pedida por Dany: "Eliminados" activado no
      // significa "incluir también los eliminados" (mezclados con los
      // activos) -- significa "mostrar SOLO los eliminados". `_cargar()`
      // sigue pidiendo ambos al backend (hace falta para poder verlos),
      // pero acá se filtran los que NO están eliminados cuando el chip
      // está activo.
      if (_incluirEliminados && !e.estaEliminado) {
        return false;
      }
      if (_especieFiltroId != null && e.animal?.especieId != _especieFiltroId) {
        return false;
      }
      if (busqueda.isNotEmpty) {
        final nombre = (e.animal?.nombreVisible ?? '').toLowerCase();
        final codigo = (e.animal?.codigo ?? '').toLowerCase();
        if (!nombre.contains(busqueda) && !codigo.contains(busqueda)) {
          return false;
        }
      }
      if (_rangoFechas != null) {
        final fecha = e.fechaEvento;
        // Sin fecha de evento no hay forma de ubicarlo en el rango -- se
        // excluye (no se incluyen eventos "Sin fecha" cuando hay un filtro
        // de fechas activo).
        if (fecha == null) return false;
        final desde = _rangoFechas!.start;
        final hasta = _rangoFechas!.end;
        if (fecha.isBefore(desde) || fecha.isAfter(hasta)) return false;
      }
      return true;
    }).toList();
  }

  List<EventoSanitario> get _paginaActual {
    final filtrados = _filtrados;
    final inicio = _pagina * _kPorPagina;
    if (inicio >= filtrados.length) return [];
    final fin = (inicio + _kPorPagina).clamp(0, filtrados.length);
    return filtrados.sublist(inicio, fin);
  }

  int get _totalPaginas {
    final total = _filtrados.length;
    if (total == 0) return 1;
    return ((total - 1) / _kPorPagina).floor() + 1;
  }

  // 2026-11-01: "Eliminado el ... por ..." para la leyenda tachada de la
  // lista -- mismo formato que la pantalla de detalle.
  String _textoEliminado(EventoSanitario e) {
    final fechaTxt = e.eliminadoEn != null
        ? _dateTimeFormat.format(e.eliminadoEn!.toLocal())
        : 'fecha desconocida';
    return 'Eliminado el $fechaTxt'
        '${e.eliminadoPorNombre != null ? ' por ${e.eliminadoPorNombre}' : ''}';
  }

  // 2026-11-01: alterna el filtro "Eliminados" -- a diferencia de los
  // demás filtros de esta pantalla, este sí necesita volver a pedir la
  // lista al backend (los eliminados ni siquiera viajan en la respuesta
  // si no se piden explícitamente).
  void _alternarIncluirEliminados() {
    setState(() => _incluirEliminados = !_incluirEliminados);
    _cargar();
  }

  /// El animal anidado en cada evento solo trae `especie_id` (sin el
  /// nombre de la especie -- el backend no lo incluye ahí), así que el
  /// nombre/emoji se resuelve con el catálogo ya cargado para los chips.
  String _emojiEspecieDe(int? especieId) {
    if (especieId == null) return '🐾';
    for (final especie in _especies) {
      if (especie.id == especieId) return emojiEspecie(especie.nombre);
    }
    return '🐾';
  }

  // 2026-11-01 (punto 6.3): abre el selector de rango nativo de Flutter.
  // `firstDate`/`lastDate` son solo los límites del calendario (no
  // significan nada de negocio) -- igual de amplios que los ya usados en
  // "Próximo refuerzo" del formulario.
  //
  // 2026-11-01 (bug reportado por Dany, crash "No MaterialLocalizations
  // found"): NO se le pasa `locale: Locale('es')` a propósito -- eso exige
  // que la app tenga configurado el paquete `flutter_localizations` para
  // español (un sistema aparte del de `intl`/`DateFormat` que ya usamos
  // para mostrar fechas en texto, y que la app no tiene armado). El
  // selector de "Próximo refuerzo" del formulario nunca pide ese locale
  // explícito y por eso nunca falla -- se deja este también sin locale,
  // usando el idioma por defecto de la app.
  Future<void> _elegirRangoFechas() async {
    final resultado = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _rangoFechas,
    );
    if (resultado != null) {
      setState(() {
        _rangoFechas = resultado;
        _pagina = 0;
      });
    }
  }

  void _limpiarRangoFechas() {
    setState(() {
      _rangoFechas = null;
      _pagina = 0;
    });
  }

  String get _etiquetaRangoFechas {
    if (_rangoFechas == null) return '📅 Fecha';
    final f = DateFormat('d MMM', 'es');
    return '📅 ${f.format(_rangoFechas!.start)} - ${f.format(_rangoFechas!.end)}';
  }

  Color _colorEstado(EventoSanitario e) {
    if (e.estaResuelto) return AppTheme.primary;
    if (e.estaEnTratamiento) return AppTheme.tertiary;
    return AppTheme.secondary;
  }

  Future<void> _abrirDetalle(EventoSanitario evento) async {
    final animal = evento.animal;
    if (animal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Este evento no trae el animal relacionado -- no se puede abrir el detalle'),
      ));
      return;
    }
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoSanitarioDetalleScreen(
          evento: evento,
          animal: animal,
          repository: widget.repository,
          insumoRepository: widget.insumoRepository,
          session: widget.session,
          soloLectura: false,
        ),
      ),
    );
    if (cambio == true) _cargar();
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
    final paginaActual = _paginaActual;
    final totalPaginas = _totalPaginas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos de salud registrados'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(106),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                TextField(
                  controller: _buscarCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o código del animal...',
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
                  ),
                  onChanged: (_) => setState(() => _pagina = 0),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _chip(
                        etiqueta: 'Todos',
                        seleccionado: _especieFiltroId == null,
                        onTap: () => setState(() {
                          _especieFiltroId = null;
                          _pagina = 0;
                        }),
                      ),
                      for (final especie in _especies) ...[
                        const SizedBox(width: 8),
                        _chip(
                          etiqueta:
                              '${emojiEspecie(especie.nombre)} ${especie.nombre}',
                          seleccionado: _especieFiltroId == especie.id,
                          onTap: () => setState(() {
                            _especieFiltroId = especie.id;
                            _pagina = 0;
                          }),
                        ),
                      ],
                      const SizedBox(width: 8),
                      // 2026-11-01 (punto 6.3, filtro tipo "Kardex"): al
                      // tocarlo (ya sea para activarlo o para cambiarlo)
                      // abre el selector de rango de fechas.
                      _chip(
                        etiqueta: _etiquetaRangoFechas,
                        seleccionado: _rangoFechas != null,
                        onTap: _elegirRangoFechas,
                      ),
                      if (_rangoFechas != null) ...[
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          tooltip: 'Quitar filtro de fecha',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          onPressed: _limpiarRangoFechas,
                        ),
                      ],
                      const SizedBox(width: 8),
                      // 2026-11-01, a pedido de Dany: filtro "Eliminados" --
                      // al activarlo, se vuelven a pedir los eventos
                      // incluyendo los que tienen borrado lógico (se ven
                      // tachados en la lista, con la leyenda de abajo).
                      _chip(
                        etiqueta: '🗑️ Eliminados',
                        seleccionado: _incluirEliminados,
                        onTap: _alternarIncluirEliminados,
                      ),
                    ],
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
              : paginaActual.isEmpty
                  ? Center(
                      child: Text(
                        _especieFiltroId != null ||
                                _buscarCtrl.text.isNotEmpty ||
                                _rangoFechas != null ||
                                _incluirEliminados
                            ? 'No hay eventos que coincidan con el filtro.'
                            : 'No hay eventos de salud registrados todavía.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: paginaActual.length,
                              itemBuilder: (context, i) {
                                final evento = paginaActual[i];
                                final animal = evento.animal;
                                // 2026-11-01: fila tachada + leyenda
                                // "Eliminado el ... por ..." cuando el
                                // evento tiene borrado lógico (solo puede
                                // aparecer aquí con el filtro "Eliminados"
                                // activo) -- mismo lenguaje visual que
                                // Producción.
                                final eliminado = evento.estaEliminado;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Opacity(
                                    opacity: eliminado ? 0.6 : 1,
                                    child: Material(
                                      color: AppTheme.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusDefault),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                            AppTheme.radiusDefault),
                                        onTap: () => _abrirDetalle(evento),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                                AppTheme.radiusDefault),
                                            border: Border.all(
                                                color: AppTheme.outlineVariant
                                                    .withValues(alpha: 0.4)),
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor:
                                                    _colorEstado(evento)
                                                        .withValues(
                                                            alpha: 0.15),
                                                child: Text(
                                                  _emojiEspecieDe(
                                                      animal?.especieId),
                                                  style: const TextStyle(
                                                      fontSize: 18),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${evento.tipoEvento} · ${animal?.nombreVisible ?? 'Animal #${evento.animalId}'}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        decoration: eliminado
                                                            ? TextDecoration
                                                                .lineThrough
                                                            : null,
                                                      ),
                                                    ),
                                                    Text(
                                                      evento.fechaEvento != null
                                                          ? _dateFormat.format(
                                                              evento
                                                                  .fechaEvento!)
                                                          : 'Sin fecha',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              AppTheme.outline),
                                                    ),
                                                    if (eliminado) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        _textoEliminado(evento),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .error,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _colorEstado(evento)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          AppTheme.radiusFull),
                                                ),
                                                child: Text(
                                                  evento.estado,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          _colorEstado(evento)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: _pagina > 0
                                      ? () => setState(() => _pagina--)
                                      : null,
                                ),
                                Text('Página ${_pagina + 1} de $totalPaginas'),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: _pagina < totalPaginas - 1
                                      ? () => setState(() => _pagina++)
                                      : null,
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
