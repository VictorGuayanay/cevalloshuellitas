import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../presentation/widgets/header_wave_clipper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../../domain/controllers/mascota_controller.dart';
import '../../../domain/controllers/noticia_controller.dart';
import '../../../data/services/solicitud_rol_service.dart';
import '../../../data/services/senso_service.dart';
import '../../../data/models/mascota_model.dart';
import '../../../data/models/senso_model.dart';
import '../../../presentation/widgets/carnet_mascota_sheet.dart';
import '../../../presentation/widgets/safe_network_image.dart';
import '../../../core/app_colors.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  /// Convierte el valor de BD a texto legible para el usuario.
  static String _labelTipoAnimales(String? valor) {
    switch (valor) {
      case 'mayores':
        return 'Animales mayores (bovinos, équidos, etc.)';
      case 'menores':
        return 'Animales menores (cerdos, aves, cuyes, etc.)';
      case 'ambos':
        return 'Mayores y menores';
      default:
        return 'No especificado';
    }
  }

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

  void _showAyudaDialog(BuildContext context) {
    const correo = 'huellistascevallos@gmail.com';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.tealLight.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.support_agent_rounded,
                      color: AppColors.tealLight, size: 32),
                ),
                const SizedBox(height: 12),
                Text('Ayuda y Soporte',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkAlt)),
              ]),
            ),
            // Cuerpo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(children: [
                Text(
                  'Para cualquier inquietud, sugerencia o problema, escríbenos al siguiente correo y te responderemos a la brevedad:',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.grey,
                      height: 1.5),
                ),
                const SizedBox(height: 16),
                // Caja del correo
                GestureDetector(
                  onTap: () async {
                    final uri = Uri(scheme: 'mailto', path: correo);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.tealLight.withValues(alpha: 0.3),
                          width: 1.5),
                    ),
                    child: Row(children: [
                      Icon(Icons.email_rounded,
                          color: AppColors.tealLight, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(correo,
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.tealLight)),
                      ),
                      // Copiar al portapapeles
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                              const ClipboardData(text: correo));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Correo copiado al portapapeles',
                                  style: GoogleFonts.poppins(fontSize: 13)),
                              backgroundColor: AppColors.tealLight,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Icon(Icons.copy_rounded,
                            color: AppColors.tealLight, size: 18),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Toca el correo para abrir tu cliente de email',
                    style: GoogleFonts.poppins(
                        fontSize: 10, color: AppColors.grey)),
              ]),
            ),
            // Botón cerrar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tealLight,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Entendido',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EditProfileSheet(),
    );
  }

  void _showEnviarNoticiaSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<NoticiaController>(),
        child: _EnviarNoticiaSheet(
          usuaId: context.read<AuthController>().currentUser?.id ?? '',
        ),
      ),
    );
  }

  void _showCambiarContrasenaDialog(BuildContext context) {
    final contrasenaController = TextEditingController();
    final confirmarController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetHandle(),
                  const SizedBox(height: 20),
                  Text('Cambiar Contraseña',
                      style: GoogleFonts.poppins(
                          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.darkAlt)),
                  const SizedBox(height: 20),
                  _PasswordField(controller: contrasenaController, label: 'Nueva contraseña'),
                  const SizedBox(height: 14),
                  _PasswordField(
                    controller: confirmarController,
                    label: 'Confirmar contraseña',
                    validator: (v) =>
                        v != contrasenaController.text ? 'Las contraseñas no coinciden' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Consumer<AuthController>(
                      builder: (ctx, auth, _) => ElevatedButton(
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final ok =
                                    await auth.cambiarContrasena(contrasenaController.text);
                                if (ok && context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('¡Contraseña actualizada correctamente!')),
                                  );
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(auth.errorMessage ??
                                            'Error al cambiar contraseña')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tealLight,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text('Actualizar Contraseña',
                                style: GoogleFonts.poppins(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;
    final isVet = user?.rol == 'veterinario';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header Premium ────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Fondo con gradiente
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1CB5C9),
                        AppColors.tealLight,
                        const Color(0xFF43B89C),
                      ],
                    ),
                  ),
                ),
                // Círculos decorativos
                Positioned(
                  top: -40, right: -30,
                  child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  top: 40, right: 60,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10, left: -20,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                // Contenido del header
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Barra superior
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            Text('Mi Perfil',
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: Colors.white, size: 20),
                              onPressed: () => _showEditProfileDialog(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Avatar con borde brillante
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Colors.white, Color(0xFFB2EBF2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: _AvatarPicker(fotoUrl: user?.fotoUrl),
                      ),
                      const SizedBox(height: 14),
                      // Nombre
                      Text(
                        user?.nombre ?? 'Usuario',
                        style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.2),
                      ),
                      const SizedBox(height: 6),
                      // Correo
                      Text(
                        user?.correo ?? '',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w400),
                      ),
                      const SizedBox(height: 12),
                      // Badge de rol
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1.2),
                        ),
                        child: Text(
                          isVet ? '🩺 Veterinario' : '🐾 Dueño de Mascotas',
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Información personal
                _SectionLabel(label: 'Información Personal'),
                const SizedBox(height: 10),
                _InfoCard(
                  children: [
                    _InfoTile(
                      icon: Icons.email_outlined,
                      label: 'Correo electrónico',
                      value: user?.correo ?? '—',
                      iconColor: AppColors.tealLight,
                    ),
                    _Separator(),
                    _InfoTile(
                      icon: Icons.phone_outlined,
                      label: 'Teléfono',
                      value: (user?.telefono?.isNotEmpty == true)
                          ? user!.telefono!
                          : 'No registrado',
                      iconColor: AppColors.tealLight,
                    ),
                    _Separator(),
                    _InfoTile(
                      icon: Icons.badge_outlined,
                      label: 'Cédula',
                      value: (user?.cedula?.isNotEmpty == true)
                          ? user!.cedula!
                          : 'No registrada',
                      iconColor: AppColors.tealLight,
                    ),
                    _Separator(),
                    _InfoTile(
                      icon: Icons.location_on_outlined,
                      label: 'Dirección / GPS',
                      value: (user?.direccionGps?.isNotEmpty == true)
                          ? user!.direccionGps!
                          : 'No registrada',
                      iconColor: AppColors.orange,
                    ),
                    _Separator(),
                    _InfoTile(
                      icon: Icons.agriculture_outlined,
                      label: 'Productor',
                      value: (user?.esProductor == true) ? 'Sí' : 'No',
                      iconColor: const Color(0xFF43B89C),
                    ),
                    if (user?.esProductor == true) ...[
                      _Separator(),
                      _InfoTile(
                        icon: Icons.pets_rounded,
                        label: 'Tipo de animales',
                        value: _labelTipoAnimales(user?.tipoAnimales),
                        iconColor: AppColors.orange,
                      ),
                    ],
                    _Separator(),
                    _InfoTile(
                      icon: Icons.badge_outlined,
                      label: 'Rol en la app',
                      value: isVet ? 'Veterinario' : 'Dueño de Mascotas',
                      iconColor: AppColors.orange,
                    ),
                    if (user?.fechaRegistro != null) ...[
                      _Separator(),
                      _InfoTile(
                        icon: Icons.calendar_today_outlined,
                        label: 'Miembro desde',
                        value:
                            '${user!.fechaRegistro!.day}/${user.fechaRegistro!.month}/${user.fechaRegistro!.year}',
                        iconColor: const Color(0xFF43B89C),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 28),

                // ── Tabla de Censo Pecuario (solo si es productor) ──────
                if (user?.esProductor == true) ...[
                  _SensoCensoSection(usuarioId: user!.id),
                  const SizedBox(height: 28),
                ],

                // Mis Mascotas y Carnets
                const _MisMascotasPerfilSection(),

                const SizedBox(height: 28),

                // Configuración de cuenta
                _SectionLabel(label: 'Ajustes y Cuenta'),
                const SizedBox(height: 10),
                _InfoCard(
                  children: [
                    _OptionTile(
                      icon: Icons.edit_outlined,
                      label: 'Editar Perfil',
                      iconColor: AppColors.tealLight,
                      iconBg: AppColors.tealLight.withValues(alpha: 0.1),
                      onTap: () => _showEditProfileDialog(context),
                    ),
                    _Separator(),
                    _OptionTile(
                      icon: Icons.newspaper_rounded,
                      label: 'Enviar noticia',
                      iconColor: const Color(0xFF7C6FCD),
                      iconBg: const Color(0xFF7C6FCD).withValues(alpha: 0.1),
                      onTap: () => _showEnviarNoticiaSheet(context),
                    ),
                    _Separator(),
                    _OptionTile(
                      icon: Icons.lock_outline_rounded,
                      label: 'Cambiar Contraseña',
                      iconColor: AppColors.orange,
                      iconBg: AppColors.orange.withValues(alpha: 0.1),
                      onTap: () => _showCambiarContrasenaDialog(context),
                    ),
                    _Separator(),
                    _OptionTile(
                      icon: Icons.help_outline_rounded,
                      label: 'Ayuda y Soporte',
                      iconColor: AppColors.grey,
                      iconBg: AppColors.grey.withValues(alpha: 0.08),
                      onTap: () => _showAyudaDialog(context),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Botón cerrar sesión
                _LogoutButton(
                  onTap: () async {
                    context.read<MascotaController>().limpiarMascotas();
                    await authController.logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Reusable Section Components
// ═══════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.darkAlt,
                letterSpacing: 0.3)),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.tealLight.withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: AppColors.tealLight.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFFF0F4F8),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: iconColor.withValues(alpha: 0.18), width: 1),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.grey,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2)),
                const SizedBox(height: 3),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkAlt)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: iconColor.withValues(alpha: 0.2), width: 1),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkAlt)),
              ),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.chevron_right_rounded,
                    color: AppColors.grey.withValues(alpha: 0.6), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF5252).withValues(alpha: 0.9),
              const Color(0xFFE53935),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFE53935).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Text('Cerrar Sesión',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Widget: Avatar con selector de foto
// ═══════════════════════════════════════════════════
class _AvatarPicker extends StatefulWidget {
  final String? fotoUrl;
  const _AvatarPicker({this.fotoUrl});

  @override
  State<_AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<_AvatarPicker> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _seleccionarFoto() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;

    final extension = picked.path.split('.').last.toLowerCase();
    const formatosPermitidos = ['jpg', 'jpeg', 'png', 'webp'];
    if (!formatosPermitidos.contains(extension)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Formato no permitido: .$extension\nSolo se aceptan: JPG, JPEG, PNG, WEBP',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final authController = context.read<AuthController>();
    final ok = await authController.subirFotoUsuario(File(picked.path), extension);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Foto actualizada correctamente'
            : (authController.errorMessage ?? 'Error al subir foto')),
        backgroundColor: ok ? AppColors.tealLight : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fotoUrl = context.select<AuthController, String?>(
      (c) => c.currentUser?.fotoUrl,
    );
    final isLoading = context.select<AuthController, bool>((c) => c.isLoading);

    return GestureDetector(
      onTap: isLoading ? null : _seleccionarFoto,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: ClipOval(
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                            color: AppColors.tealLight, strokeWidth: 2.5),
                      ),
                    )
                  : (fotoUrl != null && fotoUrl.isNotEmpty)
                      ? Image.network(
                          fotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.person_rounded,
                            size: 58,
                            color: AppColors.tealLight,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 58,
                          color: AppColors.tealLight,
                        ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.orange.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))
              ],
            ),
            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Sheet: Editar Perfil — versión mejorada
