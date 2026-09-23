import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ayuda visual para las categorías de bodega en Inventario — mismo patrón
/// que `especie_visual.dart` en Animales (ícono + color según el nombre
/// de la categoría, ya que el backend no guarda ningún ícono/color por
/// categoría). Si aparece una categoría nueva que no calza en ninguna
/// regla, cae en el ícono/color por defecto — nunca se rompe.
IconData iconoCategoriaBodega(String? nombre) {
  final n = (nombre ?? '').toLowerCase();
  if (n.contains('medic') || n.contains('sanit') || n.contains('vacun')) {
    return Icons.medical_services_rounded;
  }
  if (n.contains('aliment') || n.contains('nutri') || n.contains('concentrado')) {
    return Icons.grass_rounded;
  }
  if (n.contains('herramient') || n.contains('equipo')) {
    return Icons.build_rounded;
  }
  return Icons.inventory_2_rounded;
}

({Color fondo, Color icono}) colorCategoriaBodega(String? nombre) {
  final n = (nombre ?? '').toLowerCase();
  if (n.contains('medic') || n.contains('sanit') || n.contains('vacun')) {
    return (
      fondo: AppTheme.tertiaryContainer.withValues(alpha: 0.18),
      icono: AppTheme.tertiary,
    );
  }
  if (n.contains('aliment') || n.contains('nutri') || n.contains('concentrado')) {
    return (
      fondo: AppTheme.secondaryContainer.withValues(alpha: 0.25),
      icono: AppTheme.secondary,
    );
  }
  return (
    fondo: AppTheme.primaryContainer.withValues(alpha: 0.15),
    icono: AppTheme.primary,
  );
}

/// Etiqueta corta descriptiva por categoría, tomada del mockup de Stitch
/// para "Registrar Insumo Nuevo" (ej. "Salud y Vacunas" para Medicamentos).
/// Es puramente decorativa — el backend solo guarda el `nombre` de la
/// categoría — y para categorías que no vienen en el mockup original
/// (como "Elementos finca", agregada por Dany) cae en un texto genérico.
String etiquetaCategoriaBodega(String? nombre) {
  final n = (nombre ?? '').toLowerCase();
  if (n.contains('medic') || n.contains('sanit') || n.contains('vacun')) {
    return 'Salud y Vacunas';
  }
  if (n.contains('aliment') || n.contains('nutri') || n.contains('concentrado')) {
    return 'Nutrición y Forraje';
  }
  if (n.contains('herramient') || n.contains('equipo')) {
    return 'Mantenimiento';
  }
  return 'Uso General';
}

/// Estilo de la pill de estado de stock, con la misma terminología del
/// diseño de Stitch ("Óptimo" en vez de "Normal").
({Color fondo, Color texto, String etiqueta}) estiloEstadoStock(
  bool agotado,
  bool bajo,
) {
  if (agotado) {
    return (
      fondo: AppTheme.error.withValues(alpha: 0.15),
      texto: AppTheme.error,
      etiqueta: 'Agotado',
    );
  }
  if (bajo) {
    return (
      fondo: AppTheme.tertiaryContainer.withValues(alpha: 0.2),
      texto: AppTheme.tertiary,
      etiqueta: 'Stock Bajo',
    );
  }
  return (
    fondo: AppTheme.primaryContainer.withValues(alpha: 0.15),
    texto: const Color(0xFF2E7D32),
    etiqueta: 'Óptimo',
  );
}
