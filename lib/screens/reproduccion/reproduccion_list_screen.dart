import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/auth_session.dart';
import '../../models/animal.dart';
import '../../models/catalogo/especie.dart';
import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';
import 'fertilidad_screen.dart';
import 'historial_reproduccion_screen.dart';
import 'registrar_seguimiento_screen.dart';
import 'reproduccion_lista_filtrada_screen.dart';
import 'seguimiento_detalle_screen.dart';
import 'seguimiento_form_screen.dart';

/// Pantalla de entrada del módulo Reproducción (reemplaza a la lista plana
/// anterior), con estructura basada en el mockup de Stitch
/// "historial_de_reproducci_n", recortada a las decisiones confirmadas
/// (ver decisiones-diseno-vs-backend-reproduccion.md):
/// - Título "Control reproductivo" / subtítulo "Panorama de reproducción".
/// - 4 burbujas deslizables: Gestaciones (en curso), Partos pendientes
///   (seguimientos "Pendiente" aún sin confirmar -- métrica nueva, nace
///   con el flujo de 3 pasos agregado 2026-10-15), Partos este mes
///   (cerrados como "Parida" en el mes en curso) y Fertilidad vs mes
///   anterior (Parida / (Parida+Abortada) del mes, comparada con el mes
///   anterior).
/// - 2026-10-21 (Parte 1): cada burbuja ahora es tocable y lleva a una
///   pantalla con el listado completo de ese grupo ("Ver detalles ->
///   Editarlos ó Eliminar"); las tarjetas de la lista principal también son
///   tocables, pero abren un detalle de SOLO LECTURA (sin editar/eliminar);
///   y al final de esta pantalla hay un acceso al Historial completo
///   (incluye registros eliminados, para auditoría).
/// - Búsqueda de "Machos activos" con filtro de especie (Solo Toros / Solo
///   Cerdos -- los gallos quedan fuera de este módulo a propósito).
/// - Las tarjetas son solo informativas (2026-10-19, corregido): avanzar un
///   seguimiento (Confirmar / Parto-Aborto) pasa exclusivamente por el
///   botón "Registrar Seguimiento", nunca por un botón suelto en la
///   tarjeta -- evita confundirlo con los roles de la pantalla de inicio.
///   "+ Nuevo Evento" (FAB abajo a la derecha) es la única forma de crear
///   un evento reproductivo nuevo (IA/Monta natural).
class ReproduccionListScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;
  final CatalogoRepository catalogoRepository;
  final AuthSession session;

  const ReproduccionListScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    required this.catalogoRepository,
    required this.session,
  });

  @override
  State<ReproduccionListScreen> createState() => _ReproduccionListScreenState();
}

