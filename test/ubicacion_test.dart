import 'package:flutter_test/flutter_test.dart';
import 'package:fincas_patitas_movil_app/models/catalogo/lote_animal.dart';
import 'package:fincas_patitas_movil_app/models/catalogo/potrero.dart';

void main() {
  Map<String, dynamic> usuario(int id, String nombre) => {
        'id': id,
        'nombre_usuario': nombre,
        'correo_electronico': '$nombre@correo.com',
      };

  group('LoteAnimal.fromJson', () {
    test('lee un lote mínimo y deja los opcionales en null', () {
      final l = LoteAnimal.fromJson({'id': 1, 'nombre': 'Lote A'});

      expect(l.id, 1);
      expect(l.nombre, 'Lote A');
      expect(l.especie, isNull);
      expect(l.encargado, isNull);
      expect(l.fechaCreacion, isNull);
      expect(l.capacidadEstimada, isNull);
      expect(l.toString(), 'Lote A');
    });

    test('toma la cantidad de animales desde _count.animales', () {
      final l = LoteAnimal.fromJson({
        'id': 1,
        'nombre': 'Lote A',
        '_count': {'animales': 12},
      });

      expect(l.cantidadAnimales, 12);
    });

    test('la cantidad de animales es 0 si no llega _count', () {
      final l = LoteAnimal.fromJson({'id': 1, 'nombre': 'Lote A'});

      expect(l.cantidadAnimales, 0);
    });

    test('lee la especie y el encargado anidados', () {
      final l = LoteAnimal.fromJson({
        'id': 2,
        'nombre': 'Lote B',
        'especie_id': 3,
        'especies': {'id': 3, 'nombre': 'Bovino'},
        'encargado_id': 7,
        'encargado': usuario(7, 'dany'),
        'capacidad_estimada': 40,
        'descripcion': 'Lote de levante',
        'fecha_creacion': '2026-11-01T00:00:00.000Z',
      });

      expect(l.especie!.nombre, 'Bovino');
      expect(l.especieId, 3);
      expect(l.encargadoId, 7);
      expect(l.encargado!.nombreUsuario, 'dany');
      expect(l.encargado!.correoElectronico, 'dany@correo.com');
      expect(l.capacidadEstimada, 40);
      expect(l.descripcion, 'Lote de levante');
      expect(l.fechaCreacion, isNotNull);
    });
  });

  group('CrearLoteDTO.toJson', () {
    test('siempre envía nombre y especie_id, y omite los opcionales nulos', () {
      const dto = CrearLoteDTO(nombre: 'Lote A', especieId: 3);

      expect(dto.toJson(), {'nombre': 'Lote A', 'especie_id': 3});
    });

    test('envía los opcionales cuando existen, con la fecha AAAA-MM-DD', () {
      final dto = CrearLoteDTO(
        nombre: 'Lote A',
        especieId: 3,
        fechaCreacion: DateTime(2026, 11, 1),
        capacidadEstimada: 40,
        descripcion: 'Lote de levante',
      );

      expect(dto.toJson(), {
        'nombre': 'Lote A',
        'especie_id': 3,
        'fecha_creacion': '2026-11-01',
        'capacidad_estimada': 40,
        'descripcion': 'Lote de levante',
      });
    });
  });

  group('ActualizarLoteDTO.toJson', () {
    test('sin cambios envía un cuerpo vacío', () {
      expect(const ActualizarLoteDTO().toJson(), isEmpty);
    });

    test('solo envía los campos que cambian', () {
      const dto = ActualizarLoteDTO(capacidadEstimada: 55);

      expect(dto.toJson(), {'capacidad_estimada': 55});
    });
  });

  group('Potrero.fromJson', () {
    test('lee un potrero mínimo, sin encargados', () {
      final p = Potrero.fromJson({'id': 1, 'nombre': 'Potrero Norte'});

      expect(p.nombre, 'Potrero Norte');
      expect(p.tamanoHectareas, isNull);
      expect(p.encargados, isEmpty);
      expect(p.toString(), 'Potrero Norte');
    });

    test('convierte tamano_hectareas de texto a número', () {
      final p = Potrero.fromJson({
        'id': 1,
        'nombre': 'Potrero Norte',
        'tamano_hectareas': '2.50',
      });

      expect(p.tamanoHectareas, 2.5);
    });

    test('tamano_hectareas acepta número', () {
      final p = Potrero.fromJson(
          {'id': 1, 'nombre': 'Potrero Norte', 'tamano_hectareas': 4});

      expect(p.tamanoHectareas, 4.0);
    });

    test('lee varios encargados desde potrero_encargados', () {
      final p = Potrero.fromJson({
        'id': 1,
        'nombre': 'Potrero Norte',
        'capacidad_animales': 20,
        'estado': 'Disponible',
        'potrero_encargados': [
          {
            'usuarios': usuario(1, 'dany'),
            'asignado_en': '2026-11-02T10:00:00.000Z',
          },
          {'usuarios': usuario(2, 'milena')},
        ],
      });

      expect(p.capacidadAnimales, 20);
      expect(p.estado, 'Disponible');
      expect(p.encargados, hasLength(2));
      expect(p.encargados.first.usuario.nombreUsuario, 'dany');
      expect(p.encargados.first.asignadoEn, isNotNull);
      expect(p.encargados.last.asignadoEn, isNull);
    });
  });

  group('CrearPotreroDTO y ActualizarPotreroDTO', () {
    test('CrearPotreroDTO solo envía el nombre si no hay más datos', () {
      const dto = CrearPotreroDTO(nombre: 'Potrero Norte');

      expect(dto.toJson(), {'nombre': 'Potrero Norte'});
    });

    test('CrearPotreroDTO envía los opcionales con los nombres de la API', () {
      final dto = CrearPotreroDTO(
        nombre: 'Potrero Norte',
        capacidadAnimales: 20,
        estado: 'Disponible',
        tamanoHectareas: 2.5,
        fechaCreacion: DateTime(2026, 11, 1),
        descripcion: 'Cerca al río',
      );

      expect(dto.toJson(), {
        'nombre': 'Potrero Norte',
        'capacidad_animales': 20,
        'estado': 'Disponible',
        'tamano_hectareas': 2.5,
        'fecha_creacion': '2026-11-01',
        'descripcion': 'Cerca al río',
      });
    });

    test('ActualizarPotreroDTO solo envía lo que cambia', () {
      expect(const ActualizarPotreroDTO().toJson(), isEmpty);
      expect(const ActualizarPotreroDTO(estado: 'Ocupado').toJson(),
          {'estado': 'Ocupado'});
    });
  });
}
