import 'json_util.dart';

class Usuario {
  final int id;
  final String nombre, apellido, cedula, telefono, correo, rol;
  final bool activo;
  final int totalReservas, reservasActivas;

  const Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    this.cedula = '',
    this.telefono = '',
    required this.correo,
    required this.rol,
    this.activo = true,
    this.totalReservas = 0,
    this.reservasActivas = 0,
  });

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: entero(j['id']),
        nombre: texto(j['nombre']),
        apellido: texto(j['apellido']),
        cedula: texto(j['cedula']),
        telefono: texto(j['telefono']),
        correo: texto(j['correo']),
        rol: texto(j['rol']),
        activo: j['activo'] ?? true,
        totalReservas: entero(j['total_reservas']),
        reservasActivas: entero(j['reservas_activas']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'apellido': apellido,
        'cedula': cedula,
        'telefono': telefono,
        'correo': correo,
        'rol': rol,
        'activo': activo,
      };

  String get nombreCompleto => '$nombre $apellido';
  bool get esAdmin => rol == 'admin';
}
