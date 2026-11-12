import '../../models/animal.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../models/catalogo/potrero.dart';

/// Contrato del módulo Ubicación (Lotes y Potreros) contra
/// `/lotes-animales` y `/ubicaciones-potreros`.
///
/// Separado de `CatalogoRepository` (que sigue existiendo, de solo
/// lectura, para los dropdowns de Lote/Potrero en Animales) porque este sí
/// necesita CRUD completo -- mismo criterio que ya se usó para separar
/// Salud de Animales.
abstract class UbicacionRepository {
  // -- Lotes --
  Future<List<LoteAnimal>> listarLotes();
  Future<LoteAnimal?> obtenerLote(int id);
  Future<LoteAnimal> crearLote(CrearLoteDTO dto);
  Future<LoteAnimal> actualizarLote(int id, ActualizarLoteDTO dto);
  Future<void> eliminarLote(int id);
  Future<LoteAnimal> asignarEncargadoLote(int id, int? encargadoId);

  // -- Potreros --
  Future<List<Potrero>> listarPotreros();
  Future<Potrero?> obtenerPotrero(int id);
  Future<Potrero> crearPotrero(CrearPotreroDTO dto);
  Future<Potrero> actualizarPotrero(int id, ActualizarPotreroDTO dto);
  Future<void> eliminarPotrero(int id);
  Future<List<Animal>> animalesDelPotrero(int id);
  Future<Potrero> agregarEncargadoPotrero(int id, int usuarioId);
  Future<Potrero> quitarEncargadoPotrero(int id, int usuarioId);

  /// Sube (o reemplaza) la foto del potrero. [bytes] es el contenido del
  /// archivo elegido por el usuario (ej. vía `image_picker`), [nombreArchivo]
  /// solo se usa para que el backend/Cloudinary sepan la extensión.
  Future<Potrero> subirFotoPotrero(
    int id, {
    required List<int> bytes,
    required String nombreArchivo,
  });
}
