import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/header_wave_clipper.dart';
import '../../core/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CABECERA CON CURVA
// ─────────────────────────────────────────────────────────────────────────────

/// Cabecera con curva wave y gradiente configurable.
/// Reemplaza el Container + ClipPath manual en todas las pantallas.
class AppHeader extends StatelessWidget {
  final double height;
  final List<Color> gradientColors;
  final Widget child;
  final double curveDepth;

  const AppHeader({
    super.key,
    this.height = 220,
    required this.gradientColors,
    required this.child,
    this.curveDepth = 15,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: HeaderWaveClipper(curveDepth: curveDepth),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TÍTULO DE SECCIÓN
// ─────────────────────────────────────────────────────────────────────────────

/// Título de sección con ícono en chip de fondo teal claro.
/// Se usa en formularios y listados para separar grupos.
class SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;

  const SectionTitle(
    this.title,
    this.icon, {
    super.key,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.tealLight;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c, size: 18),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.darkAlt,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA VACÍA (empty state)
// ─────────────────────────────────────────────────────────────────────────────

/// Tarjeta de estado vacío con ícono y mensaje centrado.
class EmptyCard extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;

  const EmptyCard({
    super.key,
    required this.message,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade300;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: [
        Icon(icon, size: 40, color: c),
        const SizedBox(height: 8),
        Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey.shade400,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILA DE RESUMEN (label + value)
// ─────────────────────────────────────────────────────────────────────────────

/// Fila de resumen con etiqueta y valor.
class ResumenRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;

  const ResumenRow(
    this.label,
    this.value, {
    super.key,
    this.labelWidth = 100,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.darkAlt,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA DE RESUMEN (con encabezado de ícono + título + filas)
// ─────────────────────────────────────────────────────────────────────────────

/// Tarjeta de resumen con encabezado coloreado y lista de filas.
class ResumenCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  final List<Widget> items;

  const ResumenCard({
    super.key,
    required this.icon,
    required this.color,
    required this.titulo,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            titulo,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.darkAlt,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 8),
        ...items,
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INPUT DECORATION (estilo teal unificado)
// ─────────────────────────────────────────────────────────────────────────────

/// Genera un [InputDecoration] con el estilo teal estándar de la app.
InputDecoration appInputDeco(
  String label,
  IconData icon, {
  Color accentColor = const Color(0xFF5BBFBF),
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.poppins(
      color: Colors.grey.shade500,
      fontSize: 12,
    ),
    prefixIcon: Icon(icon, color: accentColor, size: 18),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDDEEF0), width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: accentColor, width: 2),
    ),
  );
}
