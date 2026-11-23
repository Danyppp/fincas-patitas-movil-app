import '../../utils/fecha_dia.dart';
import 'gasto.dart';
import 'venta.dart';

/// Estimación preliminar de un balance (pantalla "Generar balance").
///
/// Aplica en el teléfono la misma regla que usa el backend al generar el
/// balance (`POST /balance/generar`):
/// - Ventas: solo las `Pagado`, sumadas por su fecha de pago, dentro del
///   rango (inicio y fin incluidos). Las pendientes no cuentan.
/// - Gastos: sumados por su fecha, dentro del rango.
///
/// Es solo una vista previa: el balance real lo calcula y guarda el
/// servidor.
class EstimacionBalance {
  final double ventas;
  final double gastos;
  final int dias;

  const EstimacionBalance({
    required this.ventas,
    required this.gastos,
    required this.dias,
  });

  double get neto => ventas - gastos;

  static EstimacionBalance calcular({
    required List<Venta> ventas,
    required List<Gasto> gastos,
    required DateTime inicio,
    required DateTime fin,
  }) {
    final desde = FechaDia.soloDia(inicio);
    final hasta = FechaDia.soloDia(fin);

    bool enRango(DateTime fecha) {
      final dia = FechaDia.soloDia(fecha);
      return !dia.isBefore(desde) && !dia.isAfter(hasta);
    }

    var totalVentas = 0.0;
    for (final v in ventas) {
      final pago = v.fechaPago;
      if (v.estaPagada && pago != null && enRango(pago)) totalVentas += v.total;
    }

    var totalGastos = 0.0;
    for (final g in gastos) {
      if (enRango(g.fecha)) totalGastos += g.monto;
    }

    // Se cuentan los días con fechas UTC para que no influya el horario.
    final dias = DateTime.utc(hasta.year, hasta.month, hasta.day)
            .difference(DateTime.utc(desde.year, desde.month, desde.day))
            .inDays +
        1;

    return EstimacionBalance(
      ventas: totalVentas,
      gastos: totalGastos,
      dias: dias < 0 ? 0 : dias,
    );
  }
}
