import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../core/auth_session.dart';
import '../../models/animal.dart';
import '../../models/salud/evento_sanitario.dart';
import '../../repositories/inventario/insumo_repository.dart';
import '../../repositories/salud/evento_sanitario_repository.dart';
import '../../theme/app_theme.dart';
import 'evento_sanitario_form_screen.dart';

/// Detalle de un evento de salud.
///
/// 2026-10-27, a pedido explícito de Dany: esta misma pantalla se usa desde
/// dos lugares con permisos distintos --
/// - Desde el apartado "Salud" de la ficha del animal: `soloLectura: true`
///   -- se puede VER el detalle, pero no editar ni eliminar desde ahí.
/// - Desde "Cuenta -> Eventos de salud registrados" (historial general):
///   `soloLectura: false` -- ahí sí aparecen Editar/Eliminar/cambiar
///   estado.
///
/// 2026-10-31, reconstrucción a pedido de Dany (punto 4 de su nota):
/// - Orden exacto de campos: Fecha del evento, Medicamento aplicado, Vía
///   de administración, Dosis aplicada, ¿Refuerzo?, Descripción,
///   Profesional/responsable, Editar/Eliminar.
/// - "¿Refuerzo?" ahora es un solo campo con texto condicional: si el
///   evento está Resuelto nunca dice "vencido" (dice "Aplicado en <fecha>"
///   aunque la fecha ya haya pasado); si no está Resuelto, dice "Faltan X
///   días" / "Hoy" / "Mañana" si falta, o "Vencido hace X días" si ya pasó;
///   si no hay fecha de refuerzo, dice "No aplica".
/// - Punto 4.9: nueva sección "Flujo de registro" con cada acción
///   (Creado/Editado/Resuelto/Eliminado) tomada sobre el evento, quién y
///   cuándo -- viene de `evento.historial` (ver evento_sanitario.dart), que
///   el backend ya entrega (decisiones-diseno-vs-backend-salud.md
///   sección 4.1).
///
/// 2026-11-01, a pedido de Dany ("el mismo estilo de Historial... que
/// muestra si algunos fueron eliminados, como el de producción y
/// reproducción"): si el evento está eliminado (borrado lógico), se
/// muestra un aviso "Eliminado el ... por ..." y se ocultan Editar/
/// Eliminar -- un evento eliminado queda congelado, igual que el backend
/// ya lo rechaza (código EVENTO_ELIMINADO).
///
/// 2026-11-01 (Etapa 2: Estilos): ajustado 1:1 contra los mockups
/// `detalle_del_evento_de_salud_fincas_y_patitas` (solo lectura) y
/// `detalle_del_evento_con_edicion_y_eliminacion_fincas_y_patitas`
/// (editable) -- tarjeta de resumen con icono en placa blanca y pill de
/// estado sólido (fondo del color de estado, texto blanco, no el alpha
/// tenue que se usaba antes), y los puntos del "Flujo de registro" con los
/// mismos tonos exactos del mockup (café para Creado, rojo para Editado,
/// verde para Resuelto).
class EventoSanitarioDetalleScreen extends StatefulWidget {
  final EventoSanitario evento;
  final Animal animal;
  final EventoSanitarioRepository repository;
  final InsumoRepository insumoRepository;
  final AuthSession session;
  final bool soloLectura;

  const EventoSanitarioDetalleScreen({
    super.key,
    required this.evento,
    required this.animal,
    required this.repository,
    required this.insumoRepository,
    required this.session,
    required this.soloLectura,
  });

  @override
  State<EventoSanitarioDetalleScreen> createState() =>
      _EventoSanitarioDetalleScreenState();
}

/// Tonos exactos del "Flujo de registro" en ambos mockups de detalle.
const _dotCreado = Color(0xFF8C6239);
const _dotEditado = Color(0xFFD32F2F);
const _dotResuelto = Color(0xFF2E7D32);

