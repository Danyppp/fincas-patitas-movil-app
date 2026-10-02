import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/auth_session.dart';
import '../../models/animal.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/produccion/produccion_repository.dart';
import '../../theme/app_theme.dart';

class LecheFormScreen extends StatefulWidget {
  final ProduccionRepository repository;
  final AnimalRepository animalRepository;
  final CatalogoRepository catalogoRepository;
  final AuthSession session;
  final ProduccionLeche? registroExistente;

  const LecheFormScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    required this.catalogoRepository,
    required this.session,
    this.registroExistente,
  });

  @override
  State<LecheFormScreen> createState() => _LecheFormScreenState();
}

class _LecheFormScreenState extends State<LecheFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _litrosCtrl = TextEditingController(text: '0');
  final _observacionesCtrl = TextEditingController();

  List<Animal> _animales = [];
  List<LoteAnimal> _lotes = [];
  Animal? _animalSeleccionado;
  LoteAnimal? _loteSeleccionado;

  /// 'lote' o 'animal' — igual orden que el mockup Stitch
  /// (`registro_produccion_formulario`, modo por defecto "batch").
  String _modalidad = 'lote';
  String _jornada = 'Mañana';

  /// Fecha del registro: NUNCA editable por el usuario (corrección
  /// 2026-09-30, punto 1 — re-aplicada 2026-10-01 porque esta pantalla se
  /// había quedado con una versión vieja). Para un registro nuevo siempre
  /// es "ahora"; en edición se conserva la fecha original tal cual quedó
  /// guardada, convertida a hora local (`.toLocal()`) para que un registro
  /// creado cerca de la medianoche no se muestre con el día equivocado.
  late final DateTime _fecha;

  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.registroExistente != null;

  @override
  void initState() {
    super.initState();
    final actual = widget.registroExistente;
    _fecha = (actual?.registradoEn ?? DateTime.now()).toLocal();
    if (actual != null) {
      _litrosCtrl.text = actual.litros.toString();
      _jornada = actual.jornada ?? 'Mañana';
      _observacionesCtrl.text = actual.observaciones ?? '';
      _modalidad = actual.esPorLote ? 'lote' : 'animal';
    }
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    try {
      // Punto 1: el selector de leche solo debe mostrar VACAS (bovinas)
      // HEMBRA y ACTIVAS — se filtra en el servidor por estado/género
      // (soportado por AnimalRepository.listar) y en el cliente por
      // especie, reutilizando el mismo criterio de `especie_visual.dart`
      // (emojiEspecie) para detectar bovinos por nombre.
      final pagina = await widget.animalRepository.listar(
        estado: 'Activo',
        genero: 'Hembra',
        limite: 200,
      );
      final vacas = pagina.data.where((a) {
        final especie = (a.especie?.nombre ?? '').toLowerCase();
        return especie.contains('bov') || especie.contains('vaca');
      }).toList();
      final lotes = await widget.catalogoRepository.listarLotes();
      setState(() {
        _animales = vacas;
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
    _litrosCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  double get _litrosActuales => double.tryParse(_litrosCtrl.text.trim()) ?? 0;

  void _ajustarLitros(double delta) {
    final nuevo = (_litrosActuales + delta).clamp(0, 99999);
    setState(() => _litrosCtrl.text = nuevo.toStringAsFixed(1));
  }

  void _sumarLitros(double cantidad) {
    setState(() =>
        _litrosCtrl.text = (_litrosActuales + cantidad).toStringAsFixed(1));
  }

  String get _destinoTexto {
    if (_modalidad == 'lote') {
      return _loteSeleccionado?.nombre ?? 'Sin lote seleccionado';
    }
    return _animalSeleccionado != null
        ? '${_animalSeleccionado!.nombreVisible} (${_animalSeleccionado!.codigo})'
        : 'Sin animal seleccionado';
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_esEdicion) {
      if (_modalidad == 'animal' && _animalSeleccionado == null) {
        setState(() => _error = 'Selecciona el animal');
        return;
      }
      if (_modalidad == 'lote' && _loteSeleccionado == null) {
        setState(() => _error = 'Selecciona el lote');
        return;
      }
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final litros = _litrosActuales;
      final observaciones = _observacionesCtrl.text.trim().isEmpty
          ? null
          : _observacionesCtrl.text.trim();
      if (_esEdicion) {
        // `registradoEn` NUNCA se envía al editar: la fecha original del
        // registro no debe cambiar bajo ningún concepto.
        await widget.repository.actualizarLeche(
          widget.registroExistente!.id,
          ActualizarProduccionLecheDTO(
            litros: litros,
            jornada: _jornada,
            observaciones: observaciones,
          ),
        );
      } else {
        // La fecha se calcula FRESCA en el momento de guardar (no se usa
        // `_fecha`, que quedó fijada al abrir el formulario), para que
        // quede el instante real del registro.
        await widget.repository.crearLeche(
          CrearProduccionLecheDTO(
            animalId: _modalidad == 'animal' ? _animalSeleccionado!.id : null,
            loteId: _modalidad == 'lote' ? _loteSeleccionado!.id : null,
            litros: litros,
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
          title: Text(_esEdicion ? 'Editar ordeña' : 'Registrar ordeña')),
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
                            ? 'Seleccionar lote'
                            : 'Seleccionar vaca (hembra activa)',
                      ),
                      const SizedBox(height: 8),
                      if (_modalidad == 'lote')
                        DropdownButtonFormField<LoteAnimal>(
                          initialValue: _loteSeleccionado,
                          decoration: const InputDecoration(labelText: 'Lote'),
                          items: _lotes
                              .map((l) => DropdownMenuItem(
                                  value: l, child: Text(l.nombre)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _loteSeleccionado = v),
                          validator: (v) =>
                              v == null ? 'Selecciona un lote' : null,
                        )
                      else
                        DropdownButtonFormField<Animal>(
                          initialValue: _animalSeleccionado,
                          decoration: const InputDecoration(labelText: 'Vaca'),
                          items: _animales
                              .map((a) => DropdownMenuItem(
                                  value: a,
                                  child:
                                      Text('${a.nombreVisible} (${a.codigo})')))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _animalSeleccionado = v),
                          validator: (v) =>
                              v == null ? 'Selecciona una vaca' : null,
                        ),
                      if (_modalidad == 'animal' && _animales.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'No hay vacas hembra activas registradas todavía.',
                            style: TextStyle(
                                color: AppTheme.outline, fontSize: 12),
                          ),
                        ),
                    ] else ...[
                      Text(
                        widget.registroExistente!.esPorLote
                            ? 'Por lote: ${widget.registroExistente!.loteNombre ?? 'Lote #${widget.registroExistente!.loteId}'}'
                            : 'Por animal: ${widget.registroExistente!.animal?.nombreVisible ?? 'Animal #${widget.registroExistente!.animalId}'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Jornada ARRIBA de la fecha (punto 4 del pedido de
                    // estilos, 2026-10-02) — bloques Mañana/Tarde sin
                    // mostrar horario, mismo lenguaje visual piel/verde
                    // que los bloques de Leche/Huevos de la pantalla
                    // anterior.
                    _SeccionLabel(icono: Icons.wb_twilight, texto: 'Jornada'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < jornadasValidas.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _BloqueJornada(
                              icono: jornadasValidas[i] == 'Mañana'
                                  ? Icons.wb_sunny_outlined
                                  : Icons.wb_twilight,
                              etiqueta: jornadasValidas[i],
                              seleccionado: _jornada == jornadasValidas[i],
                              onTap: () =>
                                  setState(() => _jornada = jornadasValidas[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SeccionLabel(
                        icono: Icons.calendar_today,
                        texto: 'Fecha de registro'),
                    const SizedBox(height: 8),
                    // Solo lectura — ver comentario de `_fecha` arriba.
                    // Tono más claro (2026-10-02): antes usaba
                    // `AppTheme.surfaceContainerHigh` a toda opacidad, que
                    // en este tema se ve muy rosado — se deja un relleno
                    // neutro y claro en su lugar.
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
                        texto: 'Cantidad recolectada (litros)'),
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
                                  onPressed: () => _ajustarLitros(-0.5),
                                  icon: const Icon(Icons.remove),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _litrosCtrl,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        suffixText: 'L'),
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Ingresa los litros';
                                      }
                                      final n = double.tryParse(v.trim());
                                      if (n == null) {
                                        return 'Debe ser un número';
                                      }
                                      if (n < 0) return 'No puede ser negativo';
                                      return null;
                                    },
                                  ),
                                ),
                                IconButton.filled(
                                  onPressed: () => _ajustarLitros(0.5),
                                  icon: const Icon(Icons.add),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                for (final valor in [10.0, 20.0, 50.0])
                                  OutlinedButton(
                                    onPressed: () => _sumarLitros(valor),
                                    child: Text('+${valor.toInt()} L'),
                                  ),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _litrosCtrl.text = '0'),
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
                    // Resumen rediseñado estilo Stitch (punto 9, 2026-10-02):
                    // pastilla "Verificación", campos en tarjetas Rubro/Turno
                    // y Lote destino, y el total resaltado en verde.
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
                                        etiqueta: 'Rubro', valor: 'Leche')),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _CampoResumen(
                                        etiqueta: 'Turno', valor: _jornada)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _CampoResumen(
                              etiqueta: _modalidad == 'lote'
                                  ? 'Lote Destino'
                                  : 'Animal',
                              valor: _destinoTexto,
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
                                  const Text('Volumen a Asentar:'),
                                  Text(
                                      '${_litrosActuales.toStringAsFixed(1)} Litros',
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
                    // "Cancelar y volver" (punto 9, 2026-10-02) — cierra la
                    // pantalla sin guardar nada.
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
/// (2026-10-02, punto 1 del pedido de estilos): un solo contorno
/// redondeado de extremo a extremo, con la opción activa resaltada en
/// verde con check y la inactiva en texto neutro — reemplaza el
/// `SegmentedButton` genérico de Material.
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

/// Bloque de jornada (Mañana/Tarde), sin mostrar el rango de horas —
/// mismo lenguaje visual piel/verde de los bloques de Leche/Huevos de
/// `produccion_list_screen.dart` (2026-10-02, punto 4 del pedido de
/// estilos), para que toda la sección de registro se vea consistente.
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

/// Campo del resumen final (etiqueta arriba, valor abajo), presentado
/// dentro de su propia tarjeta clara — estilo Stitch de "Rubro" / "Turno" /
/// "Lote Destino" (2026-10-02, punto 9 del pedido de estilos).
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
