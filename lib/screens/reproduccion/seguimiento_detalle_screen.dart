import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';
import 'editar_seguimiento_screen.dart';

// 2026-10-22 (Tarea 5, mockup "Detalles_registro_evento_reproductivo"):
// mismos colores "fixed" que no están en AppTheme, usados tal cual los
// define el mockup (ver también registrar_seguimiento_screen.dart, donde
// se agregaron por primera vez).
const _secondaryFixed = Color(0xFFFFDF9E);
const _onSecondaryFixed = Color(0xFF261A00);
const _primaryFixed = Color(0xFF94F990);
const _onPrimaryFixed = Color(0xFF002204);

/// Detalle de un seguimiento (2026-10-21, nuevo a pedido de la Parte 1).
/// Se usa en DOS contextos distintos, controlados por [permitirAcciones]:
///
/// - Desde la lista principal de "Control reproductivo" (la del inicio):
///   `permitirAcciones: false` -- solo lectura, sin Editar/Eliminar, tal
///   como se pidió explícitamente ("que abran ÚNICAMENTE los detalles").
///   También se usa así desde el Historial.
/// - Desde las 4 pantallas nuevas (Gestaciones / Partos pendientes / Partos
///   este mes / Fertilidad del mes): `permitirAcciones: true` -- aquí sí
///   se puede Editar (si el registro no está cerrado) o Eliminar.
///
/// 2026-10-22: restyle calcado del mockup Stitch
/// `Detalles_registro_evento_reproductivo` -- tarjetas blancas con borde
/// suave (en vez de sombra, a diferencia de las pantallas de "Registrar
/// Seguimiento"), folio + estado arriba, animales con badge de rol, datos
/// del evento con la fecha estimada de parto destacada, y los dos botones
/// de acción en píldora al final. La funcionalidad (editar/eliminar,
/// auditoría, banner de eliminado) se mantuvo intacta -- el mockup no
/// incluye "Eliminar" así que quedó como un botón de texto más discreto
/// debajo de los dos principales.
class SeguimientoDetalleScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;
  final SeguimientoGestacion registro;
  final bool permitirAcciones;

  const SeguimientoDetalleScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    required this.registro,
    this.permitirAcciones = false,
  });

  @override
  State<SeguimientoDetalleScreen> createState() =>
      _SeguimientoDetalleScreenState();
}

class _SeguimientoDetalleScreenState extends State<SeguimientoDetalleScreen> {
  // 2026-10-22: 'd de MMMM, yyyy' en español (ya se usa en otras pantallas
  // de la app, ej. produccion_historial_screen.dart) -- la hora se deja en
  // formato 24h ('HH:mm') en vez de con a. m./p. m. (el locale español de
  // intl los escribe con puntos, no como el "AM"/"PM" limpio del mockup).
  final _dateFormat = DateFormat('d \'de\' MMMM, yyyy', 'es');
  final _dateTimeFormat = DateFormat('d \'de\' MMMM, yyyy - HH:mm', 'es');
  final _dateTimeCortoFormat = DateFormat('yyyy-MM-dd HH:mm');

  late SeguimientoGestacion _registro;
  bool _cargando = true;
  bool _eliminando = false;

  // true si algo cambió (editado o eliminado) -- se lo devolvemos a quien
  // nos abrió para que recargue su lista.
  bool _huboCambios = false;

  @override
  void initState() {
    super.initState();
    _registro = widget.registro;
    _recargar();
  }

