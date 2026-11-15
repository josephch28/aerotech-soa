import '../models/evento_historial.dart';
import '../models/pasajero.dart';
import '../models/reserva.dart';
import 'api_client.dart';

class ReservaService {
  static Map<String, dynamic> _cuerpo(List<Pasajero> pasajeros, String telefono, String correo, {int? vueloId}) => {
        'vuelo_id': ?vueloId,
        'contacto': {'telefono': telefono.trim(), 'correo': correo.trim().toLowerCase()},
        'pasajeros': pasajeros.map((p) => p.toJson()).toList(),
      };

  static Future<Reserva> crear(int vueloId, List<Pasajero> pasajeros, String telefono, String correo) async {
    final r = await ApiClient.post('/api/reservas/', cuerpo: _cuerpo(pasajeros, telefono, correo, vueloId: vueloId));
    return Reserva.fromJson(r['reserva'] as Map<String, dynamic>);
  }

  /// Devuelve la reserva actualizada y la diferencia de total (nuevo − anterior).
  static Future<({Reserva reserva, double diferencia})> editar(
      int id, List<Pasajero> pasajeros, String telefono, String correo) async {
    final r = await ApiClient.put('/api/reservas/$id', cuerpo: _cuerpo(pasajeros, telefono, correo));
    return (
      reserva: Reserva.fromJson(r['reserva'] as Map<String, dynamic>),
      diferencia: (r['diferencia'] as num).toDouble(),
    );
  }

  static Future<List<Reserva>> mias({String? estado}) async {
    final r = await ApiClient.get('/api/reservas/', query: {'estado': estado});
    return (r['reservas'] as List).map((e) => Reserva.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Reserva> detalle(int id) async =>
      Reserva.fromJson(await ApiClient.get('/api/reservas/$id') as Map<String, dynamic>);

  static Future<void> cancelar(int id, {String? motivo}) async =>
      ApiClient.put('/api/reservas/$id/cancelar', cuerpo: motivo == null ? {} : {'motivo': motivo});

  static Future<String> facturaXml(int id) => ApiClient.getTexto('/api/reservas/$id/factura');

  static Future<List<EventoHistorial>> historial(int id) async {
    final r = await ApiClient.get('/api/reservas/$id/historial');
    return (r['eventos'] as List).map((e) => EventoHistorial.fromJson(e as Map<String, dynamic>)).toList();
  }
}
