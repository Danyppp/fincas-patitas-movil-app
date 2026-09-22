import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/animal.dart';
import '../../models/catalogo/especie.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';
import '../../models/catalogo/raza.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';

/// Formulario único para crear/editar un animal, contra el
/// `AnimalRepository`/`CatalogoRepository` reales (especie/raza/lote/
/// potrero vienen del backend, no son enums locales). Madre/Padre se
/// seleccionan de la lista real de animales (Hembra/Macho respectivamente),
/// excluyendo al propio animal cuando se está editando.
///
/// Nota: no se pide "causa" al cambiar el estado a Muerto/Vendido — la
/// tabla `animales` real no tiene ninguna columna para guardarla, así
/// que se decidió no exigirla por ahora (ver
/// decisiones-diseno-vs-backend-animales.md).
class AnimalFormScreen extends StatefulWidget {
  final AnimalRepository repository;
  final CatalogoRepository catalogoRepository;
  final Animal? animalExistente;

  const AnimalFormScreen({
    super.key,
    required this.repository,
    required this.catalogoRepository,
    this.animalExistente,
  });

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _origenCtrl = TextEditingController();

  List<Especie> _especies = [];
  List<Raza> _razas = [];
  List<LoteAnimal> _lotes = [];
  List<Potrero> _potreros = [];
  List<Animal> _hembras = [];
  List<Animal> _machos = [];

  Especie? _especieSeleccionada;
  Raza? _razaSeleccionada;
  LoteAnimal? _loteSeleccionado;
  Potrero? _potreroSeleccionado;
  Animal? _madreSeleccionada;
  Animal? _padreSeleccionado;
  String _genero = 'Hembra';
  String _estado = 'Activo';
  DateTime? _fechaNacimiento;
  DateTime? _fechaIngreso;

  bool _cargandoCatalogos = true;
  bool _guardando = false;
  String? _error;

  static const _estadosValidos = ['Activo', 'Vendido', 'Muerto', 'Inactivo'];

  bool get _esEdicion => widget.animalExistente != null;

  @override
  void initState() {
    super.initState();
    final actual = widget.animalExistente;
    if (actual != null) {
      _codigoCtrl.text = actual.codigo;
      _nombreCtrl.text = actual.nombre ?? '';
      _origenCtrl.text = actual.origen ?? '';
      _genero = actual.genero;
      _estado = actual.estado;
      _fechaNacimiento = actual.fechaNacimiento;
      _fechaIngreso = actual.fechaIngreso;
    } else {
      _fechaIngreso = DateTime.now();
    }
    _cargarCatalogos();
  }

  /// Cada catálogo se carga por separado y con su propio try/catch: si uno
  /// falla (p. ej. un endpoint que no responde), los demás igual se
  /// muestran normalmente en vez de dejar todo el formulario vacío.
  Future<List<T>> _cargarCatalogoSeguro<T>(
    Future<List<T>> Function() cargar,
    String nombre,
    List<String> erroresAcumulados,
  ) async {
    try {
      return await cargar();
    } catch (e) {
      erroresAcumulados.add('$nombre: $e');
      return <T>[];
    }
  }

