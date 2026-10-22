import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/animal.dart';
import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';

// 2026-10-22 (Tarea 5, mockup "Editar_un_registro_reproductivo"): mismos
// colores "fixed" que no están en AppTheme, usados tal cual los define el
// mockup (ver también registrar_seguimiento_screen.dart y seguimiento_
// detalle_screen.dart, donde se agregaron por primera vez).
const _secondaryFixed = Color(0xFFFFDF9E);
const _onSecondaryFixedVariant = Color(0xFF5B4300);

/// Edición de un seguimiento ya existente (2026-10-21, nuevo a pedido de la
/// Parte 1): a diferencia de "Nuevo Evento" (SeguimientoFormScreen), aquí la
/// Madre ya quedó fija desde que se creó el registro -- solo se pueden tocar
/// los mismos campos que ya permitía `ActualizarSeguimientoDTO` en el
/// backend (tipo, fecha de inseminación, padre y notas). Solo aplica a
/// registros que NO estén cerrados (Parida/Abortada/Fallida) ni eliminados
/// -- el backend ya lo rechaza de todas formas, esta pantalla simplemente
/// no debe abrirse en esos casos (ver SeguimientoDetalleScreen).
///
/// Mismo mapa de días de gestación que SeguimientoFormScreen/el backend --
/// se usa para recalcular fecha_estimada_parto cuando cambia la fecha de
/// inseminación y la especie es Bovino/Cerdo (igual que al crear). Si la
/// especie no está en el mapa, no se toca fecha_estimada_parto (se deja el
/// valor que ya tenía).
///
/// 2026-10-22: restyle calcado del mockup Stitch
/// `Editar_un_registro_reproductivo` -- tarjetas blancas con sombra suave,
/// la Madre fija con su banner informativo, el Tipo como dos botones
/// grandes en vez de un dropdown, la fecha con la FEP recalculada en una
/// franja destacada, y los botones "Guardar cambios"/"Cancelar sin
/// guardar" en píldora al final. El mockup traía además una tarjeta de
/// "Potrero asignado" -- a pedido explícito de Dany, se ignoró por
/// completo (no es un dato que maneje este módulo).
class EditarSeguimientoScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;
  final SeguimientoGestacion registro;

  const EditarSeguimientoScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    required this.registro,
  });

  @override
  State<EditarSeguimientoScreen> createState() =>
      _EditarSeguimientoScreenState();
}

