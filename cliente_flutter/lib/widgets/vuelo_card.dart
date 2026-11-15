import 'package:flutter/material.dart';

import '../models/vuelo.dart';
import '../utils/formatos.dart';
import 'estado_chip.dart';

/// Tarjeta de vuelo: ruta, avión, horas, duración, precio "desde" y asientos libres.
class VueloCard extends StatelessWidget {
  final Vuelo vuelo;
  final VoidCallback? alTocar;
  final Widget? extra;
  const VueloCard({super.key, required this.vuelo, this.alTocar, this.extra});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(vuelo.codigoVuelo, style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.primary)),
              const SizedBox(width: 8),
              Text(Formatos.fecha(vuelo.fecha), style: t.textTheme.bodySmall),
              const Spacer(),
              if (vuelo.estado != 'programado') EstadoChip(vuelo.estado),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _ciudad(t, vuelo.origen, vuelo.ciudadOrigen, Formatos.hora(vuelo.horaSalida), CrossAxisAlignment.start),
              Expanded(
                child: Column(children: [
                  Text(Formatos.duracion(vuelo.duracionMinutos), style: t.textTheme.bodySmall),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Icon(Icons.flight, size: 18, color: t.colorScheme.primary),
                    const Expanded(child: Divider()),
                  ]),
                  Text(vuelo.modeloAvion, style: t.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                ]),
              ),
              _ciudad(t, vuelo.destino, vuelo.ciudadDestino, Formatos.hora(vuelo.horaLlegada), CrossAxisAlignment.end),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.event_seat, size: 16, color: t.colorScheme.outline),
              const SizedBox(width: 4),
              Text('${vuelo.asientosDisponibles} asientos libres', style: t.textTheme.bodySmall),
              const Spacer(),
              Text('desde ', style: t.textTheme.bodySmall),
              Text(Formatos.moneda(vuelo.precio),
                  style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: t.colorScheme.primary)),
            ]),
            if (extra != null) ...[const SizedBox(height: 8), extra!],
          ]),
        ),
      ),
    );
  }

  Widget _ciudad(ThemeData t, String codigo, String ciudad, String hora, CrossAxisAlignment alineacion) => Column(
        crossAxisAlignment: alineacion,
        children: [
          Text(codigo, style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(ciudad, style: t.textTheme.bodySmall),
          Text(hora, style: t.textTheme.titleSmall),
        ],
      );
}
