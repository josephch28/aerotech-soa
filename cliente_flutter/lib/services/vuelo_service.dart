import '../models/aeropuerto.dart';
import '../models/mapa_asientos.dart';
import '../models/vuelo.dart';
import 'api_client.dart';

class VueloService {
  static Future<List<Aeropuerto>> aeropuertos() async {
    final r = await ApiClient.get('/api/aeropuertos', auth: false) as List;
    return r.map((e) => Aeropuerto.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Vuelo>> buscar({String? origen, String? destino, String? fecha, int pasajeros = 1}) async {
    final r = await ApiClient.get('/api/vuelos',
        query: {'origen': origen, 'destino': destino, 'fecha': fecha, 'pasajeros': pasajeros}, auth: false);
    return (r['vuelos'] as List).map((e) => Vuelo.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Vuelo> detalle(int id) async =>
      Vuelo.fromJson(await ApiClient.get('/api/vuelos/$id', auth: false) as Map<String, dynamic>);

  static Future<MapaAsientos> mapa(int vueloId) async =>
      MapaAsientos.fromJson(await ApiClient.get('/api/vuelos/$vueloId/asientos', auth: false) as Map<String, dynamic>);
}
