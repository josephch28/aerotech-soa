import 'json_util.dart';

class Asiento {
  final String codigo, columna, clase, estado;
  final int fila;
  final bool salidaEmergencia;
  final double precio;

  const Asiento({
    required this.codigo,
    required this.fila,
    required this.columna,
    required this.clase,
    required this.salidaEmergencia,
    required this.estado,
    required this.precio,
  });

  factory Asiento.fromJson(Map<String, dynamic> j) => Asiento(
        codigo: texto(j['codigo']),
        fila: entero(j['fila']),
        columna: texto(j['columna']),
        clase: texto(j['clase']),
        salidaEmergencia: j['salida_emergencia'] ?? false,
        estado: texto(j['estado']),
        precio: numero(j['precio']),
      );

  bool get esEjecutiva => clase == 'ejecutiva';
  bool get ocupado => estado == 'ocupado';
}
