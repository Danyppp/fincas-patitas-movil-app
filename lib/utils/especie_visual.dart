import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ayudas visuales compartidas por las pantallas de Animales: el emoji que
/// representa a cada especie (el backend no soporta fotos de animales, así
/// que esto hace de "avatar" en listado/tarjeta/detalle/formulario) y el
/// color de la pill de estado. Centralizado acá para que las 4 pantallas
/// se vean siempre consistentes entre sí.
String emojiEspecie(String? nombre) {
  final n = (nombre ?? '').toLowerCase();
  if (n.contains('bov') || n.contains('vaca')) return '🐄';
  if (n.contains('cerd') || n.contains('porcin')) return '🐷';
  if (n.contains('galli') || n.contains('ave')) return '🐔';
  return '🐾';
}

({Color fondo, Color texto}) colorEstado(String estado) {
  switch (estado) {
    case 'Activo':
      return (
        fondo: AppTheme.primaryContainer.withValues(alpha: 0.15),
        texto: const Color(0xFF2E7D32),
      );
    case 'Vendido':
      return (
        fondo: AppTheme.secondaryContainer.withValues(alpha: 0.25),
        texto: const Color(0xFF6D4C41),
      );
    case 'Muerto':
      return (
        fondo: AppTheme.tertiaryContainer.withValues(alpha: 0.18),
        texto: const Color(0xFFC62828),
      );
    default: // Inactivo
      return (
        fondo: Colors.grey.withValues(alpha: 0.15),
        texto: Colors.grey.shade700
      );
  }
}
