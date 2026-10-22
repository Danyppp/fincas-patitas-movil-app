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

  // 2026-10-22 (Parte 2, estilos, punto 4 y 6): tanto la Hembra como el
  // Padre ahora se eligen con un selector modal (en vez de un dropdown
  // suelto) y se muestran como una pequeña "pill" con sus datos + un ícono
  // 🔁 que vuelve a abrir este mismo selector.
  Future<void> _elegirHembra() async {
    final resultado = await _abrirSelectorAnimal(
      titulo: 'Selecciona la Hembra',
      opciones: _hembras,
    );
    if (resultado == null || resultado.animal == null) return;
    final elegida = resultado.animal!;
    setState(() {
      _hembraSeleccionada = elegida;
      // Si el padre elegido antes ya no es de la misma especie que la
      // nueva hembra, se limpia.
      if (_padreSeleccionado != null &&
          _padreSeleccionado!.especie?.nombre != elegida.especie?.nombre) {
        _padreSeleccionado = null;
      }
    });
  }

  Future<void> _elegirPadre() async {
    if (_hembraSeleccionada == null) return;
    // 2026-10-22: "Sin especificar" se quitó a pedido -- Madre y Padre ya
    // NO pueden quedar vacíos, así que este selector ya no ofrece esa
    // opción (permiteNinguno queda en su valor por defecto, false).
    final resultado = await _abrirSelectorAnimal(
      titulo: 'Selecciona el Padre',
      opciones: _machosFiltrados,
    );
    if (resultado == null) return;
    setState(() => _padreSeleccionado = resultado.animal);
  }

  Future<_ResultadoSeleccion?> _abrirSelectorAnimal({
    required String titulo,
    required List<Animal> opciones,
    bool permiteNinguno = false,
  }) {
    return showModalBottomSheet<_ResultadoSeleccion?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        if (permiteNinguno)
                          ListTile(
                            leading: const Icon(Icons.block,
                                color: AppTheme.outline),
                            title: const Text('Sin especificar'),
                            onTap: () => Navigator.of(context)
                                .pop(const _ResultadoSeleccion(null)),
                          ),
                        if (opciones.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                                child: Text('No hay animales disponibles')),
                          ),
                        for (final animal in opciones)
                          ListTile(
                            leading:
                                const Icon(Icons.pets, color: AppTheme.primary),
                            title: Text(
                                '${animal.nombreVisible} (${animal.codigo})'),
                            subtitle:
                                Text(animal.especie?.nombre ?? 'Especie —'),
                            onTap: () => Navigator.of(context)
                                .pop(_ResultadoSeleccion(animal)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 2026-10-22, a pedido: notificación visible (SnackBar) cuando intentan
  /// guardar con Madre o Padre vacíos -- distinta del texto rojo inline
  /// (`_error`), que ya existía pero es fácil de no notar si la pantalla
  /// está desplazada. Las dos conviven: el SnackBar llama la atención de
  /// inmediato, el texto inline queda como recordatorio mientras corrigen.
  void _mostrarNotificacionCampoVacio(String campo) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No se puede guardar la información porque el campo $campo está vacío',
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hembraSeleccionada == null) {
      _mostrarNotificacionCampoVacio('Madre');
      setState(() => _error = 'Selecciona la hembra');
      return;
    }
    // 2026-10-22, a pedido: Madre y Padre ya NO pueden quedar vacíos --
    // antes el Padre era opcional (decisión original del módulo), pero
    // ahora el formulario exige elegir los dos antes de poder guardar.
    if (_padreSeleccionado == null) {
      _mostrarNotificacionCampoVacio('Padre');
      setState(() => _error = 'Selecciona el padre');
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
      appBar: AppBar(title: const Text('Registro de Evento')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 2026-10-22 (Parte 2, estilos, puntos 1-3 de la
                    // CABEZA): título grande + subtítulo gris + pill de
                    // alcance, estilo Stitch (antes el único título era el
                    // del AppBar, "Nuevo Evento").
                    const Text(
                      'Registrar Evento Reproductivo',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Módulo de reproducción, trazabilidad genética y '
                      'seguimiento de servicios.',
                      style: TextStyle(fontSize: 13, color: AppTheme.outline),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Solo monitoreo para Bovinos (Vacas) y '
                              'Porcinos (Cerdos)',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // -- 1. Hembra --
                    Row(
                      children: [
                        const Icon(Icons.female,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 6),
                        const Text('Hembra',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        if (_hembraSeleccionada != null) ...[
                          const SizedBox(width: 8),
                          const _InsigniaCheck(),
                          const SizedBox(width: 4),
                          Text('Seleccionada',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700])),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    _PillSeleccionAnimal(
                      animal: _hembraSeleccionada,
                      placeholder: 'Toca para seleccionar la hembra',
                      onRecargar: _elegirHembra,
                      error: _hembraSeleccionada == null,
                    ),
                    const SizedBox(height: 24),

                    // -- 2. Tipo de evento --
                    const Row(
                      children: [
                        Icon(Icons.event_note,
                            color: AppTheme.primary, size: 18),
                        SizedBox(width: 6),
                        Text('Tipo de evento',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 2026-10-22 (punto 5): pills verticales en vez del
                    // SegmentedButton horizontal -- marca con "✅" y en
                    // amarillo (secondaryContainer) la opción elegida.
                    _PillTipoEvento(
                      valor: 'IA',
                      icono: Icons.science_outlined,
                      seleccionado: _tipo == 'IA',
                      onTap: () => setState(() => _tipo = 'IA'),
                    ),
                    const SizedBox(height: 8),
                    _PillTipoEvento(
                      valor: 'Monta natural',
                      icono: Icons.favorite_outline,
                      seleccionado: _tipo == 'Monta natural',
                      onTap: () => setState(() => _tipo = 'Monta natural'),
                    ),
                    const SizedBox(height: 24),

                    // -- 3. Detalles específicos --
                    const Row(
                      children: [
                        Icon(Icons.list_alt, color: AppTheme.primary, size: 18),
                        SizedBox(width: 6),
                        Text('Detalles específicos',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _PillSeleccionAnimal(
                      animal: _padreSeleccionado,
                      // 2026-10-22: "(opcional)" ya no aplica -- el Padre
                      // ahora es obligatorio, igual que la Hembra.
                      placeholder: _hembraSeleccionada == null
                          ? 'Selecciona primero la hembra'
                          : 'Padre -- toca para elegir',
                      onRecargar:
                          _hembraSeleccionada == null ? null : _elegirPadre,
                      error: _padreSeleccionado == null,
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
                    // 2026-10-22 (punto 8): el cuadro de texto crece con el
                    // contenido (maxLines: null) en vez de cortar el texto,
                    // y AnimatedSize anima ese crecimiento en vez de que
                    // salte de golpe.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      alignment: Alignment.topCenter,
                      child: TextFormField(
                        controller: _notasCtrl,
                        minLines: 3,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                            hintText: 'Opcional', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // -- 6. Resumen del registro --
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

  /// Campo de solo lectura para datos "que se llenan solos" (encargado,
  /// fecha estimada de parto).
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

/// Pill con los datos del animal elegido (Nombre, ID, Especie) + un ícono
/// 🔁 que reabre el selector -- mismo patrón para Hembra y Padre (puntos 4
/// y 6 de la Parte 2, estilos). Cuando cambia el animal seleccionado, un
/// AnimatedSwitcher hace una aparición de 0.5s en vez de un cambio brusco.
class _PillSeleccionAnimal extends StatelessWidget {
  final Animal? animal;
  final String placeholder;
  final VoidCallback? onRecargar;
  final bool error;

  const _PillSeleccionAnimal({
    required this.animal,
    required this.placeholder,
    required this.onRecargar,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      onTap: onRecargar,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
            color: error
                ? AppTheme.error.withValues(alpha: 0.4)
                : AppTheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animacion) => FadeTransition(
            opacity: animacion,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(animacion),
              child: child,
            ),
          ),
          child: animal == null
              ? Padding(
                  key: const ValueKey('vacio'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(placeholder,
                      style: const TextStyle(color: AppTheme.outline)),
                )
              : Row(
                  key: ValueKey(animal!.id),
                  children: [
                    const Icon(Icons.pets, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(animal!.nombreVisible,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            'ID: ${animal!.codigo} · '
                            '${animal!.especie?.nombre ?? "Especie —"}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.outline),
                          ),
                        ],
                      ),
                    ),
                    if (onRecargar != null)
                      IconButton(
                        onPressed: onRecargar,
                        icon: const Icon(Icons.autorenew,
                            color: Color(0xFFE08B3A)),
                        tooltip: 'Cambiar',
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Pill vertical seleccionable para "Tipo de evento" -- al elegirla se
/// marca con "✅" y en amarillo (punto 5 de la Parte 2, estilos).
class _PillTipoEvento extends StatelessWidget {
  final String valor;
  final IconData icono;
  final bool seleccionado;
  final VoidCallback onTap;

  const _PillTipoEvento({
    required this.valor,
    required this.icono,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: seleccionado
              ? AppTheme.secondaryContainer
              : AppTheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
            color: seleccionado
                ? AppTheme.onSecondaryContainer.withValues(alpha: 0.3)
                : AppTheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Icon(icono,
                color: seleccionado
                    ? AppTheme.onSecondaryContainer
                    : AppTheme.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                valor,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: seleccionado ? AppTheme.onSecondaryContainer : null,
                ),
              ),
            ),
            if (seleccionado) const _InsigniaCheck(),
          ],
        ),
      ),
    );
  }
}

/// Insignia de "seleccionado/marcado" -- cuadradito con esquinas
/// redondeadas, fondo verde y check blanco (en vez del emoji "✅" plano).
/// La usan tanto "Hembra ✓ Seleccionada" como la pill de Tipo de evento
/// elegida.
class _InsigniaCheck extends StatelessWidget {
  const _InsigniaCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.green[600],
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 13),
    );
  }
}

/// Resultado del selector modal de animal -- distingue "cerró sin elegir"
/// (el Future resuelve en `null`) de "eligió explícitamente Sin
/// especificar" (resuelve en `_ResultadoSeleccion(null)`), algo que un
/// simple `Animal?` no podía distinguir.
class _ResultadoSeleccion {
  final Animal? animal;
  const _ResultadoSeleccion(this.animal);
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
/// para que el usuario revise todo antes de guardar. (Punto 9 de la Parte
/// 2, estilos: se conserva sin cambios.)
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
