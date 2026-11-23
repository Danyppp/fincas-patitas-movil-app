import '../../utils/fecha_dia.dart';

/// Estado de un balance, DEDUCIDO de sus fechas (no se guarda en la base):
/// - [enCurso]: la fecha fin todavía no ha pasado (hoy <= fecha fin).
/// - [cerrado]: la fecha fin ya pasó.
/// - [sinRango]: balances generados antes de la Etapa 0 de Financiera
///   (2026-11-19), que no guardaron fecha inicio ni fecha fin.
enum EstadoBalance { enCurso, cerrado, sinRango }

/// Modelo de la tabla real `balance` (`/api/balance`).
///
/// Un balance es una "foto fija": al generarlo, el backend suma las ventas
/// Pagadas (por fecha de pago) y los gastos (por fecha) del rango y guarda
/// solo esos totales. No cambia después aunque se editen ventas o gastos,
/// y no se puede editar ni eliminar desde la API.
///
/// - Los totales son Decimal en Prisma: llegan como STRING en el JSON.
/// - `periodo`, `fechaInicio` y `fechaFin` son fechas de calendario
///   (columnas `DATE`): se leen con [FechaDia].
class Balance {
  final int id;
  final DateTime periodo;
  final double totalVentas;
  final double totalGastos;
  final double balanceNeto;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  const Balance({
    required this.id,
    required this.periodo,
    required this.totalVentas,
    required this.totalGastos,
    required this.balanceNeto,
    this.fechaInicio,
    this.fechaFin,
  });

  /// Ver [EstadoBalance]. [hoy] solo se pasa en pruebas; por defecto se
  /// usa el día local actual.
  EstadoBalance estado({DateTime? hoy}) {
    final fin = fechaFin;
    if (fechaInicio == null || fin == null) return EstadoBalance.sinRango;
    final dia = FechaDia.soloDia(hoy ?? FechaDia.hoy());
    return dia.isAfter(fin) ? EstadoBalance.cerrado : EstadoBalance.enCurso;
  }

  factory Balance.fromJson(Map<String, dynamic> json) {
    return Balance(
      id: json['id'] as int,
      periodo: FechaDia.parseRequerida(json['periodo']),
      totalVentas: _parseDouble(json['total_ventas']) ?? 0,
      totalGastos: _parseDouble(json['total_gastos']) ?? 0,
      balanceNeto: _parseDouble(json['balance_neto']) ?? 0,
      fechaInicio: FechaDia.parse(json['fecha_inicio']),
      fechaFin: FechaDia.parse(json['fecha_fin']),
    );
  }

  static double? _parseDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }
}

/// DTO para `POST /api/balance/generar`. [periodo] es la fecha
/// representativa del período (por ejemplo, el primer día del mes). El
/// backend responde 400 si alguna fecha no es válida o si [fechaFin] es
/// anterior a [fechaInicio]; la app valida lo mismo antes de enviar.
class GenerarBalanceDTO {
  final DateTime periodo;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  const GenerarBalanceDTO({
    required this.periodo,
    required this.fechaInicio,
    required this.fechaFin,
  });

  Map<String, dynamic> toJson() => {
        'periodo': FechaDia.formatear(periodo),
        'fecha_inicio': FechaDia.formatear(fechaInicio),
        'fecha_fin': FechaDia.formatear(fechaFin),
      };
}
