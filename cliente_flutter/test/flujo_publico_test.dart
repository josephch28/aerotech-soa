// Flujo del VISITANTE (sin sesión), como en las aerolíneas reales:
// inicio → buscar → resultados → asientos → pasajeros → resumen → (recién aquí) iniciar sesión → confirmar.
//   flutter test test/flujo_publico_test.dart --dart-define=API_URL=<url>
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:aerotech/main.dart';
import 'package:aerotech/models/aeropuerto.dart';
import 'package:aerotech/screens/auth/login_screen.dart';
import 'package:aerotech/screens/cliente/cliente_home.dart';
import 'package:aerotech/screens/cliente/resumen_reserva_screen.dart';
import 'package:aerotech/screens/publico/landing_screen.dart';
import 'package:aerotech/screens/publico/resultados_screen.dart';
import 'package:aerotech/services/usuario_service.dart';
import 'package:aerotech/sesion.dart';
import 'package:aerotech/utils/validadores.dart';
import 'package:aerotech/widgets/mapa_asientos/asiento_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ayudas.dart';

const _api = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:5000');
final _random = Random();
late String _tokenAdmin;
late int _vueloId;
late String _codigoVuelo;

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

Future<void> _crearVueloDePrueba() async {
  final env = _leerEnv();
  const cab = {'Content-Type': 'application/json'};
  var r = await http.post(Uri.parse('$_api/api/auth/login'), headers: cab, body: jsonEncode({'correo': env['ADMIN_CORREO'], 'password': env['ADMIN_PASSWORD']}));
  _tokenAdmin = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['token'] as String;
  final h = {...cab, 'Authorization': 'Bearer $_tokenAdmin'};
  final aviones = jsonDecode(utf8.decode((await http.get(Uri.parse('$_api/api/admin/aviones'), headers: h)).bodyBytes)) as List;
  final a320 = aviones.firstWhere((a) => a['matricula'] == 'HC-ATA');
  for (var i = 0; i < 30; i++) {
    _codigoVuelo = 'W${String.fromCharCode(65 + _random.nextInt(26))}${1000 + _random.nextInt(9000)}';
    final hora = 6 + _random.nextInt(12);
    r = await http.post(Uri.parse('$_api/api/admin/vuelos'),
        headers: h,
        body: jsonEncode({
          'codigo_vuelo': _codigoVuelo, 'avion_id': a320['id'], 'origen': 'UIO', 'destino': 'GYE',
          'fecha': '2027-${(2 + _random.nextInt(10)).toString().padLeft(2, '0')}-${(1 + _random.nextInt(28)).toString().padLeft(2, '0')}',
          'hora_salida': '${hora.toString().padLeft(2, '0')}:00', 'hora_llegada': '${(hora + 1).toString().padLeft(2, '0')}:00',
          'precio': 60, 'precio_ejecutiva': 140,
        }));
    if (r.statusCode == 201) {
      _vueloId = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['vuelo']['id'] as int;
      return;
    }
  }
  throw StateError('No se pudo crear el vuelo de prueba');
}

Finder _asiento(String codigo) => find.byWidgetPredicate((w) => w is AsientoWidget && w.asiento.codigo == codigo);

