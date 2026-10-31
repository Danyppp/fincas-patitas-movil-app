import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/auth_session.dart';
import '../../models/animal.dart';
import '../../models/salud/evento_sanitario.dart';
import '../../repositories/inventario/insumo_repository.dart';
import '../../repositories/salud/evento_sanitario_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/especie_visual.dart';
import 'evento_sanitario_detalle_screen.dart';
import 'evento_sanitario_form_screen.dart';

/// Apartado "Salud" dentro de la Ficha de Animal, tal como lo definió Dany
/// (2026-10-26, ver decisiones-diseno-vs-backend-salud.md sección 3):
///
/// 1. Cabeza: estado de salud actual (ficha resumen).
/// 2. Cuerpo: eventos de salud activos (Abierto/En tratamiento).
/// 3. Pie de página: historial completo (todos los eventos, incluidos
///    los Resueltos).
/// 4. Botón "Registrar evento de salud".
///
/// El registro de un evento SIEMPRE pasa por aquí -- nunca desde una
/// pantalla general independiente.
class SaludAnimalScreen extends StatefulWidget {
  final Animal animal;
  final EventoSanitarioRepository repository;
  final InsumoRepository insumoRepository;
  final AuthSession session;

  const SaludAnimalScreen({
    super.key,
    required this.animal,
    required this.repository,
    required this.insumoRepository,
    required this.session,
  });

  @override
  State<SaludAnimalScreen> createState() => _SaludAnimalScreenState();
}

class _SaludAnimalScreenState extends State<SaludAnimalScreen> {
  final _dateFormat = DateFormat('d \'de\' MMMM, yyyy', 'es');

  List<EventoSanitario> _eventos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final eventos =
          await widget.repository.listar(animalId: widget.animal.id);
      if (!mounted) return;
      setState(() => _eventos = eventos);
    } catch (e) {
      setState(() => _error = 'No se pudo cargar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<EventoSanitario> get _eventosActivos =>
      _eventos.where((e) => !e.estaResuelto).toList();

  List<EventoSanitario> get _historialCompleto => _eventos;

  Future<void> _registrarEvento() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoSanitarioFormScreen(
          animal: widget.animal,
          repository: widget.repository,
          insumoRepository: widget.insumoRepository,
          session: widget.session,
        ),
      ),
    );
    if (creado == true) _cargar();
  }

  // Desde la ficha del animal el detalle es SOLO LECTURA (a pedido
  // explícito de Dany, 2026-10-27) -- editar/eliminar vive únicamente en
  // Cuenta -> Eventos de salud registrados.
  Future<void> _abrirDetalle(EventoSanitario evento) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventoSanitarioDetalleScreen(
          evento: evento,
          animal: widget.animal,
          repository: widget.repository,
          insumoRepository: widget.insumoRepository,
          session: widget.session,
          soloLectura: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Salud · ${widget.animal.nombreVisible}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      // 1. CABEZA -- estado de salud actual.
                      _EstadoActualCard(
                        animal: widget.animal,
                        eventosActivos: _eventosActivos,
                        dateFormat: _dateFormat,
                      ),
                      const SizedBox(height: 20),

                      // 2. CUERPO -- eventos activos (Abierto/En tratamiento).
                      Text('Eventos activos',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_eventosActivos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Sin eventos de salud activos en este momento',
                            style: TextStyle(color: AppTheme.outline),
                          ),
                        )
                      else
                        for (final evento in _eventosActivos)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TarjetaEvento(
                              evento: evento,
                              dateFormat: _dateFormat,
                              onTap: () => _abrirDetalle(evento),
                            ),
                          ),
                      const SizedBox(height: 24),

                      // 3. PIE DE PÁGINA -- historial completo.
                      Text('Historial de salud',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_historialCompleto.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Sin eventos de salud registrados todavía',
                            style: TextStyle(color: AppTheme.outline),
                          ),
                        )
                      else
                        for (final evento in _historialCompleto)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TarjetaEvento(
                              evento: evento,
                              dateFormat: _dateFormat,
                              onTap: () => _abrirDetalle(evento),
                              atenuada: evento.estaResuelto,
                            ),
                          ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registrarEvento,
        icon: const Icon(Icons.add),
        label: const Text('Registrar evento de salud'),
      ),
    );
  }
}

/// 1. Cabeza: ficha de estado actual -- resume si hay algo pendiente de
/// atención y el próximo refuerzo más cercano entre todos los eventos
/// activos (si alguno lo tiene programado).
class _EstadoActualCard extends StatelessWidget {
  final Animal animal;
  final List<EventoSanitario> eventosActivos;
  final DateFormat dateFormat;

  const _EstadoActualCard({
    required this.animal,
    required this.eventosActivos,
    required this.dateFormat,
  });

  EventoSanitario? get _proximoRefuerzo {
    final conRefuerzo = eventosActivos
        .where((e) => e.fechaProximoRefuerzo != null)
        .toList()
      ..sort(
          (a, b) => a.fechaProximoRefuerzo!.compareTo(b.fechaProximoRefuerzo!));
    return conRefuerzo.isEmpty ? null : conRefuerzo.first;
  }

  @override
  Widget build(BuildContext context) {
    final saludable = eventosActivos.isEmpty;
    final refuerzo = _proximoRefuerzo;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: saludable
            ? AppTheme.primaryContainer.withValues(alpha: 0.18)
            : AppTheme.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: saludable
              ? AppTheme.primaryContainer.withValues(alpha: 0.4)
              : AppTheme.tertiary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: saludable
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : AppTheme.tertiary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  saludable ? Icons.check_circle_outline : Icons.healing,
                  color: saludable ? AppTheme.primary : AppTheme.tertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      saludable
                          ? 'Sin eventos activos'
                          : '${eventosActivos.length} evento(s) activo(s)',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${emojiEspecie(animal.especie?.nombre)} ${animal.nombreVisible} · #${animal.codigo}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (refuerzo != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.event_available,
                    size: 18, color: AppTheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Próximo refuerzo: ${dateFormat.format(refuerzo.fechaProximoRefuerzo!)}'
                    '${refuerzo.diasParaProximoRefuerzo != null ? ' (${_textoDias(refuerzo.diasParaProximoRefuerzo!)})' : ''}',
                    style: textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _textoDias(int dias) {
    if (dias < 0) return 'vencido hace ${-dias} día${-dias == 1 ? '' : 's'}';
    if (dias == 0) return 'hoy';
    if (dias == 1) return 'mañana';
    return 'en $dias días';
  }
}

/// Tarjeta compacta de un evento, usada tanto en "Eventos activos" como en
/// "Historial de salud".
class _TarjetaEvento extends StatelessWidget {
  final EventoSanitario evento;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final bool atenuada;

  const _TarjetaEvento({
    required this.evento,
    required this.dateFormat,
    required this.onTap,
    this.atenuada = false,
  });

  Color get _colorEstado {
    if (evento.estaResuelto) return AppTheme.primary;
    if (evento.estaEnTratamiento) return AppTheme.tertiary;
    return AppTheme.secondary; // Abierto
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: atenuada ? 0.75 : 1,
      child: Material(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
              border: Border.all(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _colorEstado.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.medical_services_outlined,
                      color: _colorEstado, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(evento.tipoEvento,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (evento.fechaEvento != null)
                        Text(dateFormat.format(evento.fechaEvento!),
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.outline)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colorEstado.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    evento.estado,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _colorEstado),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
