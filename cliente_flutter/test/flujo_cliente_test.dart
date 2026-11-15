// Flujo completo del cliente contra el backend real (http://localhost:5000):
// buscar → elegir 2 asientos (uno ejecutivo) → pasajeros → confirmar → código → comprobante XML →
// editar a 3 asientos cambiando uno → diferencia → historial → cancelar. Más el conflicto 409.
//   flutter test test/flujo_cliente_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:aerotech/main.dart';
import 'package:aerotech/screens/auth/login_screen.dart';
import 'package:aerotech/screens/cliente/cliente_home.dart';
import 'package:aerotech/services/usuario_service.dart';
import 'package:aerotech/sesion.dart';
import 'package:aerotech/utils/validadores.dart';
import 'package:aerotech/widgets/mapa_asientos/asiento_widget.dart';
import 'package:aerotech/widgets/vuelo_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _api = 'http://localhost:5000';
late String _tokenAdmin;
late int _vueloId;
late String _codigoVuelo;
final _random = Random();

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

Future<Map<String, dynamic>> _json(http.Response r) async => jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;

Future<void> _crearVueloDePrueba() async {
  final env = _leerEnv();
  var r = await http.post(Uri.parse('$_api/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': env['ADMIN_CORREO'], 'password': env['ADMIN_PASSWORD']}));
  _tokenAdmin = (await _json(r))['token'] as String;
  final h = {'Content-Type': 'application/json', 'Authorization': 'Bearer $_tokenAdmin'};
  final aviones = jsonDecode(utf8.decode((await http.get(Uri.parse('$_api/api/admin/aviones'), headers: h)).bodyBytes)) as List;
  final a320 = aviones.firstWhere((a) => a['matricula'] == 'HC-ATA');
  for (var i = 0; i < 30; i++) {
    _codigoVuelo = 'Z${String.fromCharCode(65 + _random.nextInt(26))}${1000 + _random.nextInt(9000)}';
    final dia = 1 + _random.nextInt(28), mes = 2 + _random.nextInt(10);
    final hora = 6 + _random.nextInt(12);
    r = await http.post(Uri.parse('$_api/api/admin/vuelos'),
        headers: h,
        body: jsonEncode({
          'codigo_vuelo': _codigoVuelo, 'avion_id': a320['id'], 'origen': 'UIO', 'destino': 'GYE',
          'fecha': '2027-${mes.toString().padLeft(2, '0')}-${dia.toString().padLeft(2, '0')}',
          'hora_salida': '${hora.toString().padLeft(2, '0')}:00', 'hora_llegada': '${(hora + 1).toString().padLeft(2, '0')}:00',
          'precio': 80, 'precio_ejecutiva': 150,
        }));
    if (r.statusCode == 201) {
      _vueloId = (await _json(r))['vuelo']['id'] as int;
      return;
    }
  }
  throw StateError('No se pudo crear el vuelo de prueba');
}