// ═══════════════════════════════════════════════════
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nombreController;
  late TextEditingController _telefonoController;
  late TextEditingController _cedulaController;
  // GPS se muestra como texto pero se edita desde el mapa
  String? _latLng;          // "lat,lng" guardado en BD
  bool _esProductor = false;
  String _tipoAnimales = 'ambos'; // "mayores" | "menores" | "ambos"
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser;
    _nombreController = TextEditingController(text: user?.nombre ?? '');
    _telefonoController = TextEditingController(text: user?.telefono ?? '');
    _cedulaController = TextEditingController(text: user?.cedula ?? '');
    _latLng = user?.direccionGps;
    _esProductor = user?.esProductor ?? false;
    _tipoAnimales = user?.tipoAnimales ?? 'ambos';
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _cedulaController.dispose();
    super.dispose();
  }

  /// Abre el sheet del mapa para que el usuario elija su ubicación.
  Future<void> _abrirMapaGps() async {
    // Parsear coordenada previa si existe
    LatLng? inicial;
    if (_latLng != null && _latLng!.isNotEmpty) {
      final parts = _latLng!.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) inicial = LatLng(lat, lng);
      }
    }

    final result = await showModalBottomSheet<LatLng?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MapPickerSheet(inicial: inicial),
    );

    if (result != null && mounted) {
      setState(() {
        _latLng =
            '${result.latitude.toStringAsFixed(6)},${result.longitude.toStringAsFixed(6)}';
      });
    }
  }

  void _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;
    final authController = context.read<AuthController>();

    final okPerfil = await authController.updateProfile(
      _nombreController.text.trim(),
      _telefonoController.text.trim(),
      cedula: _cedulaController.text.trim().isEmpty
          ? null
          : _cedulaController.text.trim(),
      direccionGps: (_latLng?.isEmpty ?? true) ? null : _latLng,
      esProductor: _esProductor,
      tipoAnimales: _esProductor ? _tipoAnimales : null,
    );

    if (!mounted) return;

    if (!okPerfil) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(authController.errorMessage ?? 'Error al actualizar perfil'),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text('¡Perfil actualizado correctamente!',
              style: GoogleFonts.poppins(fontSize: 13)),
        ]),
        backgroundColor: AppColors.tealLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  /// Envía una solicitud al administrador para convertirse en veterinario.
  Future<void> _solicitarRolVeterinario() async {
    final authController = context.read<AuthController>();
    final uid = authController.currentUser?.id;
    if (uid == null) return;

    try {
      await SolicitudRolService().enviarSolicitud(uid);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.schedule_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Solicitud enviada. El administrador la revisará pronto.',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ),
        ]),
        backgroundColor: const Color(0xFF7C6FCD),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          e.toString().replaceAll('Exception: ', ''),
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final user = authController.currentUser;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Encabezado con avatar
                Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.tealLight.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.tealLight.withValues(alpha: 0.3), width: 2),
                    ),
                    child: (user?.fotoUrl != null && user!.fotoUrl!.isNotEmpty)
                        ? ClipOval(
                            child: Image.network(user.fotoUrl!, fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(
                                    Icons.person_rounded, color: AppColors.tealLight, size: 28)))
                        : const Icon(Icons.person_rounded, color: AppColors.tealLight, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Editar Perfil',
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.darkAlt)),
                      Text(user?.correo ?? '',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.grey),
                          overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ]),
                const SizedBox(height: 24),

                // Nombre
                _fieldLabel('Nombre completo'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nombreController,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.darkAlt),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'El nombre no puede estar vacío';
                    }
                    if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                    return null;
                  },
                  decoration: _fieldDeco('Tu nombre completo', Icons.person_outline_rounded),
                ),
                const SizedBox(height: 16),

                // Teléfono
                _fieldLabel('Teléfono'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.darkAlt),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(v.trim())) {
                        return 'Ingresa un número válido';
                      }
                    }
                    return null;
                  },
                  decoration: _fieldDeco('Ej. 0999999999', Icons.phone_outlined),
                ),
                const SizedBox(height: 16),

                // Cédula
                _fieldLabel('Cédula'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _cedulaController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.darkAlt),
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      if (!RegExp(r'^[0-9]{8,13}$').hasMatch(v.trim())) {
                        return 'Ingresa una cédula válida (8-13 dígitos)';
                      }
                    }
                    return null;
                  },
                  decoration: _fieldDeco('Ej. 1234567890', Icons.badge_outlined),
                ),
                const SizedBox(height: 16),

                // Dirección / GPS  — se elige desde el mapa
                _fieldLabel('Ubicación / GPS'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _abrirMapaGps,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: (_latLng?.isNotEmpty ?? false)
                              ? AppColors.tealLight
                              : const Color(0xFFBBEBF0),
                          width: 1.4),
                    ),
                    child: Row(children: [
                      Icon(Icons.map_outlined,
                          color: AppColors.tealLight, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                            (_latLng?.isNotEmpty ?? false)
                                ? 'Coordenadas seleccionadas'
                                : 'Toca para elegir en el mapa',
                            style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: (_latLng?.isNotEmpty ?? false)
                                    ? AppColors.darkAlt
                                    : AppColors.grey),
                          ),
                          if (_latLng?.isNotEmpty ?? false)
                            Text(
                              _latLng!,
                              style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppColors.grey),
                            ),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          (_latLng?.isNotEmpty ?? false)
                              ? 'Cambiar'
                              : 'Elegir',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),

                // Productor (Sí / No)
                _fieldLabel('¿Eres productor pecuario?'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBEBF0), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _esProductor = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.all(4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _esProductor
                                  ? AppColors.tealLight
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'Sí',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _esProductor
                                      ? Colors.white
                                      : AppColors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _esProductor = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.all(4),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_esProductor
                                  ? AppColors.tealLight
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'No',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: !_esProductor
                                      ? Colors.white
                                      : AppColors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Tipo de animales — solo visible si es productor
                if (_esProductor) ...[
                  const SizedBox(height: 16),
                  _fieldLabel('Tipo de animales que maneja'),
                  const SizedBox(height: 8),
                  _TipoAnimalesSelector(
                    valor: _tipoAnimales,
                    onChanged: (v) => setState(() => _tipoAnimales = v),
                  ),
                ],
                const SizedBox(height: 24),

                // Guardar datos de perfil
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authController.isLoading ? null : _guardarPerfil,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tealLight,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      disabledBackgroundColor: AppColors.tealLight.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: authController.isLoading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Guardar Cambios',
                            style: GoogleFonts.poppins(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),

                // Separador
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('¿Eres veterinario?',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.grey)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                ]),
                const SizedBox(height: 12),

                // Botón solicitar ser veterinario
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C6FCD).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF7C6FCD).withValues(alpha: 0.3)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _solicitarRolVeterinario,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C6FCD).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.medical_services_outlined,
                                color: Color(0xFF7C6FCD), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Solicitar rol de Veterinario',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF7C6FCD))),
                              Text('El administrador revisará tu solicitud',
                                  style: GoogleFonts.poppins(
                                      fontSize: 11, color: AppColors.grey)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF7C6FCD), size: 20),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(text,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.grey,
                letterSpacing: 0.3)),
      );

  InputDecoration _fieldDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.tealLight, size: 20),
        filled: true,
        fillColor: const Color(0xFFF0FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFBBEBF0), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.tealLight, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE53935), width: 2)),
      );
}

