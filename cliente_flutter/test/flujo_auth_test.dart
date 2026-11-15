// Prueba de integración ligera: ejecuta las pantallas reales contra el backend en http://localhost:5000.
// Requiere el backend en marcha y el usuario de prueba admin (ver README de pruebas).
//   flutter test test/flujo_auth_test.dart
import 'dart:io';
import 'dart:math';

import 'package:aerotech/main.dart';
import 'package:aerotech/screens/admin/admin_home.dart';
import 'package:aerotech/screens/auth/login_screen.dart';
import 'package:aerotech/screens/cliente/cliente_home.dart';
import 'package:aerotech/services/api_client.dart';
import 'package:aerotech/sesion.dart';
import 'package:aerotech/utils/validadores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Las credenciales del administrador de prueba se leen de backend/.env (ADMIN_CORREO / ADMIN_PASSWORD);
// nunca se escriben en el código.
final Map<String, String> _env = _leerEnv();
String get _correoAdminUi => _env['ADMIN_CORREO'] ?? '';
String get _claveAdminUi => _env['ADMIN_PASSWORD'] ?? '';

Map<String, String> _leerEnv() {
  final f = File('../backend/.env');
  if (!f.existsSync()) return {};
  final r = <String, String>{};
  for (final l in f.readAsLinesSync()) {
    final i = l.indexOf('=');
    if (i > 0 && !l.startsWith('#')) r[l.substring(0, i).trim()] = l.substring(i + 1).trim();
  }
  return r;
}

String _cedulaAleatoria() {
  final r = Random();
  while (true) {
    final base = '${(1 + r.nextInt(24)).toString().padLeft(2, '0')}${r.nextInt(6)}${r.nextInt(1000000).toString().padLeft(6, '0')}';
    var suma = 0;
    const coef = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    for (var i = 0; i < 9; i++) {
      var p = int.parse(base[i]) * coef[i];
      if (p > 9) p -= 9;
      suma += p;
    }
    final c = '$base${(10 - suma % 10) % 10}';
    if (Validadores.cedulaValida(c)) return c;
  }
}

/// Espera (con reloj real) hasta que aparezca el finder; las llamadas HTTP son reales.
Future<void> esperar(WidgetTester t, Finder f, {int segundos = 40}) async {
  for (var i = 0; i < segundos * 4; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 50));
    if (f.evaluate().isNotEmpty) {
      // pumpAndSettle haría avanzar el reloj simulado hasta vencer los tiempos de espera de las llamadas pendientes
      for (var k = 0; k < 4; k++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      return;
    }
  }
  throw TestFailure('No apareció: $f');
}

Future<void> abrirApp(WidgetTester t) async {
  t.view.physicalSize = const Size(1000, 1700);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  await Sesion.instancia.cerrar();
  await t.pumpWidget(const AeroTechApp());
  await esperar(t, find.byType(LoginScreen));
}

