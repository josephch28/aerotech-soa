import 'json_util.dart';

class Vuelo {
  final int id, duracionMinutos, asientosDisponibles, capacidad;
  final String codigoVuelo, origen, destino, ciudadOrigen, ciudadDestino;
  final String fecha, horaSalida, horaLlegada, estado, modeloAvion, matricula;
  final double precio, precioEjecutiva, ocupacion, ingresos;

  const Vuelo({
    required this.id,
    required this.codigoVuelo,
    required this.origen,
    required this.destino,
    this.ciudadOrigen = '',
    this.ciudadDestino = '',
    required this.fecha,
    required this.horaSalida,
    this.horaLlegada = '',
    this.duracionMinutos = 0,
    this.precio = 0,
    this.precioEjecutiva = 0,
    this.asientosDisponibles = 0,
    this.estado = 'programado',
    this.modeloAvion = '',
    this.matricula = '',
    this.capacidad = 0,
    this.ocupacion = 0,
    this.ingresos = 0,
  });

  factory Vuelo.fromJson(Map<String, dynamic> j) => Vuelo(
        id: entero(j['id']),
        codigoVuelo: texto(j['codigo_vuelo']),
        origen: texto(j['origen']),
        destino: texto(j['destino']),
        ciudadOrigen: texto(j['ciudad_origen']),
        ciudadDestino: texto(j['ciudad_destino']),
        fecha: texto(j['fecha']),
        horaSalida: texto(j['hora_salida']),
        horaLlegada: texto(j['hora_llegada']),
        duracionMinutos: entero(j['duracion_minutos']),
        precio: numero(j['precio']),
        precioEjecutiva: numero(j['precio_ejecutiva']),
        asientosDisponibles: entero(j['asientos_disponibles']),
        estado: texto(j['estado']).isEmpty ? 'programado' : texto(j['estado']),
        modeloAvion: texto(j['modelo_avion']),
        matricula: texto(j['matricula']),
        capacidad: entero(j['capacidad']),
        ocupacion: numero(j['ocupacion']),
        ingresos: numero(j['ingresos']),
      );

  /// Fecha y hora de salida (hora local de Ecuador, sin zona).
  DateTime get salida {
    final f = DateTime.parse(fecha);
    final h = horaSalida.split(':');
    return DateTime(f.year, f.month, f.day, int.parse(h[0]), int.parse(h[1]));
  }

  DateTime get fechaDia => DateTime.parse(fecha);
  String get ruta => '$origen → $destino';
}
