import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/auth_session.dart';
import '../../models/animal.dart';
import '../../models/inventario/insumo.dart';
import '../../models/salud/evento_sanitario.dart';
import '../../repositories/inventario/insumo_repository.dart';
import '../../repositories/salud/evento_sanitario_repository.dart';
import '../../theme/app_theme.dart';

/// ID real de la categoría "Medicamentos" en `categorias_bodega`
/// (confirmado en decisiones-diseno-vs-backend-inventario.md sección 6).
const int _kCategoriaMedicamentosId = 2;

/// Mismo listado que `UNIDADES_VALIDAS` en `bodega.service.ts` del backend
/// (ver `insumo_form_screen.dart`) -- reutilizado acá para que "Unidad" en
/// Salud sea el mismo catálogo cerrado que ya usa Inventario.
const List<String> _unidadesValidas = [
  'ml',
  'Ltr',
  'g',
  'Kg',
  'Dosis',
  'Unidad',
  'Bulto',
  'Arroba',
];

/// Vías de administración según el mockup de Stitch
/// (`registro_de_evento_sanitario_fincas_y_patitas`).
const List<String> _viasAdministracion = [
  'Subcutánea',
  'Intramuscular',
  'Oral',
  'Intramamaria',
  'Tópica',
  'Intravenosa',
];

/// Formulario único para crear/editar un evento de salud, siempre atado a
/// un animal puntual (nunca "lote completo" -- ver
/// decisiones-diseno-vs-backend-salud.md sección 2).
///
/// 2026-10-27, segunda ronda de estilos a pedido de Dany (comparando contra
/// el mockup real de Stitch):
/// - Tipo de evento: tarjetas seleccionables (no dropdown).
/// - Fecha del evento: fija al día del registro, no editable.
/// - Descripción: caja de texto que crece con el contenido.
/// - Detalle clínico: TODOS los campos obligatorios.
///   - Dosis: solo números enteros/decimales (máx. 2 decimales).
///   - Unidad: catálogo cerrado (mismas 8 unidades de Inventario).
///   - Vía de administración: tarjetas seleccionables del mockup.
///   - Medicamento: se elige de la Bodega real (categoría Medicamentos),
///     mostrando stock disponible -- reabre la integración Salud↔Inventario
///     que antes se había descartado, a pedido explícito de Dany.
///   - Profesional/responsable: el usuario de la sesión actual, fijo (no
///     editable) -- mismo patrón de auditoría ya usado en
///     Producción/Reproducción ("quién hizo el registro").
///   - Próximo refuerzo: calendario, sigue siendo opcional (no todo
///     tratamiento necesita refuerzo) -- si esto no es lo que querías,
///     avísame y lo hago obligatorio también.
///
/// Al CREAR un evento con medicamento seleccionado, se descuenta 1
/// movimiento de "Salida" (motivo "Consumo") en Inventario por la
/// `dosisAplicada`, usando el endpoint que ya existe
/// (`POST /bodega/:id/movimientos`) -- sin tocar el backend de Salud ni el
/// de Inventario. Si ese descuento falla, el evento de salud ya quedó
/// guardado igual (se avisa aparte, no se revierte el registro).
///
/// Al EDITAR no se vuelve a descontar inventario (para no duplicar el
/// descuento ya hecho al crear) -- si hace falta corregir stock por una
/// edición, se hace manualmente desde Inventario por ahora.
///
/// 2026-11-01 (Etapa 2: Estilos): ajustes de detalle contra los mockups
/// `registro_de_evento_sanitario_fincas_y_patitas` y
/// `editar_evento_de_salud_fincas_y_patitas` -- secciones con esquinas más
/// redondeadas (rounded-3xl del mockup), chips de "Vía de administración"
/// y "¿Próximo refuerzo?" un poco más compactos que los de "Tipo de
/// evento" (igual que en el mockup), y los campos bloqueados (fecha,
/// unidad, estado, profesional) usan el mismo tono que los campos
/// editables -- en el mockup NO hay diferencia visual entre un campo fijo
/// y uno que se puede tocar, todos comparten el mismo fondo durazno.
class EventoSanitarioFormScreen extends StatefulWidget {
  final Animal animal;
  final EventoSanitarioRepository repository;
  final InsumoRepository insumoRepository;
  final AuthSession session;
  final EventoSanitario? eventoExistente;

