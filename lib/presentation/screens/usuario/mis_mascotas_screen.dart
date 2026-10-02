import 'dart:io';
import 'package:flutter/material.dart';
import '../../../presentation/widgets/header_wave_clipper.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../../domain/controllers/mascota_controller.dart';
import '../../../data/models/mascota_model.dart';
import '../../../presentation/widgets/safe_network_image.dart';
import '../../../core/app_colors.dart';
import '../../../presentation/widgets/common_widgets.dart';
import '../../../presentation/widgets/mascota_form_sheet.dart';
import '../../../presentation/widgets/carnet_mascota_sheet.dart';

class MisMascotasScreen extends StatefulWidget {
  const MisMascotasScreen({super.key});

  @override
  State<MisMascotasScreen> createState() => _MisMascotasScreenState();
}

class _MisMascotasScreenState extends State<MisMascotasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authController = context.read<AuthController>();
      final mascotaController = context.read<MascotaController>();
      if (authController.currentUser != null) {
        mascotaController.cargarMascotas(authController.currentUser!.id);
      }
    });
  }

  void _showAddMascotaSheet(BuildContext context, {MascotaModel? mascota}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MascotaFormSheet(mascota: mascota),
    );
  }

  void _confirmarEliminar(BuildContext context, MascotaModel mascota) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFE53935), size: 22),
          ),
          const SizedBox(width: 12),
          Text('Eliminar mascota',
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.darkAlt)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro que deseas eliminar a ',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
            ),
            Text(
              '"${mascota.nombre}"?',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkAlt),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta acción no se puede deshacer.',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFE53935),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
          Consumer<MascotaController>(
            builder: (context, ctrl, _) => ElevatedButton(
              onPressed: ctrl.isLoading
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final mascotaCtrl = context.read<MascotaController>();
                      final ok = await mascotaCtrl.eliminarMascota(mascota.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? '"${mascota.nombre}" eliminada correctamente'
                            : (mascotaCtrl.errorMessage ?? 'Error al eliminar')),
                        backgroundColor:
                            ok ? const Color(0xFF43B89C) : const Color(0xFFE53935),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Eliminar',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mascotaController = context.watch<MascotaController>();
    final mascotas = mascotaController.mascotas;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMascotaSheet(context),
        backgroundColor: AppColors.tealLight,
        elevation: 6,
        hoverElevation: 8,
        label: Text(
          'Agregar Mascota',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Cabecera celeste con curva convexa ──
          SliverToBoxAdapter(
            child: ClipPath(
              clipper: HeaderWaveClipper(),
              child: Container(
                height: 180,
                color: AppColors.tealBg,
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Fila con botón de retroceso y título
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.darkAlt, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            Text(
                              'Mis Mascotas',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkAlt,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48), // Equilibrar el botón de retroceso
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${mascotas.length} registradas en tu cuenta',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.darkAlt.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Contenido de la lista ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            sliver: mascotaController.isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.tealLight),
                    ),
                  )
                : mascotas.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.pets_rounded, size: 64, color: AppColors.grey.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'No tienes mascotas registradas.',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkAlt,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Toca "Agregar Mascota" para registrar una.',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final mascota = mascotas[index];
                            return _buildMascotaCard(mascota);
                          },
                          childCount: mascotas.length,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotaCard(MascotaModel mascota) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealLight.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => mostrarCarnetMascota(context, mascota),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Foto o ícono
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: mascota.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SafeNetworkImage(
                    url: mascota.fotoUrl,
                    borderRadius: BorderRadius.circular(16),
                    fallbackIcon: mascota.icon,
                    fallbackColor: mascota.color,
                    fallbackIconSize: 36,
                  ),
                ),
                const SizedBox(width: 14),
                // Información principal
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mascota.nombre,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkAlt,
                        ),
                      ),
                      Text(
                        '${mascota.especie} · ${mascota.raza}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildChip(mascota.edad, Icons.cake_outlined, AppColors.tealLight),
                          _buildEstadoChip(mascota.estado),
                        ],
                      ),
                    ],
                  ),
                ),
                // Botones de acción
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ver Cédula / Carnet
                    GestureDetector(
                      onTap: () => mostrarCarnetMascota(context, mascota),
                      child: Tooltip(
                        message: 'Ver Cédula / Carnet',
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: mascota.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.badge_rounded, color: mascota.color, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Editar
                    GestureDetector(
                      onTap: () => _showAddMascotaSheet(context, mascota: mascota),
                      child: Tooltip(
                        message: 'Editar Mascota',
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.edit_rounded, color: AppColors.tealLight, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Eliminar
                    GestureDetector(
                      onTap: () => _confirmarEliminar(context, mascota),
                      child: Tooltip(
                        message: 'Eliminar Mascota',
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFE53935), size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoChip(String estado) {
    Color color;
    switch (estado.toLowerCase()) {
      case 'perdido':
        color = const Color(0xFFE53935);
        break;
      default:
        color = AppColors.tealLight;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
