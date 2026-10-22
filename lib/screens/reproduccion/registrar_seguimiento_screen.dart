import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';
import '../animales/animal_form_screen.dart';

// 2026-10-22: colores "fixed" del token Stitch (DESIGN.md del mockup
// `registrar_seguimiento_a_registro_reproductivo_confirmar`) que AppTheme
// todavía no define -- se usan solo acá, calcados tal cual del mockup, en
// vez de aproximarlos con los tokens existentes.
const _secondaryFixed = Color(0xFFFFDF9E);
const _onSecondaryFixed = Color(0xFF261A00);
const _primaryFixed = Color(0xFF94F990);
const _onPrimaryFixed = Color(0xFF002204);

/// "Registrar Seguimiento" (2026-10-19, corregido): pantalla UNIFICADA de
/// avance de un seguimiento ya existente. Todo lo que es "Confirmar" o
/// "Parto natural/Aborto" vive EXCLUSIVAMENTE dentro de esta pantalla --
/// no hay botones de acción sueltos en las tarjetas de la lista principal
/// (decisión confirmada: eso generaba confusión con los roles de inicio).
///
/// Flujo: 1) eliges de una lista cuál seguimiento activo (Pendiente o
/// Gestante) vas a trabajar, 2) según su estado actual, la pantalla
/// despliega la acción que le corresponde:
/// - Pendiente -> Confirmar (pasa a Gestante), con una observación
///   obligatoria.
/// - Gestante -> Parto natural / Aborto, con nota obligatoria y, si es
///   Parto, el conteo de crías que dispara el registro en Animales (igual
///   que antes, vía `AnimalFormScreen` en modo `bloquearGenealogia`).
class RegistrarSeguimientoScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;
  final CatalogoRepository catalogoRepository;

  const RegistrarSeguimientoScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    required this.catalogoRepository,
  });

  @override
  State<RegistrarSeguimientoScreen> createState() =>
      _RegistrarSeguimientoScreenState();
}

class _RegistrarSeguimientoScreenState
    extends State<RegistrarSeguimientoScreen> {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  bool _cargando = true;
  String? _error;
  List<SeguimientoGestacion> _activos = [];
  SeguimientoGestacion? _seleccionado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final registros = await widget.repository.listar();
      setState(() => _activos =
          registros.where((r) => r.estaPendiente || r.estaGestante).toList());
    } catch (e) {
      setState(() => _error = 'No se pudo cargar la lista: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_seleccionado == null
            ? 'Registrar Seguimiento'
            : 'Registrar Seguimiento'),
        leading: _seleccionado == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _seleccionado = null),
                tooltip: 'Elegir otro seguimiento',
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
              : _seleccionado == null
                  ? _SelectorSeguimiento(
                      activos: _activos,
                      dateFormat: _dateFormat,
                      onElegir: (s) => setState(() => _seleccionado = s),
                    )
                  : _FormularioAvance(
                      seguimiento: _seleccionado!,
                      dateFormat: _dateFormat,
                      repository: widget.repository,
                      animalRepository: widget.animalRepository,
                      catalogoRepository: widget.catalogoRepository,
                      onListo: () => Navigator.of(context).pop(true),
                    ),
    );
  }
}

/// Paso 1: elegir cuál seguimiento activo (Pendiente o Gestante) trabajar.
class _SelectorSeguimiento extends StatelessWidget {
  final List<SeguimientoGestacion> activos;
  final DateFormat dateFormat;
  final void Function(SeguimientoGestacion) onElegir;

  const _SelectorSeguimiento(
      {required this.activos,
      required this.dateFormat,
      required this.onElegir});

  @override
  Widget build(BuildContext context) {
    if (activos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pregnant_woman,
                  size: 40, color: AppTheme.outline),
              const SizedBox(height: 12),
              const Text(
                  'No hay seguimientos activos (Pendiente o Gestante) para trabajar ahora mismo.'),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activos.length,
      itemBuilder: (context, i) {
        final s = activos[i];
        final color = s.estaPendiente ? AppTheme.secondary : AppTheme.primary;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            onTap: () => onElegir(s),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(Icons.pregnant_woman, color: color),
            ),
            title: Text(s.animal?.nombreVisible ?? 'Animal #${s.animalId}'),
            subtitle: Text(
              'Inseminación: ${dateFormat.format(s.fechaInseminacion)}'
              '${s.fechaEstimadaParto != null ? ' · Parto est.: ${dateFormat.format(s.fechaEstimadaParto!)}' : ''}',
            ),
            trailing: Chip(
              label: Text(s.estado, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        );
      },
    );
  }
}