// ═══════════════════════════════════════════════════
// Password Field Helper
// ═══════════════════════════════════════════════════
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.tealLight, size: 20),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.grey, size: 20),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: const Color(0xFFF3FAFD),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDCEEF0), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.tealLight, width: 2)),
      ),
      validator: widget.validator ??
          (v) {
            if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
            return null;
          },
    );
  }
}




// ═══════════════════════════════════════════════════
// Sheet: Enviar Noticia
// ═══════════════════════════════════════════════════
class _EnviarNoticiaSheet extends StatefulWidget {
  final String usuaId;
  const _EnviarNoticiaSheet({required this.usuaId});

  @override
  State<_EnviarNoticiaSheet> createState() => _EnviarNoticiaSheetState();
}

class _EnviarNoticiaSheetState extends State<_EnviarNoticiaSheet> {
  final _tituloCtrl   = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  String _categoria   = 'general';
  File? _imagen;
  String? _extension;

  static const _categorias = [
    'general', 'salud', 'nutricion', 'bienestar',
    'prevencion', 'adopcion', 'perdidos', 'emergencias',
  ];

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _contenidoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImagen() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() {
      _imagen = File(picked.path);
      _extension = picked.path.split('.').last.toLowerCase();
    });
  }

  void _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = context.read<NoticiaController>();
    final ok = await ctrl.enviarNoticia(
      usuaId: widget.usuaId,
      titulo: _tituloCtrl.text.trim(),
      contenido: _contenidoCtrl.text.trim(),
      categoria: _categoria,
      imagen: _imagen,
      extension: _extension,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Noticia enviada. El admin la revisará pronto.'),
          ),
        ]),
        backgroundColor: const Color(0xFF7C6FCD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ctrl.errorMessage ?? 'Error al enviar la noticia'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),

                // Título del sheet
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C6FCD).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.newspaper_rounded,
                        color: Color(0xFF7C6FCD), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Enviar Noticia',
                        style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkAlt)),
                    Text('El administrador la revisará antes de publicar',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.grey)),
                  ]),
                ]),
                const SizedBox(height: 20),

                // Título
                TextFormField(
                  controller: _tituloCtrl,
                  style: GoogleFonts.poppins(fontSize: 14, color: AppColors.darkAlt),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El título es requerido' : null,
                  decoration: _inputDeco('Título de la noticia',
                      Icons.title_rounded),
                ),
                const SizedBox(height: 12),

                // Contenido
                TextFormField(
                  controller: _contenidoCtrl,
                  maxLines: 4,
                  style: GoogleFonts.poppins(fontSize: 13, color: AppColors.darkAlt),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El contenido es requerido' : null,
                  decoration: _inputDeco('Descripción o contenido',
                      Icons.article_outlined),
                ),
                const SizedBox(height: 12),

                // Categoría
                Text('Categoría',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkAlt)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _categorias.map((cat) {
                    final sel = _categoria == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _categoria = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFF7C6FCD)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(cat,
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white
                                    : Colors.grey.shade600)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Imagen opcional
                GestureDetector(
                  onTap: _pickImagen,
                  child: Container(
                    width: double.infinity,
                    height: _imagen != null ? 160 : 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.tealLight.withValues(alpha: 0.3), width: 1.2),
                    ),
                    child: _imagen != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(_imagen!, fit: BoxFit.cover),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_outlined,
                                  color: AppColors.tealLight, size: 20),
                              const SizedBox(width: 8),
                              Text('Agregar imagen (opcional)',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: AppColors.tealLight)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Botón enviar
                Consumer<NoticiaController>(
                  builder: (ctx, ctrl, _) => SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: ctrl.isSubmitting ? null : _enviar,
                      icon: ctrl.isSubmitting
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        ctrl.isSubmitting ? 'Enviando...' : 'Enviar para revisión',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C6FCD),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: AppColors.grey, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.tealLight, size: 20),
      filled: true,
      fillColor: const Color(0xFFF0F9FF),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: AppColors.tealLight.withValues(alpha: 0.25), width: 1.2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.tealLight, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: Color(0xFFE53935), width: 1.2)),
    );
  }
}

