import 'package:flutter/material.dart';

import '../../repositories/financiera/financiera_repository.dart';
import '../../repositories/produccion/produccion_repository.dart';
import '../../theme/app_theme.dart';
import 'balance_screen.dart';
import 'gastos_ventas_screen.dart';
import 'precios_mercado_screen.dart';

/// Inicio del módulo Financiera (se abre desde Cuenta → "Control financiero
/// y balances"). Solo reparte el acceso a las tres pantallas del módulo:
/// Gastos y ventas, Precios de mercado y Balance. No carga datos propios.
///
/// Precios de mercado limita sus fechas a un mes; desde aquí se abre con el
/// mes actual.
class InicioFinanzasScreen extends StatelessWidget {
  final FinancieraRepository repository;
  final ProduccionRepository produccionRepository;

  const InicioFinanzasScreen({
    super.key,
    required this.repository,
    required this.produccionRepository,
  });

  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control financiero')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _acceso(
            icono: Icons.receipt_long_outlined,
            titulo: 'Gastos y ventas',
            subtitulo: 'Registra y consulta los gastos y las ventas del mes',
            onTap: () =>
                _abrir(context, GastosVentasScreen(repository: repository)),
          ),
          const SizedBox(height: 12),
          _acceso(
            icono: Icons.price_change_outlined,
            titulo: 'Precios de mercado',
            subtitulo: 'Precios de referencia de la leche y los huevos',
            onTap: () => _abrir(
              context,
              PreciosMercadoScreen(
                repository: repository,
                mes: DateTime.now(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _acceso(
            icono: Icons.account_balance_wallet_outlined,
            titulo: 'Balance',
            subtitulo: 'Valor estimado de hoy y balances generados',
            onTap: () => _abrir(
              context,
              BalanceScreen(
                repository: repository,
                produccionRepository: produccionRepository,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _acceso({
    required IconData icono,
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
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F7ED),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: AppTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitulo,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppTheme.outline)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
