// noticia_detalle_screen.dart — Pantalla de detalle de una noticia.
//
// Muestra la imagen en tamaño completo (si existe), el título, la categoría,
// el contenido completo y los datos del autor.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../data/models/noticia_model.dart';

class NoticiaDetalleScreen extends StatelessWidget {
  final NoticiaModel noticia;

  const NoticiaDetalleScreen({super.key, required this.noticia});

  // Mismo mapa de colores por categoría que en el home
  static const _coloresCat = {
    'salud': Color(0xFF4A9B7F),
    'perdidos': Color(0xFFE53935),
    'adopcion': Color(0xFFE58D57),
    'nutricion': Color(0xFFE58D57),
    'bienestar': Color(0xFF7C6FCD),
    'prevencion': Color(0xFF5BBFBF),
    'emergencias': Color(0xFFE53935),
  };

  @override
  Widget build(BuildContext context) {
    final color =
        _coloresCat[noticia.categoria.toLowerCase()] ?? AppColors.tealLight;
    final tieneImagen =
        noticia.imagenUrl != null && noticia.imagenUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar con imagen de fondo o color sólido ──
          SliverAppBar(
            expandedHeight: tieneImagen ? 280 : 140,
            pinned: true,
            stretch: true,
            backgroundColor: color,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black26,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: tieneImagen
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          noticia.imagenUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: color),
                        ),
                        // Degradado para que el texto sea legible sobre la imagen
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                color.withValues(alpha: 0.85),
                              ],
                              stops: const [0.4, 1.0],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.75)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.newspaper_rounded,
                          color: Colors.white.withValues(alpha: 0.25),
                          size: 80,
                        ),
                      ),
                    ),
            ),
          ),

          // ── Contenido ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge categoría + tiempo
                  Row(
                    children: [
                      _badgeCategoria(noticia.categoria, color),
                      const Spacer(),
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppColors.grey.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        noticia.tiempoRelativo,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Título
                  Text(
                    noticia.titulo,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkAlt,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Autor si existe
                  if (noticia.autorNombre != null) ...[
                    _autorRow(noticia, color),
                    const SizedBox(height: 20),
                  ],

                  // Divisor
                  Divider(color: color.withValues(alpha: 0.15), height: 1),
                  const SizedBox(height: 20),

                  // Contenido completo
                  Text(
                    noticia.contenido,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: const Color(0xFF3A4A5C),
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Fecha completa al pie
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.grey.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatFecha(noticia.fecha),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.grey.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeCategoria(String categoria, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        categoria.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _autorRow(NoticiaModel n, Color color) {
    return Row(
      children: [
        // Avatar del autor
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: ClipOval(
            child: (n.autorFotoUrl != null && n.autorFotoUrl!.isNotEmpty)
                ? Image.network(
                    n.autorFotoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.person_rounded, size: 20, color: color),
                  )
                : Icon(Icons.person_rounded, size: 20, color: color),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              n.autorNombre!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.darkAlt,
              ),
            ),
            Text(
              'Autor',
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.grey),
            ),
          ],
        ),
      ],
    );
  }

  String _formatFecha(DateTime fecha) {
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${fecha.day} de ${meses[fecha.month - 1]} de ${fecha.year}';
  }
}