  Future<void> _cargarCatalogos() async {
    final errores = <String>[];
    final actual = widget.animalExistente;

    final especies = await _cargarCatalogoSeguro(
      widget.catalogoRepository.listarEspecies,
      'Especies',
      errores,
    );
    final lotes = await _cargarCatalogoSeguro(
      widget.catalogoRepository.listarLotes,
      'Lotes',
      errores,
    );
    final potreros = await _cargarCatalogoSeguro(
      widget.catalogoRepository.listarPotreros,
      'Potreros',
      errores,
    );
    List<Animal> hembras = [];
    List<Animal> machos = [];
    try {
      final pagina = await widget.repository.listar(genero: 'Hembra', estado: 'Todos', limite: 200);
      hembras = pagina.data.where((a) => actual == null || a.id != actual.id).toList();
    } catch (e) {
      errores.add('Animales (Madre): $e');
    }
    try {
      final pagina = await widget.repository.listar(genero: 'Macho', estado: 'Todos', limite: 200);
      machos = pagina.data.where((a) => actual == null || a.id != actual.id).toList();
    } catch (e) {
      errores.add('Animales (Padre): $e');
    }

    setState(() {
      _especies = especies;
      _lotes = lotes;
      _potreros = potreros;
      _hembras = hembras;
      _machos = machos;

      if (actual != null) {
        _especieSeleccionada = _buscarEnLista(_especies, actual.especieId, (e) => e.id);
        _loteSeleccionado = actual.loteId == null
            ? null
            : _buscarEnLista(_lotes, actual.loteId!, (l) => l.id);
        _potreroSeleccionado = actual.potreroId == null
            ? null
            : _buscarEnLista(_potreros, actual.potreroId!, (p) => p.id);
        _madreSeleccionada = actual.madreId == null
            ? null
            : _buscarEnLista(_hembras, actual.madreId!, (a) => a.id);
        _padreSeleccionado = actual.padreId == null
            ? null
            : _buscarEnLista(_machos, actual.padreId!, (a) => a.id);
      }

      _error = errores.isEmpty ? null : 'No se pudieron cargar: ${errores.join(' | ')}';
    });

    try {
      if (_especieSeleccionada != null) {
        await _cargarRazas(_especieSeleccionada!.id, preseleccionar: true);
      }
    } catch (e) {
      setState(() => _error = (_error == null ? '' : '$_error | ') + 'Razas: $e');
    } finally {
      if (mounted) setState(() => _cargandoCatalogos = false);
    }
  }