/// Paso 2: el formulario que corresponde según el estado del seguimiento
/// elegido -- Confirmar (Pendiente) o Parto natural/Aborto (Gestante).
class _FormularioAvance extends StatefulWidget {
  final SeguimientoGestacion seguimiento;
  final DateFormat dateFormat;
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;
  final CatalogoRepository catalogoRepository;
  final VoidCallback onListo;

  const _FormularioAvance({
    required this.seguimiento,
    required this.dateFormat,
    required this.repository,
    required this.animalRepository,
    required this.catalogoRepository,
    required this.onListo,
  });

  @override
  State<_FormularioAvance> createState() => _FormularioAvanceState();
}

class _FormularioAvanceState extends State<_FormularioAvance> {
  final _formKey = GlobalKey<FormState>();
  final _notasCtrl = TextEditingController();
  final _criasCtrl = TextEditingController(text: '1');

  // Solo usados cuando el seguimiento está Gestante (cierre).
  String _resultado = 'Parida';
  DateTime? _fechaRealParto;

  // Solo usado cuando el seguimiento está Pendiente: 'confirmar' (pasa a
  // Gestante, flujo normal) o 'fallida' (la IA/monta no resultó en preñez --
  // se cierra directo, sin pasar por Gestante). Agregado 2026-10-20 a
  // pedido explícito: antes no existía forma de cerrar un seguimiento
  // fallido sin pasar primero por "Confirmar".
  // 2026-10-22 (mockup "registrar_seguimiento_a_registro_reproductivo_
  // confirmar"): empieza sin elegir ninguna (null) -- igual que el mockup,
  // que exige tocar "Confirmar Gestación" o "Marcar Fallida" antes de
  // poder guardar (antes quedaba "Confirmar" preseleccionado de una vez).
  String? _accionPendiente;

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _notasCtrl.dispose();
    _criasCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFechaRealParto() async {
    final s = widget.seguimiento;
    // 2026-10-20, a pedido explícito: la fecha real del parto/aborto nunca
    // puede ser ANTERIOR a la fecha de inseminación -- no tendría sentido
    // que un animal pariera o abortara antes de haber sido inseminado/
    // montado. `firstDate` ya se lo impide desde el selector; `_guardar()`
    // abajo lo vuelve a validar como respaldo.
    final resultado = await showDatePicker(
      context: context,
      initialDate: _fechaRealParto ?? DateTime.now(),
      firstDate: s.fechaInseminacion,
      lastDate: DateTime.now(),
    );
    if (resultado != null) setState(() => _fechaRealParto = resultado);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final s = widget.seguimiento;
    int cantidadCrias = 0;

    // 2026-10-22 (mockup): "Guardar Seguimiento" exige haber tocado antes
    // "Confirmar Gestación" o "Marcar Fallida" -- igual que el alert() del
    // mockup ("Por favor selecciona una acción").
    if (s.estaPendiente && _accionPendiente == null) {
      setState(
          () => _error = 'Selecciona "Confirmar Gestación" o "Marcar Fallida"');
      return;
    }

    if (s.estaGestante) {
      if (_resultado == 'Parida' && _fechaRealParto == null) {
        setState(() => _error = 'Selecciona la fecha real del parto');
        return;
      }
      // 2026-10-20, a pedido explícito: el parto/aborto no puede quedar
      // registrado con una fecha ANTERIOR a la inseminación -- el selector
      // de fecha ya lo impide (firstDate), esto es un respaldo.
      if (_fechaRealParto != null &&
          _fechaRealParto!.isBefore(s.fechaInseminacion)) {
        setState(() => _error =
            'La fecha real del parto/aborto no puede ser anterior a la fecha de inseminación');
        return;
      }
      cantidadCrias = _resultado == 'Parida'
          ? (int.tryParse(_criasCtrl.text.trim()) ?? 0)
          : 0;
      if (_resultado == 'Parida' && cantidadCrias < 1) {
        setState(() => _error = 'Indica cuántas crías nacieron (mínimo 1)');
        return;
      }
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (s.estaPendiente) {
        if (_accionPendiente == 'fallida') {
          // Cierre directo desde Pendiente, sin pasar por Gestante: el
          // backend ya lo permitía (cerrar() solo exige que el registro no
          // esté cerrado todavía), solo faltaba agregar 'Fallida' a los
          // resultados válidos y exponer la acción aquí.
          await widget.repository.cerrar(
            s.id,
            CerrarSeguimientoDTO(
              resultado: 'Fallida',
              notas: _notasCtrl.text.trim(),
            ),
          );
        } else {
          await widget.repository
              .confirmar(s.id, notas: _notasCtrl.text.trim());
        }
      } else {
        // 2026-10-20, corregido a pedido explícito: ANTES este cerrar() se
        // mandaba primero y las crías se registraban después -- si
        // cancelabas una cría a mitad de camino, el seguimiento YA había
        // quedado cerrado como "Parida" aunque faltaran crías por crear.
        // Ahora, cuando el resultado es "Parida", las crías se registran
        // PRIMERO; solo si TODAS se completan (nadie canceló ninguna) se
        // manda el cerrar() -- si cancelas alguna, el seguimiento se queda
        // tal cual (Gestante) y no se cierra, para poder reintentarlo
        // después. Ojo: las crías que ya hayas guardado ANTES de cancelar
        // quedan creadas (no hay forma de "deshacerlas" automáticamente);
        // si reintentas el cierre más tarde, vuelve a pedir la cantidad
        // completa de crías, así que evita duplicar las que ya quedaron.
        if (_resultado == 'Parida' && cantidadCrias > 0) {
          final completo = await _registrarCrias(cantidadCrias);
          if (!mounted) return;
          if (!completo) {
            setState(() => _error =
                'Quedó incompleto el registro de crías -- el seguimiento NO se cerró y sigue como "Gestante". '
                    'Si ya guardaste alguna cría, ten cuidado de no duplicarla al reintentar.');
            return;
          }
        }
        await widget.repository.cerrar(
          s.id,
          CerrarSeguimientoDTO(
            resultado: _resultado,
            fechaRealParto: _fechaRealParto,
            notas: _notasCtrl.text.trim(),
          ),
        );
      }

      if (!mounted) return;
      widget.onListo();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Carga la Madre (y el Padre, si lo hay) completos y abre el formulario
  /// de Animales una vez por cada cría, en secuencia. Devuelve `true` solo
  /// si TODAS las crías se guardaron (nadie canceló ninguna) -- el llamador
  /// usa ese resultado para decidir si cierra el seguimiento o no (ver
  /// comentario en `_guardar()`).
  Future<bool> _registrarCrias(int cantidad) async {
    final s = widget.seguimiento;
    final madre = await widget.animalRepository.obtenerPorId(s.animalId);
    if (madre == null) {
      if (mounted) {
        setState(() => _error =
            'No se pudo cargar la Madre para registrar las crías. Intenta de nuevo.');
      }
      return false;
    }
    final padre = s.machoId == null
        ? null
        : await widget.animalRepository.obtenerPorId(s.machoId!);

    for (var i = 1; i <= cantidad; i++) {
      if (!mounted) return false;
      final guardo = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AnimalFormScreen(
            repository: widget.animalRepository,
            catalogoRepository: widget.catalogoRepository,
            madrePreseleccionada: madre,
            padrePreseleccionado: padre,
            bloquearGenealogia: true,
            fechaNacimientoPreseleccionada: _fechaRealParto,
          ),
        ),
      );
      // 2026-10-20: si cancelas una cría, el ciclo se detiene en silencio
      // (sin aviso emergente) Y se le avisa al llamador que quedó
      // incompleto, para que NO cierre el seguimiento.
      if (guardo != true) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.seguimiento;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 2026-10-22: tarjeta "ficha" del animal, calcada del mockup
            // Stitch `registrar_seguimiento_a_registro_reproductivo_
            // confirmar` -- avatar + nombre arriba, y debajo una caja
            // interna con cada dato en fila (icono + etiqueta a la
            // izquierda, valor a la derecha).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.pets,
                            color: AppTheme.primary, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.animal?.nombreVisible ?? '#${s.animalId}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Hembra${s.animal?.codigo != null ? ' • ID #${s.animal!.codigo}' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerLow,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusDefault),
                    ),
                    child: Column(
                      children: [
                        _FilaDato(
                          icono: Icons.male,
                          etiqueta: 'Padre:',
                          valor: s.macho?.nombreVisible ?? 'ANIMAL EXTERNO',
                        ),
                        const SizedBox(height: 10),
                        _FilaEstado(estado: s.estado),
                        const SizedBox(height: 10),
                        _FilaDato(
                          icono: Icons.calendar_today,
                          etiqueta: 'Inseminación:',
                          valor: widget.dateFormat.format(s.fechaInseminacion),
                        ),
                        if (s.fechaEstimadaParto != null) ...[
                          const SizedBox(height: 10),
                          _FilaDato(
                            // 2026-10-22: el mockup usa el ícono Material
                            // Symbols "event_upcoming", que no existe en el
                            // set clásico de Material Icons que trae
                            // Flutter -- "event_available" es el más
                            // parecido visualmente (calendario con check).
                            icono: Icons.event_available,
                            iconoColor: AppTheme.primary,
                            etiqueta: 'Parto estimado:',
                            valor:
                                widget.dateFormat.format(s.fechaEstimadaParto!),
                            valorColor: AppTheme.primary,
                            valorBold: true,
                          ),
                        ],
                        if (s.creadoPor != null) ...[
                          const SizedBox(height: 10),
                          _FilaDato(
                            icono: Icons.badge_outlined,
                            etiqueta: 'Creado por:',
                            valor: s.creadoPor!.nombreUsuario,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 2026-10-20: muestra las observaciones que ya tenía el
            // registro (las de cuando se creó el evento, o las del paso
            // anterior) ANTES de pedir la nueva -- ojo, al guardar este
            // paso ese campo se sobreescribe (no hay una columna separada
            // por paso), así que esto es la única oportunidad de verlas
            // antes de reemplazarlas. 2026-10-22: restyle calcado del
            // mockup -- encabezado con icono de nota + caja "candado" de
            // solo lectura.
            if (s.notas != null && s.notas!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sticky_note_2,
                            color: AppTheme.secondary, size: 20),
                        const SizedBox(width: 8),
                        Text('Observaciones registradas hasta ahora',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.secondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLowest
                            .withValues(alpha: 0.4),
                        border: Border.all(
                            color:
                                AppTheme.outlineVariant.withValues(alpha: 0.3)),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusDefault),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.notas!,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: AppTheme.onSurfaceVariant),
                            ),
                          ),
                          const Icon(Icons.lock,
                              size: 18, color: AppTheme.outline),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (s.estaPendiente) ...[
              // 2026-10-22: sección "Resultado del Chequeo" calcada del
              // mockup -- los dos botones grandes solo ELIGEN (como el
              // SegmentedButton de antes), el guardado real lo hace el
              // botón "Guardar Seguimiento" de abajo.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Resultado del Chequeo',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _accionPendiente == null
                                ? AppTheme.surfaceContainerColor
                                : (_accionPendiente == 'confirmar'
                                    ? _primaryFixed
                                    : AppTheme.errorContainer),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _accionPendiente == null
                                ? 'Selecciona uno'
                                : (_accionPendiente == 'confirmar'
                                    ? 'Seleccionado: Gestante'
                                    : 'Seleccionado: Fallida'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _accionPendiente == null
                                  ? AppTheme.onSurfaceVariant
                                  : (_accionPendiente == 'confirmar'
                                      ? _onPrimaryFixed
                                      : AppTheme.onErrorContainer),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _BotonResultado(
                            icono: Icons.check_circle,
                            etiqueta: 'Confirmar\nGestación',
                            colorFondo: AppTheme.primaryContainer,
                            colorTexto: AppTheme.onPrimaryContainer,
                            seleccionado: _accionPendiente == 'confirmar',
                            atenuado: _accionPendiente == 'fallida',
                            onTap: () =>
                                setState(() => _accionPendiente = 'confirmar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BotonResultado(
                            icono: Icons.cancel,
                            etiqueta: 'Marcar\nFallida',
                            colorFondo: AppTheme.error,
                            colorTexto: Colors.white,
                            seleccionado: _accionPendiente == 'fallida',
                            atenuado: _accionPendiente == 'confirmar',
                            onTap: () =>
                                setState(() => _accionPendiente = 'fallida'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusDefault),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.help_outline,
                                color: AppTheme.secondary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: AppTheme.secondary),
                                children: [
                                  TextSpan(
                                      text: 'Confirmar ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  TextSpan(
                                      text:
                                          'pasa el seguimiento de "Pendiente" a "Gestante". '),
                                  TextSpan(
                                      text: 'Marcar como fallida ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  TextSpan(
                                      text:
                                          'lo cierra directamente sin pasar por "Gestante" -- úsalo cuando la IA/monta no resultó en preñez.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Sección "Observación / corrección" -- mismo patrón de
              // auto-expansión ya usado en el formulario de creación
              // (punto 8), dentro de la tarjeta calcada del mockup.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_note,
                                color: AppTheme.outline, size: 18),
                            SizedBox(width: 6),
                            Text('Observación / corrección',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.errorContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Obligatoria *',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: TextFormField(
                        controller: _notasCtrl,
                        minLines: 3,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.surfaceContainerLow,
                          hintText: _accionPendiente == 'fallida'
                              ? 'Escribe aquí el motivo por el que no resultó...'
                              : 'Escribe aquí la observación o diagnóstico del veterinario/palpador...',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusDefault),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Este campo es obligatorio'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.history, size: 16, color: AppTheme.outline),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'El comentario ingresado actualizará el historial del servicio.',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 20),
                  label: const Text('Guardar Seguimiento'),
                ),
              ),
            ] else ...[
              // 2026-10-22 (Fase 3, "Cerrar"): mismo lenguaje visual que la
              // Fase 2 (Confirmar) -- no hay mockup específico para esta
              // pantalla todavía, así que reutilizo las mismas tarjetas,
              // botones grandes e íconos ya calcados del mockup de
              // "Confirmar" para que las dos fases se vean consistentes.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Resultado del Parto',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _resultado == 'Parida'
                                ? _primaryFixed
                                : AppTheme.errorContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _resultado == 'Parida'
                                ? 'Seleccionado: Parto natural'
                                : 'Seleccionado: Aborto',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _resultado == 'Parida'
                                  ? _onPrimaryFixed
                                  : AppTheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _BotonResultado(
                            icono: Icons.pets,
                            etiqueta: 'Parto\nNatural',
                            colorFondo: AppTheme.primaryContainer,
                            colorTexto: AppTheme.onPrimaryContainer,
                            seleccionado: _resultado == 'Parida',
                            atenuado: _resultado == 'Abortada',
                            onTap: () => setState(() => _resultado = 'Parida'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BotonResultado(
                            icono: Icons.cancel,
                            etiqueta: 'Aborto',
                            colorFondo: AppTheme.error,
                            colorTexto: Colors.white,
                            seleccionado: _resultado == 'Abortada',
                            atenuado: _resultado == 'Parida',
                            onTap: () =>
                                setState(() => _resultado = 'Abortada'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tarjeta de "Fecha real del parto" (+ cantidad de crías,
              // solo si el resultado es Parto natural) -- mismo estilo de
              // tarjeta blanca con sombra usado en el resto de la pantalla.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusDefault),
                      onTap: _elegirFechaRealParto,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusDefault),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 18, color: AppTheme.outline),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Fecha real del parto',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.onSurfaceVariant)),
                            ),
                            Text(
                              _fechaRealParto != null
                                  ? widget.dateFormat.format(_fechaRealParto!)
                                  : 'Sin definir',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_resultado == 'Parida') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _criasCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.surfaceContainerLow,
                          labelText: 'Cantidad de crías',
                          helperText:
                              'Por cada una se abrirá el formulario de Animales con la Madre y el Padre ya puestos.',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusDefault),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null || n < 1) {
                            return 'Indica un número mayor o igual a 1';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tarjeta de la nota -- mismo patrón de auto-expansión y
              // chip "Obligatoria *" ya usado en la Fase 2.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.edit_note,
                                color: AppTheme.outline, size: 18),
                            SizedBox(width: 6),
                            Text('Nota',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.errorContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Obligatoria *',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: TextFormField(
                        controller: _notasCtrl,
                        minLines: 3,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.surfaceContainerLow,
                          hintText: _resultado == 'Parida'
                              ? 'Escribe aquí cómo fue el parto...'
                              : 'Escribe aquí el motivo o diagnóstico del aborto...',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusDefault),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Esta nota es obligatoria'
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            // 2026-10-22: este botón genérico ya solo aplica a la Fase 3
            // (Gestante -> Parto/Aborto) -- en Pendiente, "Confirmar
            // Gestación" / "Marcar Fallida" (arriba) guardan directo.
            if (!s.estaPendiente)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 20),
                  label: const Text('Guardar Cierre'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fila "icono + etiqueta ... valor", usada dentro de la caja de datos de
/// la burbuja-resumen (ver mockup `registrar_seguimiento_a_registro_
/// reproductivo_confirmar`: Padre / Inseminación / Parto estimado / Creado
/// por comparten exactamente este layout, solo cambia el icono y si el
/// valor va en negrita/color).
class _FilaDato extends StatelessWidget {
  final IconData icono;
  final Color iconoColor;
  final String etiqueta;
  final String valor;
  final Color? valorColor;
  final bool valorBold;

  const _FilaDato({
    required this.icono,
    this.iconoColor = AppTheme.outline,
    required this.etiqueta,
    required this.valor,
    this.valorColor,
    this.valorBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icono, size: 18, color: iconoColor),
            const SizedBox(width: 6),
            Text(etiqueta,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.onSurfaceVariant)),
          ],
        ),
        Flexible(
          child: Text(
            valor,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: valorBold ? FontWeight.w800 : FontWeight.w700,
              color: valorColor ?? AppTheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila especial para "Estado actual:", con la pill de color propia del
/// estado (en vez de texto plano como el resto de filas) -- igual al
/// mockup, que usa `secondary-fixed` para "Pendiente".
class _FilaEstado extends StatelessWidget {
  final String estado;

  const _FilaEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final esPendiente = estado == 'Pendiente';
    final fondo = esPendiente ? _secondaryFixed : _primaryFixed;
    final texto = esPendiente ? _onSecondaryFixed : _onPrimaryFixed;
    final punto = esPendiente ? AppTheme.secondary : AppTheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Row(
          children: [
            Icon(Icons.sync, size: 18, color: AppTheme.outline),
            SizedBox(width: 6),
            Text('Estado actual:',
                style:
                    TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant)),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(estado,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800, color: texto)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Uno de los dos botones grandes "Confirmar Gestación" / "Marcar
/// Fallida" -- al estar `seleccionado` mantiene su color e icono a toda
/// fuerza (con sombra); al estar `atenuado` (el otro quedó elegido) pasa a
/// gris apagado y sin sombra, igual que el mockup.
class _BotonResultado extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final Color colorFondo;
  final Color colorTexto;
  final bool seleccionado;
  final bool atenuado;
  final VoidCallback onTap;

  const _BotonResultado({
    required this.icono,
    required this.etiqueta,
    required this.colorFondo,
    required this.colorTexto,
    required this.seleccionado,
    required this.atenuado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fondo = atenuado ? AppTheme.surfaceContainerColor : colorFondo;
    final texto = atenuado ? AppTheme.onSurfaceVariant : colorTexto;
    return AnimatedScale(
      scale: seleccionado ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        elevation: seleccionado ? 4 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          onTap: onTap,
          child: Container(
            // 2026-10-22: subí la altura (112 -> 124) y achiqué un poco el
            // círculo del ícono y el padding -- el texto en dos líneas
            // ("Confirmar\nGestación" / "Marcar\nFallida") se salía por 2px
            // ("BOTTOM OVERFLOWED") con las medidas anteriores.
            height: 124,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: atenuado ? 0.0 : 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icono, size: 24, color: texto),
                ),
                const SizedBox(height: 6),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: texto),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
