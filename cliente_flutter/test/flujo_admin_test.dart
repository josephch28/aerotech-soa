// Flujo del administrador contra el backend real (http://localhost:5000):
// crear avión con vista previa → vuelo → verlo como cliente → reservar → manifiesto → cancelar vuelo →
// el cliente ve la reserva cancelada con motivo → dashboard → desactivar cliente → expulsión en su siguiente acción.
//   flutter test test/flujo_admin_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:aerotech/main.dart';
import 'package:aerotech/screens/admin/admin_home.dart';
import 'package:aerotech/screens/admin/avion_form_screen.dart';
import 'package:aerotech/screens/admin/vuelos_admin_screen.dart';
import 'package:aerotech/screens/auth/login_screen.dart';
import 'package:aerotech/screens/cliente/cliente_home.dart';
import 'package:aerotech/sesion.dart';
import 'package:aerotech/utils/validadores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _api = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:5000');
final _random = Random();
late Map<String, String> _env;
late String _tokenAdmin;

Map<String, String> _leerEnv() {
  final f = File('../backend/.env');
  final r = <String, String>{};
  if (!f.existsSync()) return r;
  for (final l in f.readAsLinesSync()) {
    final i = l.indexOf('=');
    if (i > 0 && !l.startsWith('#')) r[l.substring(0, i).trim()] = l.substring(i + 1).trim();
  }
  return r;
}

String _cedula() {
  while (true) {
    final base = '${(1 + _random.nextInt(24)).toString().padLeft(2, '0')}${_random.nextInt(6)}${_random.nextInt(1000000).toString().padLeft(6, '0')}';
    var s = 0;
    const co = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    for (var i = 0; i < 9; i++) {
      var p = int.parse(base[i]) * co[i];
      if (p > 9) p -= 9;
      s += p;
    }
    final c = '$base${(10 - s % 10) % 10}';
    if (Validadores.cedulaValida(c)) return c;
  }
}

Map<String, String> get _hAdmin => {'Content-Type': 'application/json', 'Authorization': 'Bearer $_tokenAdmin'};
Future<dynamic> _j(http.Response r) async => jsonDecode(utf8.decode(r.bodyBytes));

