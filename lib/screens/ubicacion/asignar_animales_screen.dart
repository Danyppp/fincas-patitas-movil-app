import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/animal.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/boton_pill.dart';

/// Asignar Animales -- una sola pantalla reutilizada para Lote y para
/// Potrero (ver decisiones-diseno-vs-backend-ubicacion.md, sección 7).
///
/// No existe un endpoint propio: reutiliza `PUT /animales/{id}`
/// (`AnimalRepository.actualizar`), que ya aceptaba `lote_id`/`potrero_id`
/// desde antes de este módulo.
///
/// OJO -- `ActualizarAnimalDTO` SIEMPRE envía `lote_id`/`potrero_id`/
/// `madre_id`/`padre_id` (incluso en null, para poder limpiarlos desde el
/// formulario de Animal). Por eso acá, al asignar a un Lote, hay que
/// reenviar el `potreroId`/`madreId`/`padreId` que el animal ya tenía (y
/// viceversa) -- si no, asignar a un Lote borraría silenciosamente su
/// Potrero (y madre/padre).
///
/// La barra de "Ocupación actual X/Y" solo se muestra para destino
/// Potrero (el Lote no tiene límite de capacidad) -- es informativa, no
/// bloquea la asignación si ya está lleno (el mockup no pedía bloquearlo).
///
/// 2026-11-10 (Fase 2, Estilos): tarjeta de "Destino de asignación" con
/// el dropdown adentro (como el mockup), barra de ocupación en verde, y
/// filas de animal con el mismo patrón de ícono en círculo del resto del
/// módulo. **No** se implementó la selección múltiple con confirmación en
/// lote ("Seleccionar todos" + "Confirmar asignación (N)") del mockup --
/// se mantiene la asignación una por una ya confirmada por Dany, porque
/// cambiar a selección múltiple es un cambio de flujo, no solo de estilo,
/// y no fue parte de lo pedido. Tampoco se agregaron los filtros por
/// especie en chips (Vacas/Cerdos/Gallinas) del mockup -- el filtro por
/// especie ya es automático al elegir un Lote destino (ver sección 7 del
/// documento de decisiones).
class AsignarAnimalesScreen extends StatefulWidget {
  final UbicacionRepository repository;
  final AnimalRepository animalRepository;

  const AsignarAnimalesScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
  });

  @override
  State<AsignarAnimalesScreen> createState() => _AsignarAnimalesScreenState();
}

class _AsignarAnimalesScreenState extends State<AsignarAnimalesScreen> {
  final _buscarCtrl = TextEditingController();

  List<LoteAnimal> _lotes = [];
  List<Potrero> _potreros = [];
  bool _esLote = true;
  LoteAnimal? _loteDestino;
  Potrero? _potreroDestino;
  int? _ocupacionPotrero;

  List<Animal> _animales = [];
  bool _cargandoDestinos = true;
  bool _buscando = false;
  final Set<int> _asignando = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDestinos();
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDestinos() async {
    setState(() {
      _cargandoDestinos = true;
      _error = null;
    });
    try {
      final lotes = await widget.repository.listarLotes();
      final potreros = await widget.repository.listarPotreros();
      if (!mounted) return;
      setState(() {
        _lotes = lotes;
        _potreros = potreros;
      });
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar Lotes/Potreros: $e');
    } finally {
      if (mounted) setState(() => _cargandoDestinos = false);
    }
  }

  Future<void> _cambiarTipo(bool esLote) async {
    setState(() {
      _esLote = esLote;
      _ocupacionPotrero = null;
      _animales = [];
    });
    // 2026-11-10 (a pedido de Dany): si ya había un destino elegido del
    // otro tipo, no hay animales que buscar todavía -- la lista solo se
    // auto-carga cuando se elige un destino del tipo activo (ver
    // _elegirLoteDestino/_elegirPotreroDestino).
    if (_esLote && _loteDestino != null) {
      await _buscar();
    } else if (!_esLote && _potreroDestino != null) {
      await _buscar();
    }
  }

  // 2026-11-10 (a pedido de Dany): antes había que escribir algo en el
  // buscador para que apareciera cualquier animal. Ahora, en cuanto se
  // elige un Lote/Potrero destino, se carga de una vez la lista completa
  // de candidatos (ver _buscar) -- el buscador sigue sirviendo para
  // filtrar esa lista por nombre/código.
  Future<void> _elegirLoteDestino(LoteAnimal? lote) async {
    setState(() {
      _loteDestino = lote;
      _animales = [];
    });
    if (lote != null) await _buscar();
  }

