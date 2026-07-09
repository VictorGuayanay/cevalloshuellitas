import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../../domain/controllers/cita_controller.dart';
import '../../../domain/controllers/mascota_controller.dart';
import '../../../domain/controllers/noticia_controller.dart';
import '../../../data/services/solicitud_rol_service.dart';
import '../shared/historial_citas_screen.dart';

// ─── Paleta de colores Premium ───────────────────────────
const _teal = Color(0xFF5BBFBF);
const _tealDark = Color(0xFF3A9A9A);
const _orange = Color(0xFFF0954A);
const _headerBg = Color(0xFFBBE7EC); // Fondo celeste pastel de la cabecera
const _bg = Color(0xFFF0F9FF);
const _dark = Color(0xFF1A1A2E);
const _grey = Color(0xFF8A9BB0);

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authController = context.read<AuthController>();
      final mascotaController = context.read<MascotaController>();
      if (authController.currentUser != null) {
        mascotaController.cargarMascotas(authController.currentUser!.id);
        // Cargar citas del usuario para el contador
        context
            .read<CitaController>()
            .cargarCitasDeUsuario(authController.currentUser!.id);
      }
    });
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
                          fontSize: 22, fontWeight: FontWeight.w700, color: _dark)),
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
                          backgroundColor: _teal,
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
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header Premium ────────────────────────────────
          SliverToBoxAdapter(
            child: ClipPath(
              clipper: _HeaderWaveClipper(),
              child: Container(
                height: 320,
                color: _headerBg,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Fila de botones (Atrás)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _dark, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _AvatarPicker(fotoUrl: user?.fotoUrl),
                      const SizedBox(height: 14),
                      Text(
                        user?.nombre ?? 'Usuario',
                        style: GoogleFonts.poppins(
                            fontSize: 22, fontWeight: FontWeight.w800, color: _dark),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _teal.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          isVet ? '🩺 Veterinario' : '🐾 Dueño de Mascotas',
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w700, color: _tealDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                      iconColor: _teal,
                    ),
                    _Separator(),
                    _InfoTile(
                      icon: Icons.phone_outlined,
                      label: 'Teléfono',
                      value: (user?.telefono?.isNotEmpty == true)
                          ? user!.telefono!
                          : 'No registrado',
                      iconColor: _teal,
                    ),
                    _Separator(),
                    _InfoTile(
                      icon: Icons.badge_outlined,
                      label: 'Rol en la app',
                      value: isVet ? 'Veterinario' : 'Dueño de Mascotas',
                      iconColor: _orange,
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

                // Configuración de cuenta
                _SectionLabel(label: 'Ajustes y Cuenta'),
                const SizedBox(height: 10),
                _InfoCard(
                  children: [
                    _OptionTile(
                      icon: Icons.history_rounded,
                      label: 'Historial de Citas',
                      iconColor: _teal,
                      iconBg: _teal.withValues(alpha: 0.1),
                      onTap: () {
                        final uid = context.read<AuthController>().currentUser?.id;
                        if (uid != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  HistorialCitasScreen(modo: 'usuario', entityId: uid),
                            ),
                          );
                        }
                      },
                    ),
                    _Separator(),
                    _OptionTile(
                      icon: Icons.volunteer_activism_rounded,
                      label: 'Mis Solicitudes de Adopción',
                      iconColor: _orange,
                      iconBg: _orange.withValues(alpha: 0.1),
                      onTap: () => Navigator.pushNamed(context, '/solicitudes_adopcion'),
                    ),
                    _Separator(),
                    _OptionTile(
                      icon: Icons.edit_outlined,
                      label: 'Editar Perfil',
                      iconColor: _teal,
                      iconBg: _teal.withValues(alpha: 0.1),
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
                      iconColor: _orange,
                      iconBg: _orange.withValues(alpha: 0.1),
                      onTap: () => _showCambiarContrasenaDialog(context),
                    ),
                    _Separator(),
                    _OptionTile(
                      icon: Icons.help_outline_rounded,
                      label: 'Ayuda y Soporte',
                      iconColor: _grey,
                      iconBg: _grey.withValues(alpha: 0.08),
                      onTap: () {},
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
      padding: const EdgeInsets.only(left: 4),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _grey,
              letterSpacing: 0.8)),
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
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF5BBFBF).withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 6)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: _grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w500, color: _dark)),
            ),
            Icon(Icons.chevron_right_rounded, color: _grey.withValues(alpha: 0.5), size: 22),
          ],
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
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFF5252).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFE53935)),
            const SizedBox(width: 10),
            Text('Cerrar Sesión',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE53935))),
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
        backgroundColor: ok ? _teal : Colors.redAccent,
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
                            color: _teal, strokeWidth: 2.5),
                      ),
                    )
                  : (fotoUrl != null && fotoUrl.isNotEmpty)
                      ? Image.network(
                          fotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.person_rounded,
                            size: 58,
                            color: _teal,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 58,
                          color: _teal,
                        ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color: _orange.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))
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
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().currentUser;
    _nombreController = TextEditingController(text: user?.nombre ?? '');
    _telefonoController = TextEditingController(text: user?.telefono ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  void _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;
    final authController = context.read<AuthController>();

    final okPerfil = await authController.updateProfile(
      _nombreController.text.trim(),
      _telefonoController.text.trim(),
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
        backgroundColor: _teal,
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
                      color: _teal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: _teal.withValues(alpha: 0.3), width: 2),
                    ),
                    child: (user?.fotoUrl != null && user!.fotoUrl!.isNotEmpty)
                        ? ClipOval(
                            child: Image.network(user.fotoUrl!, fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(
                                    Icons.person_rounded, color: _teal, size: 28)))
                        : const Icon(Icons.person_rounded, color: _teal, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Editar Perfil',
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w700, color: _dark)),
                      Text(user?.correo ?? '',
                          style: GoogleFonts.poppins(fontSize: 12, color: _grey),
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
                  style: GoogleFonts.poppins(fontSize: 14, color: _dark),
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
                  style: GoogleFonts.poppins(fontSize: 14, color: _dark),
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
                const SizedBox(height: 24),

                // Guardar datos de perfil
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authController.isLoading ? null : _guardarPerfil,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      disabledBackgroundColor: _teal.withValues(alpha: 0.5),
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
                        style: GoogleFonts.poppins(fontSize: 11, color: _grey)),
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
                                      fontSize: 11, color: _grey)),
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
                color: _grey,
                letterSpacing: 0.3)),
      );

  InputDecoration _fieldDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: _teal, size: 20),
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
            borderSide: const BorderSide(color: _teal, width: 2)),
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
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: _teal, size: 20),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _grey, size: 20),
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
            borderSide: const BorderSide(color: _teal, width: 2)),
      ),
      validator: widget.validator ??
          (v) {
            if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
            return null;
          },
    );
  }
}

// ── Cortador de cabecera en onda convexa ──
class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 15,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
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
                            color: _dark)),
                    Text('El administrador la revisará antes de publicar',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: _grey)),
                  ]),
                ]),
                const SizedBox(height: 20),

                // Título
                TextFormField(
                  controller: _tituloCtrl,
                  style: GoogleFonts.poppins(fontSize: 14, color: _dark),
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
                  style: GoogleFonts.poppins(fontSize: 13, color: _dark),
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
                        color: _dark)),
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
                          color: _teal.withValues(alpha: 0.3), width: 1.2),
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
                                  color: _teal, size: 20),
                              const SizedBox(width: 8),
                              Text('Agregar imagen (opcional)',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: _teal)),
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
      labelStyle: GoogleFonts.poppins(color: _grey, fontSize: 13),
      prefixIcon: Icon(icon, color: _teal, size: 20),
      filled: true,
      fillColor: const Color(0xFFF0F9FF),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: _teal.withValues(alpha: 0.25), width: 1.2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _teal, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
              color: Color(0xFFE53935), width: 1.2)),
    );
  }
}
