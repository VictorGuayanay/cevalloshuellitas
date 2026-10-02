import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../domain/controllers/admin_controller.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../../domain/controllers/mascota_controller.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_usuarios_tab.dart';
import 'tabs/admin_solicitudes_tab.dart';
import 'tabs/admin_noticias_tab.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminController>().cargarDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminCtrl = context.watch<AdminController>();
    final user = context.read<AuthController>().currentUser;

    final tabs = [
      const AdminDashboardTab(),
      const AdminUsuariosTab(),
      const AdminSolicitudesTab(),
      const AdminNoticiasTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: tabs[_selectedIndex],
      bottomNavigationBar: _buildBottomBar(adminCtrl),
    );
  }

  Widget _buildBottomBar(AdminController ctrl) {
    const items = [
      _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
      _NavItem(icon: Icons.people_rounded, label: 'Usuarios'),
      _NavItem(icon: Icons.badge_rounded, label: 'Solicitudes'),
      _NavItem(icon: Icons.newspaper_rounded, label: 'Noticias'),
    ];

    final badges = [
      0,
      0,
      ctrl.stats['solicitudesPendientes'] ?? 0,
      ctrl.stats['noticiasPendientes'] ?? 0,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final selected = _selectedIndex == i;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = i);
                  // Cargar datos al cambiar de tab
                  switch (i) {
                    case 1:
                      context.read<AdminController>().cargarUsuarios();
                      break;
                    case 2:
                      context.read<AdminController>().cargarSolicitudesPendientes();
                      break;
                    case 3:
                      context.read<AdminController>().cargarNoticiasPendientes();
                      break;
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.tealLight.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            items[i].icon,
                            color: selected
                                ? AppColors.tealLight
                                : AppColors.grey,
                            size: 24,
                          ),
                          if (badges[i] > 0)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 16, minHeight: 16),
                                child: Text(
                                  '${badges[i]}',
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.tealLight
                              : AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