Future<void> iniciarSesion(WidgetTester t, String correo, String clave) async {
  await t.enterText(find.byType(TextFormField).at(0), correo);
  await t.enterText(find.byType(TextFormField).at(1), clave);
  await t.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = null; // permite llamadas reales en flutter test
    await initializeDateFormatting('es');
  });

  testWidgets('Validadores: cédula módulo 10 coincide con el backend', (t) async {
    expect(Validadores.cedulaValida('1710034065'), isTrue);
    expect(Validadores.cedulaValida('1234567890'), isFalse);
    expect(Validadores.cedulaValida('0000000000'), isFalse);
    expect(Validadores.telefono('0991234567'), isNull);
    expect(Validadores.telefono('0891234567'), isNotNull);
    expect(Validadores.password('abcdefgh'), isNotNull);
    expect(Validadores.password('Clave1234'), isNull);
    expect(Validadores.configuracionAvion('ABC-DEF'), isNull);
    expect(Validadores.configuracionAvion('ABC-ABC'), isNotNull);
    expect(Validadores.fechaNacimiento(DateTime(2026, 6, 1), DateTime(2026, 12, 21)), isNotNull); // < 2 años
    expect(Validadores.fechaNacimiento(DateTime(2015, 1, 1), DateTime(2026, 12, 21), salidaEmergencia: true), isNotNull);
    expect(Validadores.fechaNacimiento(DateTime(1990, 5, 10), DateTime(2026, 12, 21), salidaEmergencia: true), isNull);
  });

  testWidgets('Registro con cédula inválida muestra el error y no crea la cuenta', (t) async {
    await abrirApp(t);
    await t.tap(find.text('¿No tiene cuenta? Crear cuenta'));
    await t.pumpAndSettle();
    final campos = find.byType(TextFormField);
    await t.enterText(campos.at(0), 'Prueba');
    await t.enterText(campos.at(1), 'Flutter');
    await t.enterText(campos.at(2), '1234567890');
    await t.enterText(campos.at(3), '0991112233');
    await t.enterText(campos.at(4), 'test_flutter_invalido@correo.com');
    await t.enterText(campos.at(5), 'Prueba1234');
    await t.enterText(campos.at(6), 'Prueba1234');
    await t.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await t.pumpAndSettle();
    expect(find.text('Cédula ecuatoriana inválida'), findsOneWidget);
    expect(find.byType(ClienteHome), findsNothing);
  });

  testWidgets('Registro → abre ClienteHome → cerrar sesión vuelve a Login', (t) async {
    await abrirApp(t);
    await t.tap(find.text('¿No tiene cuenta? Crear cuenta'));
    await t.pumpAndSettle();
    final correo = 'test_flutter_${DateTime.now().millisecondsSinceEpoch}@correo.com';
    final campos = find.byType(TextFormField);
    await t.enterText(campos.at(0), 'Prueba');
    await t.enterText(campos.at(1), 'Flutter');
    await t.enterText(campos.at(2), _cedulaAleatoria());
    await t.enterText(campos.at(3), '0991112233');
    await t.enterText(campos.at(4), correo);
    await t.enterText(campos.at(5), 'Prueba1234');
    await t.enterText(campos.at(6), 'Prueba1234');
    await t.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await esperar(t, find.byType(ClienteHome));
    expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Mis reservas')), findsOneWidget);
    expect(Sesion.instancia.esAdmin, isFalse);

    // Cerrar sesión desde la pestaña Perfil
    await t.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Perfil')));
    await esperar(t, find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
    await t.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
    await esperar(t, find.byType(LoginScreen));
    expect(Sesion.instancia.activa, isFalse);
  });

  testWidgets('Correo duplicado: el error aparece bajo el campo correo', (t) async {
    await abrirApp(t);
    await t.tap(find.text('¿No tiene cuenta? Crear cuenta'));
    await t.pumpAndSettle();
    final campos = find.byType(TextFormField);
    await t.enterText(campos.at(0), 'Prueba');
    await t.enterText(campos.at(1), 'Duplicado');
    await t.enterText(campos.at(2), _cedulaAleatoria());
    await t.enterText(campos.at(3), '0991112233');
    await t.enterText(campos.at(4), _correoAdminUi); // ya existe
    await t.enterText(campos.at(5), 'Prueba1234');
    await t.enterText(campos.at(6), 'Prueba1234');
    await t.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await esperar(t, find.text('El correo ya está registrado'));
    expect(find.byType(ClienteHome), findsNothing);
  });

  testWidgets('Login con clave incorrecta muestra SnackBar y se queda en Login', (t) async {
    await abrirApp(t);
    await iniciarSesion(t, _correoAdminUi, 'ClaveIncorrecta1');
    await esperar(t, find.text('Credenciales incorrectas'));
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Login como admin → AdminHome → cerrar sesión vuelve a Login', (t) async {
    await abrirApp(t);
    await iniciarSesion(t, _correoAdminUi, _claveAdminUi);
    await esperar(t, find.byType(AdminHome));
    expect(find.text('ADMIN'), findsOneWidget);
    expect(Sesion.instancia.esAdmin, isTrue);
    expect(Sesion.instancia.rutaInicio, '/admin');

    await t.tap(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.logout)));
    await esperar(t, find.byType(LoginScreen));
    expect(Sesion.instancia.activa, isFalse);
  });

  testWidgets('Al abrir la app con token guardado se valida con /perfil y se enruta por rol', (t) async {
    await abrirApp(t);
    await iniciarSesion(t, _correoAdminUi, _claveAdminUi);
    await esperar(t, find.byType(AdminHome));
    // Simula cerrar y reabrir la app: la sesión guardada se recarga y el splash verifica el token
    final token = Sesion.instancia.token!;
    SharedPreferences.setMockInitialValues({
      'aerotech_token': token,
      'aerotech_usuario': '{"id":1,"nombre":"X","apellido":"Y","correo":"x@y.com","rol":"cliente"}',
    });
    await Sesion.instancia.cargar();
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(const AeroTechApp());
    await esperar(t, find.byType(AdminHome)); // el rol real viene del servidor, no del valor guardado
    // deja terminar las cargas del panel antes de cerrar la prueba (evita temporizadores pendientes)
    await t.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 160 && ApiClient.pendientes > 0; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pump(const Duration(seconds: 6)); // vence los temporizadores simulados que queden
  });

  testWidgets('Token revocado: el splash vuelve a Login', (t) async {
    await abrirApp(t);
    SharedPreferences.setMockInitialValues({
      'aerotech_token': 'token.invalido.xyz',
      'aerotech_usuario': '{"id":1,"nombre":"X","apellido":"Y","correo":"x@y.com","rol":"cliente"}',
    });
    await Sesion.instancia.cargar();
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(const AeroTechApp());
    await esperar(t, find.byType(LoginScreen));
    expect(Sesion.instancia.activa, isFalse);
  });
}
