/// Configuración central de la app.
///
/// El backend real (Express + TS + Prisma sobre Neon, repo de Milena:
/// `backend_appmovil_fincas`) corre en paralelo en el PC de Dany mientras
/// se hacen las pruebas, por eso [apiBaseUrl] apunta a localhost.
///
/// Si se prueba en Chrome/Edge (Flutter Web) con el backend corriendo con
/// `npm run dev` en el mismo PC, `http://localhost:3000/api` funciona tal
/// cual. Si en algún momento se prueba desde un emulador Android, cambiar
/// a `http://10.0.2.2:3000/api` (10.0.2.2 es el alias que usa el emulador
/// para apuntar al localhost de la máquina anfitriona).
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = 'http://localhost:3000/api';

  /// Interruptor único: false = datos de referencia (mock, sin backend),
  /// true = API real de Milena. Con el backend ya funcional, queda en true.
  static const bool useRealApi = true;

  /// Tiempo de espera para cada request HTTP.
  static const Duration requestTimeout = Duration(seconds: 15);
}
