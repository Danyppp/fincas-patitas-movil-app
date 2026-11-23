import 'package:flutter_test/flutter_test.dart';

import 'package:fincas_patitas_movil_app/models/financiera/producto_stock.dart';

void main() {
  group('ProductoStock.fromJson', () {
    test('lee el stock que llega como string (Decimal de Prisma)', () {
      final p = ProductoStock.fromJson({
        'id': 2,
        'nombre': 'Leche',
        'unidad': 'litros',
        'stock_actual': '12.5',
      });
      expect(p.id, 2);
      expect(p.nombre, 'Leche');
      expect(p.unidad, 'litros');
      expect(p.stockActual, 12.5);
    });

    test('acepta el stock como número y usa 0 si falta', () {
      final a = ProductoStock.fromJson({
        'id': 1,
        'nombre': 'Huevos',
        'unidad': 'unidades',
        'stock_actual': 100,
      });
      final b = ProductoStock.fromJson({
        'id': 1,
        'nombre': 'Huevos',
        'unidad': 'unidades',
      });
      expect(a.stockActual, 100);
      expect(b.stockActual, 0);
    });
  });
}
