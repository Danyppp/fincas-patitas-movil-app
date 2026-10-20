import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';
import '../animales/animal_form_screen.dart';

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
  String _accionPendiente = 'confirmar';

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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Animal (hembra): ${s.animal?.nombreVisible ?? '#${s.animalId}'}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (s.macho != null)
                      Text('Macho: ${s.macho!.nombreVisible}'),
                    Text('Estado actual: ${s.estado}'),
                    Text(
                        'Inseminación: ${widget.dateFormat.format(s.fechaInseminacion)}'),
                    if (s.fechaEstimadaParto != null)
                      Text(
                          'Parto estimado: ${widget.dateFormat.format(s.fechaEstimadaParto!)}'),
                  ],
                ),
              ),
            ),
            // 2026-10-20: muestra las observaciones que ya tenía el
            // registro (las de cuando se creó el evento, o las del paso
            // anterior) ANTES de pedir la nueva -- ojo, al guardar este
            // paso ese campo se sobreescribe (no hay una columna separada
            // por paso), así que esto es la única oportunidad de verlas
            // antes de reemplazarlas.
            if (s.notas != null && s.notas!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: AppTheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Observaciones registradas hasta ahora',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(s.notas!),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (s.estaPendiente) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'confirmar',
                      label: Text('Confirmar gestación'),
                      icon: Icon(Icons.check_circle_outline)),
                  ButtonSegment(
                      value: 'fallida',
                      label: Text('Marcar fallida'),
                      icon: Icon(Icons.highlight_off)),
                ],
                selected: {_accionPendiente},
                onSelectionChanged: (sel) =>
                    setState(() => _accionPendiente = sel.first),
              ),
              const SizedBox(height: 12),
              Text(
                _accionPendiente == 'fallida'
                    ? 'Al marcar como fallida, este seguimiento se cierra directamente (sin pasar por "Gestante") -- la IA/monta no resultó en preñez.'
                    : 'Al confirmar, este seguimiento pasa de "Pendiente" a "Gestante".',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notasCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: _accionPendiente == 'fallida'
                      ? 'Motivo (obligatorio)'
                      : 'Observación / corrección (obligatoria)',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Este campo es obligatorio'
                    : null,
              ),
            ] else ...[
              const Text('Registrar parto / aborto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'Parida',
                      label: Text('Parto natural'),
                      icon: Icon(Icons.pets)),
                  ButtonSegment(
                      value: 'Abortada',
                      label: Text('Aborto'),
                      icon: Icon(Icons.cancel_outlined)),
                ],
                selected: {_resultado},
                onSelectionChanged: (sel) =>
                    setState(() => _resultado = sel.first),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _elegirFechaRealParto,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Fecha real del parto',
                      border: OutlineInputBorder()),
                  child: Text(_fechaRealParto != null
                      ? widget.dateFormat.format(_fechaRealParto!)
                      : 'Sin definir'),
                ),
              ),
              if (_resultado == 'Parida') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _criasCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de crías',
                    helperText:
                        'Por cada una se abrirá el formulario de Animales con la Madre y el Padre ya puestos.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1)
                      return 'Indica un número mayor o igual a 1';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _notasCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Nota (obligatoria)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Esta nota es obligatoria'
                    : null,
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(s.estaPendiente
                      ? (_accionPendiente == 'fallida'
                          ? 'Marcar como fallida'
                          : 'Confirmar')
                      : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
