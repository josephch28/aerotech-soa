import 'package:flutter/material.dart';

/// Dibuja el avión visto desde arriba (nariz arriba): alas, estabilizadores, fuselaje y ventanillas.
class FuselajePainter extends CustomPainter {
  final double yAlas; // posición vertical (px) donde empiezan las alas
  final List<double> centrosFilas; // y del centro de cada fila (una ventanilla por fila)

  const FuselajePainter({required this.yAlas, required this.centrosFilas});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height, nariz = w * 0.85, cola = w * 0.9;
    final relleno = Paint()..color = const Color(0xFFF3F6FA);
    final borde = Paint()
      ..color = const Color(0xFF8FA3BF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final alaP = Paint()..color = const Color(0xFFDCE3EE);
    final alaBorde = Paint()
      ..color = const Color(0xFFB8C6DA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Alas (se dibujan primero, quedan detrás del fuselaje)
    final ala = w * 1.1;
    final izq = Path()
      ..moveTo(0, yAlas)
      ..lineTo(-ala, yAlas + w * 0.5)
      ..lineTo(-ala, yAlas + w * 0.75)
      ..lineTo(0, yAlas + w * 0.55)
      ..close();
    final der = Path()
      ..moveTo(w, yAlas)
      ..lineTo(w + ala, yAlas + w * 0.5)
      ..lineTo(w + ala, yAlas + w * 0.75)
      ..lineTo(w, yAlas + w * 0.55)
      ..close();
    canvas.drawPath(izq, alaP);
    canvas.drawPath(izq, alaBorde);
    canvas.drawPath(der, alaP);
    canvas.drawPath(der, alaBorde);

    // Estabilizadores horizontales en la cola
    final yc = h - cola * 0.6;
    final estIzq = Path()
      ..moveTo(w * 0.3, yc)
      ..lineTo(-w * 0.35, yc + w * 0.3)
      ..lineTo(-w * 0.35, yc + w * 0.42)
      ..lineTo(w * 0.35, yc + w * 0.3)
      ..close();
    final estDer = Path()
      ..moveTo(w * 0.7, yc)
      ..lineTo(w * 1.35, yc + w * 0.3)
      ..lineTo(w * 1.35, yc + w * 0.42)
      ..lineTo(w * 0.65, yc + w * 0.3)
      ..close();
    canvas.drawPath(estIzq, alaP);
    canvas.drawPath(estIzq, alaBorde);
    canvas.drawPath(estDer, alaP);
    canvas.drawPath(estDer, alaBorde);

    // Fuselaje
    final cuerpo = Path()
      ..moveTo(0, nariz)
      ..cubicTo(0, nariz * 0.25, w * 0.25, 0, w / 2, 0)
      ..cubicTo(w * 0.75, 0, w, nariz * 0.25, w, nariz)
      ..lineTo(w, h - cola)
      ..cubicTo(w, h - cola * 0.3, w * 0.6, h, w / 2, h)
      ..cubicTo(w * 0.4, h, 0, h - cola * 0.3, 0, h - cola)
      ..close();
    canvas.drawPath(cuerpo, relleno);
    canvas.drawPath(cuerpo, borde);

    // Parabrisas (decorativo)
    final parabrisas = Paint()..color = const Color(0xFFBBD7F5);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.28, nariz * 0.2)
        ..quadraticBezierTo(w / 2, nariz * 0.05, w * 0.72, nariz * 0.2)
        ..lineTo(w * 0.66, nariz * 0.3)
        ..quadraticBezierTo(w / 2, nariz * 0.24, w * 0.34, nariz * 0.3)
        ..close(),
      parabrisas,
    );

    // Ventanillas: una por fila, en ambos costados
    final v = Paint()..color = const Color(0xFF9EC5F0);
    for (final y in centrosFilas) {
      canvas.drawOval(Rect.fromCenter(center: Offset(5, y), width: 4, height: 10), v);
      canvas.drawOval(Rect.fromCenter(center: Offset(w - 5, y), width: 4, height: 10), v);
    }
  }

  @override
  bool shouldRepaint(covariant FuselajePainter o) =>
      o.yAlas != yAlas || o.centrosFilas.length != centrosFilas.length || o.centrosFilas.join() != centrosFilas.join();
}
