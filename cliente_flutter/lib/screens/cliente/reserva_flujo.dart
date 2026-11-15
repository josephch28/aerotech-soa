import 'package:flutter/foundation.dart';

import '../../models/asiento.dart';
import '../../models/mapa_asientos.dart';
import '../../models/pasajero.dart';
import '../../models/reserva.dart';
import '../../models/vuelo.dart';
import '../../config.dart';

/// Estado compartido entre las pantallas del flujo de reserva (selección → pasajeros → resumen).
/// Con `original` != null el flujo está en modo edición.
class ReservaFlujo {
  final Vuelo vuelo;
  final Reserva? original;
  MapaAsientos? mapa;
  List<String> seleccion;
  final Map<String, Pasajero> datos = {}; // datos escritos por asiento (se conservan entre pantallas)
  String telefono, correo;

  /// Se incrementa cuando el mapa debe recargarse (p. ej. tras un 409 de asientos ocupados).
  final ValueNotifier<int> recargarMapa = ValueNotifier(0);

  ReservaFlujo(this.vuelo, {this.original, required this.telefono, required this.correo})
      : seleccion = List.of(original?.asientos ?? const []) {
    final o = original;
    if (o != null) {
      for (final p in o.pasajeros) {
        datos[p.asiento] = Pasajero(
          asiento: p.asiento,
          nombres: p.nombres,
          apellidos: p.apellidos,
          tipoDocumento: p.tipoDocumento,
          numeroDocumento: p.numeroDocumento,
          fechaNacimiento: p.fechaNacimiento,
        );
      }
    }
  }

  bool get edicion => original != null;
  Set<String> get propios => original?.asientos.toSet() ?? <String>{};

  Asiento? asiento(String codigo) {
    final m = mapa;
    if (m == null) return null;
    for (final a in m.asientos) {
      if (a.codigo == codigo) return a;
    }
    return null;
  }

  /// "5A" < "5C" < "12A": primero por número de fila, luego por letra.
  static int comparar(String a, String b) {
    int fila(String s) => int.parse(s.substring(0, s.length - 1));
    final c = fila(a).compareTo(fila(b));
    return c != 0 ? c : a.compareTo(b);
  }

  List<String> get ordenados => (List.of(seleccion)..sort(comparar));

  double precioDe(String codigo) => asiento(codigo)?.precio ?? 0;

  double get subtotal => seleccion.fold(0.0, (s, c) => s + precioDe(c));
  double get iva => double.parse((subtotal * ivaPorcentaje / 100).toStringAsFixed(2));
  double get total => subtotal + iva;
}
