import 'json_util.dart';

class Aeropuerto {
  final String codigo, ciudad, nombre;
  const Aeropuerto({required this.codigo, required this.ciudad, this.nombre = ''});

  factory Aeropuerto.fromJson(Map<String, dynamic> j) =>
      Aeropuerto(codigo: texto(j['codigo']), ciudad: texto(j['ciudad']), nombre: texto(j['nombre']));

  @override
  String toString() => '$ciudad ($codigo)';
}
