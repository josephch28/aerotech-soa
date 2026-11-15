import 'package:intl/intl.dart';

class Formatos {
  Formatos._();

  static final _moneda = NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 2);

  /// 89 → $89.00
  static String moneda(num v) => _moneda.format(v);

  /// Diferencia con signo: +$102.35 / −$184.00
  static String monedaConSigno(num v) => '${v >= 0 ? '+' : '−'}${_moneda.format(v.abs())}';

  /// "2026-12-21" o DateTime → "21 dic 2026"
  static String fecha(dynamic v) {
    final d = v is DateTime ? v : DateTime.tryParse('$v');
    if (d == null) return '$v';
    return DateFormat('d MMM yyyy', 'es').format(d).replaceAll('.', '');
  }

  static String fechaHora(DateTime? d) =>
      d == null ? '' : '${fecha(d.toLocal())} · ${DateFormat('HH:mm').format(d.toLocal())}';

  /// "09:45" → "09:45" (ya viene en HH:MM)
  static String hora(String v) => v.length >= 5 ? v.substring(0, 5) : v;

  /// 55 → "55 min"; 150 → "2 h 30 min"
  static String duracion(int minutos) {
    if (minutos < 60) return '$minutos min';
    final h = minutos ~/ 60, m = minutos % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// Fecha en formato del backend (AAAA-MM-DD)
  static String iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String tipoDocumento(String t) => t == 'pasaporte' ? 'Pasaporte' : 'Cédula';

  static String clase(String c) => c == 'ejecutiva' ? 'Ejecutiva' : 'Económica';
}
