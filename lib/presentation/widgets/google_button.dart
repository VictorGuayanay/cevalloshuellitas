import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../domain/controllers/auth_controller.dart';

/// Botón de Google reutilizable entre LoginScreen y RegisterScreen.
/// Interno: _GoogleLogoPainter permanece privado a este archivo.
class GoogleButton extends StatelessWidget {
  const GoogleButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        return GestureDetector(
          onTap: auth.isLoading ? null : onTap,
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCEEF0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5BBFBF).withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 20),
                auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : SizedBox(
                        width: 22,
                        height: 22,
                        child: CustomPaint(painter: _GoogleLogoPainter()),
                      ),
                const SizedBox(width: 14),
                Text(
                  'Iniciar con Google',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2D2D2D),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// CustomPainter: Logo de Google (cuatro cuadrantes de color).
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];

    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2 + (math.pi / 2) * i,
        math.pi / 2,
        true,
        Paint()..color = colors[i],
      );
    }

    canvas.drawCircle(Offset(cx, cy), r * 0.58, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}