import '../models/usuario.dart';
import '../sesion.dart';
import 'api_client.dart';

class AuthService {
  /// Inicia sesión, guarda el token y devuelve el usuario.
  static Future<Usuario> login(String correo, String password) async {
    final r = await ApiClient.post('/api/auth/login',
        cuerpo: {'correo': correo.trim().toLowerCase(), 'password': password}, auth: false);
    final usuario = Usuario.fromJson(r['usuario'] as Map<String, dynamic>);
    await Sesion.instancia.guardar(r['token'] as String, usuario);
    return usuario;
  }

  /// Cierra la sesión en el servidor (revoca el token) y localmente. Nunca lanza error.
  static Future<void> logout() async {
    try {
      if (Sesion.instancia.activa) await ApiClient.post('/api/auth/logout');
    } catch (_) {}
    await Sesion.instancia.cerrar();
  }
}
