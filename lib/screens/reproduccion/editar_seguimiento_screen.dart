import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/animal.dart';
import '../../models/reproduccion/seguimiento_gestacion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/reproduccion/reproduccion_repository.dart';
import '../../theme/app_theme.dart';

/// Edición de un seguimiento ya existente (2026-10-21, nuevo a pedido de la
/// Parte 1): a diferencia de "Nuevo Evento" (SeguimientoFormScreen), aquí la
/// Madre ya quedó fija desde que se creó el registro -- solo se pueden tocar
/// los mismos campos que ya permitía `ActualizarSeguimientoDTO` en el
/// backend (tipo, fecha de inseminación, padre y notas). Solo aplica a
/// registros que NO estén cerrados (Parida/Abortada/Fallida) ni eliminados
/// -- el backend ya lo rechaza de todas formas, esta pantalla simplemente
/// no debe abrirse en esos casos (ver SeguimientoDetalleScreen).
///
/// Mismo mapa de días de gestación que SeguimientoFormScreen/el backend --
/// se usa para recalcular fecha_estimada_parto cuando cambia la fecha de
/// inseminación y la especie es Bovino/Cerdo (igual que al crear). Si la
/// especie no está en el mapa, no se toca fecha_estimada_parto (se deja el
/// valor que ya tenía).
const _diasGestacionPorEspecie = {'bovino': 283, 'cerdo': 114};

class EditarSeguimientoScreen extends StatefulWidget {
  final ReproduccionRepository repository;
  final AnimalRepository animalRepository;
  final SeguimientoGestacion registro;

  const EditarSeguimientoScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    required this.registro,
  });

  @override
  State<EditarSeguimientoScreen> createState() =>
      _EditarSeguimientoScreenState();
}

class _EditarSeguimientoScreenState extends State<EditarSeguimientoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notasCtrl = TextEditingController();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  late String? _tipo;
  late DateTime _fechaInseminacion;
  // null = "mantener el padre actual, no se manda macho_id" -- ver nota en
  // el DropdownButtonFormField más abajo.
  int? _nuevoMachoId;

  List<Animal> _machosDisponibles = [];
  bool _cargandoMachos = true;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tipo = widget.registro.tipo;
    _fechaInseminacion = widget.registro.fechaInseminacion;
    _notasCtrl.text = widget.registro.notas ?? '';
    _cargarMachos();
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarMachos() async {
    try {
      final pagina = await widget.animalRepository
          .listar(genero: 'Macho', estado: 'Activo', limite: 200);
      final especieMadre = widget.registro.animal?.especieNombre;
      setState(() {
        _machosDisponibles = especieMadre == null
            ? pagina.data
            : pagina.data
                .where((m) => m.especie?.nombre == especieMadre)
                .toList();
      });
    } catch (_) {
      // No es crítico: si falla, el usuario simplemente no puede cambiar
      // de padre en esta edición (sigue pudiendo editar el resto).
    } finally {
      if (mounted) setState(() => _cargandoMachos = false);
    }
  }

  Future<void> _elegirFechaInseminacion() async {
    final resultado = await showDatePicker(
      context: context,
      initialDate: _fechaInseminacion,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (resultado != null) setState(() => _fechaInseminacion = resultado);
  }

  DateTime? get _fechaEstimadaPartoRecalculada {
    final especie = widget.registro.animal?.especieNombre?.trim().toLowerCase();
    final dias = especie == null ? null : _diasGestacionPorEspecie[especie];
    if (dias == null) return null;
    return _fechaInseminacion.add(Duration(days: dias));
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.repository.actualizar(
        widget.registro.id,
        ActualizarSeguimientoDTO(
          tipo: _tipo,
          fechaInseminacion: _fechaInseminacion,
          fechaEstimadaParto: _fechaEstimadaPartoRecalculada,
          machoId: _nuevoMachoId,
          notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.registro;
    return Scaffold(
      appBar: AppBar(title: const Text('Editar seguimiento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppTheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Madre: ${r.animal?.nombreVisible ?? "Animal #${r.animalId}"}'
                    '${r.animal?.especieNombre != null ? " (${r.animal!.especieNombre})" : ""}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'No se puede cambiar -- quedó fija desde que se creó el registro.',
                    style: TextStyle(fontSize: 12, color: AppTheme.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: tiposMontaValidos
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _tipo = v),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Fecha de inseminación'),
                  subtitle: Text(_dateFormat.format(_fechaInseminacion)),
                  trailing: const Icon(Icons.calendar_today, size: 20),
                  onTap: _elegirFechaInseminacion,
                ),
                if (_fechaEstimadaPartoRecalculada != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Nueva fecha estimada de parto: '
                      '${_dateFormat.format(_fechaEstimadaPartoRecalculada!)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.outline),
                    ),
                  ),
                const SizedBox(height: 8),
                if (_cargandoMachos)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else
                  DropdownButtonFormField<int?>(
                    value: _nuevoMachoId,
                    decoration: const InputDecoration(labelText: 'Padre'),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'Mantener actual (${r.macho?.nombreVisible ?? "Ninguno"})',
                        ),
                      ),
                      for (final m in _machosDisponibles)
                        DropdownMenuItem<int?>(
                          value: m.id,
                          child: Text(m.nombreVisible),
                        ),
                    ],
                    onChanged: (v) => setState(() => _nuevoMachoId = v),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notasCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
