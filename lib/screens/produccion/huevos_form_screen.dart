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
    // `.toLocal()`: `actual.registradoEn` viene parseado del backend en
    // UTC: sin convertir a hora local, un registro creado cerca de la
    // medianoche podía mostrar el día equivocado (corrección 2026-10-01).
    _fecha = (actual?.registradoEn ?? DateTime.now()).toLocal();
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
                      _ModalidadPill(
                        seleccionado: _modalidad,
                        opciones: const [
                          _OpcionModalidad(
                              valor: 'lote',
                              etiqueta: 'Por lote',
                              icono: Icons.groups),
                          _OpcionModalidad(
                              valor: 'animal',
                              etiqueta: 'Por animal',
                              icono: Icons.pets),
                        ],
                        onChanged: (v) => setState(() => _modalidad = v),
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

                    // Jornada ARRIBA de la fecha (punto 4 del pedido de
                    // estilos, 2026-10-02) — antes iba después de la fecha.
                    _SeccionLabel(icono: Icons.wb_twilight, texto: 'Jornada'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _BloqueJornada(
                            icono: Icons.wb_sunny_outlined,
                            etiqueta: 'Mañana',
                            seleccionado: _jornada == 'Mañana',
                            onTap: () => setState(() => _jornada = 'Mañana'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _BloqueJornada(
                            icono: Icons.wb_twilight,
                            etiqueta: 'Tarde',
                            seleccionado: _jornada == 'Tarde',
                            onTap: () => setState(() => _jornada = 'Tarde'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _SeccionLabel(
                        icono: Icons.calendar_today,
                        texto: 'Fecha de registro'),
                    const SizedBox(height: 8),
                    // Solo lectura, igual que en Leche. Tono más claro
                    // (2026-10-02): antes se veía muy rosado en este tema.
                    InputDecorator(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF7F4F1),
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

                    // Resumen rediseñado estilo Stitch (punto 9, 2026-10-02).
                    Card(
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
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                const _InsigniaVerificacion(),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _CampoResumen(
                                    etiqueta: _modalidad == 'lote'
                                        ? 'Lote Destino'
                                        : 'Animal',
                                    valor: _destinoTexto,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _CampoResumen(
                                        etiqueta: 'Jornada', valor: _jornada)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _CampoResumen(
                              etiqueta: 'Rotos',
                              valor: _rotosCtrl.text.trim().isEmpty
                                  ? '0'
                                  : _rotosCtrl.text.trim(),
                            ),
                            const SizedBox(height: 10),
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
                    const SizedBox(height: 10),
                    // "Cancelar y volver" (punto 9, 2026-10-02).
                    OutlinedButton(
                      onPressed: _guardando
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar y volver'),
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

/// Una opción dentro de la píldora de "Modalidad de registro".
class _OpcionModalidad {
  final String valor;
  final String etiqueta;
  final IconData icono;

  const _OpcionModalidad(
      {required this.valor, required this.etiqueta, required this.icono});
}

/// Selector de modalidad en forma de píldora flotante, estilo Stitch
/// (2026-10-02, punto 1 del pedido de estilos) — ver comentario equivalente
/// en `leche_form_screen.dart`.
class _ModalidadPill extends StatelessWidget {
  final String seleccionado;
  final List<_OpcionModalidad> opciones;
  final ValueChanged<String> onChanged;

  const _ModalidadPill(
      {required this.seleccionado,
      required this.opciones,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: opciones.map((o) {
          final activo = o.valor == seleccionado;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(o.valor),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: activo ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      activo ? Icons.check_circle : o.icono,
                      size: 16,
                      color: activo ? Colors.white : AppTheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      o.etiqueta,
                      style: TextStyle(
                        color: activo ? Colors.white : AppTheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bloque de jornada (Mañana/Tarde), sin mostrar el rango de horas — mismo
/// lenguaje visual piel/verde de los bloques de Leche/Huevos de
/// `produccion_list_screen.dart` (2026-10-02, punto 4 del pedido de
/// estilos), para que toda la sección de registro se vea consistente. Igual
/// que en `leche_form_screen.dart` (se duplica a propósito: son dos
/// pantallas independientes y el widget es chico).
class _BloqueJornada extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final bool seleccionado;
  final VoidCallback onTap;

  const _BloqueJornada({
    required this.icono,
    required this.etiqueta,
    required this.seleccionado,
    required this.onTap,
  });

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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: colorFondoIcono, shape: BoxShape.circle),
                    child: Icon(icono, color: colorIcono, size: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(etiqueta,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              if (seleccionado)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(1),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle,
                        color: AppTheme.primary, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastilla "Verificación" del encabezado del resumen final, estilo Stitch.
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

/// Campo del resumen final (etiqueta arriba, valor abajo) en su propia
/// tarjeta clara — ver comentario equivalente en `leche_form_screen.dart`.
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
