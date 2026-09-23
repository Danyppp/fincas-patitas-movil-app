import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/animal.dart';
import '../../models/catalogo/potrero.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/especie_visual.dart';
import 'animal_form_screen.dart';

class AnimalDetailScreen extends StatefulWidget {
  final int animalId;
  final AnimalRepository repository;
  final CatalogoRepository catalogoRepository;

  const AnimalDetailScreen({
    super.key,
    required this.animalId,
    required this.repository,
    required this.catalogoRepository,
  });

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  Animal? _animal;
  Animal? _madre;
  Animal? _padre;
  Potrero? _potrero;
  Map<String, dynamic>? _ultimoEventoSanitario;
  bool _cargando = true;
  String? _error;
  bool _huboCambios = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final animal = await widget.repository.obtenerPorId(widget.animalId);
      if (animal == null) {
        setState(() {
          _animal = null;
          _error = 'Animal no encontrado';
        });
        return;
      }

      // Cargas secundarias (genealogía, potrero, último evento sanitario).
      // Cada una se resuelve de forma independiente y no debe tumbar la
      // pantalla si falla: si algo sale mal, simplemente no se muestra
      // esa sección.
      final madre = animal.madreId == null
          ? null
          : await _intentar(
              () => widget.repository.obtenerPorId(animal.madreId!));
      final padre = animal.padreId == null
          ? null
          : await _intentar(
              () => widget.repository.obtenerPorId(animal.padreId!));
      final potrero = animal.potreroId == null
          ? null
          : await _buscarPotrero(animal.potreroId!);
      final ultimoEvento = await _obtenerUltimoEventoSanitario(animal.id);

      setState(() {
        _animal = animal;
        _madre = madre;
        _padre = padre;
        _potrero = potrero;
        _ultimoEventoSanitario = ultimoEvento;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<T?> _intentar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } catch (_) {
      return null;
    }
  }

  Future<Potrero?> _buscarPotrero(int potreroId) async {
    final potreros =
        await _intentar(() => widget.catalogoRepository.listarPotreros());
    if (potreros == null) return null;
    for (final p in potreros) {
      if (p.id == potreroId) return p;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _obtenerUltimoEventoSanitario(
      int animalId) async {
    final respuesta =
        await _intentar(() => widget.repository.obtenerHistorial(animalId));
    final historial = respuesta?['historial'] as Map<String, dynamic>?;
    final eventos = historial?['eventosSanitarios'] as List<dynamic>?;
    if (eventos == null || eventos.isEmpty) return null;
    return eventos.first as Map<String, dynamic>;
  }

  Future<void> _editar() async {
    final actualizado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AnimalFormScreen(
          repository: widget.repository,
          catalogoRepository: widget.catalogoRepository,
          animalExistente: _animal,
        ),
      ),
    );
    if (actualizado == true) {
      _huboCambios = true;
      _cargar();
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar animal'),
        content: Text(
            '¿Eliminar a ${_animal?.nombreVisible}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await widget.repository.eliminar(widget.animalId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_huboCambios);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_animal?.nombreVisible ?? 'Animal'),
          actions: [
            if (_animal != null) ...[
              IconButton(
                  icon: const Icon(Icons.edit_outlined), onPressed: _editar),
              IconButton(
                  icon: const Icon(Icons.delete_outline), onPressed: _eliminar),
            ],
          ],
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _DetalleAnimal(
                    animal: _animal!,
                    madre: _madre,
                    padre: _padre,
                    potrero: _potrero,
                    ultimoEventoSanitario: _ultimoEventoSanitario,
                  ),
      ),
    );
  }
}

class _DetalleAnimal extends StatelessWidget {
  final Animal animal;
  final Animal? madre;
  final Animal? padre;
  final Potrero? potrero;
  final Map<String, dynamic>? ultimoEventoSanitario;

  const _DetalleAnimal({
    required this.animal,
    this.madre,
    this.padre,
    this.potrero,
    this.ultimoEventoSanitario,
  });

  int? _edadAnios() {
    final nacimiento = animal.fechaNacimiento;
    if (nacimiento == null) return null;
    final ahora = DateTime.now();
    int edad = ahora.year - nacimiento.year;
    if (ahora.month < nacimiento.month ||
        (ahora.month == nacimiento.month && ahora.day < nacimiento.day)) {
      edad--;
    }
    return edad < 0 ? 0 : edad;
  }

