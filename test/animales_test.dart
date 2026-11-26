import 'package:flutter_test/flutter_test.dart';
import 'package:fincas_patitas_movil_app/models/animal.dart';

void main() {
  // JSON mínimo con solo los campos obligatorios de la tabla `animales`.
  Map<String, dynamic> jsonBase() => {
        'id': 1,
        'codigo': 'ANI-0001',
        'genero': 'Hembra',
        'especie_id': 2,
        'raza_id': 5,
      };

  group('Animal.fromJson', () {
    test('lee la especie, la raza y el nombre del lote anidados', () {
      final animal = Animal.fromJson({
        ...jsonBase(),
        'nombre': 'Lucero',
        'estado': 'Activo',
        'lote_id': 7,
        'especies': {'id': 2, 'nombre': 'Bovino'},
        'razas': {'id': 5, 'especie_id': 2, 'nombre': 'Holstein'},
        'lotes_animales': {'id': 7, 'nombre': 'Lote Vacas #1'},
      });

      expect(animal.especie?.nombre, 'Bovino');
      expect(animal.raza?.nombre, 'Holstein');
      expect(animal.raza?.especieId, 2);
      expect(animal.loteNombre, 'Lote Vacas #1');
      expect(animal.loteId, 7);
    });

    test('pone el estado Activo si no llega y deja las fechas en null', () {
      final animal = Animal.fromJson(jsonBase());

      expect(animal.estado, 'Activo');
      expect(animal.fechaNacimiento, isNull);
      expect(animal.fechaIngreso, isNull);
      expect(animal.especie, isNull);
      expect(animal.raza, isNull);
      expect(animal.loteNombre, isNull);
    });

    test('convierte las fechas de texto cuando sí llegan', () {
      final animal = Animal.fromJson({
        ...jsonBase(),
        'fecha_nacimiento': '2024-03-15T00:00:00.000Z',
        'fecha_ingreso': '2025-01-10',
      });

      expect(animal.fechaNacimiento, isNotNull);
      expect(animal.fechaNacimiento!.year, 2024);
      expect(animal.fechaIngreso, DateTime.parse('2025-01-10'));
    });
  });

  group('Animal.nombreVisible', () {
    test('devuelve el nombre cuando existe', () {
      final animal = Animal.fromJson({...jsonBase(), 'nombre': 'Lucero'});
      expect(animal.nombreVisible, 'Lucero');
    });

    test('devuelve el código si no tiene nombre', () {
      final animal = Animal.fromJson(jsonBase());
      expect(animal.nombreVisible, 'ANI-0001');
    });

    test('devuelve el código si el nombre viene vacío', () {
      final animal = Animal.fromJson({...jsonBase(), 'nombre': ''});
      expect(animal.nombreVisible, 'ANI-0001');
    });
  });

  group('CrearAnimalDTO.toJson', () {
    test('no envía el nombre ni el origen vacíos, ni los campos nulos', () {
      const dto = CrearAnimalDTO(
        genero: 'Macho',
        especieId: 2,
        razaId: 5,
        nombre: '',
        origen: '',
      );

      final json = dto.toJson();

      expect(json, {'genero': 'Macho', 'especie_id': 2, 'raza_id': 5});
      expect(json.containsKey('nombre'), isFalse);
      expect(json.containsKey('origen'), isFalse);
      expect(json.containsKey('lote_id'), isFalse);
      expect(json.containsKey('codigo'), isFalse);
    });

    test('envía los campos opcionales cuando traen valor', () {
      final dto = CrearAnimalDTO(
        genero: 'Hembra',
        especieId: 2,
        razaId: 5,
        nombre: 'Lucero',
        origen: 'Compra',
        loteId: 7,
        madreId: 3,
        fechaNacimiento: DateTime.utc(2024, 3, 15),
      );

      final json = dto.toJson();

      expect(json['nombre'], 'Lucero');
      expect(json['origen'], 'Compra');
      expect(json['lote_id'], 7);
      expect(json['madre_id'], 3);
      expect(json['fecha_nacimiento'],
          DateTime.utc(2024, 3, 15).toIso8601String());
      expect(json.containsKey('potrero_id'), isFalse);
    });
  });

  group('ActualizarAnimalDTO.toJson', () {
    test('siempre envía lote, potrero, madre y padre aunque sean null', () {
      const dto = ActualizarAnimalDTO();

      final json = dto.toJson();

      // Así el usuario puede quitar la relación ("Sin asignar").
      expect(json.containsKey('lote_id'), isTrue);
      expect(json.containsKey('potrero_id'), isTrue);
      expect(json.containsKey('madre_id'), isTrue);
      expect(json.containsKey('padre_id'), isTrue);
      expect(json['lote_id'], isNull);
      expect(json['potrero_id'], isNull);
      expect(json['madre_id'], isNull);
      expect(json['padre_id'], isNull);
    });

    test('omite los demás campos cuando no cambian', () {
      const dto = ActualizarAnimalDTO(estado: 'Vendido', peso: 450.5);

      final json = dto.toJson();

      expect(json['estado'], 'Vendido');
      expect(json['peso'], 450.5);
      expect(json.containsKey('nombre'), isFalse);
      expect(json.containsKey('genero'), isFalse);
      expect(json.containsKey('especie_id'), isFalse);
    });
  });
}
