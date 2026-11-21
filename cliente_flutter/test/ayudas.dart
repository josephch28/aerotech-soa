// Ayudas comunes de las pruebas de flujo (la app ahora arranca en la página de inicio pública).
import 'package:aerotech/screens/auth/login_screen.dart';
import 'package:aerotech/screens/cliente/cliente_home.dart';
import 'package:aerotech/screens/publico/landing_screen.dart';
import 'package:aerotech/services/api_client.dart';
import 'package:aerotech/widgets/barra_superior.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Espera (con reloj real) hasta que aparezca [f]; las llamadas HTTP son reales.
Future<void> esperarA(WidgetTester t, Finder f, {int segundos = 60}) async {
  for (var i = 0; i < segundos * 4; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 50));
    if (f.evaluate().isNotEmpty) {
      for (var k = 0; k < 4; k++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      return;
    }
  }
  throw TestFailure('No apareció: $f');
}

/// Desde la página de inicio (sin sesión) pulsa «Iniciar sesión» de la barra superior.
Future<void> abrirLoginDesdeLanding(WidgetTester t) async {
  await esperarA(t, find.byType(LandingScreen));
  await t.tap(find.descendant(of: find.byType(BarraSuperior), matching: find.widgetWithText(FilledButton, 'Iniciar sesión')));
  await esperarA(t, find.byType(LoginScreen));
}

/// Con sesión de cliente abierta en la página de inicio: menú «Hola, …» → «Mi cuenta» (opcionalmente otra pestaña).
Future<void> abrirMiCuenta(WidgetTester t, {String? rail}) async {
  await esperarA(t, find.textContaining('Hola,'));
  await t.tap(find.textContaining('Hola,'));
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
  await t.tap(find.text('Mi cuenta'));
  await esperarA(t, find.byType(ClienteHome));
  if (rail != null) {
    // «Mi cuenta» abre el Perfil; con [rail] se pasa a otra pestaña (Vuelos, Mis reservas)
    await t.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text(rail)));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
  }
}

/// Deja terminar las llamadas en curso antes de cerrar la prueba (evita temporizadores pendientes).
Future<void> drenar(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 160 && ApiClient.pendientes > 0; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pump(const Duration(seconds: 6));
}