class _EventoSanitarioDetalleScreenState
    extends State<EventoSanitarioDetalleScreen> {
  final _dateFormat = DateFormat('d \'de\' MMMM, yyyy', 'es');
  final _dateTimeFormat = DateFormat('d MMM yyyy, h:mm a', 'es');
  late EventoSanitario _evento;
  bool _huboCambios = false;

  @override
  void initState() {
    super.initState();
    _evento = widget.evento;
  }

  Color get _colorEstado {
    if (_evento.estaResuelto) return AppTheme.primary;
    if (_evento.estaEnTratamiento) return AppTheme.tertiary;
    return AppTheme.secondary;
  }

  Future<void> _editar() async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoSanitarioFormScreen(
          animal: widget.animal,
          repository: widget.repository,
          insumoRepository: widget.insumoRepository,
          session: widget.session,
          eventoExistente: _evento,
        ),
      ),
    );
    if (cambio == true) {
      _huboCambios = true;
      // Recarga el evento actualizado para reflejar los cambios en esta
      // misma pantalla de detalle sin tener que salir y volver a entrar.
      try {
        final actualizado = await widget.repository.obtenerPorId(_evento.id);
        if (actualizado != null && mounted) {
          setState(() => _evento = actualizado);
        }
      } catch (_) {
        // Si falla la recarga no es grave -- los datos mostrados quedan
        // un poco desactualizados, pero el cambio en el backend ya se hizo.
      }
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar evento de salud'),
        content: Text(
            '¿Eliminar este evento (${_evento.tipoEvento}, ${_evento.fechaEvento != null ? _dateFormat.format(_evento.fechaEvento!) : 'sin fecha'})? Vas a poder verlo después en el historial con el filtro "Eliminados".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await widget.repository.eliminar(_evento.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  /// Texto del campo "¿Refuerzo?" (punto 4.5 de la nota de Dany).
  /// - Sin fecha programada -> "No aplica".
  /// - Evento Resuelto -> siempre "Sí · Aplicado en <fecha>", nunca dice
  ///   "vencido" aunque la fecha ya haya pasado.
  /// - Evento NO resuelto, fecha futura/hoy/mañana -> "Sí · Faltan X días"
  ///   / "Sí · Hoy" / "Sí · Mañana".
  /// - Evento NO resuelto, fecha ya pasada -> "Sí · Vencido hace X días".
  String _textoRefuerzo(EventoSanitario e) {
    if (e.fechaProximoRefuerzo == null) return 'No aplica';
    final fechaTxt = _dateFormat.format(e.fechaProximoRefuerzo!);
    if (e.estaResuelto) {
      return 'Sí · Aplicado en $fechaTxt';
    }
    final dias = e.diasParaProximoRefuerzo ?? 0;
    if (dias < 0) {
      final diasAbs = -dias;
      return 'Sí · Vencido hace $diasAbs día${diasAbs == 1 ? '' : 's'} ($fechaTxt)';
    }
    if (dias == 0) return 'Sí · Hoy ($fechaTxt)';
    if (dias == 1) return 'Sí · Mañana ($fechaTxt)';
    return 'Sí · Faltan $dias días ($fechaTxt)';
  }

  Widget _fila(IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: AppTheme.outline),
          const SizedBox(width: 10),
          SizedBox(
            width: 148,
            child: Text(etiqueta,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.outline)),
          ),
          Expanded(
            child: Text(valor,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Color _colorAccion(String accion) {
    switch (accion) {
      case 'Creado':
        return _dotCreado;
      case 'Resuelto':
        return _dotResuelto;
      case 'Eliminado':
        return Theme.of(context).colorScheme.error;
      default: // Editado
        return _dotEditado;
    }
  }

  /// Punto 4.9: "Flujo de registro" -- cada Creado/Editado/Resuelto/
  /// Eliminado tomado sobre el evento, con quién y cuándo. Viene ya
  /// ordenado del backend (ascendente por fecha).
  Widget _flujoRegistro(BuildContext context) {
    if (_evento.historial.isEmpty) return const SizedBox.shrink();
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: AppTheme.outline),
              const SizedBox(width: 8),
              Text('Flujo de registro',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          ..._evento.historial.map((h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorAccion(h.accion),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: AppTheme.onSurface, fontSize: 13),
                          children: [
                            TextSpan(
                              text: h.accion,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                                text:
                                    ' el ${_dateTimeFormat.format(h.fecha.toLocal())}'),
                            if (h.usuarioNombre != null)
                              TextSpan(text: ' por: ${h.usuarioNombre}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  /// 2026-11-01: aviso de "Eliminado el ... por ..." cuando el evento tiene
  /// borrado lógico -- mismo lenguaje visual que el resto de avisos de
  /// esta pantalla (ver el aviso de refuerzo del formulario).
  Widget _avisoEliminado(BuildContext context) {
    final e = _evento;
    if (!e.estaEliminado) return const SizedBox.shrink();
    final fechaTxt = e.eliminadoEn != null
        ? _dateTimeFormat.format(e.eliminadoEn!.toLocal())
        : 'fecha desconocida';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
              color:
                  Theme.of(context).colorScheme.error.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.delete_outline,
                size: 18, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Eliminado el $fechaTxt'
                '${e.eliminadoPorNombre != null ? ' por ${e.eliminadoPorNombre}' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = _evento;
    // 2026-11-01: un evento eliminado queda congelado -- igual que el
    // backend ya lo rechaza (EVENTO_ELIMINADO), se ocultan Editar/Eliminar
    // aunque la pantalla se haya abierto en modo "no solo lectura".
    final mostrarAcciones = !widget.soloLectura && !e.estaEliminado;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_huboCambios);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del evento'),
          actions: mostrarAcciones
              ? [
                  IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar evento',
                      onPressed: _editar),
                  IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Eliminar evento',
                      onPressed: _eliminar),
                ]
              : null,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _avisoEliminado(context),
            // -- Tarjeta resumen: igual a ambos mockups de detalle, con
            // pill de estado SÓLIDO (fondo de color, texto blanco), no el
            // tinte alpha que se usaba antes.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _colorEstado.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: _colorEstado.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                          color: _colorEstado.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.medical_services_outlined,
                        color: _colorEstado),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.tipoEvento,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                            '${widget.animal.nombreVisible} · #${widget.animal.codigo}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _colorEstado,
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(e.estado,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- 4.1 Fecha del evento --
                  _fila(
                    Icons.calendar_today_outlined,
                    'Fecha del evento',
                    e.fechaEvento != null
                        ? _dateFormat.format(e.fechaEvento!)
                        : 'Sin definir',
                  ),
                  // -- 4.2 Medicamento aplicado --
                  if (e.medicamento != null)
                    _fila(Icons.medication_outlined, 'Medicamento aplicado',
                        e.medicamento!),
                  // -- 4.3 Vía de administración --
                  if (e.viaAdministracion != null)
                    _fila(Icons.vaccines_outlined, 'Vía de administración',
                        e.viaAdministracion!),
                  // -- 4.4 Dosis aplicada --
                  if (e.dosisAplicada != null)
                    _fila(Icons.science_outlined, 'Dosis aplicada',
                        '${e.dosisAplicada}${e.unidadDosis != null ? ' ${e.unidadDosis}' : ''}'),
                  // -- 4.5 ¿Refuerzo? --
                  _fila(Icons.event_available, '¿Refuerzo?', _textoRefuerzo(e)),
                  // -- 4.6 Descripción --
                  if (e.descripcionTratamiento != null &&
                      e.descripcionTratamiento!.isNotEmpty) ...[
                    const Divider(height: 28),
                    Text('Descripción',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(e.descripcionTratamiento!,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                  ],
                  // -- 4.7 Profesional / responsable --
                  if (e.profesionalResponsable != null)
                    _fila(Icons.badge_outlined, 'Profesional / responsable',
                        e.profesionalResponsable!),
                ],
              ),
            ),
            // -- 4.9 Flujo de registro --
            const SizedBox(height: 16),
            _flujoRegistro(context),
            if (widget.soloLectura && !e.estaEliminado) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Para editar o eliminar este evento, ve a Cuenta → Eventos de salud registrados.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.outline),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