  T? _buscarEnLista<T>(List<T> lista, int id, int Function(T) idDe) {
    try {
      return lista.firstWhere((item) => idDe(item) == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cargarRazas(int especieId, {bool preseleccionar = false}) async {
    try {
      final razas = await widget.catalogoRepository.listarRazas(especieId: especieId);
      setState(() {
        _razas = razas;
        if (preseleccionar && widget.animalExistente != null) {
          final actual = widget.animalExistente!;
          _razaSeleccionada = _buscarEnLista(_razas, actual.razaId, (r) => r.id);
        } else {
          _razaSeleccionada = null;
        }
      });
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar las razas: $e');
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _origenCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha({
    required DateTime? actual,
    required void Function(DateTime) onSeleccionar,
  }) async {
    final resultado = await showDatePicker(
      context: context,
      initialDate: actual ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
    if (resultado != null) setState(() => onSeleccionar(resultado));
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_especieSeleccionada == null) {
      setState(() => _error = 'Selecciona la especie');
      return;
    }
    if (_razaSeleccionada == null) {
      setState(() => _error = 'Selecciona la raza');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_esEdicion) {
        await widget.repository.actualizar(
          widget.animalExistente!.id,
          ActualizarAnimalDTO(
            nombre: _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
            genero: _genero,
            especieId: _especieSeleccionada!.id,
            razaId: _razaSeleccionada!.id,
            fechaNacimiento: _fechaNacimiento,
            origen: _origenCtrl.text.trim().isEmpty ? null : _origenCtrl.text.trim(),
            fechaIngreso: _fechaIngreso,
            estado: _estado,
            loteId: _loteSeleccionado?.id,
            potreroId: _potreroSeleccionado?.id,
            madreId: _madreSeleccionada?.id,
            padreId: _padreSeleccionado?.id,
          ),
        );
      } else {
        await widget.repository.crear(
          CrearAnimalDTO(
            genero: _genero,
            especieId: _especieSeleccionada!.id,
            razaId: _razaSeleccionada!.id,
            nombre: _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
            fechaNacimiento: _fechaNacimiento,
            origen: _origenCtrl.text.trim().isEmpty ? null : _origenCtrl.text.trim(),
            fechaIngreso: _fechaIngreso,
            estado: _estado,
            loteId: _loteSeleccionado?.id,
            potreroId: _potreroSeleccionado?.id,
            madreId: _madreSeleccionada?.id,
            padreId: _padreSeleccionado?.id,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_esEdicion ? 'Editar animal' : 'Nuevo animal')),
      body: _cargandoCatalogos
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_esEdicion)
                      TextFormField(
                        controller: _codigoCtrl,
                        enabled: false,
                        decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder()),
                      ),
                    if (_esEdicion) const SizedBox(height: 16),
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre (opcional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Hembra', label: Text('Hembra'), icon: Icon(Icons.female)),
                        ButtonSegment(value: 'Macho', label: Text('Macho'), icon: Icon(Icons.male)),
                      ],
                      selected: {_genero},
                      onSelectionChanged: (s) => setState(() => _genero = s.first),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Especie>(
                      initialValue: _especieSeleccionada,
                      decoration: const InputDecoration(labelText: 'Especie', border: OutlineInputBorder()),
                      items: _especies
                          .map((e) => DropdownMenuItem(value: e, child: Text(e.nombre)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _especieSeleccionada = v;
                          _razaSeleccionada = null;
                          _razas = [];
                        });
                        if (v != null) _cargarRazas(v.id);
                      },
                      validator: (v) => v == null ? 'Selecciona una especie' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Raza>(
                      initialValue: _razaSeleccionada,
                      decoration: const InputDecoration(labelText: 'Raza', border: OutlineInputBorder()),
                      items: _razas
                          .map((r) => DropdownMenuItem(value: r, child: Text(r.nombre)))
                          .toList(),
                      onChanged: _especieSeleccionada == null
                          ? null
                          : (v) => setState(() => _razaSeleccionada = v),
                      validator: (v) => v == null ? 'Selecciona una raza' : null,
                    ),
                    const SizedBox(height: 16),
                    _SelectorFecha(
                      etiqueta: 'Fecha de nacimiento (opcional)',
                      fecha: _fechaNacimiento,
                      onTap: () => _elegirFecha(
                        actual: _fechaNacimiento,
                        onSeleccionar: (f) => _fechaNacimiento = f,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SelectorFecha(
                      etiqueta: 'Fecha de ingreso',
                      fecha: _fechaIngreso,
                      onTap: () => _elegirFecha(
                        actual: _fechaIngreso,
                        onSeleccionar: (f) => _fechaIngreso = f,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _origenCtrl,
                      decoration: const InputDecoration(labelText: 'Origen (opcional)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Ubicación (opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LoteAnimal?>(
                      initialValue: _loteSeleccionado,
                      decoration: const InputDecoration(labelText: 'Lote', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<LoteAnimal?>(value: null, child: Text('Sin asignar')),
                        ..._lotes.map((l) => DropdownMenuItem<LoteAnimal?>(value: l, child: Text(l.nombre))),
                      ],
                      onChanged: (v) => setState(() => _loteSeleccionado = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Potrero?>(
                      initialValue: _potreroSeleccionado,
                      decoration: const InputDecoration(labelText: 'Potrero', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<Potrero?>(value: null, child: Text('Sin asignar')),
                        ..._potreros.map((p) => DropdownMenuItem<Potrero?>(value: p, child: Text(p.nombre))),
                      ],
                      onChanged: (v) => setState(() => _potreroSeleccionado = v),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Genealogía (opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Animal?>(
                      initialValue: _madreSeleccionada,
                      decoration: const InputDecoration(labelText: 'Madre', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<Animal?>(value: null, child: Text('Sin especificar')),
                        ..._hembras.map((a) => DropdownMenuItem<Animal?>(value: a, child: Text('${a.nombreVisible} (${a.codigo})'))),
                      ],
                      onChanged: (v) => setState(() => _madreSeleccionada = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Animal?>(
                      initialValue: _padreSeleccionado,
                      decoration: const InputDecoration(labelText: 'Padre', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<Animal?>(value: null, child: Text('Sin especificar')),
                        ..._machos.map((a) => DropdownMenuItem<Animal?>(value: a, child: Text('${a.nombreVisible} (${a.codigo})'))),
                      ],
                      onChanged: (v) => setState(() => _padreSeleccionado = v),
                    ),
                    if (_esEdicion) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _estado,
                        decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
                        items: _estadosValidos
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _estado = v ?? 'Activo'),
                      ),
                    ],
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
                          : Text(_esEdicion ? 'Guardar cambios' : 'Crear animal'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SelectorFecha extends StatelessWidget {
  final String etiqueta;
  final DateTime? fecha;
  final VoidCallback onTap;

  const _SelectorFecha({
    required this.etiqueta,
    required this.fecha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: etiqueta, border: const OutlineInputBorder()),
        child: Text(fecha != null
            ? '${fecha!.year.toString().padLeft(4, '0')}-${fecha!.month.toString().padLeft(2, '0')}-${fecha!.day.toString().padLeft(2, '0')}'
            : 'Sin definir'),
      ),
    );
  }
}