class _ReproduccionListScreenState extends State<ReproduccionListScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _buscarMachoCtrl = TextEditingController();

  List<SeguimientoGestacion> _registros = [];
  bool _cargando = true;
  String? _error;

  String _filtroTipo = 'Todos'; // Todos | IA | Monta natural
  String _filtroEstado =
      'Todos'; // Todos | Pendiente | Gestante | Parida | Abortada | Fallida

  // -- Búsqueda de machos activos --
  bool _buscarMachoAbierto = false;
  List<Especie> _especies = [];
  String _filtroEspecieMacho = 'Todos'; // Todos | Bovino | Cerdo
  List<Animal> _machosEncontrados = [];
  bool _buscandoMachos = false;
  Timer? _debounceBusquedaMacho;

  // Filtro "ver solo los registros de este macho" (2026-10-20): se activa
  // al tocar un resultado del buscador.
  int? _machoFiltroId;
  String? _machoFiltroNombre;

  @override
  void initState() {
    super.initState();
    _cargar();
    widget.catalogoRepository.listarEspecies().then((especies) {
      if (mounted) setState(() => _especies = especies);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _buscarMachoCtrl.dispose();
    _debounceBusquedaMacho?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final registros = await widget.repository.listar();
      setState(() => _registros = registros);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _crear() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SeguimientoFormScreen(
          repository: widget.repository,
          animalRepository: widget.animalRepository,
          session: widget.session,
        ),
      ),
    );
    if (resultado == true) _cargar();
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// "Registrar Seguimiento" (corregido 2026-10-19): ya NO hay botones de
  /// Confirmar/Cerrar sueltos en las tarjetas -- todo pasa por esta pantalla
  /// unificada, que primero deja elegir cuál seguimiento activo trabajar.
  Future<void> _abrirRegistrarSeguimiento() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegistrarSeguimientoScreen(
          repository: widget.repository,
          animalRepository: widget.animalRepository,
          catalogoRepository: widget.catalogoRepository,
        ),
      ),
    );
    if (resultado == true) _cargar();
  }

  /// 2026-10-21: detalle de SOLO LECTURA desde la lista principal (a
  /// pedido explícito -- "que abran ÚNICAMENTE los detalles registrados
  /// hasta la fecha"). Editar/Eliminar solo viven en las 4 pantallas de
  /// las burbujas.
  void _abrirDetalleSoloLectura(SeguimientoGestacion registro) {
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

  void _abrirHistorial() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistorialReproduccionScreen(
          repository: widget.repository,
          animalRepository: widget.animalRepository,
        ),
      ),
    );
  }

  /// Búsqueda en vivo (2026-10-20, corregido): cada tecla reinicia un
  /// retraso corto antes de disparar la búsqueda real, en vez de esperar a
  /// que toques Enter o el botón "Buscar" (que se deja también, para
  /// quien prefiera usarlo).
  void _onTextoBuscarMachoCambio(String _) {
    _debounceBusquedaMacho?.cancel();
    _debounceBusquedaMacho =
        Timer(const Duration(milliseconds: 400), _buscarMachos);
  }

  void _filtrarPorMacho(Animal macho) {
    setState(() {
      _machoFiltroId = macho.id;
      _machoFiltroNombre = macho.nombreVisible;
    });
  }

  void _limpiarFiltroMacho() {
    setState(() {
      _machoFiltroId = null;
      _machoFiltroNombre = null;
    });
  }

  Future<void> _buscarMachos() async {
    setState(() => _buscandoMachos = true);
    try {
      int? especieId;
      if (_filtroEspecieMacho != 'Todos') {
        especieId = _especies
            .firstWhere(
              (e) => e.nombre == _filtroEspecieMacho,
              orElse: () => const Especie(id: -1, nombre: ''),
            )
            .id;
        if (especieId == -1) especieId = null;
      }
      final pagina = await widget.animalRepository.listar(
        genero: 'Macho',
        estado: 'Activo',
        especieId: especieId,
        buscar: _buscarMachoCtrl.text.trim().isEmpty
            ? null
            : _buscarMachoCtrl.text.trim(),
        limite: 50,
      );
      if (mounted) setState(() => _machosEncontrados = pagina.data);
    } catch (e) {
      _mostrarError('No se pudo buscar: $e');
    } finally {
      if (mounted) setState(() => _buscandoMachos = false);
    }
  }

  List<SeguimientoGestacion> get _registrosFiltrados {
    var lista = _registros;
    if (_filtroTipo != 'Todos') {
      lista = lista.where((r) => r.tipo == _filtroTipo).toList();
    }
    if (_filtroEstado != 'Todos') {
      lista = lista.where((r) => r.estado == _filtroEstado).toList();
    }
    if (_machoFiltroId != null) {
      lista = lista.where((r) => r.machoId == _machoFiltroId).toList();
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control reproductivo'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Evento'),
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
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      const Text(
                        'Panorama de reproducción',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _BurbujasPanorama(
                        registros: _registros,
                        repository: widget.repository,
                        animalRepository: widget.animalRepository,
                      ),
                      const SizedBox(height: 16),
                      _BotonRegistrarSeguimiento(
                          onPressed: _abrirRegistrarSeguimiento),
                      const SizedBox(height: 16),
                      _BuscadorMachosActivos(
                        abierto: _buscarMachoAbierto,
                        onToggle: () => setState(
                            () => _buscarMachoAbierto = !_buscarMachoAbierto),
                        controller: _buscarMachoCtrl,
                        onTextoCambio: _onTextoBuscarMachoCambio,
                        especies: _especies,
                        filtroEspecie: _filtroEspecieMacho,
                        onFiltroEspecie: (v) {
                          setState(() => _filtroEspecieMacho = v);
                          _buscarMachos();
                        },
                        onBuscar: _buscarMachos,
                        buscando: _buscandoMachos,
                        resultados: _machosEncontrados,
                        onSeleccionarMacho: _filtrarPorMacho,
                      ),
                      const SizedBox(height: 16),
                      _FiltroTipo(
                        seleccionado: _filtroTipo,
                        onChanged: (v) => setState(() => _filtroTipo = v),
                      ),
                      const SizedBox(height: 10),
                      _FiltroEstado(
                        seleccionado: _filtroEstado,
                        onChanged: (v) => setState(() => _filtroEstado = v),
                      ),
                      if (_machoFiltroId != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Chip(
                            avatar: const Icon(Icons.male, size: 18),
                            label: Text('Registros de: $_machoFiltroNombre'),
                            onDeleted: _limpiarFiltroMacho,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (_registrosFiltrados.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.pregnant_woman,
                                    size: 40, color: AppTheme.outline),
                                const SizedBox(height: 10),
                                const Text(
                                    'No hay seguimientos registrados con este filtro'),
                              ],
                            ),
                          ),
                        )
                      else
                        for (final registro in _registrosFiltrados)
                          _TarjetaSeguimiento(
                            registro: registro,
                            dateFormat: _dateFormat,
                            onTap: () => _abrirDetalleSoloLectura(registro),
                          ),
                      const SizedBox(height: 20),
                      _BotonHistorial(onPressed: _abrirHistorial),
                    ],
                  ),
                ),
    );
  }
}

