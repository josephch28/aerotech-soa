import 'package:flutter/material.dart';

/// Indicador de pasos de la compra: Vuelo → Asientos → Pasajeros → Resumen → Confirmación.
/// El inicio de sesión se pide justo antes de confirmar (paso «Confirmación»), no al empezar.
class PasosReserva extends StatelessWidget {
  final int actual; // 0..4
  const PasosReserva({super.key, required this.actual});

  static const _etiquetas = ['Vuelo', 'Asientos', 'Pasajeros', 'Resumen', 'Confirmación'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: double.infinity,
      color: t.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Row(children: [
            for (var i = 0; i < _etiquetas.length; i++) ...[
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: i <= actual ? t.colorScheme.primary : t.colorScheme.outlineVariant,
                    child: i < actual
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text('${i + 1}', style: TextStyle(fontSize: 12, color: i == actual ? Colors.white : t.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  Text(_etiquetas[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: i == actual ? FontWeight.bold : FontWeight.normal, color: i <= actual ? t.colorScheme.onSurface : t.colorScheme.outline)),
                ]),
              ),
              if (i < _etiquetas.length - 1)
                Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 18), child: Divider(thickness: 2, color: i < actual ? t.colorScheme.primary : t.colorScheme.outlineVariant))),
            ],
          ]),
        ),
      ),
    );
  }
}