// ═══════════════════════════════════════════════════
// Sección Mis Mascotas y Carnets en Perfil
// ═══════════════════════════════════════════════════
class _MisMascotasPerfilSection extends StatelessWidget {
  const _MisMascotasPerfilSection();

  @override
  Widget build(BuildContext context) {
    final mascotaCtrl = context.watch<MascotaController>();
    final mascotas = mascotaCtrl.mascotas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel(label: 'Mis Mascotas y Carnets'),
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/mis_mascotas'),
              icon: const Icon(Icons.pets_rounded, size: 16, color: AppColors.tealLight),
              label: Text(
                'Gestionar (${mascotas.length})',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealLight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (mascotaCtrl.isLoading)
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.tealLight),
            ),
          )
        else if (mascotas.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
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
            child: Column(
              children: [
                Icon(Icons.badge_outlined, size: 36, color: AppColors.grey.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Text(
                  'Aún no tienes mascotas registradas',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkAlt,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Registra a tu mascota para obtener su cédula digital con QR',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.grey),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/mis_mascotas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tealLight,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Agregar Mascota',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: mascotas.length,
              itemBuilder: (context, index) {
                final mascota = mascotas[index];
                return _MascotaPerfilCard(mascota: mascota);
              },
            ),
          ),
      ],
    );
  }
}

