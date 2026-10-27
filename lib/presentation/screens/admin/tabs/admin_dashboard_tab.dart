import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../domain/controllers/admin_controller.dart';
import '../../../../domain/controllers/auth_controller.dart';
import '../../../../data/models/mascota_model.dart';
import '../../../widgets/safe_network_image.dart';
import '../../../widgets/header_wave_clipper.dart';

class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminController>();
    final user = context.read<AuthController>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: RefreshIndicator(
        color: AppColors.tealLight,
        onRefresh: () => context.read<AdminController>().cargarDashboard(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Cabecera ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: ClipPath(
                clipper: HeaderWaveClipper(),
                child: Container(
                  height: 200,
                  color: AppColors.tealBg,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Panel Admin',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.darkAlt,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hola, ${user?.nombre ?? 'Administrador'} 👋',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppColors.darkAlt.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Botón cerrar sesión
                          GestureDetector(
                            onTap: () async {
                              await context.read<AuthController>().logout();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                color: AppColors.darkAlt,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Alertas pendientes ────────────────────────────────────────
            if (!ctrl.cargandoStats && ctrl.totalPendientes > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${ctrl.totalPendientes} elemento(s) esperando revisión',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkAlt,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Estadísticas ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  'Resumen General',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkAlt,
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: ctrl.cargandoStats
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: AppColors.tealLight,
                          ),
                        ),
                      ),
                    )
                  : SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.55,
                          ),
                      delegate: SliverChildListDelegate([
                        _StatCard(
                          label: 'Usuarios',
                          value: ctrl.stats['usuarios'] ?? 0,
                          icon: Icons.people_rounded,
                          color: AppColors.tealLight,
                        ),
                        _StatCard(
                          label: 'Mascotas',
                          value: ctrl.stats['mascotas'] ?? 0,
                          icon: Icons.pets_rounded,
                          color: AppColors.purple,
                        ),
                        _StatCard(
                          label: 'Perdidas',
                          value: ctrl.stats['mascotasPerdidas'] ?? 0,
                          icon: Icons.location_off_rounded,
                          color: AppColors.red,
                        ),
                        _StatCard(
                          label: 'Productores',
                          value: ctrl.stats['productoresPecuarios'] ?? 0,
                          icon: Icons.agriculture_rounded,
                          color: const Color(0xFF4A9B7F),
                        ),
                        _StatCard(
                          label: 'Veterinarios',
                          value: ctrl.stats['veterinarios'] ?? 0,
                          icon: Icons.medical_services_rounded,
                          color: AppColors.vetGreen,
                        ),
                        _StatCard(
                          label: 'Noticias pendientes',
                          value: ctrl.stats['noticiasPendientes'] ?? 0,
                          icon: Icons.newspaper_rounded,
                          color: AppColors.orange,
                          highlight:
                              (ctrl.stats['noticiasPendientes'] ?? 0) > 0,
                        ),
                      ]),
                    ),
            ),

            // ── Solicitudes pendientes (badge rojo) ───────────────────────
            if ((ctrl.stats['solicitudesPendientes'] ?? 0) > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _StatCard(
                    label: 'Solicitudes de rol pendientes',
                    value: ctrl.stats['solicitudesPendientes'] ?? 0,
                    icon: Icons.badge_rounded,
                    color: AppColors.red,
                    highlight: true,
                    wide: true,
                  ),
                ),
              ),

            // ── Últimas mascotas registradas ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      color: AppColors.tealLight,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Últimas mascotas registradas',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkAlt,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: ctrl.ultimasMascotas.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No hay mascotas registradas aún.',
                            style: GoogleFonts.poppins(
                              color: AppColors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) =>
                            _MascotaAdminTile(mascota: ctrl.ultimasMascotas[i]),
                        childCount: ctrl.ultimasMascotas.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de estadística ────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool highlight;
  final bool wide;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: highlight
            ? Border.all(color: color.withValues(alpha: 0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  style: GoogleFonts.poppins(
                    fontSize: wide ? 26 : 22,
                    fontWeight: FontWeight.w800,
                    color: highlight ? color : AppColors.darkAlt,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile de mascota en el dashboard ──────────────────────────────────────────
class _MascotaAdminTile extends StatelessWidget {
  final MascotaModel mascota;
  const _MascotaAdminTile({required this.mascota});

  @override
  Widget build(BuildContext context) {
    Color estadoColor;
    switch (mascota.estado.toLowerCase()) {
      case 'perdido':
        estadoColor = AppColors.red;
        break;
      case 'para adoptar':
        estadoColor = AppColors.green;
        break;
      default:
        estadoColor = AppColors.tealLight;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Foto
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: mascota.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SafeNetworkImage(
              url: mascota.fotoUrl,
              borderRadius: BorderRadius.circular(12),
              fallbackIcon: mascota.icon,
              fallbackColor: mascota.color,
              fallbackIconSize: 26,
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mascota.nombre,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkAlt,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: estadoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        mascota.estado,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: estadoColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${mascota.especie} · ${mascota.raza}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.grey,
                  ),
                ),
                if (mascota.propietarioNombre != null)
                  Text(
                    'Dueño: ${mascota.propietarioNombre}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.grey.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
