import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/auth_session.dart';
import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../models/produccion/resumen_produccion.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/produccion/produccion_repository.dart';
import '../../theme/app_theme.dart';
import 'produccion_detalle_dialog.dart';
import 'produccion_historial_screen.dart';
import 'produccion_list_screen.dart';

/// Dashboard de Producción — pantalla de entrada del módulo (reemplaza a
/// ProduccionListScreen como destino directo de la pestaña "Producción" de
/// la barra inferior, 2026-10-01). Estructura basada en el mockup de Stitch
/// "control_y_m_tricas_de_producci_n", recortada a lo que el backend
/// realmente puede respaldar (ver decisiones-diseno-vs-backend-produccion.md).
///
/// Historial de cambios relevantes:
/// - 2026-10-01: "hoy" se calcula en el cliente filtrando
///   `listarLeche()`/`listarHuevos()` por día calendario local (no por el
///   endpoint `/produccion/summary/today`, que usa el día UTC del
///   servidor). Título "Control de producción" + fecha agregado.
/// - 2026-10-02 (segunda ronda de correcciones): botón "Registrar
///   producción de hoy" rediseñado al estilo del mockup de Stitch (píldora,
///   ancho completo, ya NO flotante); se quitó "Huevos de hoy por lote"
///   (redundante con el desglose diario); se agregó acceso a la pantalla
///   de "Historial completo"; y el "Historial reciente (hoy)" ahora
///   también muestra los registros eliminados hoy (con la leyenda
///   "Eliminado el ... por ..."), aprovechando el borrado lógico agregado
///   en el backend.
class ProduccionDashboardScreen extends StatefulWidget {
  final ProduccionRepository repository;
  final AnimalRepository animalRepository;
  final CatalogoRepository catalogoRepository;
  final AuthSession session;

  const ProduccionDashboardScreen({
    super.key,
    required this.repository,
    required this.animalRepository,
    required this.catalogoRepository,
    required this.session,
  });

  @override
  State<ProduccionDashboardScreen> createState() =>
      _ProduccionDashboardScreenState();
}

