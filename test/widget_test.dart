// Prueba de humo (smoke test) de Fincas y Patitas.
//
// Con el rebuild contra el backend real, la app siempre arranca en
// LoginScreen mientras no haya una sesión guardada (SharedPreferences
// vacío en el entorno de test). Verificamos eso en vez del listado de
// Animales, que ahora vive detrás del login.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fincas_patitas_movil_app/core/auth_session.dart';
import 'package:fincas_patitas_movil_app/main.dart';

void main() {
  testWidgets('La app arranca y muestra la pantalla de inicio de sesión', (
    WidgetTester tester,
  ) async {
    // Sin esto, SharedPreferences.getInstance() lanza MissingPluginException
    // en el entorno de test (no hay plugin nativo real cargado).
    SharedPreferences.setMockInitialValues({});

    final session = AuthSession();
    await session.restoreSession();

    await tester.pumpWidget(FincasPatitasApp(session: session));
    await tester.pumpAndSettle();

    expect(find.text('Fincas y Patitas'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
  });
}
