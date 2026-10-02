import 'produccion_huevos.dart';
import 'produccion_leche.dart';

/// Respuesta real de `GET /api/produccion/summary/today` (confirmada
/// directamente contra el código del backend, 2026-10-01): devuelve los
/// totales de hoy ya sumados en el servidor (`Number(...)`, no Decimal-string)
/// más los registros completos del día (estos sí incluyen `litros` como
/// Decimal-string dentro de cada `ProduccionLeche`, ya manejado por su
/// propio `fromJson`).
class ResumenProduccionHoy {
  final double totalLitrosLeche;
  final int totalHuevosBuenos;
  final int totalHuevosRotos;
  final List<ProduccionLeche> registrosLeche;
  final List<ProduccionHuevos> registrosHuevos;
  final String? mensaje;

  const ResumenProduccionHoy({
    required this.totalLitrosLeche,
    required this.totalHuevosBuenos,
    required this.totalHuevosRotos,
    required this.registrosLeche,
    required this.registrosHuevos,
    this.mensaje,
  });

  int get totalHuevosHoy => totalHuevosBuenos + totalHuevosRotos;

  bool get hayProduccionHoy =>
      registrosLeche.isNotEmpty || registrosHuevos.isNotEmpty;

  factory ResumenProduccionHoy.fromJson(Map<String, dynamic> json) {
    return ResumenProduccionHoy(
      totalLitrosLeche: _parseDouble(json['totalLitrosLeche']) ?? 0,
      totalHuevosBuenos: (json['totalHuevosBuenos'] as num?)?.toInt() ?? 0,
      totalHuevosRotos: (json['totalHuevosRotos'] as num?)?.toInt() ?? 0,
      registrosLeche: (json['registrosLeche'] as List<dynamic>? ?? [])
          .map((e) => ProduccionLeche.fromJson(e as Map<String, dynamic>))
          .toList(),
      registrosHuevos: (json['registrosHuevos'] as List<dynamic>? ?? [])
          .map((e) => ProduccionHuevos.fromJson(e as Map<String, dynamic>))
          .toList(),
      mensaje: json['mensaje'] as String?,
    );
  }

  static double? _parseDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }
}

/// Respuesta real de `GET /api/produccion/indicadores` (confirmada contra
/// el backend, 2026-10-01). Huevos aquí solo trae `total_unidades` (no
/// separa buenos/rotos como sí lo hace el resumen de hoy), así que el
/// dashboard compara "unidades totales" contra "unidades totales" al
/// calcular la variación vs ayer, nunca mezclando con "buenos".
class IndicadoresProduccion {
  final DateTime? periodoInicio;
  final DateTime? periodoFin;
  final IndicadoresLeche leche;
  final IndicadoresHuevos huevos;

  const IndicadoresProduccion({
    this.periodoInicio,
    this.periodoFin,
    required this.leche,
    required this.huevos,
  });

  factory IndicadoresProduccion.fromJson(Map<String, dynamic> json) {
    final periodo = json['periodo'] as Map<String, dynamic>?;
    return IndicadoresProduccion(
      periodoInicio: (periodo?['fecha_inicio'] as String?) != null
          ? DateTime.tryParse(periodo!['fecha_inicio'] as String)
          : null,
      periodoFin: (periodo?['fecha_fin'] as String?) != null
          ? DateTime.tryParse(periodo!['fecha_fin'] as String)
          : null,
      leche: IndicadoresLeche.fromJson(
          json['leche'] as Map<String, dynamic>? ?? const {}),
      huevos: IndicadoresHuevos.fromJson(
          json['huevos'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class IndicadoresLeche {
  final double totalLitros;
  final double promedioLitrosPorRegistro;
  final int cantidadRegistros;
  final int animalesProductivos;

  const IndicadoresLeche({
    required this.totalLitros,
    required this.promedioLitrosPorRegistro,
    required this.cantidadRegistros,
    required this.animalesProductivos,
  });

  factory IndicadoresLeche.fromJson(Map<String, dynamic> json) {
    return IndicadoresLeche(
      totalLitros: (json['total_litros'] as num?)?.toDouble() ?? 0,
      promedioLitrosPorRegistro:
          (json['promedio_litros_por_registro'] as num?)?.toDouble() ?? 0,
      cantidadRegistros: (json['cantidad_registros'] as num?)?.toInt() ?? 0,
      animalesProductivos: (json['animales_productivos'] as num?)?.toInt() ?? 0,
    );
  }
}

class IndicadoresHuevos {
  final int totalUnidades;
  final double promedioUnidadesPorRegistro;
  final int cantidadRegistros;

  const IndicadoresHuevos({
    required this.totalUnidades,
    required this.promedioUnidadesPorRegistro,
    required this.cantidadRegistros,
  });

  factory IndicadoresHuevos.fromJson(Map<String, dynamic> json) {
    return IndicadoresHuevos(
      totalUnidades: (json['total_unidades'] as num?)?.toInt() ?? 0,
      promedioUnidadesPorRegistro:
          (json['promedio_unidades_por_registro'] as num?)?.toDouble() ?? 0,
      cantidadRegistros: (json['cantidad_registros'] as num?)?.toInt() ?? 0,
    );
  }
}