class _ProduccionDashboardScreenState extends State<ProduccionDashboardScreen> {
  bool _cargando = true;
  String? _error;
  ResumenProduccionHoy? _resumen;
  // Registros de hoy INCLUYENDO los eliminados — solo para el historial
  // reciente (los totales/tarjetas siguen usando `_resumen`, que no los
  // cuenta).
  List<ProduccionLeche> _lecheHoyTodos = [];
  List<ProduccionHuevos> _huevosHoyTodos = [];
  IndicadoresProduccion? _indicadoresAyer;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  bool _esMismoDiaLocal(DateTime fecha, DateTime diaLocal) {
    final local = fecha.toLocal();
    return local.year == diaLocal.year &&
        local.month == diaLocal.month &&
        local.day == diaLocal.day;
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final ahora = DateTime.now();
      final hoyLocal = DateTime(ahora.year, ahora.month, ahora.day);

      // `incluirEliminados: true` — se piden TODOS (activos + eliminados),
      // porque el "Historial reciente (hoy)" ahora debe mostrar también
      // los registros eliminados hoy (punto 5, 2026-10-02). Los totales de
      // las tarjetas igual solo cuentan los activos (ver más abajo).
      final todaLeche =
          await widget.repository.listarLeche(incluirEliminados: true);
      final todosHuevos =
          await widget.repository.listarHuevos(incluirEliminados: true);

      final lecheHoyTodos = todaLeche
          .where((r) => _esMismoDiaLocal(r.registradoEn, hoyLocal))
          .toList();
      final huevosHoyTodos = todosHuevos
          .where((r) => _esMismoDiaLocal(r.registradoEn, hoyLocal))
          .toList();

      final lecheHoyActivos =
          lecheHoyTodos.where((r) => !r.estaEliminado).toList();
      final huevosHoyActivos =
          huevosHoyTodos.where((r) => !r.estaEliminado).toList();

      final totalLitros =
          lecheHoyActivos.fold<double>(0, (s, r) => s + r.litros);
      final totalBuenos =
          huevosHoyActivos.fold<int>(0, (s, r) => s + r.cantidadBuenos);
      final totalRotos =
          huevosHoyActivos.fold<int>(0, (s, r) => s + r.cantidadRotos);

      final resumen = ResumenProduccionHoy(
        totalLitrosLeche: totalLitros,
        totalHuevosBuenos: totalBuenos,
        totalHuevosRotos: totalRotos,
        registrosLeche: lecheHoyActivos,
        registrosHuevos: huevosHoyActivos,
        mensaje: (lecheHoyActivos.isEmpty && huevosHoyActivos.isEmpty)
            ? 'Aún no hay producción registrada hoy'
            : null,
      );

      final inicioAyer = hoyLocal.subtract(const Duration(days: 1));
      final finAyer = hoyLocal.subtract(const Duration(milliseconds: 1));
      final indicadoresAyer = await widget.repository.indicadores(
        fechaInicio: inicioAyer,
        fechaFin: finAyer,
      );

      setState(() {
        _resumen = resumen;
        _lecheHoyTodos = lecheHoyTodos;
        _huevosHoyTodos = huevosHoyTodos;
        _indicadoresAyer = indicadoresAyer;
      });
    } catch (e) {
      setState(() => _error = 'No se pudo cargar el resumen de producción: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirRegistro() async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProduccionListScreen(
          repository: widget.repository,
          animalRepository: widget.animalRepository,
          catalogoRepository: widget.catalogoRepository,
          session: widget.session,
        ),
      ),
    );
    if (cambio == true) _cargar();
  }

  void _abrirHistorialCompleto() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProduccionHistorialScreen(repository: widget.repository),
      ),
    );
  }

  /// Variación porcentual hoy vs ayer. `null` cuando no hay valor de ayer
  /// contra qué comparar (evita dividir por cero y evita mostrar un
  /// "+∞%" sin sentido).
  double? _variacion(double hoyValor, double ayerValor) {
    if (ayerValor == 0) return null;
    return ((hoyValor - ayerValor) / ayerValor) * 100;
  }

  @override
  Widget build(BuildContext context) {
    double? variacionLeche;
    double? variacionHuevos;
    if (_resumen != null && _indicadoresAyer != null) {
      variacionLeche = _variacion(
          _resumen!.totalLitrosLeche, _indicadoresAyer!.leche.totalLitros);
      variacionHuevos = _variacion(_resumen!.totalHuevosHoy.toDouble(),
          _indicadoresAyer!.huevos.totalUnidades.toDouble());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Producción'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _cargar,
                            child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      const _TituloControl(),
                      const SizedBox(height: 12),
                      const _EncabezadoFinca(),
                      const SizedBox(height: 16),
                      _BotonRegistrarHoy(onPressed: _abrirRegistro),
                      const SizedBox(height: 16),
                      _TarjetasResumenHoy(
                        resumen: _resumen!,
                        variacionLeche: variacionLeche,
                        variacionHuevos: variacionHuevos,
                      ),
                      const SizedBox(height: 16),
                      _EventosProductivos(
                        resumen: _resumen!,
                        variacionLeche: variacionLeche,
                        variacionHuevos: variacionHuevos,
                      ),
                      const SizedBox(height: 16),
                      _HistorialReciente(
                        lecheHoyTodos: _lecheHoyTodos,
                        huevosHoyTodos: _huevosHoyTodos,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton.icon(
                          onPressed: _abrirHistorialCompleto,
                          icon: const Icon(Icons.history),
                          label: const Text('Ver historial completo'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

const _diasSemana = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Título fijo de la pantalla ("Control de producción") con la fecha de hoy
/// al lado (punto 1 del reporte de pruebas, 2026-10-01).
class _TituloControl extends StatelessWidget {
  const _TituloControl();

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final fecha = 'Hoy, ${hoy.day} de ${_meses[hoy.month - 1]}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          'Control de producción',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(fecha, style: TextStyle(color: AppTheme.outline, fontSize: 13)),
      ],
    );
  }
}

class _EncabezadoFinca extends StatelessWidget {
  const _EncabezadoFinca();

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final fechaCapitalizada =
        '${_diasSemana[hoy.weekday - 1]} ${hoy.day} de ${_meses[hoy.month - 1]}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.agriculture, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Finca La Esperanza',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                Text(fechaCapitalizada,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón "Registrar producción de hoy" rediseñado al estilo del mockup de
/// Stitch (2026-10-02, punto 2): píldora de ancho completo, verde claro,
/// con el ícono "+" en un círculo a la izquierda — ya NO es un
/// FloatingActionButton flotante, es parte normal del scroll, justo
/// después del encabezado.
class _BotonRegistrarHoy extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotonRegistrarHoy({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF8BC98F),
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                    color: Color(0xFF3F6B4A), shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Registrar Producción de Hoy',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetasResumenHoy extends StatelessWidget {
  final ResumenProduccionHoy resumen;
  final double? variacionLeche;
  final double? variacionHuevos;

  const _TarjetasResumenHoy({
    required this.resumen,
    required this.variacionLeche,
    required this.variacionHuevos,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TarjetaIndicador(
            icono: Icons.water_drop,
            titulo: 'Leche hoy',
            valor: '${resumen.totalLitrosLeche.toStringAsFixed(1)} L',
            subtitulo: '${resumen.registrosLeche.length} '
                '${resumen.registrosLeche.length == 1 ? 'registro' : 'registros'} hoy',
            variacion: variacionLeche,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TarjetaIndicador(
            icono: Icons.egg,
            titulo: 'Huevos hoy',
            valor: '${resumen.totalHuevosHoy}',
            subtitulo: '${resumen.registrosHuevos.length} '
                '${resumen.registrosHuevos.length == 1 ? 'registro' : 'registros'} hoy'
                '${resumen.totalHuevosRotos > 0 ? ' · ${resumen.totalHuevosRotos} rotos' : ''}',
            variacion: variacionHuevos,
          ),
        ),
      ],
    );
  }
}

class _TarjetaIndicador extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final String? subtitulo;
  final double? variacion;

  const _TarjetaIndicador({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.variacion,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: AppTheme.primary, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(titulo,
                      style: TextStyle(color: AppTheme.outline, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(valor,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (subtitulo != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitulo!,
                    style: TextStyle(color: AppTheme.outline, fontSize: 12)),
              ),
            const SizedBox(height: 6),
            _EtiquetaVariacion(variacion: variacion),
          ],
        ),
      ),
    );
  }
}

class _EtiquetaVariacion extends StatelessWidget {
  final double? variacion;

  const _EtiquetaVariacion({required this.variacion});

  @override
  Widget build(BuildContext context) {
    if (variacion == null) {
      return const Text('Sin datos de ayer',
          style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    final esPositivo = variacion! >= 0;
    final color = esPositivo ? Colors.green[700] : Colors.red[700];
    final icono = esPositivo ? Icons.arrow_upward : Icons.arrow_downward;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          '${variacion!.abs().toStringAsFixed(0)}% vs ayer',
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EventosProductivos extends StatelessWidget {
  final ResumenProduccionHoy resumen;
  final double? variacionLeche;
  final double? variacionHuevos;

  const _EventosProductivos({
    required this.resumen,
    required this.variacionLeche,
    required this.variacionHuevos,
  });

  @override
  Widget build(BuildContext context) {
    final mensajes = <String>[];

    if (!resumen.hayProduccionHoy) {
      mensajes.add(resumen.mensaje ?? 'Aún no hay producción registrada hoy');
    } else {
      if (variacionLeche != null && variacionLeche! < 0) {
        mensajes.add(
          'La producción de leche bajó ${variacionLeche!.abs().toStringAsFixed(0)}% respecto a ayer.',
        );
      }
      if (variacionHuevos != null && variacionHuevos! < 0) {
        mensajes.add(
          'La recolección de huevos bajó ${variacionHuevos!.abs().toStringAsFixed(0)}% respecto a ayer.',
        );
      }
    }

    if (mensajes.isEmpty) {
      mensajes.add(
          'Sin novedades: la producción de hoy va en línea con lo esperado.');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Eventos productivos',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...mensajes.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(m)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorialReciente extends StatelessWidget {
  final List<ProduccionLeche> lecheHoyTodos;
  final List<ProduccionHuevos> huevosHoyTodos;

  const _HistorialReciente(
      {required this.lecheHoyTodos, required this.huevosHoyTodos});

  @override
  Widget build(BuildContext context) {
    final formato = DateFormat('HH:mm');

    // Combina ambos tipos en un solo historial, ordenado por fecha
    // descendente, tomando como máximo los 8 más recientes. Incluye los
    // eliminados hoy (punto 5, 2026-10-02), marcados con la leyenda
    // correspondiente y tachados.
    final combinados = <_ItemHistorial>[
      ...lecheHoyTodos.map((r) => _ItemHistorial.leche(r)),
      ...huevosHoyTodos.map((r) => _ItemHistorial.huevos(r)),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    final recientes = combinados.take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historial reciente (hoy)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (recientes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Sin registros todavía hoy.',
                    style: TextStyle(color: AppTheme.outline)),
              )
            else
              ...recientes.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: item.onTap == null ? null : () => item.onTap!(context),
                  leading: Icon(item.icono,
                      color:
                          item.eliminado ? AppTheme.outline : AppTheme.primary),
                  title: Text(
                    item.titulo,
                    style: item.eliminado
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: AppTheme.outline)
                        : null,
                  ),
                  subtitle: item.eliminado
                      ? Text(
                          'Eliminado · ${item.subtitulo}',
                          style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w600),
                        )
                      : Text(item.subtitulo),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formato.format(item.fecha.toLocal())),
                      if (item.onTap != null) ...[
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.outline, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Envoltorio liviano para mezclar `ProduccionLeche` y `ProduccionHuevos`
/// en una sola lista ordenable, sin tocar esos modelos.
class _ItemHistorial {
  final DateTime fecha;
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool eliminado;
  final void Function(BuildContext)? onTap;

  _ItemHistorial._({
    required this.fecha,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.eliminado,
    this.onTap,
  });

  factory _ItemHistorial.leche(ProduccionLeche r) {
    final origen = r.esPorLote
        ? (r.loteNombre ?? 'Lote #${r.loteId}')
        : (r.animal?.nombreVisible ?? 'Animal');
    return _ItemHistorial._(
      fecha: r.registradoEn,
      icono: Icons.water_drop_outlined,
      titulo: '${r.litros} L de leche',
      subtitulo: origen,
      eliminado: r.estaEliminado,
      onTap: (context) => mostrarDetalleLeche(context, r),
    );
  }

  factory _ItemHistorial.huevos(ProduccionHuevos r) {
    final origen = r.esPorLote
        ? (r.loteNombre ?? 'Lote #${r.loteId}')
        : (r.animalId != null ? 'Animal' : 'Sin lote ni animal');
    return _ItemHistorial._(
      fecha: r.registradoEn,
      icono: Icons.egg_outlined,
      titulo: '${r.cantidad} huevos',
      subtitulo: origen,
      eliminado: r.estaEliminado,
      onTap: (context) => mostrarDetalleHuevos(context, r),
    );
  }
}