Future<void> esperar(WidgetTester t, Finder f, {int segundos = 60}) async {
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

/// Espera hasta que el finder deje de existir (p. ej. a que se cierre una pantalla).
Future<void> esperarSin(WidgetTester t, Finder f, {int segundos = 60}) async {
  for (var i = 0; i < segundos * 4; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await t.pump(const Duration(milliseconds: 50));
    if (f.evaluate().isEmpty) {
      await avanzar(t);
      return;
    }
  }
  throw TestFailure('Sigue apareciendo: $f');
}

Future<void> avanzar(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _pantalla(WidgetTester t) async {
  t.view.physicalSize = const Size(1400, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  await Sesion.instancia.cerrar();
}

Future<void> _login(WidgetTester t, String correo, String clave, Type destino) async {
  await t.pumpWidget(const AeroTechApp());
  await esperar(t, find.byType(LoginScreen));
  await t.enterText(find.byType(TextFormField).at(0), correo);
  await t.enterText(find.byType(TextFormField).at(1), clave);
  await t.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
  await esperar(t, find.byType(destino));
}

Finder _rail(String etiqueta) => find.descendant(of: find.byType(NavigationRail), matching: find.text(etiqueta));

Future<String> _registrarClienteApi() async {
  final correo = 'test_flutter_adm_${DateTime.now().microsecondsSinceEpoch}@correo.com';
  final r = await http.post(Uri.parse('$_api/api/usuarios/registro'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nombre': 'Cliente', 'apellido': 'ParaAdmin', 'cedula': _cedula(), 'telefono': '0991234567', 'correo': correo, 'password': 'Prueba1234'}));
  expect(r.statusCode, 201);
  return correo;
}

Future<String> _tokenCliente(String correo) async =>
    (await _j(await http.post(Uri.parse('$_api/api/auth/login'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'correo': correo, 'password': 'Prueba1234'}))))['token'] as String;

void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('es');
    _env = _leerEnv();
    final r = await http.post(Uri.parse('$_api/api/auth/login'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'correo': _env['ADMIN_CORREO'], 'password': _env['ADMIN_PASSWORD']}));
    _tokenAdmin = (await _j(r))['token'] as String;
  });

  testWidgets('Admin: avión con vista previa → vuelo → reserva de cliente → manifiesto → cancelar vuelo → dashboard → desactivar cliente', (t) async {
    await _pantalla(t);
    await _login(t, _env['ADMIN_CORREO']!, _env['ADMIN_PASSWORD']!, AdminHome);

    // A) Panel: chip ADMIN y dashboard con KPIs
    expect(find.text('ADMIN'), findsOneWidget);
    await esperar(t, find.text('Reservas confirmadas'));
    expect(find.text('Vuelos programados'), findsOneWidget);
    expect(find.text('Ocupación por vuelo (próximos 10)'), findsOneWidget);

    // B) Flota → nuevo avión con vista previa en vivo
    await t.tap(_rail('Flota'));
    await esperar(t, find.text('Nuevo avión'));
    await t.tap(find.text('Nuevo avión'));
    await esperar(t, find.text('Vista previa'));
    expect(find.text('Capacidad total: 120 asientos'), findsOneWidget); // valores de ejemplo: ABC-DEF × 20 filas
    final campos = find.byType(TextFormField);
    final matricula = 'HC-${String.fromCharCode(65 + _random.nextInt(26))}${String.fromCharCode(65 + _random.nextInt(26))}${_random.nextInt(10)}${_random.nextInt(10)}';
    await t.enterText(campos.at(0), 'Avión de prueba UI');
    await t.enterText(campos.at(1), matricula);
    await t.enterText(campos.at(2), 'ABC-ABC'); // inválida: letras repetidas
    await avanzar(t);
    expect(find.textContaining('Configuración inválida'), findsWidgets);
    expect(find.textContaining('Complete una configuración válida'), findsOneWidget);
    await t.enterText(campos.at(2), 'A-C');
    await t.enterText(campos.at(4), '5');
    await avanzar(t);
    expect(find.text('Capacidad total: 10 asientos'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Número de fila'), '3');
    await t.tap(find.text('Agregar'));
    await avanzar(t);
    expect(find.text('Fila 3'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Crear avión'));
    await esperar(t, find.text('Avión creado'));
    await esperarSin(t, find.byType(AvionFormScreen)); // volvió a la lista de flota
    await esperar(t, find.byType(ListTile)); // lista de flota cargada (el avión nuevo queda al final)
    await esperar(t, find.textContaining(matricula)); // los aviones más recientes aparecen primero
    expect(find.textContaining('10 asientos'), findsWidgets);

    // C) Vuelo (por API) en ese avión; el cliente lo ve en la búsqueda y reserva 2 asientos
    final aviones = await t.runAsync(() async => await _j(await http.get(Uri.parse('$_api/api/admin/aviones'), headers: _hAdmin)) as List);
    final avionId = aviones!.firstWhere((a) => a['matricula'] == matricula)['id'];
    late String codigo, fecha;
    late int vueloId;
    await t.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        codigo = 'Y${String.fromCharCode(65 + _random.nextInt(26))}${1000 + _random.nextInt(9000)}';
        fecha = '2027-${(2 + _random.nextInt(10)).toString().padLeft(2, '0')}-${(1 + _random.nextInt(28)).toString().padLeft(2, '0')}';
        final r = await http.post(Uri.parse('$_api/api/admin/vuelos'),
            headers: _hAdmin,
            body: jsonEncode({'codigo_vuelo': codigo, 'avion_id': avionId, 'origen': 'UIO', 'destino': 'CUE', 'fecha': fecha, 'hora_salida': '10:00', 'hora_llegada': '11:00', 'precio': 70, 'precio_ejecutiva': 70}));
        if (r.statusCode == 201) {
          vueloId = (await _j(r))['vuelo']['id'] as int;
          return;
        }
      }
    });
    final correoCliente = await t.runAsync(_registrarClienteApi);
    final tokenCliente = await t.runAsync(() => _tokenCliente(correoCliente!));
    late int reservaId;
    await t.runAsync(() async {
      final busq = await _j(await http.get(Uri.parse('$_api/api/vuelos?origen=UIO&destino=CUE&fecha=$fecha')));
      expect((busq['vuelos'] as List).any((v) => v['id'] == vueloId), isTrue, reason: 'el cliente debe ver el vuelo en la búsqueda');
      final r = await http.post(Uri.parse('$_api/api/reservas/'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $tokenCliente'},
          body: jsonEncode({
            'vuelo_id': vueloId,
            'pasajeros': [
              for (final a in ['1A', '1C'])
                {'asiento': a, 'nombres': 'Pasajero', 'apellidos': 'Manifiesto', 'tipo_documento': 'cedula', 'numero_documento': _cedula(), 'fecha_nacimiento': '1990-05-10'}
            ]
          }));
      expect(r.statusCode, 201);
      reservaId = (await _j(r))['reserva']['id'] as int;
    });

    // D) Vuelos → manifiesto (Mapa y Pasajeros)
    await t.tap(_rail('Vuelos'));
    await esperar(t, find.byType(Card));
    await t.scrollUntilVisible(find.text(codigo), 300,
        scrollable: find.descendant(of: find.byType(VuelosAdminScreen), matching: find.byType(Scrollable)).last, maxScrolls: 60);
    Finder menuDe() => find.descendant(of: find.ancestor(of: find.text(codigo), matching: find.byType(Card)), matching: find.byType(PopupMenuButton<String>));
    await t.ensureVisible(menuDe());
    await avanzar(t, 4);
    await t.tap(menuDe());
    await avanzar(t);
    await t.tap(find.text('Ver manifiesto'));
    await esperar(t, find.text('Pasajeros'));
    await esperar(t, find.byType(TabBarView)); // manifiesto y mapa cargados
    await t.tap(find.text('Pasajeros').last);
    await esperar(t, find.text('Pasajero Manifiesto'));
    expect(find.text('1A'), findsWidgets);
    expect(find.text('Pasajero Manifiesto'), findsNWidgets(2));
    await t.tap(find.byType(BackButton));
    await avanzar(t, 10);

    // E) Edición del vuelo: el avión queda bloqueado porque ya tiene reservas
    await t.ensureVisible(menuDe());
    await avanzar(t, 4);
    await t.tap(menuDe());
    await avanzar(t);
    await t.tap(find.text('Editar'));
    await esperar(t, find.textContaining('No se puede cambiar el avión'));
    expect(find.text('Editar vuelo $codigo'), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await avanzar(t, 10);

    // F) Cancelar el vuelo (aviso con N reservas + motivo obligatorio)
    await t.ensureVisible(menuDe());
    await avanzar(t, 4);
    await t.tap(menuDe());
    await avanzar(t);
    await t.tap(find.text('Cancelar vuelo').first);
    await esperar(t, find.textContaining('Se cancelarán 1 reserva'));
    await t.tap(find.widgetWithText(FilledButton, 'Cancelar vuelo'));
    await avanzar(t); // sin motivo: no cancela
    expect(find.textContaining('Se cancelarán 1 reserva'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).last, 'Mantenimiento no programado');
    await t.tap(find.widgetWithText(FilledButton, 'Cancelar vuelo'));
    await esperar(t, find.textContaining('Reservas afectadas: 1'));

    // G) El cliente ve la reserva cancelada con motivo; el mapa liberó los asientos
    await t.runAsync(() async {
      final d = await _j(await http.get(Uri.parse('$_api/api/reservas/$reservaId'), headers: {'Authorization': 'Bearer $tokenCliente'}));
      expect(d['estado'], 'cancelada');
      expect(d['motivo_cancelacion'], 'Vuelo cancelado por la aerolínea');
      final m = await _j(await http.get(Uri.parse('$_api/api/vuelos/$vueloId/asientos')));
      expect(m['resumen']['disponibles'], 10);
    });

    // H) Dashboard sigue operativo
    await t.tap(_rail('Dashboard'));
    await esperar(t, find.text('Resumen general'));
    expect(find.text('Rutas más vendidas'), findsOneWidget);

    // I) Reservas: el buscador por correo encuentra la reserva cancelada
    await t.tap(_rail('Reservas'));
    await esperar(t, find.byType(TextField));
    await t.enterText(find.widgetWithText(TextField, 'Código de reserva o correo'), correoCliente!);
    await t.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await esperar(t, find.textContaining('Motivo: Vuelo cancelado por la aerolínea'));

    // J) Usuarios: desactivar al cliente (con confirmación) y comprobar que su token queda revocado
    await t.tap(_rail('Usuarios'));
    await esperar(t, find.widgetWithText(TextField, 'Buscar por nombre, correo o cédula'));
    await esperar(t, find.textContaining('(usted)')); // lista inicial cargada (mientras carga, el botón Buscar está deshabilitado)
    await t.enterText(find.widgetWithText(TextField, 'Buscar por nombre, correo o cédula'), correoCliente);
    await t.tap(find.widgetWithText(FilledButton, 'Buscar').last);
    await esperar(t, find.text('Cliente ParaAdmin'));
    await t.tap(find.byType(Switch));
    await esperar(t, find.widgetWithText(FilledButton, 'Desactivar'));
    await t.tap(find.widgetWithText(FilledButton, 'Desactivar'));
    await esperar(t, find.text('Usuario desactivado'));
    await t.runAsync(() async {
      final r = await http.get(Uri.parse('$_api/api/usuarios/perfil'), headers: {'Authorization': 'Bearer $tokenCliente'});
      expect(r.statusCode, anyOf(401, 403));
    });

    // Limpieza: el avión de prueba se desactiva (ya no tiene vuelos programados)
    await t.runAsync(() => http.patch(Uri.parse('$_api/api/admin/aviones/$avionId/estado'), headers: _hAdmin, body: jsonEncode({'activo': false})));

    // Cerrar sesión desde el panel
    await t.tap(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.logout)));
    await esperar(t, find.byType(LoginScreen));
  }, timeout: const Timeout(Duration(minutes: 12)));

  testWidgets('Un cliente desactivado es expulsado en su siguiente acción y ve el motivo en Login', (t) async {
    await _pantalla(t);
    final correo = await t.runAsync(_registrarClienteApi);
    await _login(t, correo!, 'Prueba1234', ClienteHome);

    // El admin lo desactiva (por API) mientras el cliente tiene la app abierta
    await t.runAsync(() async {
      final lista = await _j(await http.get(Uri.parse('$_api/api/admin/usuarios?buscar=$correo'), headers: _hAdmin));
      final id = (lista['usuarios'] as List).first['id'];
      final r = await http.patch(Uri.parse('$_api/api/admin/usuarios/$id'), headers: _hAdmin, body: jsonEncode({'activo': false}));
      expect(r.statusCode, 200);
    });

    // Siguiente acción del cliente: abrir "Mis reservas" → el backend rechaza el token → vuelve a Login con aviso
    await t.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Mis reservas')));
    await esperar(t, find.byType(LoginScreen));
    await esperar(t, find.textContaining('Su sesión ya no es válida'));
    expect(Sesion.instancia.activa, isFalse);
    // y no puede volver a entrar
    await t.enterText(find.byType(TextFormField).at(0), correo);
    await t.enterText(find.byType(TextFormField).at(1), 'Prueba1234');
    await t.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await esperar(t, find.textContaining('Cuenta desactivada'));
    expect(find.byType(ClienteHome), findsNothing);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