  const EventoSanitarioFormScreen({
    super.key,
    required this.animal,
    required this.repository,
    required this.insumoRepository,
    required this.session,
    this.eventoExistente,
  });

  @override
  State<EventoSanitarioFormScreen> createState() =>
      _EventoSanitarioFormScreenState();
}

class _EventoSanitarioFormScreenState extends State<EventoSanitarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dosisCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _dateFormat = DateFormat('d \'de\' MMMM, yyyy', 'es');

  String? _tipoEvento;
  String _estado = 'Abierto';
  DateTime _fechaEvento = DateTime.now();
  DateTime? _fechaProximoRefuerzo;
  String? _unidadDosis;
  String? _viaAdministracion;
  Insumo? _medicamentoSeleccionado;
  bool _tieneProximoRefuerzo = false;
  // 2026-10-31 (punto 5.5.2 de la nota de Dany): "Dosis aplicada" queda
  // bloqueada hasta elegir el medicamento -- incluso en edición, aunque el
  // medicamento ya venga preseleccionado del evento existente, hay que
  // volver a tocarlo (aunque se re-elija el mismo) para desbloquear Dosis.
  // Por eso arranca siempre en false, también cuando _esEdicion.
  bool _medicamentoConfirmado = false;
  // 2026-10-31 (nuevo flujo pedido por Dany): el Estado ya no se elige
  // libremente en edición -- se deriva de la respuesta a "¿Próximo
  // refuerzo?" (Sí -> En tratamiento, No -> Resuelto). Este flag indica si
  // ya se respondió esa pregunta EN ESTA sesión de edición. Mientras sea
  // false, el campo Estado queda bloqueado/inhabilitado y no se puede
  // guardar la edición (un evento no puede quedar "Abierto").
  //
  // 2026-10-31, ajuste pedido por Dany: la regla real es "un evento no
  // puede GUARDAR CAMBIOS si está en Abierto" -- eso solo puede pasar en
  // la PRIMERA edición (todo evento nace Abierto, y esta pantalla es la
  // única forma de sacarlo de ahí). Si el evento, al abrir el formulario,
  // YA tenía un estado distinto a "Abierto" (porque una edición anterior
  // ya lo resolvió), la regla ya está cumplida -- no tiene sentido volver
  // a exigir la pregunta solo para corregir, por ejemplo, la descripción.
  // Por eso este flag arranca en `true` en ese caso (ver initState) y la
  // pregunta queda disponible pero ya NO es obligatoria para guardar.
  bool _refuerzoEstablecido = false;

  List<Insumo> _medicamentosDisponibles = [];
  bool _cargandoMedicamentos = true;
  String? _errorMedicamentos;

  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.eventoExistente != null;

  @override
  void initState() {
    super.initState();
    final actual = widget.eventoExistente;
    if (actual != null) {
      _tipoEvento = actual.tipoEvento;
      _estado = actual.estado;
      _fechaEvento = actual.fechaEvento ?? DateTime.now();
      _fechaProximoRefuerzo = actual.fechaProximoRefuerzo;
      _tieneProximoRefuerzo = actual.fechaProximoRefuerzo != null;
      // 2026-10-31: solo se exige (re)confirmar "¿Próximo refuerzo?" para
      // poder guardar si el evento sigue "Abierto" -- si ya salió de ahí
      // en una edición previa, esta pregunta queda disponible por si se
      // quiere cambiar, pero no bloquea guardar otros cambios.
      _refuerzoEstablecido = actual.estado != 'Abierto';
      _unidadDosis = actual.unidadDosis;
      _viaAdministracion = actual.viaAdministracion;
      _dosisCtrl.text = actual.dosisAplicada?.toString() ?? '';
      _descripcionCtrl.text = actual.descripcionTratamiento ?? '';
    }
    _cargarMedicamentos();
  }

  Future<void> _cargarMedicamentos() async {
    setState(() {
      _cargandoMedicamentos = true;
      _errorMedicamentos = null;
    });
    try {
      final insumos = await widget.insumoRepository.listar(
        categoriaId: _kCategoriaMedicamentosId,
        soloStockBajo: false,
      );
      if (!mounted) return;
      setState(() {
        _medicamentosDisponibles = insumos;
        // En edición: si el texto guardado coincide con un insumo real de
        // la Bodega actual, se preselecciona. Si no (insumo renombrado o
        // eliminado desde entonces), queda sin seleccionar y hay que
        // volver a elegir uno.
        final nombreGuardado = widget.eventoExistente?.medicamento;
        if (nombreGuardado != null) {
          for (final insumo in insumos) {
            if (insumo.nombre == nombreGuardado) {
              _medicamentoSeleccionado = insumo;
              break;
            }
          }
        }
      });
    } catch (e) {
      setState(() => _errorMedicamentos = 'No se pudo cargar Bodega: $e');
    } finally {
      if (mounted) setState(() => _cargandoMedicamentos = false);
    }
  }

  @override
  void dispose() {
    _dosisCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirMedicamento() async {
    final seleccionado = await showModalBottomSheet<Insumo>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SelectorMedicamento(
        medicamentos: _medicamentosDisponibles,
        cargando: _cargandoMedicamentos,
        error: _errorMedicamentos,
        onReintentar: _cargarMedicamentos,
      ),
    );
    if (seleccionado != null) {
      setState(() {
        _medicamentoSeleccionado = seleccionado;
        // 2026-10-31 (punto 3.1 de la nota de Dany): la Unidad ya no la
        // elige el usuario -- se autocompleta con la unidad real del
        // insumo en Inventario, y queda bloqueada (ver _campoBloqueado
        // en el bloque de Detalle clinico).
        _unidadDosis = seleccionado.unidadMedida;
        // 2026-10-31 (punto 5.5.2): confirmar/re-confirmar el medicamento
        // desbloquea "Dosis aplicada".
        _medicamentoConfirmado = true;
      });
    }
  }

  Future<void> _elegirFechaRefuerzo() async {
    // 2026-10-31 (bug reportado por Dany): la fecha del refuerzo no puede
    // ser anterior a la fecha del evento -- antes el calendario permitía
    // cualquier fecha desde el año 2000.
    final primeraFechaValida = _fechaEvento;
    final fechaInicial = _fechaProximoRefuerzo != null &&
            !_fechaProximoRefuerzo!.isBefore(primeraFechaValida)
        ? _fechaProximoRefuerzo!
        : primeraFechaValida;
    final resultado = await showDatePicker(
      context: context,
      initialDate: fechaInicial,
      firstDate: primeraFechaValida,
      lastDate: DateTime(2100),
    );
    if (resultado != null) {
      setState(() => _fechaProximoRefuerzo = resultado);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoEvento == null) {
      setState(() => _error = 'Selecciona el tipo de evento');
      return;
    }
    if (_viaAdministracion == null) {
      setState(() => _error = 'Selecciona la vía de administración');
      return;
    }
    if (_medicamentoSeleccionado == null) {
      setState(() => _error = 'Selecciona el medicamento/biológico aplicado');
      return;
    }
    if (_tieneProximoRefuerzo && _fechaProximoRefuerzo == null) {
      setState(() => _error = 'Selecciona la fecha del próximo refuerzo');
      return;
    }
    // 2026-10-31, nuevo flujo pedido por Dany: un evento NUNCA se guarda
    // (al editar) quedando en "Abierto" -- hay que responder "¿Próximo
    // refuerzo?" para que el Estado se derive a "En tratamiento" o
    // "Resuelto". Si no se ha respondido todavía, no se deja guardar.
    if (_esEdicion && !_refuerzoEstablecido) {
      setState(() => _error =
          'Responde "¿Próximo refuerzo?" para poder guardar los cambios. Un evento no puede quedar guardado como "Abierto".');
      return;
    }
    // 2026-10-31, a pedido de Dany: no se puede marcar un evento como
    // Resuelto mientras tenga un refuerzo pendiente -- hay que aplicarlo
    // (o quitarlo, eligiendo "No" arriba) antes de poder resolverlo.
    // Mismo bloqueo ya aplicado en el backend (cambiarEstado).
    if (_esEdicion && _estado == 'Resuelto' && _tieneProximoRefuerzo) {
      setState(() => _error =
          'No puedes marcar este evento como Resuelto mientras tenga un refuerzo pendiente. Aplícalo o cámbialo a "No" primero.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final dosis = double.parse(_dosisCtrl.text.trim().replaceAll(',', '.'));
    final nombreProfesional = widget.eventoExistente?.profesionalResponsable ??
        widget.session.usuario?.nombreUsuario ??
        'Usuario desconocido';

    try {
      if (_esEdicion) {
        final evento = widget.eventoExistente!;
        await widget.repository.actualizar(
          evento.id,
          ActualizarEventoSanitarioDTO(
            tipoEvento: _tipoEvento,
            dosisAplicada: dosis,
            descripcionTratamiento: _descripcionCtrl.text.trim().isEmpty
                ? null
                : _descripcionCtrl.text.trim(),
            fechaEvento: _fechaEvento,
            viaAdministracion: _viaAdministracion,
            unidadDosis: _unidadDosis,
            profesionalResponsable: nombreProfesional,
            medicamento: _medicamentoSeleccionado!.nombre,
            fechaProximoRefuerzo: _fechaProximoRefuerzo,
            // 2026-10-31 (bug reportado por Dany): si el usuario puso "No"
            // en refuerzo, hay que decírselo explícito al backend para que
            // borre la fecha vieja -- ver evento_sanitario.dart.
            limpiarProximoRefuerzo: !_tieneProximoRefuerzo,
          ),
        );
        if (_estado != evento.estado) {
          await widget.repository.cambiarEstado(evento.id, _estado);
        }
      } else {
        await widget.repository.crear(
          CrearEventoSanitarioDTO(
            animalId: widget.animal.id,
            tipoEvento: _tipoEvento!,
            dosisAplicada: dosis,
            descripcionTratamiento: _descripcionCtrl.text.trim().isEmpty
                ? null
                : _descripcionCtrl.text.trim(),
            fechaEvento: _fechaEvento,
            viaAdministracion: _viaAdministracion,
            unidadDosis: _unidadDosis,
            profesionalResponsable: nombreProfesional,
            medicamento: _medicamentoSeleccionado!.nombre,
            fechaProximoRefuerzo: _fechaProximoRefuerzo,
          ),
        );

        // Descuento de inventario -- solo al crear, y no bloquea el
        // registro del evento si falla (el evento ya quedó guardado).
        try {
          await widget.insumoRepository.registrarMovimiento(
            _medicamentoSeleccionado!.id,
            tipo: 'Salida',
            cantidad: dosis,
            motivo: 'Consumo',
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'El evento se guardó, pero no se pudo descontar de Bodega: $e'),
            ));
          }
        }
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

  /// Sección blanca redondeada (rounded-3xl del mockup) con icono + título
  /// a la izquierda.
  Widget _seccion(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    String? subtitulo,
    required List<Widget> children,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, color: AppTheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titulo,
                    style: textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (subtitulo != null)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text(subtitulo, style: textTheme.bodySmall),
            ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  /// Tarjeta seleccionable genérica -- usada para Tipo de evento, Vía de
  /// administración y ¿Próximo refuerzo?, mismo patrón visual que las
  /// tarjetas de especie en el formulario de Animales. `compacta` reduce
  /// el tamaño de fuente/relleno para que los chips de "Vía de
  /// administración" y "Sí/No" queden más pequeños que los de "Tipo de
  /// evento", igual que en el mockup.
  Widget _tarjetaOpcion({
    required String texto,
    required bool seleccionada,
    required VoidCallback onTap,
    bool compacta = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          vertical: compacta ? 8 : 10,
          horizontal: compacta ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: seleccionada ? AppTheme.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
            color: seleccionada
                ? AppTheme.primaryContainer
                : AppTheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: compacta ? 12 : 13,
            color: seleccionada ? Colors.white : AppTheme.onSurface,
          ),
        ),
      ),
    );
  }

  /// Campo de solo lectura -- en el mockup NO hay diferencia visual entre
  /// un campo fijo (fecha, estado, profesional) y uno editable: todos
  /// comparten el mismo fondo durazno, así que este usa el mismo
  /// `fillColor` que el resto de los `TextFormField` del formulario.
  Widget _campoBloqueado({required String etiqueta, required String valor}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        filled: true,
        fillColor: AppTheme.surfaceContainerLow,
      ),
      child: Text(valor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo =
        _esEdicion ? 'Editar evento de salud' : 'Registrar evento de salud';
    final nombreProfesional = widget.eventoExistente?.profesionalResponsable ??
        widget.session.usuario?.nombreUsuario ??
        'Usuario desconocido';

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -- 1. Animal (fijo, informativo) --
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.onSurface.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.pets, color: AppTheme.primary, size: 28),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.animal.nombreVisible,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('#${widget.animal.codigo}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.outline)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // -- 2. Tipo de evento (tarjetas seleccionables) --
              _seccion(
                context,
                icono: Icons.medical_services_outlined,
                titulo: 'Tipo de evento sanitario',
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: tiposEventoSanitarioValidos
                        .map((t) => _tarjetaOpcion(
                              texto: t,
                              seleccionada: _tipoEvento == t,
                              onTap: () => setState(() => _tipoEvento = t),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  // -- 3. Fecha del evento: fija, no editable --
                  _campoBloqueado(
                    etiqueta: 'Fecha del evento',
                    valor: _dateFormat.format(_fechaEvento),
                  ),
                  const SizedBox(height: 16),
                  // -- 4. Descripción: crece con el contenido --
                  TextFormField(
                    controller: _descripcionCtrl,
                    minLines: 3,
                    maxLines: null,
                    decoration: const InputDecoration(
                      labelText: 'Descripción del evento (opcional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // -- 5. Detalle clínico: todo obligatorio --
              _seccion(
                context,
                icono: Icons.vaccines_outlined,
                titulo: 'Detalle clínico',
                subtitulo: 'Todos los campos son obligatorios',
                children: [
                  // -- 5.1 Medicamento / biologico --
                  InkWell(
                    onTap: _elegirMedicamento,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Medicamento / biológico *'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _medicamentoSeleccionado == null
                                  ? 'Toca para elegir de Bodega'
                                  : '${_medicamentoSeleccionado!.nombre} · ${_medicamentoSeleccionado!.stockActual.toStringAsFixed(0)} ${_medicamentoSeleccionado!.unidadMedida} en Bodega',
                              style: _medicamentoSeleccionado == null
                                  ? TextStyle(color: AppTheme.outline)
                                  : null,
                            ),
                          ),
                          const Icon(Icons.inventory_2_outlined, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // -- 5.2 Dosis aplicada / Unidad (autocompletada segun el
                  // medicamento elegido arriba, no editable) --
                  // Punto 5.5.2: Dosis queda bloqueada hasta confirmar un
                  // medicamento (incluso re-seleccionando el mismo en
                  // edición -- ver _medicamentoConfirmado).
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _dosisCtrl,
                            enabled: _medicamentoConfirmado,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]')),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Dosis aplicada *',
                              helperText: _medicamentoConfirmado
                                  ? null
                                  : 'Elige el medicamento primero',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Obligatorio';
                              }
                              final normalizado = v.trim().replaceAll(',', '.');
                              final valido = RegExp(r'^\d+(\.\d{1,2})?$')
                                  .hasMatch(normalizado);
                              if (!valido) {
                                return 'Solo números, máx. 2 decimales';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _campoBloqueado(
                            etiqueta: 'Unidad',
                            valor:
                                _unidadDosis ?? 'Elige un medicamento primero',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // -- 5.3 Via de administracion --
                  Text('Vía de administración *',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _viasAdministracion
                        .map((v) => _tarjetaOpcion(
                              texto: v,
                              seleccionada: _viaAdministracion == v,
                              compacta: true,
                              onTap: () =>
                                  setState(() => _viaAdministracion = v),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  // -- 5.4 Proximo refuerzo: switch Si/No (punto 3.2 de la
                  // nota de Dany). El calendario solo aparece si "Si". --
                  Text('¿Próximo refuerzo? *',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _tarjetaOpcion(
                        texto: 'Sí',
                        compacta: true,
                        // Ninguna de las dos aparece seleccionada hasta que
                        // el usuario toque una -- evita que "No" parezca
                        // ya elegido de entrada (ver _refuerzoEstablecido).
                        seleccionada:
                            _refuerzoEstablecido && _tieneProximoRefuerzo,
                        onTap: () {
                          setState(() {
                            _tieneProximoRefuerzo = true;
                            _refuerzoEstablecido = true;
                            // Nuevo flujo (2026-10-31): "Sí" fuerza el
                            // Estado a "En tratamiento".
                            _estado = 'En tratamiento';
                          });
                          if (_fechaProximoRefuerzo == null) {
                            _elegirFechaRefuerzo();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _tarjetaOpcion(
                        texto: 'No',
                        compacta: true,
                        seleccionada:
                            _refuerzoEstablecido && !_tieneProximoRefuerzo,
                        onTap: () => setState(() {
                          _tieneProximoRefuerzo = false;
                          _fechaProximoRefuerzo = null;
                          _refuerzoEstablecido = true;
                          // Nuevo flujo (2026-10-31): "No" fuerza el
                          // Estado a "Resuelto".
                          _estado = 'Resuelto';
                        }),
                      ),
                    ],
                  ),
                  // Aviso informativo (2026-10-31, a pedido de Dany): si el
                  // evento todavía está "Abierto" (por eso falta confirmar)
                  // pero YA se había registrado con un refuerzo programado,
                  // se avisa esa fecha de entrada en vez de que el usuario
                  // tenga que tocar "Sí" a ciegas para descubrirla. Las
                  // tarjetas Sí/No de arriba siguen sin marcarse como
                  // seleccionadas hasta que se toque una -- esto es solo
                  // informativo, no reemplaza la confirmación explícita.
                  if (!_refuerzoEstablecido &&
                      _fechaProximoRefuerzo != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusDefault),
                      ),
                      child: Text(
                        'Este evento se registró con un refuerzo programado '
                        'para el ${_dateFormat.format(_fechaProximoRefuerzo!)}. '
                        'Toca "Sí" para confirmarlo o "No" si ya no aplica.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                  if (_refuerzoEstablecido && _tieneProximoRefuerzo) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _elegirFechaRefuerzo,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusDefault),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Fecha del refuerzo'),
                        child: Text(_fechaProximoRefuerzo != null
                            ? _dateFormat.format(_fechaProximoRefuerzo!)
                            : 'Toca para elegir fecha'),
                      ),
                    ),
                  ],
                  // -- Estado: depende de la respuesta de arriba. Un
                  // evento nunca se guarda en "Abierto" -- "Sí" fuerza
                  // "En tratamiento", "No" fuerza "Resuelto". Solo aplica
                  // en edición (un evento nuevo siempre nace "Abierto",
                  // eso ya lo hace el backend). --
                  if (_esEdicion) ...[
                    const SizedBox(height: 16),
                    _campoBloqueado(
                      etiqueta: 'Estado',
                      valor: _refuerzoEstablecido
                          ? _estado
                          : 'Responde "¿Próximo refuerzo?" para continuar',
                    ),
                  ],
                  const SizedBox(height: 16),
                  // -- 5.5 Profesional/responsable: el usuario logueado, fijo --
                  _campoBloqueado(
                    etiqueta: 'Profesional / responsable',
                    valor: nombreProfesional,
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_esEdicion ? 'Guardar cambios' : 'Registrar evento'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    _guardando ? null : () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(foregroundColor: AppTheme.tertiary),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior para elegir un medicamento real de Bodega (categoría
/// Medicamentos), con buscador y stock visible -- "En Bodega: N unidad"
/// como en el mockup.
class _SelectorMedicamento extends StatefulWidget {
  final List<Insumo> medicamentos;
  final bool cargando;
  final String? error;
  final VoidCallback onReintentar;

  const _SelectorMedicamento({
    required this.medicamentos,
    required this.cargando,
    required this.error,
    required this.onReintentar,
  });

  @override
  State<_SelectorMedicamento> createState() => _SelectorMedicamentoState();
}

class _SelectorMedicamentoState extends State<_SelectorMedicamento> {
  String _busqueda = '';

  List<Insumo> get _filtrados {
    if (_busqueda.trim().isEmpty) return widget.medicamentos;
    final q = _busqueda.trim().toLowerCase();
    return widget.medicamentos
        .where((m) => m.nombre.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Elegir medicamento / biológico',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _busqueda = v),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: widget.cargando
                    ? const Center(child: CircularProgressIndicator())
                    : widget.error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(widget.error!,
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton(
                                    onPressed: widget.onReintentar,
                                    child: const Text('Reintentar')),
                              ],
                            ),
                          )
                        : _filtrados.isEmpty
                            ? const Center(
                                child: Text(
                                    'No hay medicamentos en Bodega con ese nombre'),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: _filtrados.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final insumo = _filtrados[i];
                                  final agotado = insumo.stockActual <= 0;
                                  return ListTile(
                                    enabled: !agotado,
                                    leading:
                                        const Icon(Icons.medication_outlined),
                                    title: Text(insumo.nombre),
                                    subtitle: Text(agotado
                                        ? 'Agotado en Bodega'
                                        : 'En Bodega: ${insumo.stockActual.toStringAsFixed(0)} ${insumo.unidadMedida}'),
                                    trailing: agotado
                                        ? const Icon(Icons.warning_amber,
                                            color: Colors.red)
                                        : null,
                                    onTap: agotado
                                        ? null
                                        : () =>
                                            Navigator.of(context).pop(insumo),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