/// Fila de 4 burbujas deslizables horizontalmente (estilo mockup Stitch),
/// cada una con su ícono, valor y etiqueta. 2026-10-21: ahora cada burbuja
/// es tocable y lleva a su propia pantalla con el listado completo (las 3
/// primeras reutilizan ReproduccionListaFiltradaScreen; Fertilidad tiene
/// su propia pantalla con gráfico, ver FertilidadScreen).
class _BurbujasPanorama extends StatelessWidget {
  final List<SeguimientoGestacion> registros;
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;

  const _BurbujasPanorama({
    required this.registros,
    required this.repository,
    required this.animalRepository,
  });

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();

    final gestaciones = registros.where((r) => r.estaGestante).length;
    final partosPendientes = registros.where((r) => r.estaPendiente).length;

    bool enMes(DateTime? fecha, DateTime referencia) =>
        fecha != null &&
        fecha.year == referencia.year &&
        fecha.month == referencia.month;

    // 2026-10-21 (corregido a partir de la prueba de Dany): igual que en
    // FertilidadScreen, el mes se determina por la fecha REAL del evento
    // (fechaRealParto), no por cerradoEn (cuándo se dio clic en el
    // sistema) -- un registro cerrado hoy pero con fecha real del mes
    // pasado debe contar en el mes pasado.
    DateTime? fechaDeResultado(SeguimientoGestacion r) =>
        r.fechaRealParto ?? r.cerradoEn;

    final partosEsteMes = registros
        .where((r) => r.estaParida && enMes(fechaDeResultado(r), ahora))
        .length;

    double? fertilidadDe(DateTime referencia) {
      final paridas = registros
          .where((r) => r.estaParida && enMes(fechaDeResultado(r), referencia))
          .length;
      final fallidas = registros
          .where((r) =>
              r.esResultadoFallido && enMes(fechaDeResultado(r), referencia))
          .length;
      final total = paridas + fallidas;
      if (total == 0) return null;
      return (paridas / total) * 100;
    }

    final mesAnterior = DateTime(ahora.year, ahora.month - 1);
    final fertilidadActual = fertilidadDe(ahora);
    final fertilidadAnterior = fertilidadDe(mesAnterior);
    final deltaFertilidad =
        (fertilidadActual != null && fertilidadAnterior != null)
            ? fertilidadActual - fertilidadAnterior
            : null;