Future<void> _cancelarVueloDePrueba() async {
  await http.put(Uri.parse('$_api/api/admin/vuelos/$_vueloId/cancelar'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_tokenAdmin'},
      body: jsonEncode({'motivo': 'Limpieza de pruebas'}));
}

/// Avanza con reloj real hasta que aparezca el finder (las llamadas HTTP son reales).
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

Future<void> avanzar(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<String> _registrarYEntrar(WidgetTester t) async {
  t.view.physicalSize = const Size(1300, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  await Sesion.instancia.cerrar();
  final correo = 'test_flutter_cli_${DateTime.now().microsecondsSinceEpoch}@correo.com';
  await t.runAsync(() => UsuarioService.registrar(
      nombre: 'Cliente', apellido: 'Flutter', cedula: _cedula(), telefono: '0991234567', correo: correo, password: 'Prueba1234'));
  await t.pumpWidget(const AeroTechApp());
  await esperar(t, find.byType(LoginScreen));
  await t.enterText(find.byType(TextFormField).at(0), correo);
  await t.enterText(find.byType(TextFormField).at(1), 'Prueba1234');
  await t.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
  await esperar(t, find.byType(ClienteHome));
  return correo;
}

Finder _asiento(String codigo) => find.byWidgetPredicate((w) => w is AsientoWidget && w.asiento.codigo == codigo);

Future<void> _tocarAsiento(WidgetTester t, String codigo) async {
  await t.tap(_asiento(codigo), warnIfMissed: false);
  await avanzar(t);
}

Future<void> _abrirVueloYElegir(WidgetTester t) async {
  await esperar(t, find.byType(VueloCard)); // lista de vuelos cargada
  await t.scrollUntilVisible(find.text(_codigoVuelo), 400,
      scrollable: find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)), maxScrolls: 80);
  await avanzar(t);
  await t.tap(find.text(_codigoVuelo));
  await esperar(t, find.text('Elegir asientos'));
  await t.tap(find.widgetWithText(FilledButton, 'Elegir asientos'));
  await esperar(t, _asiento('1A'));
}

/// Rellena la tarjeta [i] de pasajeros (nombres, apellidos, cédula y fecha de nacimiento con el selector).
Future<void> _llenarPasajero(WidgetTester t, int i) async {
  final campos = find.byType(TextFormField);
  await t.enterText(campos.at(i * 4), 'Pasajero$i'.replaceAll(RegExp(r'\d'), ''));
  await t.enterText(campos.at(i * 4 + 1), 'Prueba');
  await t.enterText(campos.at(i * 4 + 2), _cedula());
  await t.ensureVisible(campos.at(i * 4 + 3));
  await avanzar(t);
  await t.tap(campos.at(i * 4 + 3));
  await avanzar(t, 10);
  await t.tap(find.textContaining(RegExp('aceptar', caseSensitive: false)));
  await avanzar(t, 10);
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('es');
    await _crearVueloDePrueba();
  });

  tearDownAll(_cancelarVueloDePrueba);

  testWidgets('Flujo completo: reservar, comprobante, editar a 3 asientos, historial y cancelar', (t) async {
    await _registrarYEntrar(t);

    // 1) Buscar el vuelo, abrirlo y elegir 2 asientos (1A ejecutiva, 5A económica)
    await _abrirVueloYElegir(t);
    await _tocarAsiento(t, '1A');
    await _tocarAsiento(t, '5A');
    expect(find.textContaining('Asientos: 1A, 5A'), findsWidgets);
    expect(find.textContaining('Total parcial \$230.00'), findsWidgets); // 150 + 80
    await t.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await avanzar(t, 10);

    // 2) Datos de los pasajeros
    expect(find.text('Datos de los pasajeros'), findsOneWidget);
    await _llenarPasajero(t, 0);
    await _llenarPasajero(t, 1);
    await t.ensureVisible(find.text('Continuar al resumen'));
    await t.tap(find.text('Continuar al resumen'));
    await avanzar(t, 10);

    // 3) Resumen y confirmación
    expect(find.text('Resumen de la reserva'), findsOneWidget);
    expect(find.text('\$264.50'), findsOneWidget); // (150 + 80) * 1.15
    await t.tap(find.widgetWithText(FilledButton, 'Confirmar reserva'));
    await esperar(t, find.text('¡Reserva confirmada!'));
    final codigo = (t.widget(find.byType(SelectableText).first) as SelectableText).data!;
    expect(codigo.length, 6);

    // 4) Comprobante XML
    await t.tap(find.text('Ver comprobante XML'));
    await esperar(t, find.textContaining('<factura', findRichText: true));
    expect(find.textContaining(codigo, findRichText: true), findsWidgets);
    await t.tap(find.byType(BackButton));
    await avanzar(t, 10);
    await esperar(t, find.text(codigo)); // aparece en "Mis reservas"

    // 5) Detalle y edición: soltar 5A, elegir 6A y 6C → 3 asientos (1A, 6A, 6C)
    await t.tap(find.text(codigo));
    await esperar(t, find.widgetWithText(FilledButton, 'Editar reserva'));
    await t.tap(find.widgetWithText(FilledButton, 'Editar reserva'));
    await esperar(t, _asiento('1A'));
    await _tocarAsiento(t, '5A'); // suelta un asiento propio
    await _tocarAsiento(t, '6A');
    await _tocarAsiento(t, '6C');
    expect(find.textContaining('Asientos: 1A, 6A, 6C'), findsWidgets);
    await t.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await avanzar(t, 10);
    // los datos de 1A y del pasajero que perdió su asiento se conservan; falta llenar el tercero
    await _llenarPasajero(t, 2);
    await t.ensureVisible(find.text('Continuar al resumen'));
    await t.tap(find.text('Continuar al resumen'));
    await avanzar(t, 10);
    expect(find.text('Resumen de cambios'), findsOneWidget);
    expect(find.text('Diferencia'), findsOneWidget);
    expect(find.text('+\$92.00'), findsOneWidget); // un asiento económico más: 80 * 1.15
    await t.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    await esperar(t, find.text('Reserva actualizada'));
    expect(find.textContaining('+\$92.00'), findsWidgets);
    await t.tap(find.text('Ir a mis reservas'));
    await avanzar(t, 10);

    // 6) Historial: creada + modificada
    await esperar(t, find.text(codigo));
    await t.tap(find.text(codigo));
    await esperar(t, find.text('Modificada'));
    expect(find.text('Creada'), findsOneWidget);
    expect(find.textContaining('Asientos 1A, 5A → 1A, 6A, 6C'), findsOneWidget);

    // 7) Cancelar
    await t.ensureVisible(find.widgetWithText(OutlinedButton, 'Cancelar reserva'));
    await t.tap(find.widgetWithText(OutlinedButton, 'Cancelar reserva'));
    await avanzar(t, 10);
    expect(find.textContaining('Se liberarán 3 asientos'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Cancelar reserva'));
    await esperar(t, find.text('Cancelada'));
    expect(find.text('Cancelada'), findsWidgets);
    await t.ensureVisible(find.text('Historial'));
    await esperar(t, find.text('Cancelada por el cliente', skipOffstage: false));
  }, timeout: const Timeout(Duration(minutes: 12)));

  testWidgets('Conflicto 409: otro usuario toma el asiento; se avisa, se actualiza el mapa y se conservan los datos', (t) async {
    await _registrarYEntrar(t);
    await _abrirVueloYElegir(t);
    await _tocarAsiento(t, '8C');
    await _tocarAsiento(t, '8D');
    await t.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await avanzar(t, 10);
    await _llenarPasajero(t, 0);
    await _llenarPasajero(t, 1);
    await t.ensureVisible(find.text('Continuar al resumen'));
    await t.tap(find.text('Continuar al resumen'));
    await avanzar(t, 10);
    expect(find.text('Resumen de la reserva'), findsOneWidget);

    // Mientras tanto, otro usuario reserva 8C por la API
    await t.runAsync(() async {
      final correo = 'test_flutter_otro_${DateTime.now().microsecondsSinceEpoch}@correo.com';
      final h = {'Content-Type': 'application/json'};
      await http.post(Uri.parse('$_api/api/usuarios/registro'), headers: h,
          body: jsonEncode({'nombre': 'Otro', 'apellido': 'Usuario', 'cedula': _cedula(), 'telefono': '0990000001', 'correo': correo, 'password': 'Prueba1234'}));
      final login = await _json(await http.post(Uri.parse('$_api/api/auth/login'), headers: h, body: jsonEncode({'correo': correo, 'password': 'Prueba1234'})));
      final r = await http.post(Uri.parse('$_api/api/reservas/'),
          headers: {...h, 'Authorization': 'Bearer ${login['token']}'},
          body: jsonEncode({
            'vuelo_id': _vueloId,
            'pasajeros': [
              {'asiento': '8C', 'nombres': 'Otro', 'apellidos': 'Usuario', 'tipo_documento': 'cedula', 'numero_documento': _cedula(), 'fecha_nacimiento': '1985-01-01'}
            ]
          }));
      expect(r.statusCode, 201);
    });

    await t.tap(find.widgetWithText(FilledButton, 'Confirmar reserva'));
    await esperar(t, find.textContaining('acaba de reservar 8C'));
    // volvió al mapa, que se recargó: 8C ocupado y 8D sigue seleccionado
    await esperar(t, _asiento('8C'));
    for (var i = 0; i < 120; i++) {
      // la recarga del mapa es una llamada real: se espera hasta ver 8C ocupado
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await t.pump(const Duration(milliseconds: 50));
      if (_asiento('8C').evaluate().isNotEmpty && t.widget<AsientoWidget>(_asiento('8C')).estado == EstadoVisual.ocupado) break;
    }
    await avanzar(t, 6);
    final c = t.widget<AsientoWidget>(_asiento('8C'));
    expect(c.estado, EstadoVisual.ocupado);
    expect(t.widget<AsientoWidget>(_asiento('8D')).estado, EstadoVisual.seleccionado);
    expect(find.textContaining('Asientos: 8D'), findsWidgets);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
