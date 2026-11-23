// Pruebas de los cálculos de la Etapa 4 de Financiera: valor estimado de la
// producción de hoy y estimación preliminar de un balance.
//
// Todas las fechas se construyen en hora LOCAL del equipo (DateTime(y, m, d,
// h)), así que las pruebas no dependen de la zona horaria donde se corran.

import 'package:flutter_test/flutter_test.dart';

import 'package:fincas_patitas_movil_app/models/financiera/estimacion_balance.dart';
import 'package:fincas_patitas_movil_app/models/financiera/gasto.dart';
import 'package:fincas_patitas_movil_app/models/financiera/precio_mercado.dart';
import 'package:fincas_patitas_movil_app/models/financiera/valor_estimado.dart';
import 'package:fincas_patitas_movil_app/models/financiera/venta.dart';
import 'package:fincas_patitas_movil_app/models/produccion/produccion_huevos.dart';
import 'package:fincas_patitas_movil_app/models/produccion/produccion_leche.dart';

void main() {
  final hoy = DateTime(2026, 11, 22);

  PrecioMercado precio(int id, String producto, double valor, DateTime fecha) =>
      PrecioMercado(id: id, producto: producto, precio: valor, fecha: fecha);

  group('ValorEstimadoHoy', () {
    test('suma litros de hoy y huevos sin rotos, por el último precio', () {
      final r = ValorEstimadoHoy.calcular(
        hoy: hoy,
        leche: [
          ProduccionLeche(
              id: 1, litros: 4.5, registradoEn: DateTime(2026, 11, 22, 6)),
          ProduccionLeche(
              id: 2, litros: 5.5, registradoEn: DateTime(2026, 11, 22, 17)),
          // Ayer: no cuenta.
          ProduccionLeche(
              id: 3, litros: 20, registradoEn: DateTime(2026, 11, 21, 23, 59)),
        ],
        huevos: [
          ProduccionHuevos(
              id: 1,
              cantidad: 10,
              cantidadRotos: 2,
              registradoEn: DateTime(2026, 11, 22, 8)),
        ],
        precios: [
          precio(1, 'Leche', 2500, DateTime(2026, 11, 1)),
          precio(2, 'Huevos', 500, DateTime(2026, 11, 1)),
        ],
      );
      expect(r.litrosHoy, 10);
      expect(r.huevosHoy, 8);
      expect(r.valorLeche, 25000);
      expect(r.valorHuevos, 4000);
      expect(r.total, 29000);
    });

    test('ignora los registros eliminados', () {
      final r = ValorEstimadoHoy.calcular(
        hoy: hoy,
        leche: [
          ProduccionLeche(
              id: 1,
              litros: 10,
              registradoEn: DateTime(2026, 11, 22, 6),
              eliminadoEn: DateTime(2026, 11, 22, 7)),
        ],
        huevos: [
          ProduccionHuevos(
              id: 1,
              cantidad: 30,
              registradoEn: DateTime(2026, 11, 22, 8),
              eliminadoEn: DateTime(2026, 11, 22, 9)),
        ],
        precios: [precio(1, 'Leche', 2500, DateTime(2026, 11, 1))],
      );
      expect(r.litrosHoy, 0);
      expect(r.huevosHoy, 0);
      expect(r.total, 0);
    });

    test('los huevos rotos nunca restan: si hay más rotos que huevos, aporta 0',
        () {
      final r = ValorEstimadoHoy.calcular(
        hoy: hoy,
        leche: [],
        huevos: [
          ProduccionHuevos(
              id: 1,
              cantidad: 3,
              cantidadRotos: 5,
              registradoEn: DateTime(2026, 11, 22, 8)),
          ProduccionHuevos(
              id: 2, cantidad: 6, registradoEn: DateTime(2026, 11, 22, 9)),
        ],
        precios: [precio(1, 'Huevos', 500, DateTime(2026, 11, 1))],
      );
      expect(r.huevosHoy, 6);
    });

    test('usa el precio más reciente; con la misma fecha gana el id mayor', () {
      final r = ValorEstimadoHoy.calcular(
        hoy: hoy,
        leche: [
          ProduccionLeche(
              id: 1, litros: 10, registradoEn: DateTime(2026, 11, 22, 6)),
        ],
        huevos: [],
        precios: [
          precio(1, 'Leche', 2200, DateTime(2026, 9, 15)),
          precio(2, 'Leche', 5000, DateTime(2026, 11, 22)),
          precio(3, 'Leche', 5250, DateTime(2026, 11, 22)),
        ],
      );
      expect(r.precioLeche!.id, 3);
      expect(r.valorLeche, 52500);
    });

    test('un producto sin precio no tiene valor y no suma al total', () {
      final r = ValorEstimadoHoy.calcular(
        hoy: hoy,
        leche: [
          ProduccionLeche(
              id: 1, litros: 10, registradoEn: DateTime(2026, 11, 22, 6)),
        ],
        huevos: [
          ProduccionHuevos(
              id: 1, cantidad: 4, registradoEn: DateTime(2026, 11, 22, 8)),
        ],
        precios: [precio(1, 'Huevos', 500, DateTime(2026, 11, 1))],
      );
      expect(r.precioLeche, isNull);
      expect(r.valorLeche, isNull);
      expect(r.litrosHoy, 10);
      expect(r.total, 2000);
    });

    test(
        'reconoce el producto por coincidencia parcial sin distinguir '
        'mayúsculas', () {
      final precios = [
        precio(1, 'LECHE fresca', 3000, DateTime(2026, 11, 1)),
        precio(2, 'Huevo criollo', 700, DateTime(2026, 11, 1)),
        precio(3, 'Cerdo', 9000, DateTime(2026, 11, 1)),
      ];
      expect(ValorEstimadoHoy.ultimoPrecio(precios, 'leche')!.id, 1);
      expect(ValorEstimadoHoy.ultimoPrecio(precios, 'huevo')!.id, 2);
      expect(ValorEstimadoHoy.ultimoPrecio(precios, 'queso'), isNull);
    });
  });

  group('EstimacionBalance', () {
    Venta venta(int id, double total, String estado,
            {DateTime? pago, DateTime? fecha}) =>
        Venta(
          id: id,
          producto: 'Leche',
          cantidad: 1,
          precioUnitario: total,
          total: total,
          fecha: fecha ?? DateTime(2026, 11, 1),
          estadoPago: estado,
          fechaPago: pago,
        );

    Gasto gasto(int id, double monto, DateTime fecha) =>
        Gasto(id: id, categoria: 'Alimentación', monto: monto, fecha: fecha);

    test('suma ventas pagadas por fecha de pago y gastos por fecha', () {
      final e = EstimacionBalance.calcular(
        inicio: DateTime(2026, 11, 1),
        fin: DateTime(2026, 11, 15),
        ventas: [
          venta(1, 1000, estadoPagado, pago: DateTime(2026, 11, 1)),
          venta(2, 2000, estadoPagado, pago: DateTime(2026, 11, 15)),
          // Pagada fuera del rango, aunque se vendió dentro: no cuenta.
          venta(3, 4000, estadoPagado,
              pago: DateTime(2026, 11, 16), fecha: DateTime(2026, 11, 10)),
          // Pendiente: no cuenta.
          venta(4, 8000, estadoPendiente, fecha: DateTime(2026, 11, 5)),
          // Pagada sin fecha de pago: el backend no la suma.
          venta(5, 16000, estadoPagado),
        ],
        gastos: [
          gasto(1, 500, DateTime(2026, 11, 1)),
          gasto(2, 700, DateTime(2026, 11, 15)),
          gasto(3, 900, DateTime(2026, 10, 31)),
          gasto(4, 1100, DateTime(2026, 11, 16)),
        ],
      );
      expect(e.ventas, 3000);
      expect(e.gastos, 1200);
      expect(e.neto, 1800);
      expect(e.dias, 15);
    });

    test('un día solo cuenta como 1 día y el neto puede ser negativo', () {
      final e = EstimacionBalance.calcular(
        inicio: DateTime(2026, 11, 22),
        fin: DateTime(2026, 11, 22),
        ventas: [],
        gastos: [gasto(1, 300, DateTime(2026, 11, 22))],
      );
      expect(e.dias, 1);
      expect(e.neto, -300);
    });

    test('cuenta los días de un rango que cruza meses', () {
      final e = EstimacionBalance.calcular(
        inicio: DateTime(2026, 10, 25),
        fin: DateTime(2026, 11, 5),
        ventas: [],
        gastos: [],
      );
      expect(e.dias, 12);
    });
  });
}
