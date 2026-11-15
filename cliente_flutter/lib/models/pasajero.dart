import 'json_util.dart';

class Pasajero {
  String asiento, nombres, apellidos, tipoDocumento, numeroDocumento, fechaNacimiento;
  final String clase;
  final double precio;
  final int edad;
  final bool salidaEmergencia;

  Pasajero({
    this.asiento = '',
    this.nombres = '',
    this.apellidos = '',
    this.tipoDocumento = 'cedula',
    this.numeroDocumento = '',
    this.fechaNacimiento = '',
    this.clase = '',
    this.precio = 0,
    this.edad = 0,
    this.salidaEmergencia = false,
  });

  factory Pasajero.fromJson(Map<String, dynamic> j) => Pasajero(
        asiento: texto(j['asiento']),
        nombres: texto(j['nombres']),
        apellidos: texto(j['apellidos']),
        tipoDocumento: texto(j['tipo_documento']),
        numeroDocumento: texto(j['numero_documento']),
        fechaNacimiento: texto(j['fecha_nacimiento']),
        clase: texto(j['clase']),
        precio: numero(j['precio']),
        edad: entero(j['edad']),
        salidaEmergencia: j['salida_emergencia'] ?? false,
      );

  /// Cuerpo que espera el backend al crear o editar una reserva.
  Map<String, dynamic> toJson() => {
        'asiento': asiento,
        'nombres': nombres.trim(),
        'apellidos': apellidos.trim(),
        'tipo_documento': tipoDocumento,
        'numero_documento': numeroDocumento.trim(),
        'fecha_nacimiento': fechaNacimiento,
      };

  String get nombreCompleto => '$nombres $apellidos';
}
