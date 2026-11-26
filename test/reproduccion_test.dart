import 'package:flutter_test/flutter_test.dart';
import 'package:fincas_patitas_movil_app/models/reproduccion/seguimiento_gestacion.dart';

void main() {
  // JSON mínimo de un seguimiento; cada prueba cambia solo el estado u otros
  // campos que necesita.
  Map<String, dynamic> jsonBase([String? estado]) => {
        'id': 1,
        'animal_id': 10,
        'fecha_inseminacion': '2026-03-05T00:00:00.000Z',
        if (estado != null) 'estado': estado,
      };

  SeguimientoGestacion seguimiento(String estado) =>
      SeguimientoGestacion.fromJson(jsonBase(estado));

  group('Estados del seguimiento', () {
    test('Parida está cerrado y tiene resultado exitoso', () {
      final s = seguimiento('Parida');

      expect(s.estaParida, isTrue);
      expect(s.estaCerrado, isTrue);
      expect(s.esResultadoExitoso, isTrue);
      expect(s.esResultadoFallido, isFalse);
    });

    test('Abortada está cerrado y tiene resultado fallido', () {
      final s = seguimiento('Abortada');

      expect(s.estaAbortada, isTrue);
      expect(s.estaCerrado, isTrue);
      expect(s.esResultadoFallido, isTrue);
      expect(s.esResultadoExitoso, isFalse);
    });

    test('Fallida está cerrado y tiene resultado fallido', () {
      final s = seguimiento('Fallida');

      expect(s.estaFallida, isTrue);
      expect(s.estaCerrado, isTrue);
      expect(s.esResultadoFallido, isTrue);
      expect(s.esResultadoExitoso, isFalse);
    });

    test('Pendiente y Gestante no están cerrados ni tienen resultado', () {
      for (final estado in ['Pendiente', 'Gestante']) {
        final s = seguimiento(estado);

        expect(s.estaCerrado, isFalse, reason: estado);
        expect(s.esResultadoExitoso, isFalse, reason: estado);
        expect(s.esResultadoFallido, isFalse, reason: estado);
      }
      expect(seguimiento('Pendiente').estaPendiente, isTrue);
      expect(seguimiento('Gestante').estaGestante, isTrue);
    });

    test('sin estado en el JSON queda Pendiente', () {
      final s = SeguimientoGestacion.fromJson(jsonBase());

      expect(s.estado, 'Pendiente');
      expect(s.estaPendiente, isTrue);
    });
  });

  group('SeguimientoGestacion.fromJson', () {
    test('un seguimiento con eliminado_en queda marcado como eliminado', () {
      final eliminado = SeguimientoGestacion.fromJson({
        ...jsonBase('Gestante'),
        'eliminado_en': '2026-04-01T10:00:00.000Z',
        'eliminado_por': {'id': 3, 'nombre_usuario': 'dany'},
      });
      final activo = seguimiento('Gestante');

      expect(eliminado.estaEliminado, isTrue);
      expect(eliminado.eliminadoPor?.nombreUsuario, 'dany');
      expect(activo.estaEliminado, isFalse);
      expect(activo.eliminadoPor, isNull);
    });

    test('lee el animal y el macho anidados con su especie', () {
      final s = SeguimientoGestacion.fromJson({
        ...jsonBase('Pendiente'),
        'macho_id': 11,
        'animales': {
          'id': 10,
          'codigo': 'ANI-0010',
          'nombre': '',
          'especies': {'id': 2, 'nombre': 'Bovino'},
        },
        'macho': {'id': 11, 'codigo': 'ANI-0011', 'nombre': 'Toro'},
      });

      expect(s.animal?.especieNombre, 'Bovino');
      // Nombre vacío: se muestra el código.
      expect(s.animal?.nombreVisible, 'ANI-0010');
      expect(s.macho?.nombreVisible, 'Toro');
      expect(s.macho?.especieNombre, isNull);
    });
  });

  group('CrearSeguimientoDTO.toJson', () {
    test('envía fecha_inseminacion como AAAA-MM-DD', () {
      final dto = CrearSeguimientoDTO(
        animalId: 10,
        fechaInseminacion: DateTime(2026, 3, 5),
        fechaEstimadaParto: DateTime(2026, 12, 14),
      );

      final json = dto.toJson();

      expect(json['animal_id'], 10);
      expect(json['fecha_inseminacion'], '2026-03-05');
      expect(json['fecha_estimada_parto'], '2026-12-14');
    });

    test('omite macho_id, tipo y notas si van vacíos', () {
      final dto = CrearSeguimientoDTO(
        animalId: 10,
        fechaInseminacion: DateTime(2026, 3, 5),
        notas: '',
      );

      final json = dto.toJson();

      expect(json.containsKey('macho_id'), isFalse);
      expect(json.containsKey('tipo'), isFalse);
      expect(json.containsKey('notas'), isFalse);
      expect(json.containsKey('fecha_estimada_parto'), isFalse);
    });

    test('envía macho_id, tipo y notas cuando traen valor', () {
      final dto = CrearSeguimientoDTO(
        animalId: 10,
        fechaInseminacion: DateTime(2026, 3, 5),
        machoId: 11,
        tipo: 'IA',
        notas: 'Primera monta',
      );

      final json = dto.toJson();

      expect(json['macho_id'], 11);
      expect(json['tipo'], 'IA');
      expect(json['notas'], 'Primera monta');
    });
  });

  group('CerrarSeguimientoDTO.toJson', () {
    test('envía el resultado y la fecha real de parto como AAAA-MM-DD', () {
      final dto = CerrarSeguimientoDTO(
        resultado: 'Parida',
        fechaRealParto: DateTime(2026, 12, 20),
      );

      expect(dto.toJson(), {
        'resultado': 'Parida',
        'fecha_real_parto': '2026-12-20',
      });
    });

    test('para Fallida solo envía el resultado si no hay fecha ni notas', () {
      const dto = CerrarSeguimientoDTO(resultado: 'Fallida', notas: '');

      expect(dto.toJson(), {'resultado': 'Fallida'});
      expect(resultadosCierreValidos, contains('Fallida'));
    });
  });
}
