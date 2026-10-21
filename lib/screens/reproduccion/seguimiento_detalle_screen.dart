import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';
import 'editar_seguimiento_screen.dart';

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
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

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
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
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

  @override
  Widget build(BuildContext context) {
    final r = _registro;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del seguimiento'),
        // Se sobreescribe el botón "atrás" para devolver `_huboCambios` --
        // así, si se editó el registro desde aquí, la pantalla que nos
        // abrió (una de las 4 listas filtradas) sabe que debe recargar.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_huboCambios),
        ),
        actions: [
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (r.estaEliminado)
            _BannerEliminado(registro: r, formato: _dateTimeFormat),
          Row(
            children: [
              Chip(
                label: Text(r.estado),
                backgroundColor: _colorEstado(r.estado).withValues(alpha: 0.15),
                labelStyle: TextStyle(color: _colorEstado(r.estado)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Seccion(
            titulo: 'Fecha de creación',
            child: Text(
              r.creadoEn != null
                  ? _dateTimeFormat.format(r.creadoEn!)
                  : 'No disponible',
            ),
          ),
          _Seccion(
            titulo: 'Animales involucrados',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilaAnimal(
                    etiqueta: 'Madre',
                    animal: r.animal,
                    idRespaldo: r.animalId),
                if (r.macho != null || r.machoId != null) ...[
                  const SizedBox(height: 10),
                  _FilaAnimal(
                      etiqueta: 'Padre',
                      animal: r.macho,
                      idRespaldo: r.machoId),
                ],
              ],
            ),
          ),
          _Seccion(
            titulo: 'Datos del evento',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo: ${r.tipo ?? "No especificado"}'),
                const SizedBox(height: 4),
                Text(
                    'Fecha de inseminación: ${_dateFormat.format(r.fechaInseminacion)}'),
                if (r.fechaEstimadaParto != null) ...[
                  const SizedBox(height: 4),
                  Text(
                      'Fecha estimada de parto: ${_dateFormat.format(r.fechaEstimadaParto!)}'),
                ],
                if (r.fechaRealParto != null) ...[
                  const SizedBox(height: 4),
                  Text(
                      'Fecha real de parto/aborto: ${_dateFormat.format(r.fechaRealParto!)}'),
                ],
              ],
            ),
          ),
          _Seccion(
            titulo: 'Comentarios',
            child: Text(
              (r.notas != null && r.notas!.trim().isNotEmpty)
                  ? r.notas!
                  : 'Sin comentarios registrados',
            ),
            nota: 'El sistema guarda un solo campo de comentarios por '
                'registro: si se escribe algo nuevo al confirmar, cerrar o '
                'editar, reemplaza lo anterior. No es un historial '
                'independiente de cada comentario por paso.',
          ),
          _Seccion(
            titulo: 'Flujo del registro',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PasoFlujo(
                  icono: Icons.flag_outlined,
                  titulo: 'Creación (Pendiente)',
                  persona: r.creadoPor?.nombreUsuario,
                  fecha: r.creadoEn,
                  formato: _dateTimeFormat,
                ),
                if (r.confirmadoEn != null)
                  _PasoFlujo(
                    icono: Icons.check_circle_outline,
                    titulo: 'Confirmación (Gestante)',
                    persona: r.confirmadoPor?.nombreUsuario,
                    fecha: r.confirmadoEn,
                    formato: _dateTimeFormat,
                  ),
                if (r.cerradoEn != null)
                  _PasoFlujo(
                    icono: Icons.flag_circle_outlined,
                    titulo: 'Cierre (${r.estado})',
                    persona: r.cerradoPor?.nombreUsuario,
                    fecha: r.cerradoEn,
                    formato: _dateTimeFormat,
                  ),
                if (r.editadoEn != null)
                  _PasoFlujo(
                    icono: Icons.edit_outlined,
                    titulo: 'Última edición',
                    persona: r.editadoPor?.nombreUsuario,
                    fecha: r.editadoEn,
                    formato: _dateTimeFormat,
                  ),
                if (r.eliminadoEn != null)
                  _PasoFlujo(
                    icono: Icons.delete_outline,
                    titulo: 'Eliminación',
                    persona: r.eliminadoPor?.nombreUsuario,
                    fecha: r.eliminadoEn,
                    formato: _dateTimeFormat,
                    color: Colors.red[700],
                  ),
              ],
            ),
          ),
          if (widget.permitirAcciones && !r.estaEliminado) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: r.estaCerrado ? null : _editar,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.red[700]),
                    onPressed: _eliminando ? null : _confirmarEliminar,
                    icon: _eliminando
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                  ),
                ),
              ],
            ),
            if (r.estaCerrado)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Un registro cerrado (Parida/Abortada/Fallida) no se puede '
                  'editar, solo eliminar.',
                  style: TextStyle(fontSize: 12, color: AppTheme.outline),
                ),
              ),
          ],
        ],
      ),
    );
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
        return Colors.red[700]!;
      default: // Pendiente
        return AppTheme.secondary;
    }
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;
  final Widget child;
  final String? nota;

  const _Seccion({required this.titulo, required this.child, this.nota});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          child,
          if (nota != null) ...[
            const SizedBox(height: 6),
            Text(nota!,
                style: const TextStyle(fontSize: 11, color: AppTheme.outline)),
          ],
        ],
      ),
    );
  }
}

class _FilaAnimal extends StatelessWidget {
  final String etiqueta;
  final AnimalReferencia? animal;
  final int? idRespaldo;

  const _FilaAnimal({required this.etiqueta, this.animal, this.idRespaldo});

  @override
  Widget build(BuildContext context) {
    final nombre = animal?.nombreVisible ??
        (idRespaldo != null ? 'Animal #$idRespaldo' : 'No especificado');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(etiqueta,
              style: const TextStyle(fontSize: 12, color: AppTheme.outline)),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            children: [
              Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (animal?.especieNombre != null)
                Text('· ${animal!.especieNombre}',
                    style: const TextStyle(fontSize: 13)),
              if (animal?.codigo != null)
                Text('· ${animal!.codigo}',
                    style:
                        const TextStyle(fontSize: 13, color: AppTheme.outline)),
            ],
          ),
        ),
      ],
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
                        fontWeight: FontWeight.w600, fontSize: 13)),
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
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.delete_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Registro eliminado'
              '${registro.eliminadoPor != null ? ' por ${registro.eliminadoPor!.nombreUsuario}' : ''}'
              '${registro.eliminadoEn != null ? ' · ${formato.format(registro.eliminadoEn!)}' : ''}',
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
