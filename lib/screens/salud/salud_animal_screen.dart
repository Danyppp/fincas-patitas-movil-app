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
///
/// 2026-11-01 (Etapa 2: Estilos): paleta y tarjetas ajustadas 1:1 al
/// mockup de Stitch `salud_seo_fincas_y_patitas` -- banner coral/verde de
/// resumen, filas de evento con avatar circular + pill de estado en los
/// mismos tonos exactos del mockup (que no coinciden del todo con el
/// alpha genérico de AppTheme.tertiary/primary, por eso se definen acá
/// como constantes locales, igual que ya se hizo en Producción con los
/// colores "piel").
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

/// Paleta exacta del mockup `salud_seo_fincas_y_patitas` (tokens
/// `finca-coral*` / `finca-mint*` de su `tailwind.config`).
const _coral = Color(0xFFFDECE7);
const _coralBorder = Color(0xFFF9D5CB);
const _coralText = Color(0xFFA84334);
const _coralBadge = Color(0xFFFCE8E4);
const _mint = Color(0xFFEBF6EE);
const _mintBadge = Color(0xFFE2F3E7);
const _mintText = Color(0xFF2E7D32);

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
                      const SizedBox(height: 10),
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
                            padding: const EdgeInsets.only(bottom: 10),
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
                      const SizedBox(height: 10),
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
                            padding: const EdgeInsets.only(bottom: 10),
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
        backgroundColor: AppTheme.primaryContainer,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add),
        label: const Text('Registrar evento de salud'),
      ),
    );
  }
}

/// 1. Cabeza: ficha de estado actual -- resume si hay algo pendiente de
/// atención y el próximo refuerzo más cercano entre todos los eventos
/// activos (si alguno lo tiene programado). Mismo banner redondeado
/// coral/verde del mockup, con el icono en una placa cuadrada (no
/// circular) de 48px.
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
    final fondo = saludable ? _mint : _coral;
    final borde = saludable ? _mintBadge : _coralBorder;
    final acento = saludable ? _mintText : _coralText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(
                  saludable ? Icons.check_circle_outline : Icons.healing,
                  color: acento,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(emojiEspecie(animal.especie?.nombre),
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            '${animal.nombreVisible} · #${animal.codigo}',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (refuerzo != null) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: borde.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.event_available, size: 16, color: acento),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Próximo refuerzo: ${dateFormat.format(refuerzo.fechaProximoRefuerzo!)}'
                    '${refuerzo.diasParaProximoRefuerzo != null ? ' (${_textoDias(refuerzo.diasParaProximoRefuerzo!)})' : ''}',
                    style: textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700, color: acento),
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
/// "Historial de salud" -- avatar circular (verde menta si está
/// Resuelto/sin alerta, coral si está Abierto/En tratamiento) + pill de
/// estado en el mismo tono, igual que las filas del mockup.
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

  bool get _esCoral => !evento.estaResuelto;

  @override
  Widget build(BuildContext context) {
    final fondoAvatar = _esCoral ? _coral : _mint;
    final colorIcono = _esCoral ? _coralText : _mintText;
    final fondoPill = _esCoral ? _coralBadge : _mintBadge;
    final colorPill = _esCoral ? _coralText : _mintText;

    return Opacity(
      opacity: atenuada ? 0.85 : 1,
      child: Material(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                  color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: fondoAvatar,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.medical_services_outlined,
                      color: colorIcono, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(evento.tipoEvento,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 2),
                      if (evento.fechaEvento != null)
                        Text(dateFormat.format(evento.fechaEvento!),
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.outline)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: fondoPill,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    evento.estado,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: colorPill),
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
