import 'json_util.dart';
import 'pasajero.dart';
import 'vuelo.dart';

class Reserva {
  final int id, cantidadAsientos;
  final String codigoReserva, estado, telefonoContacto, correoContacto, motivoCancelacion;
  final double subtotal, iva, total;
  final List<String> asientos;
  final List<Pasajero> pasajeros;
  final Vuelo? vuelo;
  final DateTime? fechaReserva, fechaModificacion;
  final bool puedeEditar, puedeCancelar;

  const Reserva({
    required this.id,
    required this.codigoReserva,
    required this.estado,
    required this.cantidadAsientos,
    this.subtotal = 0,
    this.iva = 0,
    this.total = 0,
    this.asientos = const [],
    this.pasajeros = const [],
    this.vuelo,
    this.telefonoContacto = '',
    this.correoContacto = '',
    this.motivoCancelacion = '',
    this.fechaReserva,
    this.fechaModificacion,
    this.puedeEditar = false,
    this.puedeCancelar = false,
  });

  factory Reserva.fromJson(Map<String, dynamic> j) {
    final pas = ((j['pasajeros'] ?? []) as List).map((e) => Pasajero.fromJson(e as Map<String, dynamic>)).toList();
    final contacto = (j['contacto'] ?? <String, dynamic>{}) as Map<String, dynamic>;
    final asientos = j['asientos'] != null
        ? (j['asientos'] as List).map((e) => '$e').toList()
        : pas.map((p) => p.asiento).toList();
    return Reserva(
      id: entero(j['id']),
      codigoReserva: texto(j['codigo_reserva']),
      estado: texto(j['estado']),
      cantidadAsientos: entero(j['cantidad_asientos']),
      subtotal: numero(j['subtotal']),
      iva: numero(j['iva']),
      total: numero(j['total']),
      asientos: asientos,
      pasajeros: pas,
      vuelo: j['vuelo'] == null ? null : Vuelo.fromJson(j['vuelo'] as Map<String, dynamic>),
      telefonoContacto: texto(contacto['telefono']),
      correoContacto: texto(contacto['correo']),
      motivoCancelacion: texto(j['motivo_cancelacion']),
      fechaReserva: fechaHora(j['fecha_reserva']),
      fechaModificacion: fechaHora(j['fecha_modificacion']),
      puedeEditar: j['puede_editar'] ?? false,
      puedeCancelar: j['puede_cancelar'] ?? false,
    );
  }

  bool get confirmada => estado == 'confirmada';
}
