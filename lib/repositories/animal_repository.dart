import '../models/animal.dart';
import '../models/species.dart';

/// Contrato del repositorio de animales.
///
/// Las pantallas SOLO conocen esta interfaz — nunca [MockAnimalRepository]
/// ni [ApiAnimalRepository] directamente. Así, cuando el backend de Milena
/// esté listo, cambiar de datos de referencia a la API real es una sola
/// línea en `main.dart`, sin tocar ninguna pantalla.
abstract class AnimalRepository {
  Future<List<Animal>> getAll();
  Future<Animal> getById(String id);
  Future<Animal> create(CreateAnimalDTO dto);

  /// Especies disponibles para el formulario de creación (bovino, porcino,
  /// etc.). Separado de [getAll] porque es un catálogo, no un listado de
  /// animales.
  Future<List<Species>> getSpecies();
}
