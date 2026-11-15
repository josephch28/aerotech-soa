import '../models/asiento.dart';
import '../models/mapa_asientos.dart';
import 'validadores.dart';

/// Construye localmente el mapa de asientos de un avión (misma lógica que `generar_asientos` del backend)
/// para la vista previa en vivo del formulario de flota. Devuelve `null` si la configuración no es válida.
MapaAsientos? construirVistaPrevia({
  required String modelo,
  required String matricula,
  required String configuracion,
  required String configuracionEjecutiva,
  required int filas,
  required int filasEjecutiva,
  required List<int> filasSalida,
}) {
  final eco = configuracion.trim().toUpperCase();
  final ej = configuracionEjecutiva.trim().toUpperCase();
  if (Validadores.configuracionAvion(eco) != null) return null;
  if (Validadores.configuracionAvion(ej, opcional: true) != null) return null;
  if (filas < 5 || filas > 60 || filasEjecutiva < 0 || filasEjecutiva >= filas) return null;

  final salida = filasSalida.where((f) => f >= 1 && f <= filas).toSet();
  final asientos = <Asiento>[];
  for (var fila = 1; fila <= filas; fila++) {
    final esEj = fila <= filasEjecutiva;
    final conf = esEj ? (ej.isEmpty ? eco : ej) : eco;
    for (final letra in conf.replaceAll('-', '').split('')) {
      asientos.add(Asiento(
        codigo: '$fila$letra',
        fila: fila,
        columna: letra,
        clase: esEj ? 'ejecutiva' : 'economica',
        salidaEmergencia: salida.contains(fila),
        estado: 'disponible',
        precio: 0,
      ));
    }
  }
  return MapaAsientos(
    modelo: modelo.trim().isEmpty ? 'Nuevo avión' : modelo.trim(),
    matricula: matricula.trim().toUpperCase(),
    configuracion: eco,
    configuracionEjecutiva: ej.isEmpty ? null : ej,
    filas: filas,
    filasEjecutiva: filasEjecutiva,
    filasSalida: salida.toList()..sort(),
    resumen: ResumenAsientos(asientos.length, asientos.length, 0),
    asientos: asientos,
  );
}
