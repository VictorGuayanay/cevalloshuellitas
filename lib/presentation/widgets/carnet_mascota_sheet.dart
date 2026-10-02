import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../../data/models/mascota_model.dart';
import '../../domain/controllers/auth_controller.dart';
import '../../core/app_colors.dart';
import 'safe_network_image.dart';

/// Muestra el carnet/cédula de identificación de una mascota como bottom sheet.
void mostrarCarnetMascota(BuildContext context, MascotaModel mascota) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CarnetMascotaSheet(mascota: mascota),
  );
}

class _CarnetMascotaSheet extends StatelessWidget {
  final MascotaModel mascota;
  const _CarnetMascotaSheet({required this.mascota});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.6,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2F6F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Título del sheet
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mascota.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.badge_rounded, color: mascota.color, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cédula de Mascota',
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkAlt)),
                Text('Huellitas Cevallos',
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.grey,
                        fontWeight: FontWeight.w500)),
              ]),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded, color: AppColors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              controller: sc,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: Column(children: [
                _buildCarnet(context),
                const SizedBox(height: 16),
                _buildDatosExtras(),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCarnet(BuildContext context) {
    final curUser = context.watch<AuthController>().currentUser;
    final propNombre = (mascota.propietarioNombre?.isNotEmpty == true)
        ? mascota.propietarioNombre!
        : (curUser != null &&
                (mascota.usuarioId.isEmpty ||
                    curUser.id == mascota.usuarioId))
            ? (curUser.nombre ?? 'Propietario')
            : 'Propietario';
    final propTel = (mascota.propietarioTelefono?.isNotEmpty == true)
        ? mascota.propietarioTelefono
        : (curUser != null &&
                (mascota.usuarioId.isEmpty ||
                    curUser.id == mascota.usuarioId))
            ? curUser.telefono
            : null;

    final accent = mascota.color;
    final accentDark = HSLColor.fromColor(accent)
        .withLightness(
            (HSLColor.fromColor(accent).lightness - 0.12).clamp(0.0, 1.0))
        .toColor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: [
          // ── Banda superior de color ──────────────────────────────────────
          Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentDark, accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(children: [
              // Decoración círculo fondo
              Positioned(
                right: -30, top: -30,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                left: -20, bottom: -40,
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Huella decorativa
              Positioned(
                right: 14, bottom: 8,
                child: Transform.rotate(
                  angle: math.pi / 5,
                  child: Icon(Icons.pets_rounded,
                      size: 54,
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              // Contenido de la banda
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Foto
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: SafeNetworkImage(
                          url: mascota.fotoUrl,
                          fallbackIcon: mascota.icon,
                          fallbackColor: Colors.white,
                          fallbackIconSize: 36,
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Nombre + especie + estado
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            mascota.nombre.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.3,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${mascota.especie}  ·  ${mascota.raza}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.92),
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          _estadoBadge(mascota.estado),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),

          // ── Cuerpo blanco ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila 1: Sexo · Edad · ID
                Row(children: [
                  Expanded(child: _infoCell('Sexo',
                      mascota.genero.isEmpty ? '—' : mascota.genero,
                      Icons.transgender_rounded, accent)),
                  _vertDiv(),
                  Expanded(child: _infoCell(
                    'Edad',
                    mascota.edad.isEmpty
                        ? '—'
                        : mascota.edad == 'Menor de 1 año'
                            ? '< 1 año'
                            : '${mascota.edad} año(s)',
                    Icons.cake_outlined,
                    accent,
                  )),
                  _vertDiv(),
                  Expanded(child: _infoCell(
                    'ID',
                    '#${mascota.id.length > 6 ? mascota.id.substring(0, 6).toUpperCase() : mascota.id.toUpperCase()}',
                    Icons.tag_rounded,
                    accent,
                  )),
                ]),

                // Fila 2: Color · Tamaño · Peso · Esterilizado (solo si existen)
                if (mascota.colorMascota?.isNotEmpty == true ||
                    mascota.tamano?.isNotEmpty == true ||
                    mascota.peso?.isNotEmpty == true ||
                    mascota.esterilizado != null) ...[
                  _horzDiv(),
                  Row(children: [
                    if (mascota.colorMascota?.isNotEmpty == true)
                      Expanded(
                        child: _infoCell('Color', mascota.colorMascota!,
                            Icons.palette_outlined, AppColors.orange),
                      ),
                    if (mascota.colorMascota?.isNotEmpty == true &&
                        (mascota.tamano?.isNotEmpty == true ||
                            mascota.peso?.isNotEmpty == true ||
                            mascota.esterilizado != null))
                      _vertDiv(),
                    if (mascota.tamano?.isNotEmpty == true)
                      Expanded(
                        child: _infoCell('Tamaño', mascota.tamano!,
                            Icons.straighten_rounded, AppColors.orange),
                      ),
                    if (mascota.tamano?.isNotEmpty == true &&
                        (mascota.peso?.isNotEmpty == true ||
                            mascota.esterilizado != null))
                      _vertDiv(),
                    if (mascota.peso?.isNotEmpty == true)
                      Expanded(
                        child: _infoCell('Peso', '${mascota.peso} kg',
                            Icons.monitor_weight_outlined,
                            const Color(0xFF7C6FCD)),
                      ),
                    if (mascota.peso?.isNotEmpty == true &&
                        mascota.esterilizado != null)
                      _vertDiv(),
                    if (mascota.esterilizado != null)
                      Expanded(
                        child: _infoCell(
                          'Esterilizado',
                          mascota.esterilizado! ? 'Sí' : 'No',
                          Icons.medical_services_outlined,
                          mascota.esterilizado!
                              ? AppColors.green
                              : AppColors.grey,
                        ),
                      ),
                  ]),
                ],

                // Rasgos distintivos
                if (mascota.rasgoDistintivo?.isNotEmpty == true) ...[
                  _horzDiv(),
                  _fullRow(
                    'Rasgos distintivos',
                    mascota.rasgoDistintivo!,
                    Icons.remove_red_eye_outlined,
                    accent,
                  ),
                ],

                _horzDiv(),

                // Propietario + QR
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.person_outline_rounded,
                                size: 13, color: AppColors.grey),
                            const SizedBox(width: 5),
                            Text('PROPIETARIO',
                                style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.grey,
                                    letterSpacing: 1.0)),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            propNombre,
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkAlt),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (propTel != null && propTel.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(children: [
                              Icon(Icons.phone_rounded,
                                  size: 12, color: accent),
                              const SizedBox(width: 4),
                              Text(propTel,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: accent,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          ],
                          if (mascota.createdAt != null) ...[
                            const SizedBox(height: 6),
                            Row(children: [
                              Icon(Icons.calendar_today_outlined,
                                  size: 11, color: AppColors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Reg: ${mascota.createdAt!.day.toString().padLeft(2, '0')}/${mascota.createdAt!.month.toString().padLeft(2, '0')}/${mascota.createdAt!.year}',
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AppColors.grey,
                                    fontWeight: FontWeight.w500),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // QR
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.2), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: 'huellitas://mascota/${mascota.id}',
                        version: QrVersions.auto,
                        size: 72,
                        eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: accentDark),
                        dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppColors.darkAlt),
                      ),
                    ),
                  ],
                ),

                // Pie del carnet
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pets_rounded, size: 12, color: accent),
                      const SizedBox(width: 6),
                      Text('HUELLITAS CEVALLOS  ·  CÉDULA OFICIAL',
                          style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: accent,
                              letterSpacing: 0.8)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Celda de dato individual ────────────────────────────────────────────────
  Widget _infoCell(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey,
                  letterSpacing: 0.6)),
        ]),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.darkAlt),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  // ── Fila de dato de ancho completo ─────────────────────────────────────────
  Widget _fullRow(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey,
                    letterSpacing: 0.6)),
            const SizedBox(height: 3),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkAlt),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }

  Widget _vertDiv() => Container(
        width: 1,
        height: 44,
        color: const Color(0xFFEEF1F6),
      );

  Widget _horzDiv() => Container(
        height: 1,
        color: const Color(0xFFEEF1F6),
      );

  Widget _estadoBadge(String estado) {
    final color = _estadoColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        estado.toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: color == AppColors.tealLight ? Colors.white : Colors.white,
            letterSpacing: 0.6),
      ),
    );
  }

  // ── Tarjeta de datos extras debajo del carnet ───────────────────────────────
  Widget _buildDatosExtras() {
    final tieneDescripcion = mascota.descripcion?.isNotEmpty == true;
    final hasExtras = tieneDescripcion ||
        mascota.rasgoDistintivo?.isNotEmpty == true ||
        mascota.colorMascota?.isNotEmpty == true ||
        mascota.tamano?.isNotEmpty == true ||
        mascota.peso?.isNotEmpty == true ||
        mascota.esterilizado != null;

    if (!hasExtras) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.tealLight, size: 17),
          const SizedBox(width: 8),
          Text('Información adicional',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkAlt)),
        ]),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (mascota.colorMascota?.isNotEmpty == true)
              _chip(Icons.palette_outlined, 'Color',
                  mascota.colorMascota!, AppColors.tealLight),
            if (mascota.tamano?.isNotEmpty == true)
              _chip(Icons.straighten_rounded, 'Tamaño',
                  mascota.tamano!, AppColors.orange),
            if (mascota.peso?.isNotEmpty == true)
              _chip(Icons.monitor_weight_outlined, 'Peso',
                  '${mascota.peso} kg', const Color(0xFF7C6FCD)),
            if (mascota.esterilizado != null)
              _chip(
                  Icons.medical_services_outlined,
                  'Esterilizado',
                  mascota.esterilizado! ? 'Sí' : 'No',
                  mascota.esterilizado! ? AppColors.green : AppColors.grey),
          ],
        ),
        if (mascota.rasgoDistintivo?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          _extraRow(Icons.remove_red_eye_outlined, 'Rasgos distintivos',
              mascota.rasgoDistintivo!, AppColors.tealLight),
        ],
        if (tieneDescripcion) ...[
          const SizedBox(height: 14),
          _extraRow(Icons.notes_rounded, 'Notas',
              mascota.descripcion!, AppColors.grey),
        ],
      ]),
    );
  }

  Widget _chip(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey,
                  letterSpacing: 0.3)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkAlt)),
        ]),
      ]),
    );
  }

  Widget _extraRow(
      IconData icon, String label, String value, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: AppColors.grey,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkAlt,
                  height: 1.4)),
        ]),
      ),
    ]);
  }

  Color _estadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'perdido':
        return const Color(0xFFE53935);
      default:
        return AppColors.tealLight;
    }
  }
}
