import '../models/avion.dart';
import '../models/mapa_asientos.dart';
import '../models/usuario.dart';
import '../models/vuelo.dart';
import 'api_client.dart';

typedef Json = Map<String, dynamic>;

class AdminService {
  // ── Flota ──
  static Future<List<Avion>> aviones() async =>
      (await ApiClient.get('/api/admin/aviones') as List).map((e) => Avion.fromJson(e as Json)).toList();

  static Future<Avion> crearAvion(Json datos) async =>
      Avion.fromJson((await ApiClient.post('/api/admin/aviones', cuerpo: datos))['avion'] as Json);

  static Future<Avion> editarAvion(int id, Json datos) async =>
      Avion.fromJson((await ApiClient.put('/api/admin/aviones/$id', cuerpo: datos))['avion'] as Json);

  static Future<void> estadoAvion(int id, bool activo) async =>
      ApiClient.patch('/api/admin/aviones/$id/estado', cuerpo: {'activo': activo});

  static Future<MapaAsientos> vistaPrevia(int avionId) async =>
      MapaAsientos.fromJson(await ApiClient.get('/api/admin/aviones/$avionId/vista-previa') as Json);

  // ── Vuelos ──
  static Future<List<Vuelo>> vuelos({String? estado, String? desde, String? hasta, String? origen, String? destino}) async {
    final r = await ApiClient.get('/api/admin/vuelos',
        query: {'estado': estado, 'desde': desde, 'hasta': hasta, 'origen': origen, 'destino': destino});
    return (r['vuelos'] as List).map((e) => Vuelo.fromJson(e as Json)).toList();
  }

  static Future<int> crearVuelo(Json datos) async {
    final r = await ApiClient.post('/api/admin/vuelos', cuerpo: datos);
    return r['asientos_generados'] as int;
  }

  static Future<void> editarVuelo(int id, Json datos) async => ApiClient.put('/api/admin/vuelos/$id', cuerpo: datos);

  /// Devuelve el número de reservas afectadas.
  static Future<int> cancelarVuelo(int id, String motivo) async {
    final r = await ApiClient.put('/api/admin/vuelos/$id/cancelar', cuerpo: {'motivo': motivo});
    return r['reservas_afectadas'] as int;
  }

  static Future<Json> manifiesto(int vueloId) async =>
      await ApiClient.get('/api/admin/vuelos/$vueloId/manifiesto') as Json;

  // ── Reservas y usuarios ──
  static Future<List<Json>> reservas({String? estado, int? vueloId, String? codigo, String? correo}) async {
    final r = await ApiClient.get('/api/admin/reservas',
        query: {'estado': estado, 'vuelo_id': vueloId, 'codigo': codigo, 'correo': correo});
    return (r['reservas'] as List).map((e) => e as Json).toList();
  }

  static Future<void> cancelarReserva(int id, String motivo) async =>
      ApiClient.put('/api/reservas/$id/cancelar', cuerpo: {'motivo': motivo});

  static Future<List<Usuario>> usuarios({String? rol, bool? activo, String? buscar}) async {
    final r = await ApiClient.get('/api/admin/usuarios', query: {'rol': rol, 'activo': activo, 'buscar': buscar});
    return (r['usuarios'] as List).map((e) => Usuario.fromJson(e as Json)).toList();
  }

  static Future<void> modificarUsuario(int id, {String? rol, bool? activo}) async => ApiClient.patch(
      '/api/admin/usuarios/$id', cuerpo: {'rol': ?rol, 'activo': ?activo});
}
