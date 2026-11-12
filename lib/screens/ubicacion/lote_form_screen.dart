import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_exception.dart';
import '../../models/catalogo/especie.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import '../../theme/app_theme.dart';

/// Formulario de Crear/Editar Lote, contra `UbicacionRepository`.
///
/// Fase 1 (funcional, pocos estilos): sin tarjetas grandes de especie ni
/// diseño del mockup todavía -- un `Form` simple con los campos reales que
/// acepta el backend (`nombre` y `especie_id` obligatorios, el resto
/// opcional). Asignar encargado NO está acá -- queda para la pantalla
/// "Asignar Personal — Lote" (ver decisiones-diseno-vs-backend-ubicacion.md,
/// sección 7), que todavía no existe.
///
/// 2026-11-10 (Fase 2, Estilos): banner superior con ícono (como el
/// mockup), y el selector de Especie pasa de `DropdownButtonFormField` a
/// tarjetas seleccionables (una por especie real del catálogo -- no
/// hardcodeadas a Bovino/Porcino/Aves como en el mockup, porque el
/// catálogo puede tener más). El slider de "Capacidad estimada" del
/// mockup **no** se implementó -- el backend no define un rango mín/máx
/// para validarlo, así que se mantiene como el campo numérico ya
/// existente (con el mismo filtro de solo-dígitos). Se agregó un botón
/// "Cancelar" debajo de "Crear Lote", como en el mockup.
class LoteFormScreen extends StatefulWidget {
  final UbicacionRepository repository;
  final CatalogoRepository catalogoRepository;
  final LoteAnimal? loteExistente;

  const LoteFormScreen({
    super.key,
    required this.repository,
    required this.catalogoRepository,
    this.loteExistente,
  });

  @override
  State<LoteFormScreen> createState() => _LoteFormScreenState();
}

class _LoteFormScreenState extends State<LoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _capacidadCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  List<Especie> _especies = [];
  Especie? _especieSeleccionada;
  DateTime? _fechaCreacion;

  bool _cargandoEspecies = true;
  bool _guardando = false;
  bool _eliminando = false;
  String? _error;

  bool get _esEdicion => widget.loteExistente != null;

  @override
  void initState() {
    super.initState();
    final actual = widget.loteExistente;
    if (actual != null) {
      _nombreCtrl.text = actual.nombre;
      _capacidadCtrl.text = actual.capacidadEstimada?.toString() ?? '';
      _descripcionCtrl.text = actual.descripcion ?? '';
      _fechaCreacion = actual.fechaCreacion;
    }
    _cargarEspecies();
  }

  Future<void> _cargarEspecies() async {
    try {
      final especies = await widget.catalogoRepository.listarEspecies();
      if (!mounted) return;
      setState(() {
        _especies = especies;
        final actual = widget.loteExistente;
        if (actual?.especieId != null) {
          try {
            _especieSeleccionada =
                especies.firstWhere((e) => e.id == actual!.especieId);
          } catch (_) {
            _especieSeleccionada = null;
          }
        }
      });
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar las especies: $e');
    } finally {
      if (mounted) setState(() => _cargandoEspecies = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _capacidadCtrl.dispose();
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
    if (_especieSeleccionada == null) {
      setState(() => _error = 'Selecciona la especie');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    final capacidad = _capacidadCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(_capacidadCtrl.text.trim());
    final descripcion = _descripcionCtrl.text.trim().isEmpty
        ? null
        : _descripcionCtrl.text.trim();

    try {
      if (_esEdicion) {
        await widget.repository.actualizarLote(
          widget.loteExistente!.id,
          ActualizarLoteDTO(
            nombre: _nombreCtrl.text.trim(),
            especieId: _especieSeleccionada!.id,
            fechaCreacion: _fechaCreacion,
            capacidadEstimada: capacidad,
            descripcion: descripcion,
          ),
        );
      } else {
        await widget.repository.crearLote(
          CrearLoteDTO(
            nombre: _nombreCtrl.text.trim(),
            especieId: _especieSeleccionada!.id,
            fechaCreacion: _fechaCreacion,
            capacidadEstimada: capacidad,
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
        title: const Text('Eliminar lote'),
        content: Text(
            '¿Seguro que quieres eliminar "${widget.loteExistente!.nombre}"? '
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
      await widget.repository.eliminarLote(widget.loteExistente!.id);
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Lote' : 'Crear Lote'),
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
      body: _cargandoEspecies
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.secondaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: AppTheme.secondaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.grid_view_rounded,
                              color: AppTheme.onSecondaryContainer),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _esEdicion
                                    ? 'Editar Grupo de Animales'
                                    : 'Nuevo Grupo de Animales',
                                style: textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 2),
                              Text('Agrupa para control de pastura y vacunas',
                                  style: textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Nombre del lote *', style: textTheme.labelMedium),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Lote Terneros Primavera',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                  ),
                  const SizedBox(height: 16),
                  Text('Especie animal *', style: textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _especies.map((especie) {
                      final seleccionada =
                          _especieSeleccionada?.id == especie.id;
                      return _tarjetaEspecie(especie, seleccionada);
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Capacidad estimada', style: textTheme.labelMedium),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _capacidadCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'Ej. 10',
                      suffixText: 'animales',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Descripción / Observaciones',
                      style: textTheme.labelMedium),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descripcionCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'Notas de origen, características particulares o '
                          'condiciones del lote...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Fecha de creación', style: textTheme.labelMedium),
                  const SizedBox(height: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                    onTap: _elegirFecha,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusDefault),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _fechaCreacion == null
                                  ? 'Sin definir'
                                  : '${_fechaCreacion!.day}/${_fechaCreacion!.month}/${_fechaCreacion!.year}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    child: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_esEdicion ? 'Guardar cambios' : 'Crear Lote'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        _guardando ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
    );
  }

  // Tarjeta seleccionable de especie (reemplazo del dropdown, siguiendo el
  // mockup) -- es un InkWell + Container, no un ButtonStyleButton, así que
  // es seguro usarla aunque más adelante quede dentro de un Card.
  Widget _tarjetaEspecie(Especie especie, bool seleccionada) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      onTap: () => setState(() => _especieSeleccionada = especie),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: seleccionada
              ? AppTheme.primaryContainer
              : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
            color: seleccionada
                ? AppTheme.primaryContainer
                : AppTheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: seleccionada
                    ? Colors.white.withValues(alpha: 0.3)
                    : AppTheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.pets,
                  size: 18,
                  color:
                      seleccionada ? Colors.white : AppTheme.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                especie.nombre,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: seleccionada ? Colors.white : AppTheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
