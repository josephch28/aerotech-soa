import 'json_util.dart';

class EventoHistorial {
  final String accion, usuario;
  final DateTime? fecha;
  final Map<String, dynamic> detalle;

  const EventoHistorial({required this.accion, required this.usuario, this.fecha, this.detalle = const {}});

  factory EventoHistorial.fromJson(Map<String, dynamic> j) => EventoHistorial(
        accion: texto(j['accion']),
        usuario: texto(j['usuario']),
        fecha: fechaHora(j['fecha']),
        detalle: (j['detalle'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      );
}
