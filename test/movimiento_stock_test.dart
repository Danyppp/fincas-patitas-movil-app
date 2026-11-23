import 'package:flutter_test/flutter_test.dart';
import 'package:fincas_patitas_movil_app/models/inventario/movimiento_stock.dart';

void main() {
  test('MovimientoStock.fromJson lee cantidad como string y relaciones', () {
    final m = MovimientoStock.fromJson({
      'id': 7,
      'tipo': 'Entrada',
      'cantidad': '28.00',
      'origen': 'ProduccionHuevos',
      'motivo': null,
      'fecha': '2026-11-22T15:00:00.000Z',
      'productos_finca': {'nombre': 'Huevos', 'unidad': 'unidades'},
      'usuarios': {'nombre_usuario': 'dany'},
    });
    expect(m.cantidad, 28);
    expect(m.producto, 'Huevos');
    expect(m.usuario, 'dany');
    expect(m.origenTexto, 'Producción de huevos');
  });

  test('MovimientoStock acepta cantidad negativa de un ajuste', () {
    final m = MovimientoStock.fromJson({
      'id': 8,
      'tipo': 'Ajuste',
      'cantidad': '-3.5',
      'origen': 'Manual',
      'motivo': 'Derrame',
      'fecha': '2026-11-22T15:00:00.000Z',
      'productos_finca': {'nombre': 'Leche', 'unidad': 'litros'},
    });
    expect(m.cantidad, -3.5);
    expect(m.usuario, isNull);
    expect(m.origenTexto, 'Ajuste manual');
  });
}
