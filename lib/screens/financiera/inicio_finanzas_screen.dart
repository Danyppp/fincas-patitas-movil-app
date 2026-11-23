import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/financiera/resumen_mes.dart';
import '../../repositories/financiera/financiera_repository.dart';
import '../../repositories/produccion/produccion_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/fecha_dia.dart';
import '../../utils/formato_cop.dart';
import 'balance_screen.dart';
import 'gastos_ventas_screen.dart';
import 'precios_mercado_screen.dart';

/// Inicio del módulo Financiera (se abre desde Cuenta → "Control financiero
/// y balances").
///
/// - Tarjeta "Flujo de caja" del mes actual: ventas cobradas, gastos y
///   diferencia, con la barra de rentabilidad (diferencia sobre lo cobrado).
///   Usa la misma regla que Gastos y Ventas y que el balance del backend
///   (`ResumenMes`). Si falla la carga, solo esa tarjeta avisa; los accesos
///   siguen funcionando.
/// - Accesos a Gastos y ventas, Precios de mercado y Balance.
///
/// Precios de mercado limita sus fechas a un mes; desde aquí se abre con el
/// mes actual.
class InicioFinanzasScreen extends StatefulWidget {
  final FinancieraRepository repository;
  final ProduccionRepository produccionRepository;

  const InicioFinanzasScreen({
    super.key,
    required this.repository,
    required this.produccionRepository,
  });

  @override
  State<InicioFinanzasScreen> createState() => _InicioFinanzasScreenState();
}

class _InicioFinanzasScreenState extends State<InicioFinanzasScreen> {
  bool _cargando = true;
  String? _error;
  ResumenMes? _resumen;

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
      final ventas = await widget.repository.listarVentas();
      final gastos = await widget.repository.listarGastos();
      final hoy = FechaDia.hoy();
      final resumen = ResumenMes.calcular(
        ventas: ventas,
        gastos: gastos,
        mes: DateTime(hoy.year, hoy.month),
      );
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } on ApiException catch (e) {
      _falloCarga(e.message);
    } on NetworkException catch (e) {
      _falloCarga(e.message);
    }
  }

  void _falloCarga(String mensaje) {
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = mensaje;
    });
  }

  /// Abre una pantalla y, al volver, recarga el flujo de caja (puede haber
  /// cambiado al registrar gastos o ventas).
  Future<void> _abrir(Widget pantalla) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));
    if (mounted) await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control financiero')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _tarjetaFlujo(),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 10),
              child: Text('Operaciones',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            _acceso(
              icono: Icons.account_balance_wallet_outlined,
              colorFondo: AppTheme.primaryContainer,
              colorIcono: AppTheme.onPrimary,
              titulo: 'Gastos y ventas',
              subtitulo: 'Registra y consulta los gastos y las ventas del mes',
              onTap: () =>
                  _abrir(GastosVentasScreen(repository: widget.repository)),
            ),
            const SizedBox(height: 12),
            _acceso(
              icono: Icons.sell_outlined,
              colorFondo: AppTheme.secondaryContainer,
              colorIcono: AppTheme.onSecondaryContainer,
              titulo: 'Precios de mercado',
              subtitulo: 'Precios de referencia de la leche y los huevos',
              onTap: () => _abrir(PreciosMercadoScreen(
                repository: widget.repository,
                mes: DateTime.now(),
              )),
            ),
            const SizedBox(height: 12),
            _acceso(
              icono: Icons.bar_chart_rounded,
              colorFondo: AppTheme.tertiaryContainer,
              colorIcono: AppTheme.onTertiaryContainer,
              titulo: 'Balance',
              subtitulo: 'Valor estimado de hoy y balances generados',
              onTap: () => _abrir(BalanceScreen(
                repository: widget.repository,
                produccionRepository: widget.produccionRepository,
              )),
            ),
          ],
        ),
      ),
    );
  }

  // ── Flujo de caja ─────────────────────────────────────────────────────

  Widget _tarjetaFlujo() {
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
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                    color: AppTheme.primaryContainer, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('FLUJO DE CAJA DEL MES',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppTheme.onSurfaceVariant)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: const Text('COP',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.secondary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null || _resumen == null)
            Column(
              children: [
                Text(_error ?? 'No se pudo cargar el flujo de caja.',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: AppTheme.error, fontSize: 13)),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed: _cargar, child: const Text('Reintentar')),
              ],
            )
          else
            _contenidoFlujo(_resumen!),
        ],
      ),
    );
  }

  Widget _contenidoFlujo(ResumenMes r) {
    final margen = r.margenPorcentaje;
    final positivo = r.diferencia >= 0;
    // Parte verde de la barra: lo que queda de lo cobrado tras los gastos.
    final parteVerde = margen == null ? 0.0 : (margen / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _cajaDato(
                icono: Icons.trending_up,
                titulo: 'Ventas',
                valor: FormatoCOP.pesos(r.ventasCobradas),
                detalle: 'Cobradas',
                color: AppTheme.primary,
                fondo: AppTheme.surfaceContainerLow,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _cajaDato(
                icono: Icons.trending_down,
                titulo: 'Gastos',
                valor: FormatoCOP.pesos(r.gastos),
                detalle: r.cantidadGastos == 1
                    ? '1 registro'
                    : '${r.cantidadGastos} registros',
                color: AppTheme.tertiaryContainer,
                fondo: AppTheme.surfaceContainerLow,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _cajaDato(
                icono: Icons.account_balance_outlined,
                titulo: 'Diferencia',
                valor: FormatoCOP.pesos(r.diferencia),
                detalle: margen == null
                    ? 'Sin ventas cobradas'
                    : '${margen.round()}% margen',
                color: positivo ? AppTheme.secondary : AppTheme.error,
                fondo: const Color(0xFFFFF3E6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Balance de operaciones',
                style: TextStyle(
                    fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
            if (margen != null)
              Text('${margen.round()}% rentabilidad neta',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: positivo ? AppTheme.primary : AppTheme.error)),
          ],
        ),
        const SizedBox(height: 8),
        if (margen == null)
          const Text(
              'Aún no hay ventas cobradas este mes para calcular la rentabilidad.',
              style: TextStyle(fontSize: 12, color: AppTheme.outline))
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (parteVerde > 0)
                    Expanded(
                      flex: (parteVerde * 1000).round(),
                      child: const ColoredBox(color: AppTheme.primaryContainer),
                    ),
                  if (parteVerde < 1)
                    Expanded(
                      flex: ((1 - parteVerde) * 1000).round(),
                      child: ColoredBox(
                          color: positivo
                              ? AppTheme.secondaryContainer
                              : AppTheme.tertiaryContainer),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _cajaDato({
    required IconData icono,
    required String titulo,
    required String valor,
    required String detalle,
    required Color color,
    required Color fondo,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm * 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 15, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(titulo,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(height: 2),
          Text(detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: AppTheme.outline)),
        ],
      ),
    );
  }

  // ── Accesos ───────────────────────────────────────────────────────────

  Widget _acceso({
    required IconData icono,
    required Color colorFondo,
    required Color colorIcono,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      elevation: 1,
      shadowColor: AppTheme.onSurface.withValues(alpha: 0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(color: colorFondo, shape: BoxShape.circle),
                child: Icon(icono, color: colorIcono, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitulo,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppTheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                    color: AppTheme.surfaceContainerColor,
                    shape: BoxShape.circle),
                child: const Icon(Icons.chevron_right,
                    color: AppTheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
