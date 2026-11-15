import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../sesion.dart';

/// Navegador global para poder volver a Login desde cualquier capa (por ejemplo ante un 401).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Mensaje que la pantalla de Login muestra una vez (p. ej. al ser expulsado por token revocado).
final ValueNotifier<String?> avisoLogin = ValueNotifier<String?>(null);

class ApiException implements Exception {
  final String mensaje;
  final int codigo;
  final Map<String, String> campos;
  final Map<String, dynamic> extra;

  ApiException(this.mensaje, {this.codigo = 0, this.campos = const {}, this.extra = const {}});

  @override
  String toString() => mensaje;
}

/// Cliente HTTP único: Bearer automático, tiempo de espera de 60 s y errores uniformes.
class ApiClient {
  ApiClient._();

  /// `true` cuando alguna llamada lleva más de 5 s (se muestra "Conectando con el servidor…").
  static final ValueNotifier<bool> conexionLenta = ValueNotifier(false);
  static int _pendientes = 0;

  /// Llamadas en curso (las pruebas lo usan para esperar a que todo termine).
  static int get pendientes => _pendientes;

  static Uri _uri(String ruta, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) q[k] = '$v';
    });
    return Uri.parse('$apiUrl$ruta').replace(queryParameters: q.isEmpty ? null : q);
  }

  static Map<String, String> _cabeceras({bool json = false, bool auth = true}) => {
        if (json) 'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        if (auth && Sesion.instancia.activa) 'Authorization': 'Bearer ${Sesion.instancia.token}',
      };

  static Future<http.Response> _ejecutar(Future<http.Response> Function() llamada) async {
    _pendientes++;
    final aviso = Timer(umbralConexionLenta, () => conexionLenta.value = true);
    try {
      return await llamada().timeout(tiempoEspera);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder. Intente de nuevo.');
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor. Verifique su conexión.');
    } finally {
      aviso.cancel();
      _pendientes--;
      if (_pendientes == 0) conexionLenta.value = false;
    }
  }

  static Future<dynamic> _procesar(http.Response r, {required bool conToken}) async {
    final cuerpo = r.bodyBytes.isEmpty ? '' : utf8.decode(r.bodyBytes);
    dynamic datos;
    try {
      datos = cuerpo.isEmpty ? null : jsonDecode(cuerpo);
    } catch (_) {
      datos = null;
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return datos;

    final mapa = datos is Map<String, dynamic> ? datos : <String, dynamic>{};
    final campos = <String, String>{};
    (mapa['campos'] as Map?)?.forEach((k, v) => campos['$k'] = '$v');
    final extra = Map<String, dynamic>.from(mapa)..removeWhere((k, _) => ['error', 'codigo', 'campos'].contains(k));
    final mensaje = (mapa['error'] as String?) ?? 'Error del servidor (${r.statusCode})';

    // Sesión inválida (token revocado/expirado) o cuenta desactivada: se cierra la sesión y se vuelve a Login con aviso.
    final cuentaDesactivada = r.statusCode == 403 && mensaje.contains('desactivada');
    if ((r.statusCode == 401 || cuentaDesactivada) && conToken && Sesion.instancia.activa) {
      await Sesion.instancia.cerrar();
      avisoLogin.value = cuentaDesactivada
          ? 'Su cuenta fue desactivada. Contacte al administrador.'
          : 'Su sesión ya no es válida (se cerró o su cuenta fue desactivada). Inicie sesión de nuevo.';
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    }
    throw ApiException(mensaje, codigo: r.statusCode, campos: campos, extra: extra);
  }

  static Future<dynamic> get(String ruta, {Map<String, dynamic>? query, bool auth = true}) async =>
      _procesar(await _ejecutar(() => http.get(_uri(ruta, query), headers: _cabeceras(auth: auth))), conToken: auth);

  static Future<dynamic> post(String ruta, {Object? cuerpo, bool auth = true}) async => _procesar(
      await _ejecutar(() => http.post(_uri(ruta), headers: _cabeceras(json: true, auth: auth), body: jsonEncode(cuerpo ?? {}))),
      conToken: auth);

  static Future<dynamic> put(String ruta, {Object? cuerpo}) async => _procesar(
      await _ejecutar(() => http.put(_uri(ruta), headers: _cabeceras(json: true), body: jsonEncode(cuerpo ?? {}))),
      conToken: true);

  static Future<dynamic> patch(String ruta, {Object? cuerpo}) async => _procesar(
      await _ejecutar(() => http.patch(_uri(ruta), headers: _cabeceras(json: true), body: jsonEncode(cuerpo ?? {}))),
      conToken: true);

  /// Descarga texto plano (el comprobante XML).
  static Future<String> getTexto(String ruta) async {
    final r = await _ejecutar(() => http.get(_uri(ruta), headers: {
          'Accept': 'application/xml',
          if (Sesion.instancia.activa) 'Authorization': 'Bearer ${Sesion.instancia.token}',
        }));
    if (r.statusCode >= 200 && r.statusCode < 300) return utf8.decode(r.bodyBytes);
    await _procesar(r, conToken: true);
    return '';
  }
}
