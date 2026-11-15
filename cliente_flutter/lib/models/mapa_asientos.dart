import 'asiento.dart';
import 'json_util.dart';

class ResumenAsientos {
  final int total, disponibles, ocupados;
  const ResumenAsientos(this.total, this.disponibles, this.ocupados);
}

class MapaAsientos {
  // Vuelo (puede ser nulo en la vista previa del administrador)
  final int? vueloId;
  final String codigoVuelo, origen, destino, fecha, horaSalida;
  final double precio, precioEjecutiva;
  // Avión
  final String modelo, matricula, configuracion;
  final String? configuracionEjecutiva;
  final int filas, filasEjecutiva;
  final List<int> filasSalida;
  final ResumenAsientos resumen;
  final List<Asiento> asientos;

  const MapaAsientos({
    this.vueloId,
    this.codigoVuelo = '',
    this.origen = '',
    this.destino = '',
    this.fecha = '',
    this.horaSalida = '',
    this.precio = 0,
    this.precioEjecutiva = 0,
    required this.modelo,
    required this.matricula,
    required this.configuracion,
    this.configuracionEjecutiva,
    required this.filas,
    required this.filasEjecutiva,
    required this.filasSalida,
    required this.resumen,
    required this.asientos,
  });

  factory MapaAsientos.fromJson(Map<String, dynamic> j) {
    final v = (j['vuelo'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final a = j['avion'] as Map<String, dynamic>;
    final r = j['resumen'] as Map<String, dynamic>;
    return MapaAsientos(
      vueloId: v['id'] == null ? null : entero(v['id']),
      codigoVuelo: texto(v['codigo_vuelo']),
      origen: texto(v['origen']),
      destino: texto(v['destino']),
      fecha: texto(v['fecha']),
      horaSalida: texto(v['hora_salida']),
      precio: numero(v['precio']),
      precioEjecutiva: numero(v['precio_ejecutiva']),
      modelo: texto(a['modelo']),
      matricula: texto(a['matricula']),
      configuracion: texto(a['configuracion']),
      configuracionEjecutiva: a['configuracion_ejecutiva'] as String?,
      filas: entero(a['filas']),
      filasEjecutiva: entero(a['filas_ejecutiva']),
      filasSalida: ((a['filas_salida'] ?? []) as List).map(entero).toList(),
      resumen: ResumenAsientos(entero(r['total']), entero(r['disponibles']), entero(r['ocupados'])),
      asientos: (j['asientos'] as List).map((e) => Asiento.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