    void abrirLista({
      required String titulo,
      required IconData icono,
      required Color color,
      required bool Function(SeguimientoGestacion) filtro,
      required String mensajeVacio,
    }) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReproduccionListaFiltradaScreen(
            repository: repository,
            animalRepository: animalRepository,
            titulo: titulo,
            icono: icono,
            color: color,
            filtro: filtro,
            mensajeVacio: mensajeVacio,
          ),
        ),
      );
    }

    void abrirFertilidad() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FertilidadScreen(
            repository: repository,
            animalRepository: animalRepository,
          ),
        ),
      );
    }

    final burbujas = [
      _DatoBurbuja(
        icono: Icons.pregnant_woman,
        color: AppTheme.primary,
        valor: '$gestaciones',
        etiqueta: 'Gestaciones',
        onTap: () => abrirLista(
          titulo: 'Gestaciones',
          icono: Icons.pregnant_woman,
          color: AppTheme.primary,
          filtro: (r) => r.estaGestante,
          mensajeVacio: 'No hay gestaciones activas en este momento',
        ),
      ),
      _DatoBurbuja(
        icono: Icons.hourglass_top,
        color: AppTheme.secondary,
        valor: '$partosPendientes',
        etiqueta: 'Partos pendientes',
        onTap: () => abrirLista(
          titulo: 'Partos pendientes',
          icono: Icons.hourglass_top,
          color: AppTheme.secondary,
          filtro: (r) => r.estaPendiente,
          mensajeVacio: 'No hay seguimientos pendientes de confirmar',
        ),
      ),
      _DatoBurbuja(
        icono: Icons.celebration_outlined,
        color: AppTheme.tertiary,
        valor: '$partosEsteMes',
        etiqueta: 'Partos este mes',
        onTap: () => abrirLista(
          titulo: 'Partos este mes',
          icono: Icons.celebration_outlined,
          color: AppTheme.tertiary,
          filtro: (r) => r.estaParida && enMes(fechaDeResultado(r), ahora),
          mensajeVacio: 'Ningún parto exitoso registrado este mes todavía',
        ),
      ),
      _DatoBurbuja(
        icono: Icons.trending_up,
        color: const Color(0xFFCE8A3D),
        valor: fertilidadActual == null
            ? 'Sin datos'
            : '${fertilidadActual.toStringAsFixed(0)}%',
        etiqueta: deltaFertilidad == null
            ? 'Fertilidad del mes'
            : 'Fertilidad (${deltaFertilidad >= 0 ? '+' : ''}${deltaFertilidad.toStringAsFixed(0)} pts vs mes ant.)',
        onTap: abrirFertilidad,
      ),
    ];

    return SizedBox(
      // 2026-10-21 (segundo ajuste): 104 se quedaba corto para la etiqueta
      // de Fertilidad cuando trae el "(+N pts vs mes ant.)" en 2 líneas --
      // el primer intento con Expanded "arreglaba" el overflow pero
      // aplastaba el texto hasta hacerlo ilegible. Se sube la tarjeta a
      // 124 y se usan espaciados fijos (ver _BurbujaCard) en vez de
      // Expanded/spaceBetween, para que el texto tenga su alto real.
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: burbujas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _BurbujaCard(dato: burbujas[i]),
      ),
    );
  }
}

class _DatoBurbuja {
  final IconData icono;
  final Color color;
  final String valor;
  final String etiqueta;
  final VoidCallback onTap;

  const _DatoBurbuja({
    required this.icono,
    required this.color,
    required this.valor,
    required this.etiqueta,
    required this.onTap,
  });
}

class _BurbujaCard extends StatelessWidget {
  final _DatoBurbuja dato;

