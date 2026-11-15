import 'package:flutter/material.dart';

/// confirmada = verde, cancelada = rojo, programado = azul (cancelado también rojo).
class EstadoChip extends StatelessWidget {
  final String estado;
  const EstadoChip(this.estado, {super.key});

  @override
  Widget build(BuildContext context) {
    final (color, texto) = switch (estado) {
      'confirmada' => (Colors.green.shade700, 'Confirmada'),
      'cancelada' => (Colors.red.shade700, 'Cancelada'),
      'cancelado' => (Colors.red.shade700, 'Cancelado'),
      'programado' => (Colors.blue.shade700, 'Programado'),
      _ => (Colors.grey.shade700, estado),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
