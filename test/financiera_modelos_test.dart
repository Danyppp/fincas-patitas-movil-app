// Pruebas de los modelos de Financiera (Etapa 1).
//
// Los JSON de ejemplo tienen la misma forma que devuelve el backend real:
// los Decimal de Prisma llegan como TEXTO ("10000"), y las columnas DATE
// llegan como medianoche UTC ("2020-01-10T00:00:00.000Z"). Estas pruebas no
// dependen de la zona horaria del equipo donde se corran.

import 'package:flutter_test/flutter_test.dart';

import 'package:fincas_patitas_movil_app/models/financiera/balance.dart';
import 'package:fincas_patitas_movil_app/models/financiera/gasto.dart';
import 'package:fincas_patitas_movil_app/models/financiera/precio_mercado.dart';
import 'package:fincas_patitas_movil_app/models/financiera/venta.dart';
import 'package:fincas_patitas_movil_app/utils/fecha_dia.dart';

void main() {
  group('FechaDia', () {
    test('lee la fecha sin correrla de día', () {
      expect(FechaDia.parse('2020-01-10T00:00:00.000Z'), DateTime(2020, 1, 10));
      expect(FechaDia.parse('2020-01-10'), DateTime(2020, 1, 10));
    });

    test('devuelve null si no hay fecha o no es válida', () {
      expect(FechaDia.parse(null), isNull);
      expect(FechaDia.parse('no es una fecha'), isNull);
      expect(() => FechaDia.parseRequerida(null), throwsFormatException);
    });

    test('formatea como AAAA-MM-DD sin hora ni zona', () {
      expect(FechaDia.formatear(DateTime(2026, 9, 5)), '2026-09-05');
    });

    test('suma días de calendario cruzando el mes', () {
      expect(
          FechaDia.sumarDias(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
      expect(
          FechaDia.sumarDias(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });
  });

  group('Gasto', () {
    test('lee un gasto con medio de pago', () {
      final gasto = Gasto.fromJson({
        'id': 3,
        'categoria': 'Prueba Etapa0',
        'descripcion': 'Gasto de prueba',
        'monto': '10000',
        'fecha': '2020-01-05T00:00:00.000Z',
        'metodo_pago': 'Efectivo',
        'creado_en': '2026-11-19T20:00:00.000Z',
      });
      expect(gasto.id, 3);
      expect(gasto.monto, 10000.0);
      expect(gasto.fecha, DateTime(2020, 1, 5));
      expect(gasto.metodoPago, 'Efectivo');
    });

    test('lee un gasto antiguo sin medio de pago ni descripción', () {
      final gasto = Gasto.fromJson({
        'id': 1,
        'categoria': 'Alimento',
        'descripcion': null,
        'monto': '180000.00',
        'fecha': '2026-09-10T00:00:00.000Z',
        'metodo_pago': null,
      });
      expect(gasto.monto, 180000.0);
      expect(gasto.metodoPago, isNull);
      expect(gasto.descripcion, isNull);
    });

    test('el DTO de crear envía la fecha como AAAA-MM-DD', () {
      final json = CrearGastoDTO(
        categoria: 'Alimento',
        monto: 5000,
        fecha: DateTime(2026, 11, 20),
        metodoPago: 'Transferencia',
      ).toJson();
      expect(json['fecha'], '2026-11-20');
      expect(json['metodo_pago'], 'Transferencia');
      expect(json.containsKey('descripcion'), isFalse);
    });
  });

  group('Venta', () {
    final jsonPendiente = {
      'id': 3,
      'producto': 'Huevos',
      'cantidad': '4',
      'precio_unitario': '1000',
      'total': '4000',
      'comprador': null,
      'fecha': '2020-01-12T00:00:00.000Z',
      'estado_pago': 'Pendiente',
      'fecha_pago': null,
      'fecha_limite_pago': '2020-01-19T00:00:00.000Z',
    };

    test('lee una venta pendiente con fecha límite', () {
      final venta = Venta.fromJson(jsonPendiente);
      expect(venta.total, 4000.0);
      expect(venta.estaPendiente, isTrue);
      expect(venta.fechaPago, isNull);
      expect(venta.fechaLimitePago, DateTime(2020, 1, 19));
    });

    test('"Vencida" se deduce: solo cuando hoy es posterior al límite', () {
      final venta = Venta.fromJson(jsonPendiente);
      expect(venta.estaVencida(hoy: DateTime(2020, 1, 19)), isFalse);
      expect(venta.estaVencida(hoy: DateTime(2020, 1, 20)), isTrue);
    });

    test('lee una venta pagada y nunca está vencida', () {
      final venta = Venta.fromJson({
        'id': 2,
        'producto': 'Huevos',
        'cantidad': '10',
        'precio_unitario': '500',
        'total': '5000',
        'comprador': 'Tienda',
        'fecha': '2020-01-10T00:00:00.000Z',
        'estado_pago': 'Pagado',
        'fecha_pago': '2020-01-10T00:00:00.000Z',
        'fecha_limite_pago': null,
      });
      expect(venta.estaPagada, isTrue);
      expect(venta.fechaPago, DateTime(2020, 1, 10));
      expect(venta.estaVencida(hoy: DateTime(2030, 1, 1)), isFalse);
    });

    test('el DTO de crear nunca envía total', () {
      final json = CrearVentaDTO(
        producto: 'Leche',
        cantidad: 50,
        precioUnitario: 2000,
        fecha: DateTime(2026, 11, 20),
      ).toJson();
      expect(json.containsKey('total'), isFalse);
      expect(json.containsKey('estado_pago'), isFalse);
      expect(json['fecha'], '2026-11-20');
    });

    test('"Marcar como pagada" envía estado y fecha de pago explícita', () {
      final json = ActualizarVentaDTO(
        estadoPago: estadoPagado,
        fechaPago: DateTime(2026, 11, 20),
      ).toJson();
      expect(json, {'estado_pago': 'Pagado', 'fecha_pago': '2026-11-20'});
    });
  });

  group('PrecioMercado', () {
    test('lee el precio y deriva la unidad del producto', () {
      final leche = PrecioMercado.fromJson({
        'id': 2,
        'producto': 'Leche',
        'precio': '2200',
        'fecha': '2026-11-16T00:00:00.000Z',
      });
      expect(leche.precio, 2200.0);
      expect(leche.fecha, DateTime(2026, 11, 16));
      expect(leche.unidad, 'L');

      final huevos = PrecioMercado(
          id: 3,
          producto: 'huevos AA',
          precio: 500,
          fecha: DateTime(2026, 11, 16));
      expect(huevos.unidad, 'unid.');

      final otro = PrecioMercado(
          id: 4, producto: 'Queso', precio: 100, fecha: DateTime(2026, 11, 16));
      expect(otro.unidad, '');
    });
  });

  group('Balance', () {
    final jsonConRango = {
      'id': 2,
      'periodo': '2020-01-01T00:00:00.000Z',
      'total_ventas': '5000',
      'total_gastos': '10000',
      'balance_neto': '-5000',
      'fecha_inicio': '2020-01-01T00:00:00.000Z',
      'fecha_fin': '2020-01-31T00:00:00.000Z',
    };

    test('lee los totales (texto) y el rango', () {
      final balance = Balance.fromJson(jsonConRango);
      expect(balance.totalVentas, 5000.0);
      expect(balance.totalGastos, 10000.0);
      expect(balance.balanceNeto, -5000.0);
      expect(balance.fechaInicio, DateTime(2020, 1, 1));
      expect(balance.fechaFin, DateTime(2020, 1, 31));
    });

    test('"En curso" hasta el último día del rango, "Cerrado" después', () {
      final balance = Balance.fromJson(jsonConRango);
      expect(balance.estado(hoy: DateTime(2020, 1, 31)), EstadoBalance.enCurso);
      expect(balance.estado(hoy: DateTime(2020, 2, 1)), EstadoBalance.cerrado);
    });

    test('un balance antiguo sin fechas queda "sin rango"', () {
      final balance = Balance.fromJson({
        'id': 1,
        'periodo': '2026-09-01T00:00:00.000Z',
        'total_ventas': '100000',
        'total_gastos': '65000',
        'balance_neto': '35000',
        'fecha_inicio': null,
        'fecha_fin': null,
      });
      expect(
          balance.estado(hoy: DateTime(2026, 11, 20)), EstadoBalance.sinRango);
    });

    test('el DTO de generar envía las tres fechas como AAAA-MM-DD', () {
      final json = GenerarBalanceDTO(
        periodo: DateTime(2026, 11, 1),
        fechaInicio: DateTime(2026, 11, 1),
        fechaFin: DateTime(2026, 11, 30),
      ).toJson();
      expect(json, {
        'periodo': '2026-11-01',
        'fecha_inicio': '2026-11-01',
        'fecha_fin': '2026-11-30',
      });
    });
  });
}
