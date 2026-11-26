import 'package:flutter_test/flutter_test.dart';
import 'package:fincas_patitas_movil_app/models/salud/evento_sanitario.dart';

void main() {
  Map<String, dynamic> jsonBase() => {
        'id': 1,
        'animal_id': 10,
        'tipo_evento': 'Vacunación',
      };

  /// Fecha local "hoy + [dias]" en el formato AAAA-MM-DD que usa el backend.
  String fechaEnDias(int dias) {
    final hoy = DateTime.now();
    final f = DateTime(hoy.year, hoy.month, hoy.day + dias);
    final m = f.month.toString().padLeft(2, '0');
    final d = f.day.toString().padLeft(2, '0');
    return '${f.year}-$m-$d';
  }

  group('EventoSanitario.fromJson', () {
    test('pone el estado Abierto si no llega', () {
      final e = EventoSanitario.fromJson(jsonBase());

      expect(e.estado, 'Abierto');
      expect(e.estaAbierto, isTrue);
    });

    test('convierte la dosis de texto a número', () {
      final e = EventoSanitario.fromJson({
        ...jsonBase(),
        'dosis_aplicada': '2.50',
        'unidad_dosis': 'ml',
      });

      expect(e.dosisAplicada, 2.5);
      expect(e.unidadDosis, 'ml');
    });

    test('la dosis acepta número, y queda null si falta o no es válida', () {
      final numero =
          EventoSanitario.fromJson({...jsonBase(), 'dosis_aplicada': 3});
      final falta = EventoSanitario.fromJson(jsonBase());
      final invalida =
          EventoSanitario.fromJson({...jsonBase(), 'dosis_aplicada': 'abc'});

      expect(numero.dosisAplicada, 3.0);
      expect(falta.dosisAplicada, isNull);
      expect(invalida.dosisAplicada, isNull);
    });

    test('deja las fechas sin hora, como fecha local pura', () {
      // Prisma serializa un @db.Date como instante UTC con "Z".
      final e = EventoSanitario.fromJson({
        ...jsonBase(),
        'fecha_evento': '2026-11-01T00:00:00.000Z',
        'fecha_proximo_refuerzo': '2026-12-15T00:00:00.000Z',
      });

      expect(e.fechaEvento, DateTime(2026, 11, 1));
      expect(e.fechaEvento!.isUtc, isFalse);
      expect(e.fechaEvento!.hour, 0);
      expect(e.fechaProximoRefuerzo, DateTime(2026, 12, 15));
    });

    test('las fechas faltantes quedan en null', () {
      final e = EventoSanitario.fromJson(jsonBase());

      expect(e.fechaEvento, isNull);
      expect(e.fechaProximoRefuerzo, isNull);
    });

    test('lee el historial del evento como lista', () {
      final e = EventoSanitario.fromJson({
        ...jsonBase(),
        'eventos_sanitarios_historial': [
          {
            'accion': 'Creado',
            'fecha': '2026-11-01T10:00:00.000Z',
            'usuarios': {'nombre_usuario': 'dany'},
          },
          {'accion': 'Resuelto', 'fecha': '2026-11-05T09:30:00.000Z'},
        ],
      });

      expect(e.historial, hasLength(2));
      expect(e.historial.first.accion, 'Creado');
      expect(e.historial.first.usuarioNombre, 'dany');
      expect(e.historial.last.usuarioNombre, isNull);
    });

    test('sin historial queda como lista vacía', () {
      final e = EventoSanitario.fromJson(jsonBase());

      expect(e.historial, isEmpty);
    });

    test('un evento con eliminado_en queda marcado como eliminado', () {
      final e = EventoSanitario.fromJson({
        ...jsonBase(),
        'eliminado_en': '2026-11-10T08:00:00.000Z',
        'eliminado_por': {'id': 1, 'nombre_usuario': 'dany'},
        'creado_por': {'id': 1, 'nombre_usuario': 'milena'},
      });

      expect(e.estaEliminado, isTrue);
      expect(e.eliminadoPorNombre, 'dany');
      expect(e.creadoPorNombre, 'milena');
      expect(EventoSanitario.fromJson(jsonBase()).estaEliminado, isFalse);
    });
  });

  group('Estados del evento', () {
    test('Abierto, En tratamiento y Resuelto se reconocen bien', () {
      EventoSanitario evento(String estado) =>
          EventoSanitario.fromJson({...jsonBase(), 'estado': estado});

      final abierto = evento('Abierto');
      final tratamiento = evento('En tratamiento');
      final resuelto = evento('Resuelto');

      expect(abierto.estaAbierto, isTrue);
      expect(abierto.estaEnTratamiento, isFalse);
      expect(tratamiento.estaEnTratamiento, isTrue);
      expect(tratamiento.estaResuelto, isFalse);
      expect(resuelto.estaResuelto, isTrue);
      expect(resuelto.estaAbierto, isFalse);
    });

    test('los tres estados están en la lista de estados válidos', () {
      expect(estadosEventoSanitarioValidos,
          ['Abierto', 'En tratamiento', 'Resuelto']);
    });
  });

  group('diasParaProximoRefuerzo', () {
    EventoSanitario conRefuerzo(int dias) => EventoSanitario.fromJson({
          ...jsonBase(),
          'fecha_proximo_refuerzo': fechaEnDias(dias),
        });

    test('es null si no hay fecha de refuerzo', () {
      expect(
          EventoSanitario.fromJson(jsonBase()).diasParaProximoRefuerzo, isNull);
    });

    test('es positivo si el refuerzo está por venir', () {
      expect(conRefuerzo(5).diasParaProximoRefuerzo, 5);
      expect(conRefuerzo(1).diasParaProximoRefuerzo, 1);
    });

    test('es 0 si el refuerzo es hoy', () {
      expect(conRefuerzo(0).diasParaProximoRefuerzo, 0);
    });

    test('es negativo si el refuerzo ya pasó', () {
      expect(conRefuerzo(-3).diasParaProximoRefuerzo, -3);
    });
  });

  group('CrearEventoSanitarioDTO.toJson', () {
    test('arma el cuerpo con los nombres de campo de la API', () {
      final dto = CrearEventoSanitarioDTO(
        animalId: 10,
        tipoEvento: 'Vacunación',
        dosisAplicada: 2.5,
        descripcionTratamiento: 'Refuerzo anual',
        fechaEvento: DateTime(2026, 11, 1),
        viaAdministracion: 'Intramuscular',
        unidadDosis: 'ml',
        profesionalResponsable: 'Dr. Pérez',
        medicamento: 'Aftosa',
        fechaProximoRefuerzo: DateTime(2027, 5, 1),
      );

      expect(dto.toJson(), {
        'animal_id': 10,
        'tipo_evento': 'Vacunación',
        'dosis_aplicada': 2.5,
        'descripcion_tratamiento': 'Refuerzo anual',
        'fecha_evento': '2026-11-01',
        'via_administracion': 'Intramuscular',
        'unidad_dosis': 'ml',
        'profesional_responsable': 'Dr. Pérez',
        'medicamento': 'Aftosa',
        'fecha_proximo_refuerzo': '2027-05-01',
      });
    });

    test('omite los campos opcionales vacíos o nulos', () {
      const dto = CrearEventoSanitarioDTO(
        animalId: 10,
        tipoEvento: 'Chequeo General',
        descripcionTratamiento: '',
        medicamento: '',
      );

      expect(dto.toJson(), {'animal_id': 10, 'tipo_evento': 'Chequeo General'});
    });
  });

  group('ActualizarEventoSanitarioDTO.toJson', () {
    test('solo envía los campos que cambian', () {
      const dto = ActualizarEventoSanitarioDTO(medicamento: 'Ivermectina');

      expect(dto.toJson(), {'medicamento': 'Ivermectina'});
    });

    test('limpiarProximoRefuerzo envía la fecha en null de forma explícita',
        () {
      const dto = ActualizarEventoSanitarioDTO(limpiarProximoRefuerzo: true);

      final json = dto.toJson();

      expect(json.containsKey('fecha_proximo_refuerzo'), isTrue);
      expect(json['fecha_proximo_refuerzo'], isNull);
    });

    test('si hay una fecha de refuerzo nueva, esa se envía', () {
      final dto = ActualizarEventoSanitarioDTO(
        fechaProximoRefuerzo: DateTime(2027, 1, 20),
        limpiarProximoRefuerzo: true,
      );

      expect(dto.toJson()['fecha_proximo_refuerzo'], '2027-01-20');
    });
  });
}
