import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Tarjeta blanca elevada que envuelve los formularios de Auth (Login,
/// Registro, Recuperar/Restablecer contraseña) — replica el contenedor
/// `bg-surface-container-lowest rounded-xl shadow-[...]` de las pantallas
/// de Stitch. Sin esto, los inputs quedaban flotando directo sobre el
/// fondo crema/rosado y la pantalla se veía plana.
class AuthCard extends StatelessWidget {
  final List<Widget> children;

  const AuthCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}
