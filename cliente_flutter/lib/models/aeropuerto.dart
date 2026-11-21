import 'json_util.dart';

class Aeropuerto {
  final String codigo, ciudad, nombre;
  const Aeropuerto({required this.codigo, required this.ciudad, this.nombre = ''});

  factory Aeropuerto.fromJson(Map<String, dynamic> j) =>
      Aeropuerto(codigo: texto(j['codigo']), ciudad: texto(j['ciudad']), nombre: texto(j['nombre']));

  /// Dos aeropuertos son iguales si tienen el mismo código IATA (necesario para los selectores:
  /// la lista se vuelve a cargar en cada pantalla y los objetos no son la misma instancia).
  @override
  bool operator ==(Object other) => other is Aeropuerto && other.codigo == codigo;

  @override
  int get hashCode => codigo.hashCode;

  @override
  String toString() => '$ciudad ($codigo)';
}
