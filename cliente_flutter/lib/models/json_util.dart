/// Conversiones tolerantes para los JSON del backend.
double numero(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);
int entero(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);
String texto(dynamic v) => v == null ? '' : '$v';
DateTime? fechaHora(dynamic v) => v == null ? null : DateTime.tryParse('$v');
