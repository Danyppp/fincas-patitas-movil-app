/// Configuración central de la app.
///
/// `apiBaseUrl` apunta al backend de Milena (Express + TS sobre Neon).
/// Mientras ese backend no esté listo, la app trabaja con
/// [MockAnimalRepository] y este valor no se usa todavía — cuando exista
/// el endpoint real, se activa [ApiAnimalRepository] en `main.dart` sin
/// tocar ninguna pantalla.
class AppConfig {
  AppConfig._();

  /// TODO(Dany/Milena): reemplazar por la URL real del backend cuando
  /// esté desplegado (o por http://10.0.2.2:PORT/ para probar contra
  /// el backend corriendo en localhost desde el emulador de Android).
  static const String apiBaseUrl = 'https://PENDIENTE-backend-milena/api';

  /// Interruptor único: false = datos de referencia (mock), true = API real.
  static const bool useRealApi = false;
}
