import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/animal.dart';
import '../../models/catalogo/potrero.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import '../../widgets/boton_pill.dart';
import 'potrero_form_screen.dart';

/// Detalle de un Potrero: reemplaza la antigua hoja inferior de solo
/// lectura -- ahora es una pantalla propia, con la foto real (y la
/// posibilidad de subir/cambiar una), sus encargados y los animales que
/// tiene asignados (vía `GET /ubicaciones-potreros/:id/animales`).
///
/// Se usa `file_picker` (no `image_picker`) para elegir la foto porque sí
/// funciona en Windows desktop además de Android/iOS/Web -- `image_picker`
/// de Google solo soporta oficialmente Android/iOS/Web.
///
/// Agregar/quitar encargados NO está acá -- va en "Asignar Personal —
/// Potrero" (ver decisiones-diseno-vs-backend-ubicacion.md, sección 7);
/// acá los encargados se muestran de solo lectura. Quitar un ANIMAL de
/// acá (2026-11-10, a pedido de Dany) sí está disponible directamente en
/// esta pantalla, con un botón "Quitar" por fila (mismo patrón que
/// `LoteDetalleScreen`).
class PotreroDetalleScreen extends StatefulWidget {
  final int potreroId;
  final UbicacionRepository repository;
  final AnimalRepository animalRepository;

  const PotreroDetalleScreen({
    super.key,
    required this.potreroId,
    required this.repository,
    required this.animalRepository,
  });

  @override
  State<PotreroDetalleScreen> createState() => _PotreroDetalleScreenState();
}

class _PotreroDetalleScreenState extends State<PotreroDetalleScreen> {
  Potrero? _potrero;
  List<Animal> _animales = [];
  bool _cargando = true;
  bool _eliminando = false;
  bool _subiendoFoto = false;
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
      final potrero = await widget.repository.obtenerPotrero(widget.potreroId);
      if (potrero == null) {
        setState(() => _error = 'Este potrero ya no existe');
        return;
      }
      final animales =
          await widget.repository.animalesDelPotrero(widget.potreroId);
      if (!mounted) return;
      setState(() {
        _potrero = potrero;
        _animales = animales;
      });
    } catch (e) {
      setState(() => _error = 'No se pudo cargar: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarFoto() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final archivo = resultado?.files.single;
    if (archivo == null || archivo.bytes == null) return;

    setState(() {
      _subiendoFoto = true;
      _error = null;
    });
    try {
      final actualizado = await widget.repository.subirFotoPotrero(
        widget.potreroId,
        bytes: archivo.bytes!,
        nombreArchivo: archivo.name,
      );
      if (!mounted) return;
      setState(() => _potrero = actualizado);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'No se pudo subir la foto: $e');
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _editar() async {
    final editado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PotreroFormScreen(
          repository: widget.repository,
          potreroExistente: _potrero,
        ),
      ),
    );
    if (editado == true) _cargar();
  }

  Future<void> _confirmarEliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar potrero'),
        content: Text('¿Seguro que quieres eliminar "${_potrero!.nombre}"? '
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
      await widget.repository.eliminarPotrero(widget.potreroId);
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

  // 2026-11-10 (a pedido de Dany): "Quitar" un animal de este potrero --
  // solo limpia `potrero_id`. OJO -- `ActualizarAnimalDTO` siempre envía
  // `lote_id`/`potrero_id`/`madre_id`/`padre_id` (incluso en null), así
  // que hay que reenviar explícitamente el lote/madre/padre que el animal
  // ya tenía, o se borrarían sin querer (mismo detalle que
  // `AsignarAnimalesScreen`/`LoteDetalleScreen`, ver
  // decisiones-diseno-vs-backend-ubicacion.md sección 7).
  Future<void> _quitarAnimal(Animal animal) async {
    setState(() {
      _quitando.add(animal.id);
      _error = null;
    });
    try {
      await widget.animalRepository.actualizar(
        animal.id,
        ActualizarAnimalDTO(
          loteId: animal.loteId,
          potreroId: null,
          madreId: animal.madreId,
          padreId: animal.padreId,
        ),
      );
      if (!mounted) return;
      setState(() => _animales.removeWhere((a) => a.id == animal.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${animal.nombreVisible} se quitó de este potrero')),
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
    final potrero = _potrero;
    return Scaffold(
      appBar: AppBar(
        title: Text(potrero?.nombre ?? 'Potrero'),
        actions: [
          if (potrero != null) ...[
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
          : potrero == null
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
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: potrero.fotoUrl != null
                                ? Image.network(potrero.fotoUrl!,
                                    height: 170,
                                    width: double.infinity,
                                    fit: BoxFit.cover)
                                : Container(
                                    height: 170,
                                    width: double.infinity,
                                    color: const Color(0xFFEFEBE9),
                                    child: const Icon(Icons.image_outlined,
                                        size: 48, color: Colors.black38),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: FloatingActionButton.small(
                              heroTag: 'cambiarFotoPotrero',
                              onPressed: _subiendoFoto ? null : _cambiarFoto,
                              child: _subiendoFoto
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.camera_alt_outlined,
                                      size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _fila('Estado', potrero.estado ?? '—'),
                      _fila('Capacidad',
                          potrero.capacidadAnimales?.toString() ?? '—'),
                      _fila(
                          'Tamaño',
                          potrero.tamanoHectareas != null
                              ? '${potrero.tamanoHectareas} ha'
                              : '—'),
                      _fila(
                          'Fecha de creación',
                          potrero.fechaCreacion != null
                              ? '${potrero.fechaCreacion!.day}/${potrero.fechaCreacion!.month}/${potrero.fechaCreacion!.year}'
                              : '—'),
                      _fila('Descripción', potrero.descripcion ?? '—'),
                      const SizedBox(height: 20),
                      Text('Encargados (${potrero.encargados.length})',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (potrero.encargados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('Sin encargados asignados',
                              style: TextStyle(color: Colors.black54)),
                        )
                      else
                        ...potrero.encargados.map((pe) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text(pe.usuario.nombreUsuario),
                                subtitle: Text(pe.usuario.correoElectronico),
                              ),
                            )),
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
  // -- mismo motivo que en `LoteDetalleScreen`/`asignar_animales_screen.dart`
  // (ButtonStyleButton dentro de un Card, en esta versión de Flutter, puede
  // romper el layout). BotonTexto no hereda de ButtonStyleButton.
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
