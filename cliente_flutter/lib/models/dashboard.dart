import 'json_util.dart';

class Dashboard {
  final int vuelosProgramados, reservasConfirmadas, pasajeros, usuariosClientes;
  final double ingresos, ocupacionPromedio;
  final List<Map<String, dynamic>> ocupacionPorVuelo, reservasPorDia, rutasTop;

  const Dashboard({
    required this.vuelosProgramados,
    required this.reservasConfirmadas,
    required this.pasajeros,
    required this.usuariosClientes,
    required this.ingresos,
    required this.ocupacionPromedio,
    required this.ocupacionPorVuelo,
    required this.reservasPorDia,
    required this.rutasTop,
  });

  static List<Map<String, dynamic>> _lista(dynamic v) =>
      ((v ?? []) as List).map((e) => e as Map<String, dynamic>).toList();

  factory Dashboard.fromJson(Map<String, dynamic> j) {
    final i = j['indicadores'] as Map<String, dynamic>;
    return Dashboard(
      vuelosProgramados: entero(i['vuelos_programados']),
      reservasConfirmadas: entero(i['reservas_confirmadas']),
      pasajeros: entero(i['pasajeros']),
      usuariosClientes: entero(i['usuarios_clientes']),
      ingresos: numero(i['ingresos']),
      ocupacionPromedio: numero(i['ocupacion_promedio']),
      ocupacionPorVuelo: _lista(j['ocupacion_por_vuelo']),
      reservasPorDia: _lista(j['reservas_por_dia']),
      rutasTop: _lista(j['rutas_top']),
    );
  }
}
