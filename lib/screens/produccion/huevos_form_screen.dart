import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/produccion/produccion_huevos.dart';
import '../../repositories/produccion/produccion_repository.dart';

class HuevosFormScreen extends StatefulWidget {
  final ProduccionRepository repository;
  final ProduccionHuevos? registroExistente;

  const HuevosFormScreen({super.key, required this.repository, this.registroExistente});

  @override
  State<HuevosFormScreen> createState() => _HuevosFormScreenState();
}

class _HuevosFormScreenState extends State<HuevosFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadCtrl = TextEditingController();
  final _loteIdCtrl = TextEditingController();

  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.registroExistente != null;

  @override
  void initState() {
    super.initState();
    final actual = widget.registroExistente;
    if (actual != null) {
      _cantidadCtrl.text = actual.cantidad.toString();
      if (actual.loteId != null) _loteIdCtrl.text = actual.loteId.toString();
    }
  }

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _loteIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final cantidad = int.parse(_cantidadCtrl.text.trim());
      final loteId = _loteIdCtrl.text.trim().isEmpty ? null : int.tryParse(_loteIdCtrl.text.trim());

      if (_esEdicion) {
        await widget.repository.actualizarHuevos(
          widget.registroExistente!.id,
          ActualizarProduccionHuevosDTO(cantidad: cantidad),
        );
      } else {
        await widget.repository.crearHuevos(
          CrearProduccionHuevosDTO(cantidad: cantidad, loteId: loteId),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar recolección' : 'Registrar recolección')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _cantidadCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad de huevos', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa la cantidad';
                  if (int.tryParse(v.trim()) == null) return 'Debe ser un número entero';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _loteIdCtrl,
                keyboardType: TextInputType.number,
                enabled: !_esEdicion,
                decoration: const InputDecoration(
                  labelText: 'ID de lote (opcional)',
                  helperText: 'Déjalo vacío si no aplica',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_esEdicion ? 'Guardar cambios' : 'Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