class _MascotaPerfilCard extends StatelessWidget {
  final MascotaModel mascota;
  const _MascotaPerfilCard({required this.mascota});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: mascota.color.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
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
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: mascota.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: SafeNetworkImage(
                        url: mascota.fotoUrl,
                        fallbackIcon: mascota.icon,
                        fallbackColor: mascota.color,
                        fallbackIconSize: 24,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mascota.nombre,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkAlt,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${mascota.especie} · ${mascota.raza}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => mostrarCarnetMascota(context, mascota),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mascota.color.withValues(alpha: 0.12),
                      foregroundColor: mascota.color,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: Icon(Icons.badge_rounded, size: 16, color: mascota.color),
                    label: Text(
                      'Ver Cédula',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: mascota.color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════
// Widget: Selector de tipo de animales (mayores/menores/ambos)
// Solo se muestra cuando _esProductor = true
// ═══════════════════════════════════════════════════
class _TipoAnimalesSelector extends StatelessWidget {
  final String valor;
  final ValueChanged<String> onChanged;

  const _TipoAnimalesSelector({
    required this.valor,
    required this.onChanged,
  });

  static const _opciones = [
    (value: 'mayores', label: 'Mayores', icon: Icons.set_meal_rounded, desc: 'Bovinos, équidos, etc.'),
    (value: 'menores', label: 'Menores', icon: Icons.cruelty_free_rounded, desc: 'Cerdos, aves, cuyes, etc.'),
    (value: 'ambos',   label: 'Ambos',   icon: Icons.diversity_3_rounded, desc: 'Mayores y menores'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _opciones.map((op) {
        final selected = valor == op.value;
        return GestureDetector(
          onTap: () => onChanged(op.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.tealLight.withValues(alpha: 0.10)
                  : const Color(0xFFF0FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.tealLight : const Color(0xFFBBEBF0),
                width: selected ? 1.8 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.tealLight.withValues(alpha: 0.15)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    op.icon,
                    size: 18,
                    color: selected ? AppColors.tealLight : AppColors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        op.label,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? AppColors.tealDark : AppColors.darkAlt,
                        ),
                      ),
                      Text(
                        op.desc,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.tealLight, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════
// Sheet: Mapa para seleccionar coordenadas GPS
// Usa flutter_map + geolocator. El usuario toca el mapa
// y la coordenada se guarda como "lat,lng".
// ═══════════════════════════════════════════════════
class _MapPickerSheet extends StatefulWidget {
  /// Coordenada previa (si existe) para centrar el mapa al abrirlo.
  final LatLng? inicial;

  const _MapPickerSheet({this.inicial});

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  static const _defaultCenter = LatLng(-1.8312, -78.1834); // Ecuador centro

  late final MapController _mapController;
  LatLng? _marcador;
  bool _cargandoGps = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _marcador = widget.inicial;
  }

  /// Solicita permiso y mueve el mapa a la ubicación actual del dispositivo.
  Future<void> _irAMiUbicacion() async {
    setState(() => _cargandoGps = true);
    try {
      bool servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (!servicioActivo) {
        _mostrarSnack('El GPS está desactivado. Actívalo en ajustes.');
        return;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          _mostrarSnack('Permiso de ubicación denegado.');
          return;
        }
      }
      if (permiso == LocationPermission.deniedForever) {
        _mostrarSnack(
            'Permiso denegado permanentemente. Habilítalo en ajustes.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _marcador = latLng);
      _mapController.move(latLng, 15);
    } catch (e) {
      _mostrarSnack('No se pudo obtener la ubicación.');
    } finally {
      if (mounted) setState(() => _cargandoGps = false);
    }
  }

  void _mostrarSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: AppColors.grey,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final centro = widget.inicial ?? _defaultCenter;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── Handle + Encabezado ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              children: [
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.map_rounded,
                          color: AppColors.tealLight, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selecciona tu ubicación',
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkAlt)),
                          Text('Toca el mapa para marcar el punto',
                              style: GoogleFonts.poppins(
                                  fontSize: 11, color: AppColors.grey)),
                        ],
                      ),
                    ),
                    // Botón GPS
                    GestureDetector(
                      onTap: _cargandoGps ? null : _irAMiUbicacion,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.tealLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.tealLight.withValues(alpha: 0.3)),
                        ),
                        child: _cargandoGps
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.tealLight),
                              )
                            : const Icon(Icons.my_location_rounded,
                                color: AppColors.tealLight, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // ── Mapa ──────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: centro,
                  initialZoom: widget.inicial != null ? 15 : 7,
                  onTap: (tapPosition, latLng) {
                    setState(() => _marcador = latLng);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.cevallos.huellitas',
                  ),
                  if (_marcador != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _marcador!,
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.redAccent,
                            size: 48,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // ── Pie con coordenadas + botón Confirmar ──────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_marcador != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.tealLight.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppColors.tealLight, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_marcador!.latitude.toStringAsFixed(6)}, '
                            '${_marcador!.longitude.toStringAsFixed(6)}',
                            style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkAlt),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    // Cancelar
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.grey,
                          side: const BorderSide(
                              color: Color(0xFFDCEEF0), width: 1.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Cancelar',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Confirmar
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _marcador == null
                            ? null
                            : () => Navigator.pop(context, _marcador),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.tealLight,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          disabledBackgroundColor:
                              AppColors.tealLight.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Confirmar ubicación',
                            style: GoogleFonts.poppins(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════
// Sección: Tabla del Censo Pecuario en el Perfil
// Se muestra solo si el usuario es productor (esProductor = true).
// Carga los registros del censo desde Supabase y los muestra
// en una tabla estilo Excel con scroll horizontal.
// ═══════════════════════════════════════════════════
class _SensoCensoSection extends StatefulWidget {
  final String usuarioId;
  const _SensoCensoSection({required this.usuarioId});

  @override
  State<_SensoCensoSection> createState() => _SensoCensoSectionState();
}

class _SensoCensoSectionState extends State<_SensoCensoSection> {
  static const _accentColor = Color(0xFF4A9B7F);
  static const _accentBg    = Color(0xFFF0FAF6);

  List<SensoModel> _registros = [];
  bool _cargando              = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    _registros = await SensoService().obtenerPorUsuario(widget.usuarioId);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _confirmarEliminar(SensoModel senso) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('¿Eliminar registro?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Se eliminará el registro de ${senso.especie} (${senso.numeroAnimales} animales).',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red, elevation: 0),
            child: Text('Eliminar',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    if (senso.id == null) return;
    await SensoService().eliminarSenso(senso.id!);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Encabezado de la sección ───────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accentBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _accentColor.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.agriculture_rounded,
                  color: _accentColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Censo Pecuario',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkAlt),
            ),
            const Spacer(),
            if (!_cargando)
              Text(
                '${_registros.length} registro${_registros.length != 1 ? "s" : ""}',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _accentColor,
                    fontWeight: FontWeight.w600),
              ),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Contenido ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _cargando
              ? Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _accentColor.withValues(alpha: 0.2)),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: _accentColor, strokeWidth: 2),
                  ),
                )
              : _registros.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _accentBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _accentColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            color: _accentColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Aún no tienes registros de censo. '
                            'Usa el botón Censo en el inicio para agregar.',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: _accentColor),
                          ),
                        ),
                      ]),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _accentColor.withValues(alpha: 0.25),
                            width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: _buildTabla(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTabla() {
    const headerStyle = TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    );

    const colWidths = [130.0, 90.0, 100.0, 110.0, 120.0, 90.0, 36.0];
    const headers = [
      'Especie', 'Tipo', 'N° Animales',
      'Alimentación', 'Destino', 'Fecha', '',
    ];

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        for (int i = 0; i < colWidths.length; i++)
          i: FixedColumnWidth(colWidths[i]),
      },
      border: TableBorder(
        horizontalInside: BorderSide(
            color: _accentColor.withValues(alpha: 0.12), width: 1),
        verticalInside: BorderSide(
            color: _accentColor.withValues(alpha: 0.12), width: 1),
      ),
      children: [
        // ── Fila de encabezados ───────────────────────────────────
        TableRow(
          decoration: const BoxDecoration(color: _accentColor),
          children: headers.map((h) {
            if (h.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Text(h, style: headerStyle),
            );
          }).toList(),
        ),

        // ── Filas de datos ────────────────────────────────────────
        ..._registros.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final isEven = i % 2 == 0;
          final rowColor =
              isEven ? Colors.white : _accentBg;

          final fecha = s.creadoEn != null
              ? '${s.creadoEn!.day}/${s.creadoEn!.month}/${s.creadoEn!.year}'
              : '—';

          return TableRow(
            decoration: BoxDecoration(color: rowColor),
            children: [
              // Especie
              _tableCell(s.especie, bold: true),
              // Tipo
              _tableCellBadge(
                s.produccionLabel == 'Animales Menores'
                    ? 'Menores'
                    : 'Mayores',
                s.produccionLabel == 'Animales Menores'
                    ? const Color(0xFF43B89C)
                    : const Color(0xFF5BBFBF),
              ),
              // N° Animales
              _tableCell('${s.numeroAnimales}', centered: true),
              // Alimentación
              _tableCell(s.alimentacionLabel),
              // Destino
              _tableCellBadge(
                s.destinacionLabel,
                s.destinacion == 'venta'
                    ? AppColors.orange
                    : s.destinacion == 'ambos'
                        ? AppColors.purple
                        : _accentColor,
              ),
              // Fecha
              _tableCell(fecha, small: true),
              // Botón eliminar
              TableCell(
                child: Center(
                  child: IconButton(
                    onPressed: () => _confirmarEliminar(s),
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppColors.red),
                    tooltip: 'Eliminar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 36, minHeight: 36),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  TableCell _tableCell(String text,
      {bool bold = false,
      bool centered = false,
      bool small = false}) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(
          text,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.poppins(
            fontSize: small ? 10 : 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.darkAlt,
          ),
        ),
      ),
    );
  }

  TableCell _tableCellBadge(String text, Color color) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