  const _BurbujaCard({required this.dato});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        onTap: dato.onTap,
        child: Container(
          width: 148,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dato.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
            border: Border.all(color: dato.color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(dato.icono, color: dato.color, size: 22),
              const SizedBox(height: 6),
              Text(dato.valor,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              // 2026-10-21 (segundo ajuste): ya NO usa Expanded (eso
              // aplastaba el texto hasta hacerlo ilegible). Con
              // mainAxisSize.min + la tarjeta en 124 de alto, el texto
              // simplemente ocupa el espacio real que necesita; el
              // maxLines/ellipsis sigue ahí por si algún texto fuera aún
              // más largo.
              Text(
                dato.etiqueta,
                style: TextStyle(fontSize: 11, color: AppTheme.outline),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón "Registrar seguimiento" con el mismo estilo de píldora usado en
/// Producción ("Registrar producción de hoy").
class _BotonRegistrarSeguimiento extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotonRegistrarSeguimiento({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF8BC98F),
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                    color: Color(0xFF3F6B4A), shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Registrar Seguimiento',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acceso al Historial completo (2026-10-21, nuevo a pedido de la Parte 1):
/// "al final del inicio aparezca el Historial de todos los registros hechos
/// y eliminados (para la auditoria)". Se deja como un botón/entrada al
/// final de la pantalla en vez de mostrar la lista completa inline, porque
/// el historial puede crecer mucho -- la lista en sí vive en su propia
/// pantalla (HistorialReproduccionScreen).
class _BotonHistorial extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotonHistorial({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.history, color: AppTheme.primary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ver historial completo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Buscador de "Machos activos" colapsable, con filtro de especie (Solo
/// Toros / Solo Cerdos -- no incluye gallos a propósito, confirmado como
/// fuera del alcance de este módulo).
class _BuscadorMachosActivos extends StatelessWidget {
  final bool abierto;
  final VoidCallback onToggle;
  final TextEditingController controller;
  final void Function(String) onTextoCambio;
  final List<Especie> especies;
  final String filtroEspecie;
  final void Function(String) onFiltroEspecie;
  final VoidCallback onBuscar;
  final bool buscando;
  final List<Animal> resultados;
  final void Function(Animal) onSeleccionarMacho;

  const _BuscadorMachosActivos({
    required this.abierto,
    required this.onToggle,
    required this.controller,
    required this.onTextoCambio,
    required this.especies,
    required this.filtroEspecie,
    required this.onFiltroEspecie,
    required this.onBuscar,
    required this.buscando,
    required this.resultados,
    required this.onSeleccionarMacho,
  });

  // Solo estas dos especies entran en el filtro -- Reproducción no
  // contempla aves/gallos.
  static const _especiesPermitidas = ['Bovino', 'Cerdo'];

  @override
  Widget build(BuildContext context) {
    final opcionesFiltro = [
      'Todos',
      ...especies.map((e) => e.nombre).where(_especiesPermitidas.contains),
    ];

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.search, color: AppTheme.primary),
            title: const Text('Buscar machos activos'),
            subtitle: const Text('Toros y cerdos disponibles para monta'),
            trailing: Icon(abierto ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (abierto)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Nombre o código...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: onTextoCambio,
                    onSubmitted: (_) => onBuscar(),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final opcion in opcionesFiltro.isEmpty
                          ? ['Todos']
                          : opcionesFiltro)
                        ChoiceChip(
                          label: Text(opcion == 'Todos'
                              ? 'Todos'
                              : 'Solo ${opcion == 'Bovino' ? 'Toros' : 'Cerdos'}'),
                          selected: filtroEspecie == opcion,
                          onSelected: (_) => onFiltroEspecie(opcion),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: buscando ? null : onBuscar,
                    child: buscando
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Buscar'),
                  ),
                  if (resultados.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final macho in resultados)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.male, color: AppTheme.primary),
                        title: Text('${macho.nombreVisible} (${macho.codigo})'),
                        subtitle: Text(macho.especie?.nombre ??
                            'Especie #${macho.especieId}'),
                        trailing: const Icon(Icons.filter_alt_outlined,
                            size: 18, color: AppTheme.outline),
                        onTap: () => onSeleccionarMacho(macho),
                      ),
                  ] else if (!buscando)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Sin resultados todavía',
                          style: TextStyle(color: AppTheme.outline)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FiltroTipo extends StatelessWidget {
  final String seleccionado;
  final void Function(String) onChanged;

  const _FiltroTipo({required this.seleccionado, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const opciones = ['Todos', 'IA', 'Monta natural'];
    return Wrap(
      spacing: 8,
      children: [
        for (final opcion in opciones)
          ChoiceChip(
            label: Text(opcion),
            selected: seleccionado == opcion,
            onSelected: (_) => onChanged(opcion),
          ),
      ],
    );
  }
}

/// Filtro por estado (2026-10-20, nuevo a pedido): además de Pendiente y
/// Gestante (los estados "activos"), ahora deja filtrar puntualmente por
/// Parida, Abortada o Fallida -- útil para revisar el historial cerrado sin
/// desplazarte por toda la lista.
class _FiltroEstado extends StatelessWidget {
  final String seleccionado;
  final void Function(String) onChanged;

  const _FiltroEstado({required this.seleccionado, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const opciones = [
      'Todos',
      'Pendiente',
      'Gestante',
      'Parida',
      'Abortada',
      'Fallida',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final opcion in opciones)
          ChoiceChip(
            label: Text(opcion),
            selected: seleccionado == opcion,
            onSelected: (_) => onChanged(opcion),
          ),
      ],
    );
  }
}

/// Tarjeta de un seguimiento en la lista principal -- SOLO LECTURA
/// (2026-10-19, corregido; ampliado 2026-10-21): no tiene botones de
/// acción propios ("Confirmar" / "Registrar parto-aborto" se quitaron de
/// aquí, y Editar/Eliminar NUNCA viven aquí a propósito -- eso vive en las
/// 4 pantallas de las burbujas). Tocar la tarjeta abre un detalle de solo
/// lectura (SeguimientoDetalleScreen con permitirAcciones: false).
class _TarjetaSeguimiento extends StatelessWidget {
  final SeguimientoGestacion registro;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _TarjetaSeguimiento({
    required this.registro,
    required this.dateFormat,
    required this.onTap,
  });

  Color get _colorEstado {
    switch (registro.estado) {
      case 'Gestante':
        return AppTheme.primary;
      case 'Parida':
        return Colors.green[700]!;
      case 'Abortada':
        return AppTheme.tertiary;
      case 'Fallida':
        return Colors.red[700]!;
      default: // Pendiente
        return AppTheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _colorEstado.withValues(alpha: 0.15),
                    child: Icon(Icons.pregnant_woman, color: _colorEstado),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          registro.animal?.nombreVisible ??
                              'Animal #${registro.animalId}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Inseminación: ${dateFormat.format(registro.fechaInseminacion)}'
                          '${registro.fechaEstimadaParto != null ? ' · Parto est.: ${dateFormat.format(registro.fechaEstimadaParto!)}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(registro.estado,
                        style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: _colorEstado.withValues(alpha: 0.12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _LineaAuditoria(registro: registro),
            ],
          ),
        ),
      ),
    );
  }
}

/// Constancia de quién hizo cada paso -- adelanto puntual del módulo de
/// auditoría que se planea extender a todas las pantallas de historial
/// (incluida Producción). Solo muestra los pasos que ya ocurrieron.
class _LineaAuditoria extends StatelessWidget {
  final SeguimientoGestacion registro;

  const _LineaAuditoria({required this.registro});

  @override
  Widget build(BuildContext context) {
    final partes = <String>[];
    if (registro.creadoPor != null)
      partes.add('Creó: ${registro.creadoPor!.nombreUsuario}');
    if (registro.confirmadoPor != null)
      partes.add('Confirmó: ${registro.confirmadoPor!.nombreUsuario}');
    if (registro.cerradoPor != null)
      partes.add('Cerró: ${registro.cerradoPor!.nombreUsuario}');
    if (partes.isEmpty) return const SizedBox.shrink();
    return Text(
      partes.join(' · '),
      style: const TextStyle(fontSize: 11, color: AppTheme.outline),
    );
  }
}