  Future<void> _elegirPotreroDestino(Potrero? potrero) async {
    setState(() {
      _potreroDestino = potrero;
      _ocupacionPotrero = null;
      _animales = [];
    });
    if (potrero == null) return;
    try {
      final animales = await widget.repository.animalesDelPotrero(potrero.id);
      if (!mounted) return;
      setState(() => _ocupacionPotrero = animales.length);
    } catch (_) {
      // Informativo -- si falla, simplemente no se muestra la barra.
    }
    await _buscar();
  }

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      // 2026-11-10 (a pedido de Dany): al destino Lote, la lista se filtra
      // por la especie de ese Lote (un Lote es de una sola especie -- ver
      // decisiones-diseno-vs-backend-ubicacion.md sección 1) -- muestra
      // TODOS los animales de esa especie, estén o no ya asignados a este
      // u otro Lote (para poder reasignarlos). Al destino Potrero no se
      // filtra por especie (un Potrero admite cualquier especie).
      final pagina = await widget.animalRepository.listar(
        especieId: _esLote ? _loteDestino?.especieId : null,
        buscar: _buscarCtrl.text.trim(),
        estado: 'Activo',
        limite: 100,
      );
      if (!mounted) return;
      setState(() => _animales = pagina.data);
    } catch (e) {
      setState(() => _error = 'No se pudo buscar: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _mostrarDetalle(Animal animal) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(animal.nombreVisible),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filaDetalle('Código', animal.codigo),
            _filaDetalle('Nombre',
                animal.nombre?.isNotEmpty == true ? animal.nombre! : '—'),
            _filaDetalle('Especie', animal.especie?.nombre ?? '—'),
            _filaDetalle('Raza', animal.raza?.nombre ?? '—'),
          ],
        ),
        actions: [
          BotonTexto(texto: 'Cerrar', onTap: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  Widget _filaDetalle(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(etiqueta,
                style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(valor,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  String _nombreLote(int? id) {
    if (id == null) return '';
    try {
      return _lotes.firstWhere((l) => l.id == id).nombre;
    } catch (_) {
      return 'Lote #$id';
    }
  }

  String _nombrePotrero(int? id) {
    if (id == null) return '';
    try {
      return _potreros.firstWhere((p) => p.id == id).nombre;
    } catch (_) {
      return 'Potrero #$id';
    }
  }

  Future<void> _asignar(Animal animal) async {
    final destinoLoteId = _esLote ? _loteDestino?.id : animal.loteId;
    final destinoPotreroId = _esLote ? animal.potreroId : _potreroDestino?.id;

    setState(() {
      _asignando.add(animal.id);
      _error = null;
    });
    try {
      await widget.animalRepository.actualizar(
        animal.id,
        ActualizarAnimalDTO(
          loteId: destinoLoteId,
          potreroId: destinoPotreroId,
          madreId: animal.madreId,
          padreId: animal.padreId,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${animal.nombreVisible} asignado(a) correctamente')),
      );
      // Refresca la búsqueda para que la fila muestre el nuevo destino, y
      // la ocupación del potrero si corresponde.
      await _buscar();
      if (!_esLote && _potreroDestino != null) {
        _elegirPotreroDestino(_potreroDestino);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _asignando.remove(animal.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinoElegido =
        _esLote ? _loteDestino != null : _potreroDestino != null;
    final textTheme = Theme.of(context).textTheme;
    final colorAcento = _esLote ? AppTheme.primary : AppTheme.tertiary;
    final colorAcentoFondo =
        _esLote ? AppTheme.primaryContainer : AppTheme.tertiaryContainer;

    return Scaffold(
      appBar: AppBar(title: const Text('Asignar Animales')),
      body: _cargandoDestinos
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: true,
                        label: Text('A un Lote'),
                        icon: Icon(Icons.grid_view_outlined)),
                    ButtonSegment(
                        value: false,
                        label: Text('A un Potrero'),
                        icon: Icon(Icons.map_outlined)),
                  ],
                  selected: {_esLote},
                  onSelectionChanged: (s) => _cambiarTipo(s.first),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorAcentoFondo.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: colorAcentoFondo.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _esLote
                                  ? Icons.grid_view_outlined
                                  : Icons.map_outlined,
                              size: 15,
                              color: colorAcento,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('DESTINO DE ASIGNACIÓN',
                              style: textTheme.labelSmall
                                  ?.copyWith(color: colorAcento)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLowest,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusDefault),
                        ),
                        child: _esLote
                            ? DropdownButtonHideUnderline(
                                child: DropdownButtonFormField<LoteAnimal>(
                                  value: _loteDestino,
                                  decoration: const InputDecoration(
                                    labelText: 'Lote destino',
                                    border: InputBorder.none,
                                    filled: false,
                                  ),
                                  items: _lotes
                                      .map((l) => DropdownMenuItem(
                                          value: l, child: Text(l.nombre)))
                                      .toList(),
                                  onChanged: _elegirLoteDestino,
                                ),
                              )
                            : DropdownButtonHideUnderline(
                                child: DropdownButtonFormField<Potrero>(
                                  value: _potreroDestino,
                                  decoration: const InputDecoration(
                                    labelText: 'Potrero destino',
                                    border: InputBorder.none,
                                    filled: false,
                                  ),
                                  items: _potreros
                                      .map((p) => DropdownMenuItem(
                                          value: p, child: Text(p.nombre)))
                                      .toList(),
                                  onChanged: _elegirPotreroDestino,
                                ),
                              ),
                      ),
                      if (!_esLote &&
                          _potreroDestino != null &&
                          _ocupacionPotrero != null) ...[
                        const SizedBox(height: 10),
                        _barraOcupacion(_ocupacionPotrero!,
                            _potreroDestino!.capacidadAnimales),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (destinoElegido) ...[
                  TextField(
                    controller: _buscarCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar por arete, nombre...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _buscando
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                  const SizedBox(height: 12),
                  if (_buscando)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_animales.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _esLote
                            ? 'No hay animales de esta especie disponibles'
                            : 'No hay animales disponibles',
                        style: textTheme.bodyMedium,
                      ),
                    )
                  else
                    ..._animales.map(_filaAnimal),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                        'Elige un ${_esLote ? 'Lote' : 'Potrero'} destino para buscar animales',
                        style: textTheme.bodyMedium),
                  ),
              ],
            ),
    );
  }

  Widget _barraOcupacion(int ocupados, int? capacidad) {
    final texto = capacidad != null
        ? 'Ocupación actual: $ocupados / $capacidad'
        : 'Ocupación actual: $ocupados (sin capacidad definida)';
    final valor =
        (capacidad != null && capacidad > 0) ? ocupados / capacidad : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(texto,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          child: LinearProgressIndicator(
            value: valor.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.6),
            color: valor >= 1.0 ? AppTheme.error : AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _filaAnimal(Animal animal) {
    final yaEnLote = _esLote && animal.loteId == _loteDestino?.id;
    final yaEnPotrero = !_esLote && animal.potreroId == _potreroDestino?.id;
    final yaAqui = yaEnLote || yaEnPotrero;
    final asignandoEste = _asignando.contains(animal.id);

    final ubicacionActual = [
      if (animal.loteId != null) 'Lote: ${_nombreLote(animal.loteId)}',
      if (animal.potreroId != null)
        'Potrero: ${_nombrePotrero(animal.potreroId)}',
    ];

    // 2026-11-05: se cambió ListTile por una Row simple dentro de la
    // tarjeta. ListTile calcula internamente el ancho "ideal" de su
    // trailing con lógica de intrínsecos, y un botón con texto ahí (incluso
    // envuelto en FittedBox) puede disparar "BoxConstraints forces an
    // infinite width" y dejar la fila sin tamaño (invisible) en viewports
    // angostos (confirmado en la terminal de Dany). Row no tiene ese
    // problema: el título ocupa el espacio restante (Expanded) y el botón
    // se dibuja con su tamaño natural.
    // 2026-11-10 (a pedido de Dany): tocar la fila (fuera del botón) abre
    // un detalle rápido del animal (Código/Nombre/Especie/Raza). Se usa
    // Material+InkWell (no ButtonStyleButton) -- mismo motivo que
    // boton_pill.dart.
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _mostrarDetalle(animal),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.pets_outlined,
                    color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(animal.nombreVisible,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        animal.codigo,
                        if (ubicacionActual.isEmpty)
                          'Sin ubicación'
                        else
                          ubicacionActual.join(' · '),
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 12.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              yaAqui
                  ? EtiquetaPill(
                      texto: 'Ya aquí',
                      color: AppTheme.primaryContainer.withValues(alpha: 0.5),
                      colorTexto: AppTheme.primary,
                    )
                  : BotonPill(
                      texto: ubicacionActual.isEmpty ? 'Asignar' : 'Reasignar',
                      color: AppTheme.primaryContainer,
                      cargando: asignandoEste,
                      onTap: () => _asignar(animal),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
