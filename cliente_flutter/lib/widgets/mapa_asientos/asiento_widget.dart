import 'package:flutter/material.dart';

import '../../models/asiento.dart';
import '../../utils/formatos.dart';

enum EstadoVisual { disponible, seleccionado, propio, ocupado }

const Color dorado = Color(0xFFC9A227);
const Color doradoClaro = Color(0xFFFFF4CC);

/// Una butaca: respaldo redondeado arriba + cojín. Cambia de estado con una animación de 150 ms.
class AsientoWidget extends StatelessWidget {
  final Asiento asiento;
  final EstadoVisual estado;
  final String posicion; // Ventana / Pasillo / Centro
  final VoidCallback? alTocar;

  const AsientoWidget({
    super.key,
    required this.asiento,
    required this.estado,
    required this.posicion,
    this.alTocar,
  });

  static double ancho(Asiento a) => a.esEjecutiva ? 46 : 36;
  static double alto(Asiento a) => a.esEjecutiva ? 44 : 40;

  @override
  Widget build(BuildContext context) {
    final ej = asiento.esEjecutiva;
    Color fondo, borde, texto;
    double grosor = 1.5;
    Widget? icono;

    switch (estado) {
      case EstadoVisual.ocupado:
        fondo = Colors.grey.shade300;
        borde = Colors.grey.shade400;
        texto = Colors.grey.shade600;
        icono = Icon(Icons.close, size: 18, color: Colors.grey.shade600);
      case EstadoVisual.seleccionado:
        fondo = Colors.blue.shade700;
        borde = Colors.blue.shade900;
        texto = Colors.white;
        icono = const Icon(Icons.check, size: 18, color: Colors.white);
      case EstadoVisual.propio:
        fondo = Colors.green.shade600;
        borde = Colors.green.shade900;
        texto = Colors.white;
        icono = const Icon(Icons.check, size: 18, color: Colors.white);
      case EstadoVisual.disponible:
        if (asiento.salidaEmergencia) {
          fondo = ej ? doradoClaro : Colors.white;
          borde = Colors.red.shade600;
          grosor = 2.8;
        } else if (ej) {
          fondo = doradoClaro;
          borde = dorado;
        } else {
          fondo = Colors.white;
          borde = Colors.blue.shade400;
        }
        texto = Colors.black87;
    }

    final w = ancho(asiento), h = alto(asiento);
    final cojin = Color.alphaBlend(Colors.black.withValues(alpha: 0.12), fondo);
    final mensaje = '${asiento.codigo} · ${Formatos.clase(asiento.clase)} · $posicion · ${Formatos.moneda(asiento.precio)}'
        '${asiento.salidaEmergencia ? ' · Salida de emergencia' : ''}'
        '${asiento.ocupado && estado == EstadoVisual.ocupado ? ' · Ocupado' : ''}';

    return Tooltip(
      message: mensaje,
      waitDuration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: estado == EstadoVisual.ocupado ? null : alTocar,
        child: MouseRegion(
          cursor: estado == EstadoVisual.ocupado || alTocar == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: fondo,
                border: Border.all(color: borde, width: grosor),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Stack(children: [
                // cojín
                Positioned(
                  left: 3,
                  right: 3,
                  bottom: 2,
                  height: 8,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(color: cojin, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: icono ??
                        Text(asiento.columna,
                            style: TextStyle(fontSize: ej ? 13 : 11, fontWeight: FontWeight.w600, color: texto)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
