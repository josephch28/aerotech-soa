import 'package:flutter/material.dart';

import 'asiento_widget.dart';

class LeyendaAsientos extends StatelessWidget {
  final bool mostrarPropios;
  final bool mostrarSeleccion;
  const LeyendaAsientos({super.key, this.mostrarPropios = false, this.mostrarSeleccion = true});

  Widget _item(String texto, Color fondo, Color borde, {double grosor = 1.5, IconData? icono, Color? colorIcono}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 20,
        height: 22,
        decoration: BoxDecoration(
          color: fondo,
          border: Border.all(color: borde, width: grosor),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
        ),
        child: icono == null ? null : Icon(icono, size: 13, color: colorIcono),
      ),
      const SizedBox(width: 6),
      Text(texto, style: const TextStyle(fontSize: 12)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.center, children: [
      _item('Disponible', Colors.white, Colors.blue.shade400),
      _item('Ejecutiva', doradoClaro, dorado),
      _item('Salida de emergencia', Colors.white, Colors.red.shade600, grosor: 2.8),
      if (mostrarSeleccion) _item('Seleccionado', Colors.blue.shade700, Colors.blue.shade900, icono: Icons.check, colorIcono: Colors.white),
      if (mostrarPropios) _item('Tus asientos', Colors.green.shade600, Colors.green.shade900, icono: Icons.check, colorIcono: Colors.white),
      _item('Ocupado', Colors.grey.shade300, Colors.grey.shade400, icono: Icons.close, colorIcono: Colors.grey.shade600),
    ]);
  }
}
