import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/animal.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import '../../widgets/boton_pill.dart';
import 'lote_form_screen.dart';

/// Detalle de un Lote: reemplaza la antigua hoja inferior de solo lectura
/// -- ahora es una pantalla propia, con los animales reales que tiene
/// asignados (vía `AnimalRepository.listar(loteId: ...)`, el mismo filtro
/// que ya usa Animales) y accesos directos a Editar/Eliminar.
///
/// Asignar animales a este lote sigue siendo desde "Asignar Animales" (ver
/// decisiones-diseno-vs-backend-ubicacion.md, sección 7). Quitar un animal
/// de acá (2026-11-10, a pedido de Dany) sí está disponible directamente
/// en esta pantalla, con el mismo botón "Quitar" por fila.
class LoteDetalleScreen extends StatefulWidget {
  final int loteId;
  final UbicacionRepository repository;
  final CatalogoRepository catalogoRepository;
  final AnimalRepository animalRepository;

  const LoteDetalleScreen({
    super.key,
    required this.loteId,
    required this.repository,
    required this.catalogoRepository,
    required this.animalRepository,
  });

  @override
  State<LoteDetalleScreen> createState() => _LoteDetalleScreenState();
}

class _LoteDetalleScreenState extends State<LoteDetalleScreen> {
  LoteAnimal? _lote;
  List<Animal> _animales = [];
  bool _cargando = true;
  bool _eliminando = false;
  final Set<int> _quitando = {};
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
      final lote = await widget.repository.obtenerLote(widget.loteId);
      if (lote == null) {
        setState(() => _error = 'Este lote ya no existe');
        return;
      }
      final pagina = await widget.animalRepository
          .listar(loteId: widget.loteId, estado: 'Todos', limite: 200);
      if (!mounted) return;
      setState(() {
        _lote = lote;
        _animales = pagina.data;
      });
    } catch (e) {
      setState(() => _error = 'No se pudo cargar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar() async {
    final editado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoteFormScreen(
          repository: widget.repository,
          catalogoRepository: widget.catalogoRepository,
          loteExistente: _lote,
        ),
      ),
    );
    if (editado == true) _cargar();
  }

  Future<void> _confirmarEliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar lote'),
        content: Text('¿Seguro que quieres eliminar "${_lote!.nombre}"? '
            'Esto no se puede deshacer.'),
        actions: [
          BotonTexto(
            texto: 'Cancelar',
            onTap: () => Navigator.of(context).pop(false),
          ),
          BotonTexto(
            texto: 'Eliminar',
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() {
      _eliminando = true;
      _error = null;
    });
    try {
      await widget.repository.eliminarLote(widget.loteId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  // 2026-11-10 (a pedido de Dany): "Quitar" un animal de este lote -- solo
  // limpia `lote_id`. OJO -- `ActualizarAnimalDTO` siempre envía
  // `lote_id`/`potrero_id`/`madre_id`/`padre_id` (incluso en null), así
  // que hay que reenviar explícitamente el potrero/madre/padre que el
  // animal ya tenía, o se borrarían sin querer (mismo detalle que
  // `AsignarAnimalesScreen`, ver decisiones-diseno-vs-backend-ubicacion.md
  // sección 7).
  Future<void> _quitarAnimal(Animal animal) async {
    setState(() {
      _quitando.add(animal.id);
      _error = null;
    });
    try {
      await widget.animalRepository.actualizar(
        animal.id,
        ActualizarAnimalDTO(
          loteId: null,
          potreroId: animal.potreroId,
          madreId: animal.madreId,
          padreId: animal.padreId,
        ),
      );
      if (!mounted) return;
      setState(() => _animales.removeWhere((a) => a.id == animal.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${animal.nombreVisible} se quitó de este lote')),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _quitando.remove(animal.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lote = _lote;
    return Scaffold(
      appBar: AppBar(
        title: Text(lote?.nombre ?? 'Lote'),
        actions: [
          if (lote != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editar,
            ),
            IconButton(
              icon: _eliminando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline),
              onPressed: _eliminando ? null : _confirmarEliminar,
            ),
          ],
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : lote == null
              ? Center(child: Text(_error ?? 'No se pudo cargar'))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null) ...[
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                      ],
                      _fila('Especie', lote.especie?.nombre ?? '—'),
                      _fila('Capacidad estimada',
                          lote.capacidadEstimada?.toString() ?? '—'),
                      _fila('Encargado',
                          lote.encargado?.nombreUsuario ?? 'Sin asignar'),
                      _fila(
                          'Fecha de creación',
                          lote.fechaCreacion != null
                              ? '${lote.fechaCreacion!.day}/${lote.fechaCreacion!.month}/${lote.fechaCreacion!.year}'
                              : '—'),
                      _fila('Descripción', lote.descripcion ?? '—'),
                      const SizedBox(height: 20),
                      Text('Animales (${_animales.length})',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_animales.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Sin animales asignados',
                              style: TextStyle(color: Colors.black54)),
                        )
                      else
                        ..._animales.map(_filaAnimal),
                    ],
                  ),
                ),
    );
  }

  // 2026-11-10: Card + Row (no ListTile con botón de texto como trailing)
  // -- ver la nota del mismo patrón en asignar_animales_screen.dart
  // (ButtonStyleButton dentro de un Card, en esta versión de Flutter,
  // puede romper el layout). BotonTexto no hereda de ButtonStyleButton, así
  // que es seguro usarlo acá.
  Widget _filaAnimal(Animal animal) {
    final quitandoEste = _quitando.contains(animal.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.pets_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(animal.nombre ?? animal.codigo,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${animal.codigo} · ${animal.genero} · ${animal.estado}',
                      style: const TextStyle(
                          fontSize: 12.5, color: Colors.black54)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            quitandoEste
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : BotonTexto(
                    texto: 'Quitar',
                    onTap: () => _quitarAnimal(animal),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 150,
              child: Text(etiqueta,
                  style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(valor)),
        ],
      ),
    );
  }
}
