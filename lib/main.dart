import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/app_config.dart';
import 'repositories/animal_repository.dart';
import 'repositories/api_animal_repository.dart';
import 'repositories/api_reproduction_repository.dart';
import 'repositories/mock_animal_repository.dart';
import 'repositories/mock_reproduction_repository.dart';
import 'repositories/reproduction_repository.dart';
import 'screens/home/home_shell.dart';

Future<void> main() async {
  // Necesario antes de usar DateFormat con locale 'es' (fechas de
  // Reproducción y Animales) — sin esto, DateFormat lanza
  // LocaleDataException al primer build.
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  runApp(const FincasPatitasApp());
}

class FincasPatitasApp extends StatelessWidget {
  const FincasPatitasApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Único punto donde se decide qué implementación de AnimalRepository
    // usa toda la app. Cuando el backend de Milena esté listo: cambiar
    // AppConfig.useRealApi a true (y la URL en app_config.dart) — ninguna
    // pantalla necesita cambiar.
    final AnimalRepository animalRepository =
        AppConfig.useRealApi ? ApiAnimalRepository() : MockAnimalRepository();
    final ReproductionRepository reproductionRepository = AppConfig.useRealApi
        ? ApiReproductionRepository()
        : MockReproductionRepository();

    return MaterialApp(
      title: 'Fincas y Patitas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F6B4A),
        useMaterial3: true,
      ),
      home: HomeShell(
        animalRepository: animalRepository,
        reproductionRepository: reproductionRepository,
      ),
    );
  }
}
