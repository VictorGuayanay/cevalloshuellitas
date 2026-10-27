// wave_background.dart — Fondo con ondas lavanda compartido.
// Extraído de login_screen.dart (task 12.15) para reutilizar en
// RecuperarContrasenaScreen y NuevaContrasenaScreen sin duplicar el painter.

import 'package:flutter/material.dart';

/// Widget público que pinta el fondo decorativo con ondas lavanda.
/// Usado por LoginScreen, RecuperarContrasenaScreen y NuevaContrasenaScreen.
class WaveBackground extends StatelessWidget {
  const WaveBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: CustomPaint(painter: _WavePainter()));
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintTop = Paint()
      ..color = const Color(0xFFCBEBFC).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final paintBottom = Paint()
      ..color = const Color(0xFFD4EFFF).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final paintAccent = Paint()
      ..color = const Color(0xFFBBE5F9).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Blob superior izquierdo
    final pathTop = Path()
      ..moveTo(0, 0)
      ..cubicTo(
        size.width * 0.15,
        -size.height * 0.04,
        size.width * 0.55,
        size.height * 0.05,
        size.width * 0.4,
        size.height * 0.22,
      )
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.32,
        -size.width * 0.05,
        size.height * 0.25,
        0,
        size.height * 0.15,
      )
      ..close();
    canvas.drawPath(pathTop, paintTop);

    // Blob superior derecho
    final pathTopRight = Path()
      ..moveTo(size.width, 0)
      ..cubicTo(
        size.width * 0.85,
        size.height * 0.02,
        size.width * 0.65,
        size.height * 0.12,
        size.width * 0.75,
        size.height * 0.28,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.38,
        size.width * 1.05,
        size.height * 0.3,
        size.width,
        size.height * 0.18,
      )
      ..close();
    canvas.drawPath(pathTopRight, paintAccent);

    // Blob inferior izquierdo
    final pathBottomLeft = Path()
      ..moveTo(0, size.height)
      ..cubicTo(
        size.width * 0.05,
        size.height * 0.82,
        size.width * 0.25,
        size.height * 0.78,
        size.width * 0.2,
        size.height * 0.88,
      )
      ..cubicTo(
        size.width * 0.15,
        size.height * 0.95,
        size.width * 0.08,
        size.height * 1.02,
        0,
        size.height,
      )
      ..close();
    canvas.drawPath(pathBottomLeft, paintAccent);

    // Blob inferior derecho grande
    final pathBottom = Path()
      ..moveTo(size.width, size.height)
      ..cubicTo(
        size.width * 0.85,
        size.height * 0.92,
        size.width * 0.55,
        size.height * 0.88,
        size.width * 0.6,
        size.height * 0.75,
      )
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.65,
        size.width * 1.08,
        size.height * 0.7,
        size.width,
        size.height * 0.85,
      )
      ..close();
    canvas.drawPath(pathBottom, paintBottom);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
