import 'gasto.dart';
import 'venta.dart';

/// Resumen financiero de un mes, calculado con la misma regla que usa el
/// balance del backend:
/// - Ventas cobradas: ventas `Pagado` cuya fecha de pago cae en el mes (si
///   una venta pagada no trae fecha de pago, se usa la fecha de la venta).
/// - Gastos: los gastos cuya fecha cae en el mes.
/// - Diferencia: ventas cobradas - gastos.
///
/// Lo usan Inicio de Finanzas y Gastos y Ventas para mostrar los mismos
/// números. No guarda nada: es solo una vista de los datos del mes.
class ResumenMes {
  final double ventasCobradas;
  final double gastos;
  final int cantidadGastos;

  /// Ventas pendientes de pago (de cualquier mes: es plata por cobrar).
  final int ventasPorCobrar;
  final double montoPorCobrar;

  const ResumenMes({
    required this.ventasCobradas,
    required this.gastos,
    required this.cantidadGastos,
    required this.ventasPorCobrar,
    required this.montoPorCobrar,
  });

  double get diferencia => ventasCobradas - gastos;

  /// Diferencia sobre ventas cobradas, en porcentaje (puede ser negativo).
  /// null si no hay ventas cobradas (no se puede calcular).
  double? get margenPorcentaje =>
      ventasCobradas > 0 ? diferencia / ventasCobradas * 100 : null;

  /// Qué parte de lo cobrado se fue en gastos, en porcentaje. null si no hay
  /// ventas cobradas.
  double? get gastosSobreIngresos =>
      ventasCobradas > 0 ? gastos / ventasCobradas * 100 : null;

  static bool _enMes(DateTime fecha, DateTime mes) =>
      fecha.year == mes.year && fecha.month == mes.month;

  static ResumenMes calcular({
    required List<Venta> ventas,
    required List<Gasto> gastos,
    required DateTime mes,
  }) {
    var cobradas = 0.0;
    var porCobrar = 0;
    var montoPorCobrar = 0.0;
    for (final v in ventas) {
      if (v.estaPagada) {
        if (_enMes(v.fechaPago ?? v.fecha, mes)) cobradas += v.total;
      } else if (v.estaPendiente) {
        porCobrar++;
        montoPorCobrar += v.total;
      }
    }

    var totalGastos = 0.0;
    var cantidad = 0;
    for (final g in gastos) {
      if (_enMes(g.fecha, mes)) {
        totalGastos += g.monto;
        cantidad++;
      }
    }

    return ResumenMes(
      ventasCobradas: cobradas,
      gastos: totalGastos,
      cantidadGastos: cantidad,
      ventasPorCobrar: porCobrar,
      montoPorCobrar: montoPorCobrar,
    );
  }
}
