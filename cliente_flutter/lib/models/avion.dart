import 'json_util.dart';

class Avion {
  final int id, filas, filasEjecutiva, capacidad, vuelosFuturos;
  final String modelo, matricula, configuracion;
  final String? configuracionEjecutiva;
  final List<int> filasSalida;
  final bool activo;

  const Avion({
    required this.id,
    required this.modelo,
    required this.matricula,
    required this.configuracion,
    this.configuracionEjecutiva,
    required this.filas,
    this.filasEjecutiva = 0,
    this.filasSalida = const [],
    this.activo = true,
    this.capacidad = 0,
    this.vuelosFuturos = 0,
  });

  factory Avion.fromJson(Map<String, dynamic> j) => Avion(
        id: entero(j['id']),
        modelo: texto(j['modelo']),
        matricula: texto(j['matricula']),
        configuracion: texto(j['configuracion']),
        configuracionEjecutiva: j['configuracion_ejecutiva'] as String?,
        filas: entero(j['filas']),
        filasEjecutiva: entero(j['filas_ejecutiva']),
        filasSalida: ((j['filas_salida'] ?? []) as List).map(entero).toList(),
        activo: j['activo'] ?? true,
        capacidad: entero(j['capacidad']),
        vuelosFuturos: entero(j['vuelos_futuros']),
      );

  @override
  String toString() => '$modelo · $matricula';
}