  Widget _pill(String texto, Color fondo, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        texto,
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _tarjeta(
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
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _filaFicha(
      BuildContext context, IconData icono, String etiqueta, String valor) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: AppTheme.outline),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(etiqueta, style: textTheme.bodySmall),
          ),
          Expanded(
            child: Text(valor,
                style:
                    textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formato = DateFormat('yyyy-MM-dd');
    final especie = animal.especie?.nombre ?? '#${animal.especieId}';
    final raza = animal.raza?.nombre ?? '#${animal.razaId}';
    final esHembra = animal.genero.toLowerCase().startsWith('h');
    final colores = colorEstado(animal.estado);
    final edad = _edadAnios();
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // -- "Hero" (sin foto real: el backend no la soporta, así que se
        // usa el emoji de la especie a gran tamaño como sustituto). --
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryContainer.withValues(alpha: 0.22),
                AppTheme.surfaceContainerLowest,
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _pill('#${animal.codigo}', AppTheme.surfaceContainerLowest,
                      AppTheme.onSurface),
                  Row(
                    children: [
                      _pill(animal.estado, colores.fondo, colores.texto),
                      if (edad != null) ...[
                        const SizedBox(width: 8),
                        _pill('$edad años', AppTheme.surfaceContainerLowest,
                            AppTheme.onSurface),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(emojiEspecie(animal.especie?.nombre),
                    style: const TextStyle(fontSize: 64)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: Text(animal.nombreVisible,
                        style: textTheme.displayLarge),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    esHembra ? Icons.female : Icons.male,
                    color: esHembra
                        ? const Color(0xFFAE2F34)
                        : const Color(0xFF006E1C),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('$especie · Raza $raza', style: textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // -- Ficha técnica (solo datos reales del modelo `animales`). --
        _tarjeta(
          context,
          icono: Icons.badge_outlined,
          titulo: 'Ficha técnica',
          children: [
            _filaFicha(context, Icons.tag, 'Código', animal.codigo),
            _filaFicha(context, Icons.pets, 'Especie', especie),
            _filaFicha(context, Icons.category_outlined, 'Raza', raza),
            _filaFicha(context, Icons.wc, 'Género', animal.genero),
            if (animal.fechaNacimiento != null)
              _filaFicha(context, Icons.cake_outlined, 'Fecha de nacimiento',
                  formato.format(animal.fechaNacimiento!)),
            if (animal.fechaIngreso != null)
              _filaFicha(context, Icons.login, 'Fecha de ingreso',
                  formato.format(animal.fechaIngreso!)),
            if (animal.origen != null && animal.origen!.isNotEmpty)
              _filaFicha(context, Icons.info_outline, 'Origen', animal.origen!),
            if (animal.loteNombre != null)
              _filaFicha(
                  context, Icons.grid_view_rounded, 'Lote', animal.loteNombre!),
            if (potrero != null)
              _filaFicha(
                  context, Icons.map_outlined, 'Potrero', potrero!.nombre),
          ],
        ),

        // -- Genealogía (solo si hay datos reales de madre/padre). --
        if (madre != null || padre != null) ...[
          const SizedBox(height: 16),
          _tarjeta(
            context,
            icono: Icons.account_tree_outlined,
            titulo: 'Origen y genealogía',
            children: [
              if (madre != null) _filaGenealogia(context, 'Madre', madre!),
              if (padre != null) _filaGenealogia(context, 'Padre', padre!),
            ],
          ),
        ],

        // -- Estado de salud: solo datos reales del backend (sin
        // veterinario ni "próximo refuerzo", eso no existe en el modelo
        // de eventos_sanitarios). --
        const SizedBox(height: 16),
        _tarjeta(
          context,
          icono: Icons.health_and_safety_outlined,
          titulo: 'Estado de salud',
          children: [
            if (ultimoEventoSanitario == null)
              Text('Sin eventos sanitarios registrados',
                  style: textTheme.bodyMedium)
            else ...[
              _filaFicha(context, Icons.event_note_outlined, 'Último evento',
                  ultimoEventoSanitario!['tipo_evento'] as String? ?? '-'),
              if (ultimoEventoSanitario!['fecha_evento'] != null)
                _filaFicha(
                  context,
                  Icons.calendar_today_outlined,
                  'Fecha',
                  formato.format(DateTime.parse(
                      ultimoEventoSanitario!['fecha_evento'] as String)),
                ),
              if ((ultimoEventoSanitario!['descripcion_tratamiento'] as String?)
                      ?.isNotEmpty ==
                  true)
                _filaFicha(
                    context,
                    Icons.description_outlined,
                    'Descripción',
                    ultimoEventoSanitario!['descripcion_tratamiento']
                        as String),
              if (ultimoEventoSanitario!['estado'] != null)
                _filaFicha(context, Icons.flag_outlined, 'Estado del evento',
                    ultimoEventoSanitario!['estado'] as String),
            ],
          ],
        ),
      ],
    );
  }

  Widget _filaGenealogia(
      BuildContext context, String etiqueta, Animal progenitor) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primaryContainer.withValues(alpha: 0.15),
            child: Text(emojiEspecie(progenitor.especie?.nombre),
                style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta.toUpperCase(),
                    style: textTheme.labelSmall
                        ?.copyWith(color: AppTheme.outline)),
                Text(
                  '${progenitor.nombreVisible} · #${progenitor.codigo}',
                  style: textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (progenitor.raza != null)
                  Text(progenitor.raza!.nombre, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
