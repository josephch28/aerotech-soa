import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// SnackBar rojo con el mensaje de error (usa el `error` del backend cuando existe).
void mostrarError(BuildContext context, Object error) {
  if (!context.mounted) return;
  final mensaje = error is ApiException ? error.mensaje : (error is String ? error : 'Ocurrió un error inesperado');
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(mensaje),
    backgroundColor: Colors.red.shade700,
    behavior: SnackBarBehavior.floating,
  ));
}

void mostrarMensaje(BuildContext context, String mensaje) {
  if (!context.mounted) return;
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating));
}

/// Diálogo de confirmación; devuelve true si el usuario acepta.
Future<bool> confirmar(BuildContext context,
    {required String titulo, required String mensaje, String aceptar = 'Aceptar', bool peligro = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Volver')),
        FilledButton(
          style: peligro ? FilledButton.styleFrom(backgroundColor: Colors.red.shade700) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(aceptar),
        ),
      ],
    ),
  );
  return r ?? false;
}