class _EditarSeguimientoScreenState extends State<EditarSeguimientoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notasCtrl = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _dateFormatLargo = DateFormat('d \'de\' MMMM, yyyy', 'es');

  late String? _tipo;
  late DateTime _fechaInseminacion;
  // null = "mantener el padre actual, no se manda macho_id" -- ver nota en
  // el selector más abajo.
  int? _nuevoMachoId;

  List<Animal> _machosDisponibles = [];
  bool _cargandoMachos = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tipo = widget.registro.tipo;
    _fechaInseminacion = widget.registro.fechaInseminacion;
    _notasCtrl.text = widget.registro.notas ?? '';
    _cargarMachos();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarMachos() async {
    try {
      final pagina = await widget.animalRepository
          .listar(genero: 'Macho', estado: 'Activo', limite: 200);
      final especieMadre = widget.registro.animal?.especieNombre;
      setState(() {
        _machosDisponibles = especieMadre == null
            ? pagina.data
            : pagina.data
                .where((m) => m.especie?.nombre == especieMadre)
                .toList();
      });
    } catch (_) {
      // No es crítico: si falla, el usuario simplemente no puede cambiar
      // de padre en esta edición (sigue pudiendo editar el resto).
    } finally {
      if (mounted) setState(() => _cargandoMachos = false);
    }
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

  DateTime? get _fechaEstimadaPartoRecalculada {
    final especie = widget.registro.animal?.especieNombre?.trim().toLowerCase();
    final dias = especie == null ? null : _diasGestacionPorEspecie[especie];
    if (dias == null) return null;
    return _fechaInseminacion.add(Duration(days: dias));
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repository.actualizar(
        widget.registro.id,
        ActualizarSeguimientoDTO(
          tipo: _tipo,
          fechaInseminacion: _fechaInseminacion,
          fechaEstimadaParto: _fechaEstimadaPartoRecalculada,
          machoId: _nuevoMachoId,
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // 2026-10-22 (mockup, botón "Cancelar sin guardar"): antes esta pantalla
  // no tenía un botón de cancelar explícito (solo la flecha de volver del
  // AppBar) -- se agrega con el mismo diálogo de confirmación que ya usa
  // el mockup, para no perder cambios por accidente.
  Future<void> _cancelar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text(
            'Perderás los cambios que hayas hecho en este formulario.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    if (confirmado == true && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.registro;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('Editar Seguimiento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // -- Madre (fija, no editable) --
          _TarjetaCampo(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.pets,
                          color: AppTheme.primary, size: 26),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  r.animal?.nombreVisible ??
                                      'Animal #${r.animalId}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (r.animal?.especieNombre != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(r.animal!.especieNombre!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.onSurfaceVariant)),
                                ),
                              ],
                            ],
                          ),
                          if (r.animal?.codigo != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Arete ${r.animal!.codigo}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primary)),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.lock,
                              size: 15, color: AppTheme.onSurfaceVariant),
                          SizedBox(width: 4),
                          Text('Fijo',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        AppTheme.surfaceContainerLowest.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: AppTheme.secondary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'La madre quedó fija desde que se registró este '
                          'ciclo reproductivo y no puede cambiarse.',
                          style: TextStyle(
                              fontSize: 12.5, color: AppTheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -- Tipo de reproducción --
                _TarjetaCampo(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _TituloCampo(
                          icono: Icons.pets, texto: 'Tipo de reproducción'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _BotonTipo(
                              icono: Icons.eco,
                              etiqueta: 'Monta natural',
                              subetiqueta: 'Toro en campo',
                              seleccionado: _tipo == 'Monta natural',
                              onTap: () =>
                                  setState(() => _tipo = 'Monta natural'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _BotonTipo(
                              icono: Icons.biotech,
                              etiqueta: 'Inseminación',
                              subetiqueta: 'Pajilla / Semen',
                              seleccionado: _tipo == 'IA',
                              onTap: () => setState(() => _tipo = 'IA'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // -- Fecha de monta/servicio + FEP recalculada --
                _TarjetaCampo(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _TituloCampo(
                          icono: Icons.calendar_month,
                          texto: 'Fecha de monta o servicio'),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusDefault),
                        onTap: _elegirFechaInseminacion,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusDefault),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_dateFormat.format(_fechaInseminacion),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              const Icon(Icons.edit_calendar,
                                  color: AppTheme.primary, size: 24),
                            ],
                          ),
                        ),
                      ),
                      if (_fechaEstimadaPartoRecalculada != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _secondaryFixed.withValues(alpha: 0.5),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusDefault),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.event_available,
                                    size: 18,
                                    color: AppTheme.onSecondaryContainer),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('FECHA ESTIMADA DE PARTO (FEP)',
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.4,
                                            color: _onSecondaryFixedVariant)),
                                    const SizedBox(height: 2),
                                    Text(
                                      _dateFormatLargo.format(
                                          _fechaEstimadaPartoRecalculada!),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Cálculo basado en los días promedio '
                                      'de gestación de la especie.',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppTheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // -- Padre --
                _TarjetaCampo(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _TituloCampo(
                          icono: Icons.male, texto: 'Toro reproductor (Padre)'),
                      const SizedBox(height: 10),
                      if (_cargandoMachos)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceContainerLow,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusDefault),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<int?>(
                              value: _nuevoMachoId,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: AppTheme.onSurfaceVariant, size: 26),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                              ),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onSurface),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    'Mantener actual (${r.macho?.nombreVisible ?? "Ninguno"})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                for (final m in _machosDisponibles)
                                  DropdownMenuItem<int?>(
                                    value: m.id,
                                    child: Text(
                                        '${m.nombreVisible} (${m.especie?.nombre ?? "?"} · Arete ${m.codigo})',
                                        overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _nuevoMachoId = v),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.touch_app,
                              size: 16, color: AppTheme.primary),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Toca para cambiar si hubo un error en la '
                              'elección del macho.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // -- Observaciones --
                _TarjetaCampo(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          _TituloCampo(
                              icono: Icons.notes,
                              texto: 'Observaciones del corral'),
                          Text('Opcional',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _notasCtrl,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 14, height: 1.4),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.surfaceContainerLow,
                          hintText:
                              'Escribe novedades de la vaca o el servicio...',
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusDefault),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerHigh,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusDefault),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber,
                                size: 18, color: AppTheme.tertiary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppTheme.onSurface),
                                  children: [
                                    TextSpan(
                                        text: 'Aviso: ',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    TextSpan(
                                        text:
                                            'El texto que guardes aquí reemplazará las notas anteriores de este registro.'),
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
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: const TextStyle(color: AppTheme.error)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 56,
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
                        : const Icon(Icons.save, size: 22),
                    label: const Text('Guardar cambios',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.surfaceContainerColor,
                      foregroundColor: AppTheme.onSurface,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: _guardando ? null : _cancelar,
                    icon: const Icon(Icons.close, size: 20),
                    label: const Text('Cancelar sin guardar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mismo mapa de días de gestación que SeguimientoFormScreen/el backend.
const _diasGestacionPorEspecie = {'bovino': 283, 'cerdo': 114};

/// Tarjeta blanca con sombra suave -- el contenedor que se repite en cada
/// campo de este formulario, calcado del mockup.
class _TarjetaCampo extends StatelessWidget {
  final Widget child;

  const _TarjetaCampo({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}

/// Título "ícono + texto" que encabeza cada tarjeta de campo.
class _TituloCampo extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _TituloCampo({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, color: AppTheme.primary, size: 22),
        const SizedBox(width: 8),
        Text(texto,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

/// Uno de los dos botones grandes de "Tipo de reproducción" -- el
/// seleccionado queda en verde de marca, el otro en gris neutro.
class _BotonTipo extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String subetiqueta;
  final bool seleccionado;
  final VoidCallback onTap;

  const _BotonTipo({
    required this.icono,
    required this.etiqueta,
    required this.subetiqueta,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fondo = seleccionado
        ? AppTheme.primaryContainer
        : AppTheme.surfaceContainerColor;
    final texto =
        seleccionado ? AppTheme.onPrimaryContainer : AppTheme.onSurface;
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      elevation: seleccionado ? 2 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icono, size: 18, color: texto),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(etiqueta,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: texto),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(subetiqueta,
                  style: TextStyle(
                      fontSize: 11,
                      color: seleccionado
                          ? texto.withValues(alpha: 0.9)
                          : AppTheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
