import '../models/usuario.dart';
import '../sesion.dart';
import 'api_client.dart';

class UsuarioService {
  static Future<void> registrar({
    required String nombre,
    required String apellido,
    required String cedula,
    required String telefono,
    required String correo,
    required String password,
  }) async {
    await ApiClient.post('/api/usuarios/registro',
        cuerpo: {
          'nombre': nombre.trim(),
          'apellido': apellido.trim(),
          'cedula': cedula.trim(),
          'telefono': telefono.trim(),
          'correo': correo.trim().toLowerCase(),
          'password': password,
        },
        auth: false);
  }

  /// Perfil actual (también valida que el token guardado siga vigente).
  static Future<Usuario> perfil({bool expulsar = true}) async {
    final r = await ApiClient.get('/api/usuarios/perfil', expulsar: expulsar);
    final u = Usuario.fromJson(r as Map<String, dynamic>);
    await Sesion.instancia.actualizarUsuario(u);
    return u;
  }

  static Future<Usuario> editarPerfil({required String nombre, required String apellido, required String telefono}) async {
    await ApiClient.put('/api/usuarios/perfil',
        cuerpo: {'nombre': nombre.trim(), 'apellido': apellido.trim(), 'telefono': telefono.trim()});
    return perfil();
  }

  static Future<void> cambiarPassword(String actual, String nueva) async {
    await ApiClient.put('/api/usuarios/password', cuerpo: {'password_actual': actual, 'password_nueva': nueva});
  }
}
