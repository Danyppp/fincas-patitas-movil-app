// Prueba de humo (smoke test) de Fincas y Patitas.
//
// El test por defecto que genera `flutter create` hace referencia a una
// clase `MyApp` con un contador — no existen en esta app. Aquí verificamos
// en su lugar que la app arranca correctamente y que la pantalla de
// Animales (pantalla inicial de HomeShell) se muestra.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fincas_patitas_movil_app/main.dart';

void main() {
  testWidgets('La app arranca y muestra el módulo de Animales', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FincasPatitasApp());

    // Esperamos a que resuelva el FutureBuilder de la lista de animales
    // (MockAnimalRepository simula latencia con Future.delayed).
    await tester.pumpAndSettle();

    // El AppBar del módulo de Animales debe estar visible al abrir la app.
    expect(find.text('Animales'), findsWidgets);

    // La barra de navegación inferior debe incluir los módulos ya
    // implementados.
    expect(find.text('Reproducción'), findsOneWidget);
  });
}
