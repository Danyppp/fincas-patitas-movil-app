import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/auth_session.dart';
import '../../models/animal.dart';
import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';

/// "Nuevo Evento" (2026-10-19): registro de un evento reproductivo nuevo
/// (IA o Monta natural). Deja el seguimiento en estado "Pendiente".
///
/// "Parto natural / Aborto" queda FUERA de este formulario a propósito
/// (decisión confirmada 2026-10-19): eso no es un evento nuevo, es el
/// cierre de uno que ya existe, y vive en la pantalla "Registrar
/// Seguimiento".
///
/// Mismo mapa de días de gestación que el backend
/// (`seguimientoGestacion.service.ts`, DIAS_GESTACION_POR_ESPECIE) --
/// se usa aquí solo para MOSTRAR la fecha estimada de parto ya calculada
/// y bloqueada; el backend la vuelve a calcular él mismo al guardar, así
/// que nunca hay riesgo de que el cliente mande un valor manipulado.
const _diasGestacionPorEspecie = {'bovino': 283, 'cerdo': 114};

class SeguimientoFormScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;
  final AuthSession session;

  const SeguimientoFormScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    required this.session,
  });

  @override
  State<SeguimientoFormScreen> createState() => _SeguimientoFormScreenState();
}

class _SeguimientoFormScreenState extends State<SeguimientoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notasCtrl = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  List<Animal> _hembras = [];
  List<Animal> _machos = [];
  Animal? _hembraSeleccionada;
  Animal? _padreSeleccionado;
  String? _tipo;
  DateTime _fechaInseminacion = DateTime.now();

  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  // Solo estas dos especies entran en el módulo (decisión confirmada: no
  // ovinos ni aves) -- tanto para la Hembra como para el Padre.
  bool _especiePermitida(Animal a) {
    final nombre = a.especie?.nombre.trim().toLowerCase();
    return nombre == 'bovino' || nombre == 'cerdo';
  }

  /// Machos de la MISMA especie que la hembra elegida -- no tiene sentido
  /// que el Padre sea de otra especie (2026-10-20, corregido: antes se
  /// mostraban todos los machos de ambas especies sin filtrar por la
  /// hembra).
  List<Animal> get _machosFiltrados {
    final especieHembra = _hembraSeleccionada?.especie?.nombre;
    if (especieHembra == null) return const [];
    return _machos.where((m) => m.especie?.nombre == especieHembra).toList();
  }

  @override
  void initState() {
    super.initState();
    _cargarAnimales();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarAnimales() async {
    try {
      final hembras = await widget.animalRepository
          .listar(genero: 'Hembra', estado: 'Activo', limite: 200);
      final machos = await widget.animalRepository
          .listar(genero: 'Macho', estado: 'Activo', limite: 200);
      setState(() {
        _hembras = hembras.data.where(_especiePermitida).toList();
        _machos = machos.data.where(_especiePermitida).toList();
      });
    } catch (e) {
      setState(() => _error = 'No se pudo cargar la lista de animales: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Fecha estimada de parto, calculada en el cliente solo para mostrarla
  /// bloqueada -- el backend la recalcula él mismo al guardar.
  DateTime? get _fechaEstimadaParto {
    final especie = _hembraSeleccionada?.especie?.nombre.trim().toLowerCase();
    final dias = especie == null ? null : _diasGestacionPorEspecie[especie];
    if (dias == null) return null;
    return _fechaInseminacion.add(Duration(days: dias));
  }

  Future<void> _elegirFechaInseminacion() async {
    final resultado = await showDatePicker(
      context: context,
      initialDate: _fechaInseminacion,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (resultado != null) setState(() => _fechaInseminacion = resultado);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hembraSeleccionada == null) {
      setState(() => _error = 'Selecciona la hembra');
      return;
    }
    if (_tipo == null) {
      setState(() => _error = 'Selecciona el tipo de evento');
      return;
    }
    if (_fechaEstimadaParto == null) {
      setState(() => _error =
          'No se pudo calcular la fecha estimada de parto para esta especie. Verifica que la hembra sea Bovino o Cerdo.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.repository.crear(
        CrearSeguimientoDTO(
          animalId: _hembraSeleccionada!.id,
          machoId: _padreSeleccionado?.id,
          tipo: _tipo,
          fechaInseminacion: _fechaInseminacion,
          fechaEstimadaParto: _fechaEstimadaParto,
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Evento')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // -- 1. Hembra --
                    _SeccionLabel(icono: Icons.female, texto: '1. Hembra'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Animal>(
                      initialValue: _hembraSeleccionada,
                      decoration: const InputDecoration(
                          labelText: 'Animal (hembra)',
                          border: OutlineInputBorder()),
                      items: _hembras
                          .map((a) => DropdownMenuItem(
                                value: a,
                                child: Text(
                                    '${a.nombreVisible} (${a.codigo}) · ${a.especie?.nombre ?? '—'}'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _hembraSeleccionada = v;
                        // Si el padre elegido antes ya no es de la misma
                        // especie que la nueva hembra, se limpia.
                        if (_padreSeleccionado != null &&
                            _padreSeleccionado!.especie?.nombre !=
                                v?.especie?.nombre) {
                          _padreSeleccionado = null;
                        }
                      }),
                      validator: (v) =>
                          v == null ? 'Selecciona una hembra' : null,
                    ),
                    const SizedBox(height: 20),

                    // -- 2. Tipo de evento --
                    _SeccionLabel(
                        icono: Icons.event_note, texto: '2. Tipo de evento'),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'IA',
                            label: Text('IA'),
                            icon: Icon(Icons.science_outlined)),
                        ButtonSegment(
                            value: 'Monta natural',
                            label: Text('Monta natural'),
                            icon: Icon(Icons.favorite_outline)),
                      ],
                      selected: _tipo == null ? {} : {_tipo!},
                      emptySelectionAllowed: true,
                      onSelectionChanged: (s) =>
                          setState(() => _tipo = s.isEmpty ? null : s.first),
                    ),
                    const SizedBox(height: 20),

                    // -- 3. Detalles específicos --
                    _SeccionLabel(
                        icono: Icons.list_alt,
                        texto: '3. Detalles específicos'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Animal?>(
                      initialValue: _padreSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Padre (opcional)',
                        border: const OutlineInputBorder(),
                        helperText: _hembraSeleccionada == null
                            ? 'Selecciona primero la hembra'
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem<Animal?>(
                            value: null, child: Text('Sin especificar')),
                        ..._machosFiltrados
                            .map((a) => DropdownMenuItem<Animal?>(
                                  value: a,
                                  child: Text(
                                      '${a.nombreVisible} (${a.codigo}) · ${a.especie?.nombre ?? '—'}'),
                                )),
                      ],
                      onChanged: _hembraSeleccionada == null
                          ? null
                          : (v) => setState(() => _padreSeleccionado = v),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _padreSeleccionado == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _campoAutoCompletado(
                                etiqueta: 'Raza del Padre',
                                valor: _padreSeleccionado!.raza?.nombre ??
                                    'Sin raza registrada',
                              ),
                            ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: _hembraSeleccionada == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _campoAutoCompletado(
                                etiqueta: 'Raza de la Madre',
                                valor: _hembraSeleccionada!.raza?.nombre ??
                                    'Sin raza registrada',
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _elegirFechaInseminacion,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Fecha de inseminación',
                            border: OutlineInputBorder()),
                        child: Text(_dateFormat.format(_fechaInseminacion)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _campoAutoCompletado(
                      etiqueta: 'Personal encargado del registro',
                      valor: widget.session.usuario?.nombreUsuario ?? '—',
                    ),
                    const SizedBox(height: 20),

                    // -- 4. Estimaciones --
                    _SeccionLabel(
                        icono: Icons.calendar_month, texto: '4. Estimaciones'),
                    const SizedBox(height: 8),
                    _campoAutoCompletado(
                      etiqueta: 'Fecha estimada de parto',
                      valor: _fechaEstimadaParto != null
                          ? _dateFormat.format(_fechaEstimadaParto!)
                          : 'Selecciona una hembra Bovino o Cerdo',
                    ),
                    const SizedBox(height: 20),

                    // -- 5. Observaciones --
                    _SeccionLabel(
                        icono: Icons.edit_note, texto: '5. Observaciones'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notasCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          hintText: 'Opcional', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),

                    // -- 6. Resumen del registro (NUEVO) --
                    _SeccionLabel(
                        icono: Icons.assignment_turned_in,
                        texto: '6. Resumen del registro'),
                    const SizedBox(height: 8),
                    _ResumenRegistro(
                      hembra: _hembraSeleccionada?.nombreVisible ??
                          'Sin seleccionar',
                      tipo: _tipo ?? 'Sin seleccionar',
                      padre: _padreSeleccionado?.nombreVisible ??
                          'Sin especificar',
                      fechaInseminacion: _dateFormat.format(_fechaInseminacion),
                      fechaEstimadaParto: _fechaEstimadaParto != null
                          ? _dateFormat.format(_fechaEstimadaParto!)
                          : 'Sin calcular',
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _guardando
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Guardar'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Campo de solo lectura para datos "que se llenan solos" (raza del
  /// padre/madre, encargado, fecha estimada de parto).
  Widget _campoAutoCompletado(
      {required String etiqueta, required String valor}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        filled: true,
        fillColor: AppTheme.surfaceContainerHigh,
      ),
      child: Text(valor),
    );
  }
}

class _SeccionLabel extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _SeccionLabel({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, color: AppTheme.primary, size: 18),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// "Resumen del registro" (punto 6, nuevo) -- mismo patrón visual que ya
/// usamos en Producción (pastilla "Verificación" + campos de solo lectura),
/// para que el usuario revise todo antes de guardar.
class _ResumenRegistro extends StatelessWidget {
  final String hembra;
  final String tipo;
  final String padre;
  final String fechaInseminacion;
  final String fechaEstimadaParto;

  const _ResumenRegistro({
    required this.hembra,
    required this.tipo,
    required this.padre,
    required this.fechaInseminacion,
    required this.fechaEstimadaParto,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_turned_in,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Resumen del Registro',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const _InsigniaVerificacion(),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _CampoResumen(etiqueta: 'Hembra', valor: hembra)),
                const SizedBox(width: 10),
                Expanded(
                    child:
                        _CampoResumen(etiqueta: 'Tipo de evento', valor: tipo)),
              ],
            ),
            const SizedBox(height: 10),
            _CampoResumen(etiqueta: 'Padre', valor: padre),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _CampoResumen(
                        etiqueta: 'Fecha de inseminación',
                        valor: fechaInseminacion)),
                const SizedBox(width: 10),
                Expanded(
                    child: _CampoResumen(
                        etiqueta: 'Fecha estimada de parto',
                        valor: fechaEstimadaParto)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InsigniaVerificacion extends StatelessWidget {
  const _InsigniaVerificacion();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE8B2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Verificación',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8A6A1E)),
      ),
    );
  }
}

class _CampoResumen extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _CampoResumen({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta,
              style: TextStyle(color: AppTheme.outline, fontSize: 12)),
          const SizedBox(height: 2),
          Text(valor,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
