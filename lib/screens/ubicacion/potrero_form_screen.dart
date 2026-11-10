import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../models/catalogo/potrero.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';

/// Formulario de Crear/Editar Potrero, contra `UbicacionRepository`.
///
/// Fase 1 (funcional, pocos estilos). `estado` no tiene una lista fija en
/// el backend (es un `string` libre) -- se ofrece un dropdown con los
/// valores que ya se usan en los datos reales/de prueba (Disponible,
/// Ocupado, En mantenimiento) para no dejarlo en blanco por error.
///
/// La foto NO está en este formulario: subir una requiere elegir un
/// archivo de la galería/cámara (paquete `image_picker`, que el proyecto
/// todavía no tiene instalado) -- queda para cuando se construya la
/// pantalla de Detalle de Potrero. Asignar encargados tampoco está acá,
/// igual que en Lote -- va en "Asignar Personal — Potrero".
class PotreroFormScreen extends StatefulWidget {
  final UbicacionRepository repository;
  final Potrero? potreroExistente;

  const PotreroFormScreen({
    super.key,
    required this.repository,
    this.potreroExistente,
  });

  @override
  State<PotreroFormScreen> createState() => _PotreroFormScreenState();
}

class _PotreroFormScreenState extends State<PotreroFormScreen> {
  static const _estadosSugeridos = [
    'Disponible',
    'Ocupado',
    'En mantenimiento'
  ];

  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  final _tamanoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  String? _estado;
  DateTime? _fechaCreacion;

  bool _guardando = false;
  bool _eliminando = false;
  String? _error;

  bool get _esEdicion => widget.potreroExistente != null;

  @override
  void initState() {
    super.initState();
    final actual = widget.potreroExistente;
    if (actual != null) {
      _nombreCtrl.text = actual.nombre;
      _capacidadCtrl.text = actual.capacidadAnimales?.toString() ?? '';
      _tamanoCtrl.text = actual.tamanoHectareas?.toString() ?? '';
      _descripcionCtrl.text = actual.descripcion ?? '';
      _fechaCreacion = actual.fechaCreacion;
      _estado =
          actual.estado != null && _estadosSugeridos.contains(actual.estado)
              ? actual.estado
              : actual.estado;
    } else {
      _estado = 'Disponible';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _capacidadCtrl.dispose();
    _tamanoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final resultado = await showDatePicker(
      context: context,
      initialDate: _fechaCreacion ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (resultado != null) setState(() => _fechaCreacion = resultado);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final capacidad = _capacidadCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(_capacidadCtrl.text.trim());
    final tamano = _tamanoCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_tamanoCtrl.text.trim());
    final descripcion = _descripcionCtrl.text.trim().isEmpty
        ? null
        : _descripcionCtrl.text.trim();

    try {
      if (_esEdicion) {
        await widget.repository.actualizarPotrero(
          widget.potreroExistente!.id,
          ActualizarPotreroDTO(
            nombre: _nombreCtrl.text.trim(),
            capacidadAnimales: capacidad,
            estado: _estado,
            tamanoHectareas: tamano,
            fechaCreacion: _fechaCreacion,
            descripcion: descripcion,
          ),
        );
      } else {
        await widget.repository.crearPotrero(
          CrearPotreroDTO(
            nombre: _nombreCtrl.text.trim(),
            capacidadAnimales: capacidad,
            estado: _estado,
            tamanoHectareas: tamano,
            fechaCreacion: _fechaCreacion,
            descripcion: descripcion,
          ),
        );
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

  Future<void> _confirmarEliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar potrero'),
        content: Text(
            '¿Seguro que quieres eliminar "${widget.potreroExistente!.nombre}"? '
            'Esto no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
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
      await widget.repository.eliminarPotrero(widget.potreroExistente!.id);
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

  @override
  Widget build(BuildContext context) {
    // El dropdown necesita que `_estado` exista entre sus `items` (o sea
    // null) -- si el potrero editado trae un estado "raro" que no está en
    // _estadosSugeridos, se agrega como opción extra para no romper el
    // DropdownButtonFormField.
    final opciones =
        {..._estadosSugeridos, if (_estado != null) _estado!}.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Potrero' : 'Crear Potrero'),
        actions: [
          if (_esEdicion)
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
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _estado,
              decoration: const InputDecoration(
                labelText: 'Estado',
                border: OutlineInputBorder(),
              ),
              items: opciones
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _estado = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacidadCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Capacidad (animales)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tamanoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              decoration: const InputDecoration(
                labelText: 'Tamaño (hectáreas)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de creación'),
              subtitle: Text(_fechaCreacion == null
                  ? 'Sin definir'
                  : '${_fechaCreacion!.day}/${_fechaCreacion!.month}/${_fechaCreacion!.year}'),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: _elegirFecha,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_esEdicion ? 'Guardar cambios' : 'Crear Potrero'),
            ),
          ],
        ),
      ),
    );
  }
}
