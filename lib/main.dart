import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/app_config.dart';
import 'core/api_client.dart';
import 'core/auth_session.dart';
import 'theme/app_theme.dart';
import 'repositories/animales/animal_repository.dart';
import 'repositories/animales/api_animal_repository.dart';
import 'repositories/animales/mock_animal_repository.dart';
import 'repositories/auth/api_auth_repository.dart';
import 'repositories/auth/auth_repository.dart';
import 'repositories/auth/mock_auth_repository.dart';
import 'repositories/catalogo/api_catalogo_repository.dart';
import 'repositories/catalogo/catalogo_repository.dart';
import 'repositories/catalogo/mock_catalogo_repository.dart';
import 'repositories/inventario/api_insumo_repository.dart';
import 'repositories/inventario/insumo_repository.dart';
import 'repositories/inventario/mock_insumo_repository.dart';
import 'repositories/produccion/api_produccion_repository.dart';
import 'repositories/produccion/mock_produccion_repository.dart';
import 'repositories/produccion/produccion_repository.dart';
import 'repositories/reproduccion/api_reproduccion_repository.dart';
import 'repositories/reproduccion/mock_reproduccion_repository.dart';
import 'repositories/reproduccion/reproduccion_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';

Future<void> main() async {
  // Necesario antes de usar DateFormat con locale 'es' (fechas de
  // Reproducción, Animales, Producción e Inventario) — sin esto,
  // DateFormat lanza LocaleDataException al primer build.
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  final session = AuthSession();
  await session.restoreSession();

  runApp(FincasPatitasApp(session: session));
}

class FincasPatitasApp extends StatefulWidget {
  final AuthSession session;

  const FincasPatitasApp({super.key, required this.session});

  @override
  State<FincasPatitasApp> createState() => _FincasPatitasAppState();
}

class _FincasPatitasAppState extends State<FincasPatitasApp> {
  late final ApiClient _apiClient = ApiClient(session: widget.session);

  late final AuthRepository _authRepository = AppConfig.useRealApi
      ? ApiAuthRepository(client: _apiClient)
      : MockAuthRepository();

  late final CatalogoRepository _catalogoRepository = AppConfig.useRealApi
      ? ApiCatalogoRepository(client: _apiClient)
      : MockCatalogoRepository();

  late final AnimalRepository _animalRepository = AppConfig.useRealApi
      ? ApiAnimalRepository(client: _apiClient)
      : MockAnimalRepository();

  late final ReproduccionRepository _reproduccionRepository =
      AppConfig.useRealApi
          ? ApiReproduccionRepository(client: _apiClient)
          : MockReproduccionRepository();

  late final ProduccionRepository _produccionRepository = AppConfig.useRealApi
      ? ApiProduccionRepository(client: _apiClient)
      : MockProduccionRepository();

  late final InsumoRepository _insumoRepository = AppConfig.useRealApi
      ? ApiInsumoRepository(client: _apiClient)
      : MockInsumoRepository();

  @override
  void initState() {
    super.initState();
    // HomeShell/LoginScreen se reconstruyen automáticamente cuando cambia
    // el estado de sesión (login, logout, o si restoreSession() encuentra
    // una sesión guardada).
    widget.session.addListener(_onSessionChanged);
  }

  void _onSessionChanged() => setState(() {});

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fincas y Patitas',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: !widget.session.isInitialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : widget.session.isAuthenticated
              ? HomeShell(
                  animalRepository: _animalRepository,
                  catalogoRepository: _catalogoRepository,
                  reproduccionRepository: _reproduccionRepository,
                  produccionRepository: _produccionRepository,
                  insumoRepository: _insumoRepository,
                  session: widget.session,
                )
              : LoginScreen(
                  repository: _authRepository, session: widget.session),
    );
  }
}
