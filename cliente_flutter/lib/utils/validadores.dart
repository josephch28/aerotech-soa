/// Mismas reglas que el backend (backend/validaciones.py). Cada función devuelve `null` si es válido
/// o el mensaje de error, de modo que sirven directamente como `validator` de un TextFormField.
class Validadores {
  Validadores._();

  static final _texto = RegExp(r"^[A-Za-zÁÉÍÓÚáéíóúÑñÜü' ]{2,60}$");
  static final _telefono = RegExp(r'^09\d{8}$');
  static final _correo = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
  static final _pasaporte = RegExp(r'^[A-Z0-9]{6,15}$');
  static final _codigoVuelo = RegExp(r'^[A-Z]{2}\d{3,4}$');
  static final _matricula = RegExp(r'^HC-[A-Z0-9]{3,4}$');
  static final _config = RegExp(r'^[A-K]{1,4}(-[A-K]{1,4}){1,2}$');

  static String limpiar(String? s) => (s ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

  static String? nombre(String? v) =>
      _texto.hasMatch(limpiar(v)) ? null : 'Solo letras y espacios (2-60 caracteres)';

  /// Cédula ecuatoriana: 10 dígitos y algoritmo módulo 10.
  static bool cedulaValida(String? c) {
    if (c == null || !RegExp(r'^\d{10}$').hasMatch(c)) return false;
    final provincia = int.parse(c.substring(0, 2));
    final tercero = int.parse(c[2]);
    if (!((provincia >= 1 && provincia <= 24) || provincia == 30) || tercero >= 6) return false;
    const coef = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    var suma = 0;
    for (var i = 0; i < 9; i++) {
      var p = int.parse(c[i]) * coef[i];
      if (p > 9) p -= 9;
      suma += p;
    }
    return (10 - suma % 10) % 10 == int.parse(c[9]);
  }

  static String? cedula(String? v) => cedulaValida((v ?? '').trim()) ? null : 'Cédula ecuatoriana inválida';

  static String? pasaporte(String? v) =>
      _pasaporte.hasMatch((v ?? '').trim().toUpperCase()) ? null : 'Pasaporte inválido (6-15 letras/números)';

  static String? documento(String tipo, String? v) => tipo == 'cedula' ? cedula(v) : pasaporte(v);

  static String? telefono(String? v) =>
      _telefono.hasMatch((v ?? '').trim()) ? null : 'Teléfono celular inválido (09XXXXXXXX)';

  static String? correo(String? v) => _correo.hasMatch((v ?? '').trim().toLowerCase()) ? null : 'Correo inválido';

  static String? password(String? v) {
    final s = v ?? '';
    final ok = s.length >= 8 && RegExp(r'[A-Za-z]').hasMatch(s) && RegExp(r'\d').hasMatch(s);
    return ok ? null : 'Mínimo 8 caracteres con letras y números';
  }

  static String? confirmar(String? v, String original) => v == original ? null : 'Las contraseñas no coinciden';

  static String? obligatorio(String? v, [String mensaje = 'Campo obligatorio']) =>
      (v ?? '').trim().isEmpty ? mensaje : null;

  static String? motivo(String? v) {
    final n = (v ?? '').trim().length;
    return n >= 5 && n <= 200 ? null : 'El motivo debe tener entre 5 y 200 caracteres';
  }

  // ── Datos de vuelos y aviones (administrador) ──
  static String? codigoVuelo(String? v) =>
      _codigoVuelo.hasMatch((v ?? '').trim().toUpperCase()) ? null : 'Formato: 2 letras y 3-4 números (AT123)';

  static String? matricula(String? v) =>
      _matricula.hasMatch((v ?? '').trim().toUpperCase()) ? null : 'Formato: HC-XXX';

  static String? configuracionAvion(String? v, {bool opcional = false}) {
    final s = (v ?? '').trim().toUpperCase();
    if (s.isEmpty && opcional) return null;
    const msg = 'Configuración inválida (ej. ABC-DEF)';
    if (!_config.hasMatch(s) || s.length > 10) return msg;
    final letras = s.replaceAll('-', '').split('');
    if (letras.toSet().length != letras.length || letras.length > 10) return msg;
    return null;
  }

  static String? precio(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (n == null) return 'Precio inválido';
    return n >= 20 && n <= 2000 ? null : 'El precio debe estar entre 20 y 2000';
  }

  // ── Edades (a la fecha del vuelo) ──
  static int edadA(DateTime nacimiento, DateTime fecha) {
    var e = fecha.year - nacimiento.year;
    if (fecha.month < nacimiento.month || (fecha.month == nacimiento.month && fecha.day < nacimiento.day)) e--;
    return e;
  }

  /// Valida la fecha de nacimiento de un pasajero respecto a la fecha del vuelo.
  static String? fechaNacimiento(DateTime? nacimiento, DateTime fechaVuelo, {bool salidaEmergencia = false}) {
    if (nacimiento == null) return 'Seleccione la fecha de nacimiento';
    if (nacimiento.isAfter(DateTime.now())) return 'La fecha de nacimiento no puede ser futura';
    final edad = edadA(nacimiento, fechaVuelo);
    if (edad < 2) return 'Los menores de 2 años no ocupan asiento';
    if (edad > 110) return 'Edad inválida (máximo 110 años)';
    if (salidaEmergencia && edad < 15) {
      return 'Los asientos de salida de emergencia requieren pasajeros mayores de 15 años';
    }
    return null;
  }
}
