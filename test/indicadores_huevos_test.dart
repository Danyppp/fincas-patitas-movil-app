import 'package:flutter_test/flutter_test.dart';
import 'package:fincas_patitas_movil_app/models/produccion/resumen_produccion.dart';

void main() {
  test('IndicadoresHuevos lee rotos y aprovechables del backend', () {
    final h = IndicadoresHuevos.fromJson({
      'total_unidades': 105,
      'promedio_unidades_por_registro': 26.25,
      'cantidad_registros': 4,
      'total_rotos': 10,
      'total_aprovechables': 95,
    });
    expect(h.totalUnidades, 105);
    expect(h.totalRotos, 10);
    expect(h.totalAprovechables, 95);
  });

  test('IndicadoresHuevos vale 0 si el backend no envia el desglose', () {
    final h = IndicadoresHuevos.fromJson({'total_unidades': 20});
    expect(h.totalRotos, 0);
    expect(h.totalAprovechables, 0);
  });
}
