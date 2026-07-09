import 'package:flutter/material.dart';

/// Clipper reutilizable que genera la curva convexa en la parte inferior
/// de los encabezados de pantalla.
///
/// Parámetros:
/// - [curveDepth]: qué tan pronunciada baja la curva en el centro (default 15).
/// - [sideOffset]: altura desde la base donde arrancan los extremos (default 40).
///
/// Uso:
/// ```dart
/// ClipPath(
///   clipper: HeaderWaveClipper(),
///   child: Container(height: 220, color: AppColors.tealBg),
/// )
/// ```
class HeaderWaveClipper extends CustomClipper<Path> {
  final double curveDepth;
  final double sideOffset;

  const HeaderWaveClipper({
    this.curveDepth = 15,
    this.sideOffset = 40,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - sideOffset);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + curveDepth,
      size.width,
      size.height - sideOffset,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant HeaderWaveClipper oldClipper) =>
      oldClipper.curveDepth != curveDepth ||
      oldClipper.sideOffset != sideOffset;
}
