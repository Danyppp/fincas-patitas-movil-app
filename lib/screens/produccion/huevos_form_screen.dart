import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/auth_session.dart';
import '../../models/animal.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/produccion/produccion_huevos.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/produccion/produccion_repository.dart';
import '../../theme/app_theme.dart';

class HuevosFormScreen extends StatefulWidget {
  final ProduccionRepository repository;
  final AnimalRepository animalRepository;
  final CatalogoRepository catalogoRepository;
  final AuthSession session;
  final ProduccionHuevos? registroExistente;

  const HuevosFormScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    required this.catalogoRepository,
    required this.session,
    this.registroExistente,
  });

  @override
  State<HuevosFormScreen> createState() => _HuevosFormScreenState();
}

class _HuevosFormScreenState extends State<HuevosFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadCtrl = TextEditingController(text: '0');
  final _rotosCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  List<Animal> _animales = [];
  List<LoteAnimal> _lotes = [];
  Animal? _animalSeleccionado;
  LoteAnimal? _loteSeleccionado;

  String _modalidad = 'lote';

  // Jornada (Mañana/Tarde) — agregado 2026-10-01 tras la extensión de
  // backend (PR #14), mismo patrón ya usado en el formulario de Leche.
  String _jornada = 'Mañana';

  /// Fecha del registro: NUNCA editable por el usuario (corrección
  /// 2026-09-30, punto 1) — igual que en Leche.
  late final DateTime _fecha;

  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.registroExistente != null;

  @override
  void initState() {
    super.initState();
    final actual = widget.registroExistente;
    _fecha = actual?.registradoEn ?? DateTime.now();
    if (actual != null) {
      _cantidadCtrl.text = actual.cantidad.toString();
      if (actual.cantidadRotos > 0) {
        _rotosCtrl.text = actual.cantidadRotos.toString();
      }
      _observacionesCtrl.text = actual.observaciones ?? '';
      _modalidad = actual.animalId != null ? 'animal' : 'lote';
      _jornada = actual.jornada ?? 'Mañana';
    }
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    try {
      // Mismo criterio que Leche: solo aves hembra activas ponen huevos.
      final pagina = await widget.animalRepository.listar(
        estado: 'Activo',
        genero: 'Hembra',
        limite: 200,
      );
      final aves = pagina.data.where((a) {
        final especie = (a.especie?.nombre ?? '').toLowerCase();
        return especie.contains('ave') || especie.contains('galli');
      }).toList();
      final lotes = await widget.catalogoRepository.listarLotes();
      setState(() {
        _animales = aves;
        _lotes = lotes;
        if (widget.registroExistente != null) {
          final actual = widget.registroExistente!;
          try {
            if (actual.animalId != null) {
              _animalSeleccionado =
                  _animales.firstWhere((a) => a.id == actual.animalId);
            } else if (actual.loteId != null) {
              _loteSeleccionado =
                  _lotes.firstWhere((l) => l.id == actual.loteId);
            }
          } catch (_) {}
        }
      });
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar los catálogos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _rotosCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  int get _cantidadActual => int.tryParse(_cantidadCtrl.text.trim()) ?? 0;

  void _ajustarCantidad(int delta) {
    final nuevo = (_cantidadActual + delta).clamp(0, 999999);
    setState(() => _cantidadCtrl.text = nuevo.toString());
  }

  void _sumarCantidad(int valor) {
    setState(() => _cantidadCtrl.text = (_cantidadActual + valor).toString());
  }

  String get _destinoTexto {
    if (_modalidad == 'lote') {
      return _loteSeleccionado?.nombre ?? 'Sin lote (opcional)';
    }
    return _animalSeleccionado != null
        ? '${_animalSeleccionado!.nombreVisible} (${_animalSeleccionado!.codigo})'
        : 'Sin animal (opcional)';
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final cantidad = _cantidadActual;
      final rotosTexto = _rotosCtrl.text.trim();
      final rotos = rotosTexto.isEmpty ? null : int.tryParse(rotosTexto);
      final observaciones = _observacionesCtrl.text.trim().isEmpty
          ? null
          : _observacionesCtrl.text.trim();

      if (rotos != null && rotos > cantidad) {
        setState(() {
          _error = 'Los huevos rotos no pueden ser más que la cantidad total';
          _guardando = false;
        });
        return;
      }

      if (_esEdicion) {
        await widget.repository.actualizarHuevos(
          widget.registroExistente!.id,
          ActualizarProduccionHuevosDTO(
            cantidad: cantidad,
            cantidadRotos: rotos,
            jornada: _jornada,
            observaciones: observaciones,
          ),
        );
      } else {
        await widget.repository.crearHuevos(
          CrearProduccionHuevosDTO(
            loteId: _modalidad == 'lote' ? _loteSeleccionado?.id : null,
            animalId: _modalidad == 'animal' ? _animalSeleccionado?.id : null,
            cantidad: cantidad,
            cantidadRotos: rotos,
            jornada: _jornada,
            observaciones: observaciones,
            registradoEn: DateTime.now(),
          ),
        );
      }
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
    final usuario = widget.session.usuario;

    return Scaffold(
      appBar: AppBar(
          title: Text(
              _esEdicion ? 'Editar recolección' : 'Registrar recolección')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_esEdicion) ...[
                      _SeccionLabel(
                          icono: Icons.alt_route,
                          texto: 'Modalidad de registro'),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: AppTheme.primaryContainer,
                          selectedForegroundColor: Colors.white,
                        ),
                        segments: const [
                          ButtonSegment(
                              value: 'lote',
                              label: Text('Por lote'),
                              icon: Icon(Icons.groups)),
                          ButtonSegment(
                              value: 'animal',
                              label: Text('Por animal'),
                              icon: Icon(Icons.pets)),
                        ],
                        selected: {_modalidad},
                        onSelectionChanged: (s) =>
                            setState(() => _modalidad = s.first),
                      ),
                      const SizedBox(height: 16),
                      _SeccionLabel(
                        icono: _modalidad == 'lote' ? Icons.groups : Icons.pets,
                        texto: _modalidad == 'lote'
                            ? 'Lote (opcional)'
                            : 'Ave (opcional, hembra activa)',
                      ),
                      const SizedBox(height: 8),
                      if (_modalidad == 'lote')
                        DropdownButtonFormField<LoteAnimal>(
                          initialValue: _loteSeleccionado,
                          decoration: const InputDecoration(
                              helperText: 'Déjalo vacío si no aplica'),
                          items: _lotes
                              .map((l) => DropdownMenuItem(
                                  value: l, child: Text(l.nombre)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _loteSeleccionado = v),
                        )
                      else
                        DropdownButtonFormField<Animal>(
                          initialValue: _animalSeleccionado,
                          decoration: const InputDecoration(
                              helperText: 'Déjalo vacío si no aplica'),
                          items: _animales
                              .map((a) => DropdownMenuItem(
                                  value: a,
                                  child:
                                      Text('${a.nombreVisible} (${a.codigo})')))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _animalSeleccionado = v),
                        ),
                    ] else ...[
                      Text(
                        widget.registroExistente!.esPorLote
                            ? 'Por lote: ${widget.registroExistente!.loteNombre ?? 'Lote #${widget.registroExistente!.loteId}'}'
                            : (widget.registroExistente!.animalId != null
                                ? 'Por animal: ${widget.registroExistente!.animal?.nombreVisible ?? 'Animal #${widget.registroExistente!.animalId}'}'
                                : 'Sin lote ni animal asociado'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),

                    _SeccionLabel(
                        icono: Icons.calendar_today,
                        texto: 'Fecha de registro'),
                    const SizedBox(height: 8),
                    // Solo lectura, igual que en Leche.
                    InputDecorator(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceContainerHigh,
                        suffixIcon: !_esEdicion
                            ? const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Center(
                                  widthFactor: 1,
                                  child: Text('Hoy',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                              )
                            : null,
                      ),
                      child: Text(
                        '${_fecha.year.toString().padLeft(4, '0')}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    const SizedBox(height: 16),

                    _SeccionLabel(icono: Icons.wb_twilight, texto: 'Jornada'),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: AppTheme.primaryContainer,
                        selectedForegroundColor: Colors.white,
                      ),
                      segments: const [
                        ButtonSegment(
                            value: 'Mañana',
                            label: Text('Mañana'),
                            icon: Icon(Icons.wb_sunny_outlined)),
                        ButtonSegment(
                            value: 'Tarde',
                            label: Text('Tarde'),
                            icon: Icon(Icons.wb_twilight)),
                      ],
                      selected: {_jornada},
                      onSelectionChanged: (s) =>
                          setState(() => _jornada = s.first),
                    ),
                    const SizedBox(height: 16),

                    _SeccionLabel(
                        icono: Icons.scale,
                        texto: 'Cantidad recolectada (huevos)'),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton.filledTonal(
                                  onPressed: () => _ajustarCantidad(-1),
                                  icon: const Icon(Icons.remove),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cantidadCtrl,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        suffixText: 'uds'),
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Ingresa la cantidad';
                                      }
                                      final n = int.tryParse(v.trim());
                                      if (n == null)
                                        return 'Debe ser un número entero';
                                      if (n < 0) return 'No puede ser negativo';
                                      return null;
                                    },
                                  ),
                                ),
                                IconButton.filled(
                                  onPressed: () => _ajustarCantidad(1),
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton(
                                    onPressed: () => _sumarCantidad(30),
                                    child: const Text('+30 (1 cubeta)')),
                                OutlinedButton(
                                    onPressed: () => _sumarCantidad(60),
                                    child: const Text('+60 (2 cubetas)')),
                                OutlinedButton(
                                    onPressed: () => _sumarCantidad(150),
                                    child: const Text('+150')),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _cantidadCtrl.text = '0'),
                                  child: const Text('Limpiar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _SeccionLabel(
                        icono: Icons.egg_alt, texto: 'Huevos rotos (opcional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _rotosCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return null;
                        }
                        if (int.tryParse(v.trim()) == null)
                          return 'Debe ser un número entero';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _SeccionLabel(
                        icono: Icons.engineering,
                        texto: 'Operario responsable'),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryContainer,
                          child: Text(
                            (usuario?.nombreUsuario.isNotEmpty == true)
                                ? usuario!.nombreUsuario[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(usuario?.nombreUsuario ?? 'Usuario actual'),
                        subtitle: Text(usuario?.rolNombre ?? ''),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _SeccionLabel(
                        icono: Icons.edit_note,
                        texto: 'Novedad u observación (opcional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _observacionesCtrl,
                      maxLength: 255,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(alignLabelWithHint: true),
                    ),
                    const SizedBox(height: 8),

                    Card(
                      color: AppTheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.assignment_turned_in,
                                    color: AppTheme.primary, size: 20),
                                SizedBox(width: 8),
                                Text('Resumen del registro',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _FilaResumen(
                              etiqueta: _modalidad == 'lote'
                                  ? 'Lote destino'
                                  : 'Animal',
                              valor: _destinoTexto,
                            ),
                            _FilaResumen(etiqueta: 'Jornada', valor: _jornada),
                            _FilaResumen(
                              etiqueta: 'Rotos',
                              valor: _rotosCtrl.text.trim().isEmpty
                                  ? '0'
                                  : _rotosCtrl.text.trim(),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryContainer
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total a asentar:'),
                                  Text('$_cantidadActual huevos',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_esEdicion ? 'Guardar cambios' : 'Registrar'),
                    ),
                  ],
                ),
              ),
            ),
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
        Icon(icono, size: 18, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _FilaResumen extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _FilaResumen({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: TextStyle(color: AppTheme.outline)),
          Flexible(
              child: Text(valor,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
