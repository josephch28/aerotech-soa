import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/usuario.dart';

/// Sesión única de la aplicación (singleton): token JWT y usuario, persistidos en el dispositivo.
/// Es un [ChangeNotifier] para que la barra superior y las pantallas públicas se actualicen al
/// iniciar o cerrar sesión.
class Sesion extends ChangeNotifier {
  Sesion._();
  static final Sesion instancia = Sesion._();

  static const _claveToken = 'aerotech_token';
  static const _claveUsuario = 'aerotech_usuario';

  String? token;
  Usuario? usuario;

  bool get activa => token != null && token!.isNotEmpty;
  bool get esAdmin => usuario?.esAdmin ?? false;
  String get rol => usuario?.rol ?? '';

  /// Pantalla a la que se va después de iniciar sesión: el administrador a su panel y el cliente
  /// a la página principal (como en las aerolíneas reales, donde se vuelve al inicio con la sesión abierta).
  String get rutaInicio => esAdmin ? '/admin' : '/inicio';

  Future<void> cargar() async {
    try {
      final p = await SharedPreferences.getInstance();
      token = p.getString(_claveToken);
      final u = p.getString(_claveUsuario);
      usuario = u == null ? null : Usuario.fromJson(jsonDecode(u) as Map<String, dynamic>);
    } catch (_) {
      token = null;
      usuario = null;
    }
    notifyListeners();
  }

  Future<void> guardar(String nuevoToken, Usuario nuevoUsuario) async {
    token = nuevoToken;
    usuario = nuevoUsuario;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_claveToken, nuevoToken);
      await p.setString(_claveUsuario, jsonEncode(nuevoUsuario.toJson()));
    } catch (_) {}
  }

  /// Actualiza solo los datos del usuario (por ejemplo tras verificar el perfil o editarlo).
  Future<void> actualizarUsuario(Usuario nuevo) async {
    usuario = nuevo;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_claveUsuario, jsonEncode(nuevo.toJson()));
    } catch (_) {}
  }

  Future<void> cerrar() async {
    token = null;
    usuario = null;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_claveToken);
      await p.remove(_claveUsuario);
    } catch (_) {}
  }
}
