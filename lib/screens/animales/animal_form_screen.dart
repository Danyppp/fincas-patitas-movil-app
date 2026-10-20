import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/animal.dart';
import '../../models/catalogo/especie.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';
import '../../models/catalogo/raza.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/especie_visual.dart';

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

  // Reproducción (2026-10-15, corregido 2026-10-20): al cerrar un parto, la
  // cría nace con su madre/padre, especie, raza y fecha de nacimiento ya
  // conocidos -- nada de eso es editable ni opcional. Cuando
  // `bloquearGenealogia` es true:
  // - Especie/Madre/Padre quedan fijos y de solo lectura.
  // - Raza solo deja elegir entre la de la Madre y la del Padre (nunca
  //   cualquier raza del catálogo).
  // - Fecha de nacimiento queda fija a `fechaNacimientoPreseleccionada`
  //   (la fecha real del parto que se confirmó al cerrar el seguimiento).
  // - Fecha de ingreso nace vacía (un recién nacido no "ingresa" a la
  //   finca hasta que se le apliquen las vacunas de primeros días).
  // - Origen nace con "Nacido en finca" como sugerencia, pero sigue siendo
  //   editable.
  final Animal? madrePreseleccionada;
  final Animal? padrePreseleccionado;
  final bool bloquearGenealogia;
  final DateTime? fechaNacimientoPreseleccionada;

  const AnimalFormScreen({
    super.key,
    required this.repository,
    required this.catalogoRepository,
    this.animalExistente,
    this.madrePreseleccionada,
    this.padrePreseleccionado,
    this.bloquearGenealogia = false,
    this.fechaNacimientoPreseleccionada,
  }) : assert(
          !bloquearGenealogia || madrePreseleccionada != null,
          'bloquearGenealogia requiere madrePreseleccionada',
        );

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

  /// Razas permitidas cuando `bloquearGenealogia` es true: solo la de la
  /// Madre y la del Padre (si la tiene y es distinta). Si por algún motivo
  /// ninguna de las dos viene cargada, se cae de vuelta al catálogo
  /// completo de la especie para no dejar el formulario sin opciones.
  List<Raza> get _razasSeleccionables {
    if (!widget.bloquearGenealogia) return _razas;
    final porId = <int, Raza>{};
    final razaMadre = widget.madrePreseleccionada?.raza;
    final razaPadre = widget.padrePreseleccionado?.raza;
    if (razaMadre != null) porId[razaMadre.id] = razaMadre;
    if (razaPadre != null) porId[razaPadre.id] = razaPadre;
    return porId.isEmpty ? _razas : porId.values.toList();
  }

  /// Raza por defecto para el dropdown en modo `bloquearGenealogia`.
  ///
  /// OJO: hay que devolver la MISMA instancia de `Raza` que aparece dentro
  /// de `_razasSeleccionables` (y no, por ejemplo,
  /// `widget.madrePreseleccionada?.raza` directamente), porque
  /// `DropdownButtonFormField` compara su `value` contra los `items` por
  /// identidad de objeto. Cuando Madre y Padre comparten la misma raza
  /// (p. ej. ambos Duroc), `_razasSeleccionables` deduplica por id y se
  /// queda con la instancia del Padre -- si acá devolvíamos la instancia de
  /// la Madre, el dropdown no encontraba ninguna coincidencia y Flutter
  /// lanzaba el assertion error "zero or 2 or more... detected".
  /// Verdadero cuando la genealogía (Especie / Raza / Fecha de nacimiento /
  /// Madre / Padre) debe quedar bloqueada: o bien se está registrando una
  /// cría recién nacida (`widget.bloquearGenealogia`, viene de "Registrar
  /// Seguimiento"), o bien se está EDITANDO un animal que ya tiene madre
  /// registrada -- es decir, nació por este mismo flujo de Reproducción (o
  /// con genealogía cargada manualmente). En ambos casos, dejar cambiar la
  /// especie o los padres después de creado rompería la consistencia con
  /// el registro de parto/genealogía ya guardado.
  ///
  /// 2026-10-20, a pedido explícito: "no me gustaría que el animal se
  /// registre como Cerdo/Vaca y luego desde 'editar animal' se cambie a
  /// Gallina" -- antes esto solo se bloqueaba al CREAR la cría, no al
  /// editarla después.
  bool get _bloquearGenealogiaEfectivo =>
      widget.bloquearGenealogia ||
      (_esEdicion && widget.animalExistente!.madreId != null);

  /// La Raza, a diferencia de Especie/Fecha de nacimiento/Madre/Padre, SÍ
  /// se deja elegir (entre la de la Madre y la del Padre) mientras se está
  /// CREANDO la cría -- por si el cruce es de dos razas distintas. Pero una
  /// vez creada, al editarla, también queda bloqueada (ya no tiene sentido
  /// seguir "decidiendo" la raza de un animal que ya nació).
  bool get _razaBloqueada => _bloquearGenealogiaEfectivo && _esEdicion;

  Raza? get _razaPorDefecto {
    final disponibles = _razasSeleccionables;
    if (disponibles.isEmpty) return null;
    final razaMadreId = widget.madrePreseleccionada?.raza?.id;
    if (razaMadreId != null) {
      for (final r in disponibles) {
        if (r.id == razaMadreId) return r;
      }
    }
    return disponibles.first;
  }

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
    } else if (widget.bloquearGenealogia) {
      // Registro de cría: fecha de nacimiento = fecha real del parto (fija,
      // no editable); fecha de ingreso nace vacía; origen sugiere "Nacido
      // en finca" pero se puede cambiar.
      _fechaNacimiento = widget.fechaNacimientoPreseleccionada;
      _fechaIngreso = null;
      _origenCtrl.text = 'Nacido en finca';
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

    setState(() {
      _especies = especies;
      _lotes = lotes;
      _potreros = potreros;

      if (actual != null) {
        _especieSeleccionada =
            _buscarEnLista(_especies, actual.especieId, (e) => e.id);
        _loteSeleccionado = actual.loteId == null
            ? null
            : _buscarEnLista(_lotes, actual.loteId!, (l) => l.id);
        _potreroSeleccionado = actual.potreroId == null
            ? null
            : _buscarEnLista(_potreros, actual.potreroId!, (p) => p.id);
      } else if (widget.bloquearGenealogia) {
        // Registro de cría: la especie se fija a la de la madre, nunca se
        // deja elegir otra (una cría no puede ser de otra especie).
        _especieSeleccionada = _buscarEnLista(
            _especies, widget.madrePreseleccionada!.especieId, (e) => e.id);
      }

      _error = errores.isEmpty
          ? null
          : 'No se pudieron cargar: ${errores.join(' | ')}';
    });

    try {
      if (_especieSeleccionada != null) {
        await _cargarRazas(_especieSeleccionada!.id, preseleccionar: true);
        // Madre/Padre solo tiene sentido dentro de la MISMA especie (una
        // gallina no puede ser hija de una vaca) — se cargan filtrados por
        // especie, igual que las razas.
        await _cargarGenealogia(_especieSeleccionada!.id, preseleccionar: true);
        if (widget.bloquearGenealogia && mounted) {
          // Fuerza madre/padre a los valores del parto que se está
          // cerrando, sin importar lo que haya resuelto _cargarGenealogia
          // (que no los conoce porque no vienen de un `animalExistente`).
          setState(() {
            _madreSeleccionada = widget.madrePreseleccionada;
            _padreSeleccionado = widget.padrePreseleccionado;
            // La raza por defecto es la de la Madre (si la tiene); el
            // usuario puede cambiarla a la del Padre si corresponde. Debe
            // ser la MISMA instancia que aparece en _razasSeleccionables
            // (ver comentario en _razaPorDefecto).
            _razaSeleccionada = _razaPorDefecto;
          });
        }
      }
    } catch (e) {
      setState(
          () => _error = (_error == null ? '' : '$_error | ') + 'Razas: $e');
    } finally {
      if (mounted) setState(() => _cargandoCatalogos = false);
    }
  }

  /// Carga las listas de posibles Madre (Hembra) y Padre (Macho) para el
  /// selector de Genealogía, filtradas por especie: un animal solo puede
  /// tener madre/padre de su misma especie. Se recarga cada vez que cambia
  /// la Especie seleccionada en el formulario (igual que las razas).
  Future<void> _cargarGenealogia(int especieId,
      {bool preseleccionar = false}) async {
    final actual = widget.animalExistente;
    final errores = <String>[];
    List<Animal> hembras = [];
    List<Animal> machos = [];
    try {
      final pagina = await widget.repository.listar(
        genero: 'Hembra',
        estado: 'Todos',
        especieId: especieId,
        limite: 200,
      );
      hembras = pagina.data
          .where((a) => actual == null || a.id != actual.id)
          .toList();
    } catch (e) {
      errores.add('Animales (Madre): $e');
    }
    try {
      final pagina = await widget.repository.listar(
        genero: 'Macho',
        estado: 'Todos',
        especieId: especieId,
        limite: 200,
      );
      machos = pagina.data
          .where((a) => actual == null || a.id != actual.id)
          .toList();
    } catch (e) {
      errores.add('Animales (Padre): $e');
    }

    if (!mounted) return;
    setState(() {
      _hembras = hembras;
      _machos = machos;

      if (preseleccionar && actual != null) {
        _madreSeleccionada = actual.madreId == null
            ? null
            : _buscarEnLista(_hembras, actual.madreId!, (a) => a.id);
        _padreSeleccionado = actual.padreId == null
            ? null
            : _buscarEnLista(_machos, actual.padreId!, (a) => a.id);
      } else if (!widget.bloquearGenealogia) {
        // Cambio manual de especie: si la madre/padre ya elegida ya no
        // pertenece a la nueva especie, se limpia la selección. (En modo
        // bloqueado esto nunca aplica -- la especie no se puede cambiar.)
        if (_madreSeleccionada != null &&
            !_hembras.any((a) => a.id == _madreSeleccionada!.id)) {
          _madreSeleccionada = null;
        }
        if (_padreSeleccionado != null &&
            !_machos.any((a) => a.id == _padreSeleccionado!.id)) {
          _padreSeleccionado = null;
        }
      }

      if (errores.isNotEmpty) {
        _error = (_error == null ? '' : '$_error | ') + errores.join(' | ');
      }
    });
  }

  T? _buscarEnLista<T>(List<T> lista, int id, int Function(T) idDe) {
    try {
      return lista.firstWhere((item) => idDe(item) == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cargarRazas(int especieId,
      {bool preseleccionar = false}) async {
    try {
      final razas =
          await widget.catalogoRepository.listarRazas(especieId: especieId);
      setState(() {
        _razas = razas;
        if (preseleccionar && widget.animalExistente != null) {
          final actual = widget.animalExistente!;
          _razaSeleccionada =
              _buscarEnLista(_razas, actual.razaId, (r) => r.id);
        } else if (!widget.bloquearGenealogia) {
          _razaSeleccionada = null;
        }
      });
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar las razas: $e');
    }
  }

  /// Selección de especie desde las tarjetas grandes (reemplaza al antiguo
  /// dropdown). Recarga razas y genealogía igual que antes. No hace nada en
  /// modo `bloquearGenealogia`: la especie viene fija de la madre.
  void _seleccionarEspecie(Especie especie) {
    if (_bloquearGenealogiaEfectivo) return;
    if (_especieSeleccionada?.id == especie.id) return;
    setState(() {
      _especieSeleccionada = especie;
      _razaSeleccionada = null;
      _razas = [];
      _madreSeleccionada = null;
      _padreSeleccionado = null;
      _hembras = [];
      _machos = [];
    });
    _cargarRazas(especie.id);
    _cargarGenealogia(especie.id);
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
            nombre: _nombreCtrl.text.trim().isEmpty
                ? null
                : _nombreCtrl.text.trim(),
            genero: _genero,
            especieId: _especieSeleccionada!.id,
            razaId: _razaSeleccionada!.id,
            fechaNacimiento: _fechaNacimiento,
            origen: _origenCtrl.text.trim().isEmpty
                ? null
                : _origenCtrl.text.trim(),
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
            nombre: _nombreCtrl.text.trim().isEmpty
                ? null
                : _nombreCtrl.text.trim(),
            fechaNacimiento: _fechaNacimiento,
            origen: _origenCtrl.text.trim().isEmpty
                ? null
                : _origenCtrl.text.trim(),
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

  Widget _seccion(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    String? subtitulo,
    required List<Widget> children,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icono, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(titulo, style: textTheme.headlineSmall),
              ],
            ),
            if (subtitulo != null)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text(subtitulo, style: textTheme.bodySmall),
              ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Tarjeta de especie. En modo `bloquearGenealogia` (registro de cría) se
  /// siguen mostrando TODAS las tarjetas (en vez de reemplazarlas por un
  /// campo de texto bloqueado), pero las que no son la especie de la Madre
  /// aparecen en gris y no son tocables -- una cría no puede ser de otra
  /// especie, y así queda visualmente claro por qué (2026-10-20, a pedido:
  /// antes esta sección se reemplazaba por un campo bloqueado "Especie:
  /// Cerdo" sin mostrar las demás opciones).
  Widget _tarjetaEspecie(Especie especie) {
    final seleccionada = _especieSeleccionada?.id == especie.id;
    final deshabilitada = _bloquearGenealogiaEfectivo && !seleccionada;
    return GestureDetector(
      onTap: deshabilitada ? null : () => _seleccionarEspecie(especie),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: seleccionada
              ? AppTheme.primaryContainer
              : (deshabilitada ? AppTheme.surfaceContainerHigh : Colors.white),
          borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
          border: Border.all(
            color: seleccionada
                ? AppTheme.primaryContainer
                : AppTheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Opacity(
          opacity: deshabilitada ? 0.45 : 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emojiEspecie(especie.nombre),
                  style: const TextStyle(fontSize: 26, height: 1)),
              const SizedBox(height: 4),
              Text(
                especie.nombre,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.1,
                  color: seleccionada ? Colors.white : AppTheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Campo de solo lectura genérico -- usado para Especie/Madre/Padre
  /// (genealogía bloqueada) y ahora también para la Fecha de nacimiento
  /// cuando viene fija del parto.
  Widget _campoBloqueado({
    required String etiqueta,
    required String valor,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: etiqueta,
        filled: true,
        fillColor: AppTheme.surfaceContainerHigh,
      ),
      child: Text(valor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _esEdicion
        ? 'Editar animal'
        : (widget.bloquearGenealogia ? 'Registrar cría' : 'Nuevo animal');
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: _cargandoCatalogos
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // -- Datos principales --
                    _seccion(
                      context,
                      icono: Icons.pets,
                      titulo: 'Datos principales',
                      children: [
                        if (_esEdicion) ...[
                          TextFormField(
                            controller: _codigoCtrl,
                            enabled: false,
                            decoration:
                                const InputDecoration(labelText: 'Código'),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text('Especie',
                            style: Theme.of(context).textTheme.labelMedium),
                        if (_bloquearGenealogiaEfectivo)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.bloquearGenealogia
                                  ? 'Fija por la Madre -- las demás aparecen en gris'
                                  : 'No editable -- genealogía ya registrada',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 96,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _especies.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, i) =>
                                _tarjetaEspecie(_especies[i]),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nombreCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Nombre (opcional)'),
                        ),
                        const SizedBox(height: 16),
                        if (_razaBloqueada)
                          _campoBloqueado(
                            etiqueta: 'Raza',
                            valor: _razaSeleccionada?.nombre ?? '—',
                          )
                        else
                          DropdownButtonFormField<Raza>(
                            initialValue: _razaSeleccionada,
                            decoration:
                                const InputDecoration(labelText: 'Raza'),
                            items: _razasSeleccionables
                                .map((r) => DropdownMenuItem(
                                    value: r, child: Text(r.nombre)))
                                .toList(),
                            onChanged: _especieSeleccionada == null
                                ? null
                                : (v) => setState(() => _razaSeleccionada = v),
                            validator: (v) =>
                                v == null ? 'Selecciona una raza' : null,
                          ),
                        const SizedBox(height: 16),
                        SegmentedButton<String>(
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppTheme.primaryContainer,
                            selectedForegroundColor: Colors.white,
                          ),
                          segments: const [
                            ButtonSegment(
                                value: 'Hembra',
                                label: Text('Hembra'),
                                icon: Icon(Icons.female)),
                            ButtonSegment(
                                value: 'Macho',
                                label: Text('Macho'),
                                icon: Icon(Icons.male)),
                          ],
                          selected: {_genero},
                          onSelectionChanged: (s) =>
                              setState(() => _genero = s.first),
                        ),
                        const SizedBox(height: 16),
                        if (_bloquearGenealogiaEfectivo)
                          _campoBloqueado(
                            etiqueta: 'Fecha de nacimiento',
                            valor: _fechaNacimiento != null
                                ? '${_fechaNacimiento!.year.toString().padLeft(4, '0')}-${_fechaNacimiento!.month.toString().padLeft(2, '0')}-${_fechaNacimiento!.day.toString().padLeft(2, '0')}'
                                : 'Sin definir',
                          )
                        else
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
                          etiqueta: widget.bloquearGenealogia
                              ? 'Fecha de ingreso (opcional)'
                              : 'Fecha de ingreso',
                          fecha: _fechaIngreso,
                          onTap: () => _elegirFecha(
                            actual: _fechaIngreso,
                            onSeleccionar: (f) => _fechaIngreso = f,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _origenCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Origen (opcional)'),
                        ),
                        if (_esEdicion) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _estado,
                            decoration:
                                const InputDecoration(labelText: 'Estado'),
                            items: _estadosValidos
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _estado = v ?? 'Activo'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // -- Ubicación --
                    _seccion(
                      context,
                      icono: Icons.map_outlined,
                      titulo: 'Lote o potrero',
                      subtitulo: 'Opcional',
                      children: [
                        DropdownButtonFormField<LoteAnimal?>(
                          initialValue: _loteSeleccionado,
                          decoration: const InputDecoration(labelText: 'Lote'),
                          items: [
                            const DropdownMenuItem<LoteAnimal?>(
                                value: null, child: Text('Sin asignar')),
                            ..._lotes.map((l) => DropdownMenuItem<LoteAnimal?>(
                                value: l, child: Text(l.nombre))),
                          ],
                          onChanged: (v) =>
                              setState(() => _loteSeleccionado = v),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Potrero?>(
                          initialValue: _potreroSeleccionado,
                          decoration:
                              const InputDecoration(labelText: 'Potrero'),
                          items: [
                            const DropdownMenuItem<Potrero?>(
                                value: null, child: Text('Sin asignar')),
                            ..._potreros.map((p) => DropdownMenuItem<Potrero?>(
                                value: p, child: Text(p.nombre))),
                          ],
                          onChanged: (v) =>
                              setState(() => _potreroSeleccionado = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // -- Genealogía --
                    _seccion(
                      context,
                      icono: Icons.account_tree_outlined,
                      titulo: 'Origen y genealogía',
                      subtitulo: !_bloquearGenealogiaEfectivo
                          ? (_especieSeleccionada == null
                              ? 'Selecciona una especie primero'
                              : 'Opcional')
                          : (widget.bloquearGenealogia
                              ? 'Tomados del registro de parto'
                              : 'No editable -- genealogía ya registrada'),
                      children: _bloquearGenealogiaEfectivo
                          ? [
                              _campoBloqueado(
                                etiqueta: 'Madre',
                                valor: _madreSeleccionada != null
                                    ? '${_madreSeleccionada!.nombreVisible} (${_madreSeleccionada!.codigo})'
                                    : 'Sin especificar',
                              ),
                              const SizedBox(height: 16),
                              _campoBloqueado(
                                etiqueta: 'Padre',
                                valor: _padreSeleccionado != null
                                    ? '${_padreSeleccionado!.nombreVisible} (${_padreSeleccionado!.codigo})'
                                    : 'Sin especificar',
                              ),
                            ]
                          : [
                              DropdownButtonFormField<Animal?>(
                                initialValue: _madreSeleccionada,
                                decoration:
                                    const InputDecoration(labelText: 'Madre'),
                                items: [
                                  const DropdownMenuItem<Animal?>(
                                      value: null,
                                      child: Text('Sin especificar')),
                                  ..._hembras.map((a) => DropdownMenuItem<
                                          Animal?>(
                                      value: a,
                                      child: Text(
                                          '${a.nombreVisible} (${a.codigo})'))),
                                ],
                                onChanged: _especieSeleccionada == null
                                    ? null
                                    : (v) =>
                                        setState(() => _madreSeleccionada = v),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<Animal?>(
                                initialValue: _padreSeleccionado,
                                decoration:
                                    const InputDecoration(labelText: 'Padre'),
                                items: [
                                  const DropdownMenuItem<Animal?>(
                                      value: null,
                                      child: Text('Sin especificar')),
                                  ..._machos.map((a) => DropdownMenuItem<
                                          Animal?>(
                                      value: a,
                                      child: Text(
                                          '${a.nombreVisible} (${a.codigo})'))),
                                ],
                                onChanged: _especieSeleccionada == null
                                    ? null
                                    : (v) =>
                                        setState(() => _padreSeleccionado = v),
                              ),
                            ],
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
                      child: _guardando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _esEdicion ? 'Guardar cambios' : 'Crear animal'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _guardando
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.tertiary),
                      child: const Text('Cancelar'),
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
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      child: InputDecorator(
        decoration: InputDecoration(labelText: etiqueta),
        child: Text(fecha != null
            ? '${fecha!.year.toString().padLeft(4, '0')}-${fecha!.month.toString().padLeft(2, '0')}-${fecha!.day.toString().padLeft(2, '0')}'
            : 'Sin definir'),
      ),
    );
  }
}