Future<void> _avanzar(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _llenarPasajero(WidgetTester t, int i) async {
  final campos = find.byType(TextFormField);
  await t.enterText(campos.at(i * 4), 'Visitante');
  await t.enterText(campos.at(i * 4 + 1), 'Prueba');
  await t.enterText(campos.at(i * 4 + 2), _cedula());
  await t.ensureVisible(campos.at(i * 4 + 3));
  await _avanzar(t);
  await t.tap(campos.at(i * 4 + 3));
  await _avanzar(t, 10);
  await t.tap(find.textContaining(RegExp('aceptar', caseSensitive: false)));
  await _avanzar(t, 10);
}

void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('es');
    await _crearVueloDePrueba();
  });

  tearDownAll(() async {
    await http.put(Uri.parse('$_api/api/admin/vuelos/$_vueloId/cancelar'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_tokenAdmin'}, body: jsonEncode({'motivo': 'Limpieza de pruebas'}));
  });

  testWidgets('Visitante: busca, elige asientos y llena pasajeros sin cuenta; el login se pide al final y la reserva continúa', (t) async {
    t.view.physicalSize = const Size(1500, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    await Sesion.instancia.cerrar();

    // El cliente existe (se crea por la API); el visitante todavía NO ha iniciado sesión
    final correo = 'test_flutter_pub_${DateTime.now().microsecondsSinceEpoch}@correo.com';
    await t.runAsync(() => UsuarioService.registrar(
        nombre: 'Cliente', apellido: 'Visitante', cedula: _cedula(), telefono: '0991234567', correo: correo, password: 'Prueba1234'));

    await t.pumpWidget(const AeroTechApp());
    await esperarA(t, find.byType(LandingScreen));
    expect(Sesion.instancia.activa, isFalse);

    // 1) Buscar en la portada: Quito → Guayaquil
    await esperarA(t, find.widgetWithText(FilledButton, 'Buscar'));
    await t.tap(find.byType(DropdownButtonFormField<Aeropuerto>).first);
    await _avanzar(t);
    await t.tap(find.text('Quito (UIO)').last);
    await _avanzar(t);
    await t.tap(find.byType(DropdownButtonFormField<Aeropuerto>).last);
    await _avanzar(t);
    await t.tap(find.text('Guayaquil (GYE)').last);
    await _avanzar(t);
    await t.tap(find.widgetWithText(FilledButton, 'Buscar'));

    // 2) Resultados públicos: elegir el vuelo
    await esperarA(t, find.byType(ResultadosScreen));
    await esperarA(t, find.text(_codigoVuelo));
    await t.ensureVisible(find.text(_codigoVuelo));
    await _avanzar(t, 4);
    await t.tap(find.text(_codigoVuelo));
    await esperarA(t, find.widgetWithText(FilledButton, 'Elegir asientos'));
    await t.tap(find.widgetWithText(FilledButton, 'Elegir asientos'));

    // 3) Asientos: sin sesión
    await esperarA(t, _asiento('9A'));
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Asientos'), findsWidgets); // paso 2 del indicador de pasos
    await t.tap(_asiento('9A'), warnIfMissed: false);
    await _avanzar(t);
    await t.tap(_asiento('9B'), warnIfMissed: false);
    await _avanzar(t);
    await t.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await _avanzar(t, 10);

    // 4) Datos de pasajeros y contacto: sin sesión (no existe «Soy yo quien viaja»)
    expect(find.text('Datos de los pasajeros'), findsOneWidget);
    expect(find.text('Soy yo quien viaja'), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    await _llenarPasajero(t, 0);
    await _llenarPasajero(t, 1);
    final campos = find.byType(TextFormField);
    await t.enterText(campos.at(8), '0991234567');
    await t.enterText(campos.at(9), correo);
    await t.ensureVisible(find.text('Continuar al resumen'));
    await t.tap(find.text('Continuar al resumen'));
    await _avanzar(t, 10);

    // 5) Resumen: aquí aparece el aviso y el botón pide iniciar sesión (no se confirma todavía)
    expect(find.byType(ResumenReservaScreen), findsOneWidget);
    expect(find.textContaining('Para confirmar tu reserva inicia sesión'), findsOneWidget);
    expect(Sesion.instancia.activa, isFalse);
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Iniciar sesión para confirmar'));
    await t.tap(find.widgetWithText(FilledButton, 'Iniciar sesión para confirmar'));
    await esperarA(t, find.byType(LoginScreen));
    expect(find.text('Confirma tu reserva'), findsOneWidget);
    expect(find.textContaining('Tus asientos y los datos de los pasajeros se conservan'), findsOneWidget);

    // 6) Inicia sesión y vuelve al resumen con todo intacto
    await t.enterText(find.byType(TextFormField).at(0), correo);
    await t.enterText(find.byType(TextFormField).at(1), 'Prueba1234');
    await t.tap(find.widgetWithText(FilledButton, 'Iniciar sesión y continuar'));
    await esperarA(t, find.widgetWithText(FilledButton, 'Confirmar reserva'));
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(ResumenReservaScreen), findsOneWidget);
    expect(Sesion.instancia.activa, isTrue);
    expect(find.textContaining('9A'), findsWidgets);
    expect(find.text('\$138.00'), findsOneWidget); // (60 + 60) * 1.15

    // 7) Confirma y termina en «Mis reservas»
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Confirmar reserva'));
    await t.tap(find.widgetWithText(FilledButton, 'Confirmar reserva'));
    await esperarA(t, find.text('¡Reserva confirmada!'));
    final codigo = (t.widget(find.byType(SelectableText).first) as SelectableText).data!;
    expect(codigo.length, 6);
    await t.tap(find.text('Ir a mis reservas'));
    await esperarA(t, find.byType(ClienteHome));
    await esperarA(t, find.text(codigo));
    await drenar(t);
  }, timeout: const Timeout(Duration(minutes: 12)));
}
