import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'repositories/animal_repository.dart';
import 'repositories/api_animal_repository.dart';
import 'repositories/mock_animal_repository.dart';
import 'screens/home/home_shell.dart';

void main() {
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

    return MaterialApp(
      title: 'Fincas y Patitas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F6B4A),
        useMaterial3: true,
      ),
      home: HomeShell(animalRepository: animalRepository),
    );
  }
}
