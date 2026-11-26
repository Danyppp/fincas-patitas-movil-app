import 'package:flutter_test/flutter_test.dart';
import 'package:fincas_patitas_movil_app/models/produccion/produccion_huevos.dart';
import 'package:fincas_patitas_movil_app/models/produccion/produccion_leche.dart';
import 'package:fincas_patitas_movil_app/models/produccion/resumen_produccion.dart';

void main() {
  const fecha = '2026-11-23T15:00:00.000Z';

  group('ProduccionHuevos', () {
    test('cantidadBuenos es la cantidad menos los rotos', () {
      final h = ProduccionHuevos.fromJson({
        'id': 1,
        'cantidad': 30,
        'cantidad_rotos': 4,
        'registrado_en': fecha,
      });

      expect(h.cantidad, 30);
      expect(h.cantidadRotos, 4);
      expect(h.cantidadBuenos, 26);
    });

    test('si no llegan rotos se asume 0 y todos son buenos', () {
      final h = ProduccionHuevos.fromJson({
        'id': 2,
        'cantidad': 12,
        'registrado_en': fecha,
      });

      expect(h.cantidadRotos, 0);
      expect(h.cantidadBuenos, 12);
    });

    test('esPorLote depende de si trae lote_id, y lee el nombre del lote', () {
      final porLote = ProduccionHuevos.fromJson({
        'id': 3,
        'lote_id': 7,
        'cantidad': 10,
        'registrado_en': fecha,
        'lotes_animales': {'id': 7, 'nombre': 'Lote Aves #1'},
      });
      final porAnimal = ProduccionHuevos.fromJson({
        'id': 4,
        'animal_id': 9,
        'cantidad': 1,
        'registrado_en': fecha,
      });

      expect(porLote.esPorLote, isTrue);
      expect(porLote.loteNombre, 'Lote Aves #1');
      expect(porAnimal.esPorLote, isFalse);
    });

    test('un registro con eliminado_en queda marcado como eliminado', () {
      final h = ProduccionHuevos.fromJson({
        'id': 5,
        'cantidad': 8,
        'registrado_en': fecha,
        'eliminado_en': '2026-11-24T10:00:00.000Z',
        'eliminado_por': {'id': 1, 'nombre_usuario': 'dany'},
      });

      expect(h.estaEliminado, isTrue);
      expect(h.eliminadoPorNombre, 'dany');
    });
  });

  group('ProduccionLeche.fromJson', () {
    test('lee los litros aunque lleguen como texto (Decimal de Prisma)', () {
      final l = ProduccionLeche.fromJson({
        'id': 1,
        'litros': '12.5',
        'registrado_en': fecha,
      });

      expect(l.litros, 12.5);
    });

    test('también acepta los litros como número', () {
      final l = ProduccionLeche.fromJson({
        'id': 2,
        'litros': 8,
        'registrado_en': fecha,
      });

      expect(l.litros, 8.0);
    });

    test('usa 0 si los litros faltan', () {
      final l = ProduccionLeche.fromJson({
        'id': 3,
        'registrado_en': fecha,
      });

      expect(l.litros, 0);
    });

    test('marca esPorLote cuando viene un lote_id', () {
      final porLote = ProduccionLeche.fromJson({
        'id': 4,
        'lote_id': 3,
        'litros': '20.0',
        'registrado_en': fecha,
        'lotes_animales': {'id': 3, 'nombre': 'Lote Vacas #1'},
      });
      final porAnimal = ProduccionLeche.fromJson({
        'id': 5,
        'animal_id': 12,
        'litros': '6.0',
        'registrado_en': fecha,
        'animales': {'id': 12, 'codigo': 'ANI-0012', 'nombre': 'Lucero'},
      });

      expect(porLote.esPorLote, isTrue);
      expect(porLote.loteNombre, 'Lote Vacas #1');
      expect(porAnimal.esPorLote, isFalse);
      expect(porAnimal.animal?.nombreVisible, 'Lucero');
    });

    test('un registro sin eliminado_en no está eliminado', () {
      final l = ProduccionLeche.fromJson({
        'id': 6,
        'litros': '1.0',
        'registrado_en': fecha,
      });

      expect(l.estaEliminado, isFalse);
    });
  });

  group('ResumenProduccionHoy', () {
    test('totalHuevosHoy suma buenos y rotos', () {
      final r = ResumenProduccionHoy.fromJson({
        'totalLitrosLeche': '25.5',
        'totalHuevosBuenos': 84,
        'totalHuevosRotos': 6,
        'registrosLeche': [],
        'registrosHuevos': [],
      });

      expect(r.totalHuevosHoy, 90);
      expect(r.totalLitrosLeche, 25.5);
    });

    test('hayProduccionHoy es falso cuando no hay registros', () {
      final r = ResumenProduccionHoy.fromJson({
        'totalLitrosLeche': 0,
        'totalHuevosBuenos': 0,
        'totalHuevosRotos': 0,
        'registrosLeche': [],
        'registrosHuevos': [],
        'mensaje': 'Aún no hay producción registrada hoy',
      });

      expect(r.hayProduccionHoy, isFalse);
      expect(r.mensaje, isNotNull);
    });

    test('hayProduccionHoy es verdadero con al menos un registro', () {
      final r = ResumenProduccionHoy.fromJson({
        'totalLitrosLeche': '10.0',
        'totalHuevosBuenos': 0,
        'totalHuevosRotos': 0,
        'registrosLeche': [
          {'id': 1, 'litros': '10.0', 'registrado_en': fecha},
        ],
        'registrosHuevos': [],
      });

      expect(r.hayProduccionHoy, isTrue);
      expect(r.registrosLeche, hasLength(1));
      expect(r.registrosLeche.first.litros, 10.0);
    });

    test('con un JSON vacío todo queda en cero y sin registros', () {
      final r = ResumenProduccionHoy.fromJson({});

      expect(r.totalLitrosLeche, 0);
      expect(r.totalHuevosHoy, 0);
      expect(r.hayProduccionHoy, isFalse);
    });
  });
}
