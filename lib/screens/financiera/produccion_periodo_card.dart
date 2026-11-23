import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_exception.dart';
import '../../models/produccion/resumen_produccion.dart';
import '../../repositories/produccion/produccion_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/formato_cop.dart';

/// Resumen de la producción del mes en curso dentro de Balance: huevos
/// producidos, rotos y aprovechables, y litros de leche. Usa el endpoint
/// `GET /produccion/indicadores` con los límites del mes (día local) y es
/// solo informativo: no cambia el valor estimado de hoy ni el stock.
class ProduccionPeriodoCard extends StatefulWidget {
  final ProduccionRepository repository;

  const ProduccionPeriodoCard({super.key, required this.repository});

  @override
  State<ProduccionPeriodoCard> createState() => _ProduccionPeriodoCardState();
}

class _ProduccionPeriodoCardState extends State<ProduccionPeriodoCard> {
  bool _cargando = true;
  String? _error;
  IndicadoresProduccion? _indicadores;
  late final DateTime _inicio;
  late final DateTime _fin;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _inicio = DateTime(hoy.year, hoy.month, 1);
    // Último instante del mes (el backend compara con "menor o igual").
    _fin = DateTime(hoy.year, hoy.month + 1, 1)
        .subtract(const Duration(milliseconds: 1));
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await widget.repository
          .indicadores(fechaInicio: _inicio, fechaFin: _fin);
      if (!mounted) return;
      setState(() {
        _indicadores = r;
        _cargando = false;
      });
    } on ApiException catch (e) {
      _fallo(e.message);
    } on NetworkException catch (e) {
      _fallo(e.message);
    } catch (_) {
      _fallo('No se pudo cargar la producción del mes.');
    }
  }

  void _fallo(String mensaje) {
    if (!mounted) return;
    setState(() {
      _error = mensaje;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mes = toBeginningOfSentenceCase(
        DateFormat('MMMM yyyy', 'es').format(_inicio));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Producción de $mes',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _cargando ? null : _cargar,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13))
          else ...[
            _fila(Icons.egg_outlined, 'Huevos producidos',
                '${FormatoCOP.cantidad(_indicadores!.huevos.totalUnidades.toDouble())} unid.'),
            _fila(Icons.heart_broken_outlined, 'Huevos rotos',
                '${FormatoCOP.cantidad(_indicadores!.huevos.totalRotos.toDouble())} unid.'),
            _fila(Icons.check_circle_outline, 'Huevos aprovechables',
                '${FormatoCOP.cantidad(_indicadores!.huevos.totalAprovechables.toDouble())} unid.'),
            const Divider(height: 20),
            _fila(Icons.local_drink_outlined, 'Leche producida',
                '${FormatoCOP.cantidad(_indicadores!.leche.totalLitros)} L'),
          ],
        ],
      ),
    );
  }

  Widget _fila(IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icono, size: 18, color: AppTheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(etiqueta, style: const TextStyle(fontSize: 14)),
          ),
          Text(valor,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