  Future<void> _recargar() async {
    try {
      final fresco = await widget.repository.obtenerPorId(_registro.id);
      if (fresco != null && mounted) setState(() => _registro = fresco);
    } catch (_) {
      // No es crítico -- si falla, nos quedamos con los datos que ya
      // teníamos (los que trajo la lista que abrió este detalle).
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _volver() => Navigator.of(context).pop(_huboCambios);

  Future<void> _editar() async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditarSeguimientoScreen(
          repository: widget.repository,
          animalRepository: widget.animalRepository,
          registro: _registro,
        ),
      ),
    );
    if (resultado == true) {
      _huboCambios = true;
      _recargar();
    }
  }

  Future<void> _confirmarEliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar seguimiento'),
        content: const Text(
          'El registro no se borra para siempre: queda guardado en el '
          'Historial (para auditoría), marcado como eliminado y con tu '
          'nombre. ¿Confirmas que quieres eliminarlo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    setState(() => _eliminando = true);
    try {
      await widget.repository.eliminar(_registro.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _eliminando = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
      }
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Gestante':
        return AppTheme.primary;
      case 'Parida':
        return Colors.green[700]!;
      case 'Abortada':
        return AppTheme.tertiary;
      case 'Fallida':
        return AppTheme.error;
      default: // Pendiente
        return AppTheme.secondary;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'Gestante':
      case 'Parida':
        return Icons.check_circle;
      case 'Abortada':
      case 'Fallida':
        return Icons.cancel;
      default: // Pendiente
        return Icons.schedule;
    }
  }

  /// "Diagnóstico" de la tarjeta "Datos del Evento Reproductivo" -- el
  /// mockup muestra "Preñez confirmada" porque su ejemplo está Gestante;
  /// acá se adapta según el estado real del registro.
  String _diagnostico(SeguimientoGestacion r) {
    switch (r.estado) {
      case 'Gestante':
        return 'Preñez confirmada';
      case 'Parida':
        return 'Parto registrado';
      case 'Abortada':
        return 'Aborto registrado';
      case 'Fallida':
        return 'No hubo preñez';
      default: // Pendiente
        return 'Pendiente por confirmar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _registro;
    final colorEstado = _colorEstado(r.estado);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        titleSpacing: 0,
        // Se sobreescribe el botón "atrás" para devolver `_huboCambios` --
        // así, si se editó el registro desde aquí, la pantalla que nos
        // abrió (una de las 4 listas filtradas) sabe que debe recargar.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _volver,
        ),
        title: const Text('Detalle del Seguimiento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _primaryFixed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'FOLIO #REP-${r.id.toString().padLeft(4, '0')}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _onPrimaryFixed),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (r.estaEliminado) ...[
            const SizedBox(height: 4),
            _BannerEliminado(registro: r, formato: _dateTimeCortoFormat),
          ],
          // -- Folio de Registro + estado --
          _TarjetaSeccion(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FOLIO DE REGISTRO',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: AppTheme.onSurfaceVariant)),
                        Text('#REP-${r.id.toString().padLeft(4, '0')}',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: colorEstado,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_iconoEstado(r.estado),
                              size: 17, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(r.estado,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(color: AppTheme.surfaceContainerColor)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event,
                          size: 18, color: AppTheme.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppTheme.onSurfaceVariant),
                            children: [
                              const TextSpan(text: 'Fecha de registro: '),
                              TextSpan(
                                text: r.creadoEn != null
                                    ? _dateTimeFormat.format(r.creadoEn!)
                                    : 'No disponible',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.onSurface),
                              ),
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
          const SizedBox(height: 14),
          // -- Animales Involucrados --
          _TarjetaSeccion(
            titulo: 'Animales Involucrados',
            icono: Icons.pets,
            child: Column(
              children: [
                _FilaAnimal(
                  etiqueta: 'Madre',
                  colorBadge: _primaryFixed,
                  colorTextoBadge: _onPrimaryFixed,
                  animal: r.animal,
                  idRespaldo: r.animalId,
                ),
                if (r.macho != null || r.machoId != null) ...[
                  const SizedBox(height: 10),
                  _FilaAnimal(
                    etiqueta: 'Padre / Semental',
                    colorBadge: _secondaryFixed,
                    colorTextoBadge: _onSecondaryFixed,
                    animal: r.macho,
                    idRespaldo: r.machoId,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // -- Datos del Evento Reproductivo --
          _TarjetaSeccion(
            titulo: 'Datos del Evento Reproductivo',
            icono: Icons.calendar_month,
            child: Column(
              children: [
                _FilaDato(
                    etiqueta: 'Tipo de evento',
                    valor: r.tipo ?? 'No especificado'),
                const SizedBox(height: 10),
                _FilaDato(
                    etiqueta: 'Fecha de monta',
                    valor: _dateFormat.format(r.fechaInseminacion)),
                if (r.fechaEstimadaParto != null) ...[
                  const SizedBox(height: 10),
                  _TarjetaFEP(
                    fecha: r.fechaEstimadaParto!,
                    formato: _dateFormat,
                    mostrarCuentaRegresiva: !r.estaCerrado,
                  ),
                ],
                if (r.fechaRealParto != null) ...[
                  const SizedBox(height: 10),
                  _FilaDato(
                      etiqueta: 'Fecha real de parto/aborto',
                      valor: _dateFormat.format(r.fechaRealParto!)),
                ],
                const SizedBox(height: 10),
                _FilaDato(
                  etiqueta: 'Diagnóstico',
                  valor: _diagnostico(r),
                  valorColor: colorEstado,
                  valorIcono: _iconoEstado(r.estado),
                ),
                const SizedBox(height: 10),
                _FilaDato(
                  etiqueta: 'Responsable',
                  valor: r.creadoPor?.nombreUsuario ?? 'No disponible',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // -- Comentario / Observación --
          _TarjetaSeccion(
            titulo: 'Comentario / Observación',
            icono: Icons.comment,
            tituloTrailing: r.creadoEn != null
                ? DateFormat('dd/MM/yyyy').format(r.creadoEn!)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                  ),
                  child: Text(
                    (r.notas != null && r.notas!.trim().isNotEmpty)
                        ? '"${r.notas!}"'
                        : 'Sin comentarios registrados',
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppTheme.secondary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Nota: el sistema guarda un solo comentario por '
                        'registro -- si se escribe uno nuevo al confirmar, '
                        'cerrar o editar, reemplaza al actual.',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // -- Flujo del registro (auditoría) -- se mantiene, con el mismo
          // estilo de tarjeta que el resto de esta pantalla.
          _TarjetaSeccion(
            titulo: 'Flujo del Registro',
            icono: Icons.history,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PasoFlujo(
                  icono: Icons.flag_outlined,
                  titulo: 'Creación (Pendiente)',
                  persona: r.creadoPor?.nombreUsuario,
                  fecha: r.creadoEn,
                  formato: _dateTimeCortoFormat,
                ),
                if (r.confirmadoEn != null)
                  _PasoFlujo(
                    icono: Icons.check_circle_outline,
                    titulo: 'Confirmación (Gestante)',
                    persona: r.confirmadoPor?.nombreUsuario,
                    fecha: r.confirmadoEn,
                    formato: _dateTimeCortoFormat,
                  ),
                if (r.cerradoEn != null)
                  _PasoFlujo(
                    icono: Icons.flag_circle_outlined,
                    titulo: 'Cierre (${r.estado})',
                    persona: r.cerradoPor?.nombreUsuario,
                    fecha: r.cerradoEn,
                    formato: _dateTimeCortoFormat,
                  ),
                if (r.editadoEn != null)
                  _PasoFlujo(
                    icono: Icons.edit_outlined,
                    titulo: 'Última edición',
                    persona: r.editadoPor?.nombreUsuario,
                    fecha: r.editadoEn,
                    formato: _dateTimeCortoFormat,
                  ),
                if (r.eliminadoEn != null)
                  _PasoFlujo(
                    icono: Icons.delete_outline,
                    titulo: 'Eliminación',
                    persona: r.eliminadoPor?.nombreUsuario,
                    fecha: r.eliminadoEn,
                    formato: _dateTimeCortoFormat,
                    color: AppTheme.error,
                  ),
              ],
            ),
          ),
          if (widget.permitirAcciones && !r.estaEliminado) ...[
            const SizedBox(height: 20),
            if (!r.estaCerrado)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _editar,
                  icon: const Icon(Icons.edit_note, size: 22),
                  label: const Text('Editar o Actualizar Registro',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Un registro cerrado (Parida/Abortada/Fallida) no se '
                  'puede editar, solo eliminar.',
                  style: TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.errorContainer,
                  foregroundColor: AppTheme.onErrorContainer,
                  shape: const StadiumBorder(),
                ),
                onPressed: _eliminando ? null : _confirmarEliminar,
                icon: _eliminando
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.onErrorContainer),
                      )
                    : const Icon(Icons.delete_outline, size: 20),
                label: const Text('Eliminar Registro'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.surfaceContainerColor,
                foregroundColor: AppTheme.onSurface,
                shape: const StadiumBorder(),
              ),
              onPressed: _volver,
              icon: const Icon(Icons.arrow_back, size: 20),
              label: const Text('Volver a Reproducción'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta blanca con borde suave -- el patrón que se repite en todas las
/// secciones de esta pantalla (a diferencia de "Registrar Seguimiento",
/// que usa sombra; acá el mockup usa borde, ver `border border-outline-
/// variant/30` en el HTML original).
class _TarjetaSeccion extends StatelessWidget {
  final String? titulo;
  final IconData? icono;
  final String? tituloTrailing;
  final Widget child;

  const _TarjetaSeccion({
    this.titulo,
    this.icono,
    this.tituloTrailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border:
            Border.all(color: AppTheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null) ...[
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: AppTheme.surfaceContainerColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (icono != null) ...[
                        Icon(icono, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(titulo!,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  if (tituloTrailing != null)
                    Text(tituloTrailing!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

/// Fila "Madre"/"Padre" con avatar circular, badge de rol de color y
/// nombre + especie + arete -- calcado del mockup (que usa foto real; acá
/// usamos un ícono porque no manejamos fotos de animales).
class _FilaAnimal extends StatelessWidget {
  final String etiqueta;
  final Color colorBadge;
  final Color colorTextoBadge;
  final AnimalReferencia? animal;
  final int? idRespaldo;

  const _FilaAnimal({
    required this.etiqueta,
    required this.colorBadge,
    required this.colorTextoBadge,
    this.animal,
    this.idRespaldo,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = animal?.nombreVisible ??
        (idRespaldo != null ? 'Animal #$idRespaldo' : 'No especificado');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primary.withValues(alpha: 0.1),
              border: Border.all(color: colorBadge, width: 2),
            ),
            child: const Icon(Icons.pets, color: AppTheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorBadge,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(etiqueta,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: colorTextoBadge)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(nombre,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontSize: 12.5, color: AppTheme.onSurfaceVariant),
                    children: [
                      if (animal?.especieNombre != null)
                        TextSpan(text: '${animal!.especieNombre} · '),
                      const TextSpan(text: 'Arete: '),
                      TextSpan(
                        text: animal?.codigo ?? '--',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface),
                      ),
                    ],
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

/// Fila simple "etiqueta ... valor" dentro de "Datos del Evento
/// Reproductivo" -- opcionalmente con ícono y color propio (lo usa
/// "Diagnóstico").
class _FilaDato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color? valorColor;
  final IconData? valorIcono;

  const _FilaDato({
    required this.etiqueta,
    required this.valor,
    this.valorColor,
    this.valorIcono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta,
              style: const TextStyle(
                  fontSize: 13.5, color: AppTheme.onSurfaceVariant)),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (valorIcono != null) ...[
                  Icon(valorIcono, size: 16, color: valorColor),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    valor,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: valorColor ?? AppTheme.onSurface),
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

/// Caja destacada ámbar de "Fecha Estimada de Parto (FEP)" -- con la
/// cuenta regresiva en días, calculada en vivo contra la fecha de hoy
/// (el mockup la muestra fija porque es un ejemplo estático).
class _TarjetaFEP extends StatelessWidget {
  final DateTime fecha;
  final DateFormat formato;
  final bool mostrarCuentaRegresiva;

  const _TarjetaFEP({
    required this.fecha,
    required this.formato,
    required this.mostrarCuentaRegresiva,
  });

  @override
  Widget build(BuildContext context) {
    final dias = fecha.difference(DateTime.now()).inDays;
    final etiquetaDias =
        dias >= 0 ? 'Faltan ~$dias días' : 'Venció hace ${-dias} días';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _secondaryFixed.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Fecha Estimada de Parto (FEP)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.secondary)),
              ),
              if (mostrarCuentaRegresiva)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(etiquetaDias,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSecondaryContainer)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formato.format(fecha),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const Text('(±7 días)',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasoFlujo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? persona;
  final DateTime? fecha;
  final DateFormat formato;
  final Color? color;

  const _PasoFlujo({
    required this.icono,
    required this.titulo,
    required this.formato,
    this.persona,
    this.fecha,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: color ?? AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  [
                    if (persona != null) persona!,
                    if (fecha != null) formato.format(fecha!),
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerEliminado extends StatelessWidget {
  final SeguimientoGestacion registro;
  final DateFormat formato;

  const _BannerEliminado({required this.registro, required this.formato});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.delete_outline, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Registro eliminado'
              '${registro.eliminadoPor != null ? ' por ${registro.eliminadoPor!.nombreUsuario}' : ''}'
              '${registro.eliminadoEn != null ? ' · ${formato.format(registro.eliminadoEn!)}' : ''}',
              style: const TextStyle(
                  color: AppTheme.onErrorContainer,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
