import 'package:flutter_test/flutter_test.dart';

import 'package:fincas_patitas_movil_app/models/financiera/gasto.dart';
import 'package:fincas_patitas_movil_app/models/financiera/resumen_mes.dart';
import 'package:fincas_patitas_movil_app/models/financiera/venta.dart';

void main() {
  final mes = DateTime(2026, 11, 1);

  Venta venta(int id, double total, String estado,
          {DateTime? pago, DateTime? fecha}) =>
      Venta(
        id: id,
        producto: 'Leche',
        cantidad: 1,
        precioUnitario: total,
        total: total,
        fecha: fecha ?? DateTime(2026, 11, 5),
        estadoPago: estado,
        fechaPago: pago,
      );

  Gasto gasto(int id, double monto, DateTime fecha) =>
      Gasto(id: id, categoria: 'Alimentación', monto: monto, fecha: fecha);

  test('suma solo lo cobrado en el mes y los gastos del mes', () {
    final r = ResumenMes.calcular(
      mes: mes,
      ventas: [
        venta(1, 1000, estadoPagado, pago: DateTime(2026, 11, 10)),
        // Pagada en otro mes: no cuenta en noviembre.
        venta(2, 4000, estadoPagado, pago: DateTime(2026, 10, 30)),
        // Pagada sin fecha de pago: se usa la fecha de la venta.
        venta(3, 500, estadoPagado, fecha: DateTime(2026, 11, 7)),
      ],
      gastos: [
        gasto(1, 300, DateTime(2026, 11, 2)),
        gasto(2, 900, DateTime(2026, 10, 31)),
      ],
    );
    expect(r.ventasCobradas, 1500);
    expect(r.gastos, 300);
    expect(r.cantidadGastos, 1);
    expect(r.diferencia, 1200);
  });

  test('las pendientes de cualquier mes cuentan como por cobrar', () {
    final r = ResumenMes.calcular(
      mes: mes,
      ventas: [
        venta(1, 700, estadoPendiente, fecha: DateTime(2026, 10, 1)),
        venta(2, 300, estadoPendiente),
      ],
      gastos: [],
    );
    expect(r.ventasCobradas, 0);
    expect(r.ventasPorCobrar, 2);
    expect(r.montoPorCobrar, 1000);
  });

  test('margen y gastos sobre ingresos', () {
    final r = ResumenMes.calcular(
      mes: mes,
      ventas: [venta(1, 1000, estadoPagado, pago: DateTime(2026, 11, 3))],
      gastos: [gasto(1, 670, DateTime(2026, 11, 4))],
    );
    expect(r.margenPorcentaje, closeTo(33, 0.001));
    expect(r.gastosSobreIngresos, closeTo(67, 0.001));
  });

  test('sin ventas cobradas no hay porcentajes; el margen puede ser negativo',
      () {
    final sinVentas = ResumenMes.calcular(
      mes: mes,
      ventas: [],
      gastos: [gasto(1, 200, DateTime(2026, 11, 4))],
    );
    expect(sinVentas.margenPorcentaje, isNull);
    expect(sinVentas.gastosSobreIngresos, isNull);
    expect(sinVentas.diferencia, -200);

    final perdida = ResumenMes.calcular(
      mes: mes,
      ventas: [venta(1, 100, estadoPagado, pago: DateTime(2026, 11, 3))],
      gastos: [gasto(1, 150, DateTime(2026, 11, 4))],
    );
    expect(perdida.margenPorcentaje, closeTo(-50, 0.001));
  });
}
