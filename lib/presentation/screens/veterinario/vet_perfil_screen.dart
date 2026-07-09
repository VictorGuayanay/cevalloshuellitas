import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../data/models/veterinario_model.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../../domain/controllers/cita_controller.dart';
import '../../../domain/controllers/mascota_controller.dart';
import '../../../domain/controllers/veterinario_controller.dart';
import '../../../domain/controllers/servicio_controller.dart';
import '../../../domain/controllers/noticia_controller.dart';
import '../shared/historial_citas_screen.dart';
import 'seleccionar_ubicacion_screen.dart';

// ─── Paleta profesional veterinario ───────────────────────────────────────────
const _primary = Color(0xFF2D8B6F);
const _primaryDark = Color(0xFF1A5C47);
const _primaryLight = Color(0xFF4CAF8E);
const _accent = Color.fromARGB(255, 67, 184, 156);
const _dark = Color.fromARGB(255, 26, 46, 37);
const _textSecondary = Color(0xFF6B7F8E);
const _cardBg = Colors.white;
const _bgColor = Color(0xFFF2F7F5);
const _dividerColor = Color(0xFFF0F3F1);
const _orangeAccent = Color(0xFFE58D57);
const _purpleAccent = Color(0xFF7C6FCD);

class VetPerfilScreen extends StatefulWidget {
  const VetPerfilScreen({super.key});

  @override
  State<VetPerfilScreen> createState() => _VetPerfilScreenState();
}

class _VetPerfilScreenState extends State<VetPerfilScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final uid = context.read<AuthController>().currentUser?.id;
      if (uid == null) return;

      final vetCtrl = context.read<VeterinarioController>();
      final servCtrl = context.read<ServicioController>();

      await vetCtrl.cargarPerfil(uid);

      // Cargar catálogo de servicios siempre
      servCtrl.cargarServicios();

      // Cargar mis servicios si ya tiene perfil en veterinarios
      final veteId = vetCtrl.perfil?.id;
      if (veteId != null && veteId.isNotEmpty) {
        servCtrl.cargarMisServicios(veteId);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final vetCtrl = context.watch<VeterinarioController>();
    final vet = vetCtrl.perfil;
    final citas = context.watch<CitaController>();
    final mascotas = context.watch<MascotaController>();

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // ── Fondo con gradiente y patrón decorativo ──
          _buildHeaderBackground(),

          // ── Contenido principal ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  // ── App bar transparente ──
                  _buildAppBar(auth),
                  // ── Contenido scrollable ──
                  Expanded(
                    child: vetCtrl.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: _primaryLight))
                        : SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                // ── Sección avatar + info ──
                                _buildProfileHeader(user, vet),
                                const SizedBox(height: 20),
                                // ── Estadísticas ──
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: _buildStatsRow(citas, mascotas),
                                ),
                                const SizedBox(height: 24),
                                // ── Tarjetas de información ──
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Column(
                                    children: [
                                      _buildProfessionalCard(vet),
                                      const SizedBox(height: 16),
                                      _buildPersonalCard(user),
                                      const SizedBox(height: 16),
                                      _buildAccountCard(vetCtrl, vet),
                                      const SizedBox(height: 20),
                                      _buildLogoutButton(auth),
                                      const SizedBox(height: 36),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER BACKGROUND
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeaderBackground() {
    return Container(
      height: 340,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A5C47), Color(0xFF3DA07B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _HeaderPatternPainter(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAppBar(AuthController auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text('Mi Perfil',
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3)),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILE HEADER (Avatar + Name + Specialty)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildProfileHeader(dynamic user, VeterinarioModel? vet) {
    return Column(
      children: [
        const SizedBox(height: 4),
        // Avatar con anillo decorativo
        _VetAvatarPicker(fotoUrl: user?.fotoUrl),
        const SizedBox(height: 14),
        // Nombre
        Text(
          'Dr. ${user?.nombre ?? 'Veterinario'}',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        // Badge de especialidad
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Text(
                vet?.especialidad ?? 'Médico Veterinario',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
        // Indicador de disponibilidad
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: (vet?.disponible ?? true)
                    ? const Color(0xFF6FE5B8)
                    : Colors.grey.shade400,
                shape: BoxShape.circle,
                boxShadow: [
                  if (vet?.disponible ?? true)
                    BoxShadow(
                      color: const Color(0xFF6FE5B8).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              (vet?.disponible ?? true)
                  ? 'Disponible'
                  : 'No disponible',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATISTICS ROW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStatsRow(CitaController citas, MascotaController mascotas) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _statItem(
            '${citas.todasLasCitas.length}',
            'Citas totales',
            Icons.calendar_today_rounded,
            _primary,
          ),
          _verticalDivider(),
          _statItem(
            '${citas.citasCompletadasHoy}',
            'Completadas',
            Icons.task_alt_rounded,
            _accent,
          ),
          _verticalDivider(),
          _statItem(
            '${mascotas.todasLasMascotas.length}',
            'Pacientes',
            Icons.pets_rounded,
            _purpleAccent,
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                    height: 1)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 50,
      color: _dividerColor,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFESSIONAL INFO CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildProfessionalCard(VeterinarioModel? vet) {
    return _modernCard(
      icon: Icons.medical_services_rounded,
      title: 'Información Profesional',
      accentColor: _primary,
      children: [
        _modernInfoRow(
          Icons.school_rounded,
          'Especialidad',
          vet?.especialidad ?? 'No registrada',
          _primary,
        ),
        _modernInfoRow(
          Icons.work_history_rounded,
          'Experiencia',
          vet?.experiencia != null
              ? '${vet!.experiencia} años'
              : 'No registrada',
          _accent,
        ),
        _modernInfoRow(
          Icons.payments_rounded,
          'Tarifa consulta',
          vet?.tarifa != null
              ? '\$${vet!.tarifa!.toStringAsFixed(2)}'
              : 'No registrada',
          _orangeAccent,
        ),
        _modernInfoRow(
          Icons.location_on_rounded,
          'Ubicación del consultorio',
          vet?.direccion != null && vet!.direccion!.isNotEmpty
              ? vet.direccion!
              : (vet?.latitud != null
                  ? 'Lat: ${vet!.latitud!.toStringAsFixed(5)}, Lng: ${vet.longitud!.toStringAsFixed(5)}'
                  : 'No registrada'),
          const Color(0xFFE53935),
          isLast: true,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSONAL INFO CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPersonalCard(dynamic user) {
    return _modernCard(
      icon: Icons.person_rounded,
      title: 'Información Personal',
      accentColor: _purpleAccent,
      children: [
        _modernInfoRow(
          Icons.email_rounded,
          'Correo electrónico',
          user?.correo ?? '—',
          _primary,
        ),
        _modernInfoRow(
          Icons.phone_rounded,
          'Teléfono',
          user?.telefono ?? 'No registrado',
          _accent,
        ),
        if (user?.fechaRegistro != null)
          _modernInfoRow(
            Icons.calendar_month_rounded,
            'Miembro desde',
            '${user!.fechaRegistro!.day}/${user.fechaRegistro!.month}/${user.fechaRegistro!.year}',
            _orangeAccent,
            isLast: true,
          ),
        if (user?.fechaRegistro == null)
          const SizedBox(height: 4),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCOUNT CARD
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAccountCard(VeterinarioController vetCtrl, VeterinarioModel? vet) {
    return _modernCard(
      icon: Icons.tune_rounded,
      title: 'Gestión de Cuenta',
      accentColor: _accent,
      children: [
        _modernOptionRow(
          Icons.history_rounded,
          'Historial de Citas',
          'Revisa tus citas anteriores',
          _primary,
          () {
            final veteId = vetCtrl.perfil?.id;
            if (veteId != null && veteId.isNotEmpty) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistorialCitasScreen(
                        modo: 'veterinario', entityId: veteId),
                  ));
            }
          },
        ),
        _modernOptionRow(
          Icons.edit_note_rounded,
          'Editar información',
          'Actualiza tu perfil profesional',
          _accent,
          () => _showEditSheet(context, vet),
        ),
        _modernOptionRow(
          Icons.location_on_rounded,
          'Mi ubicación en el mapa',
          'Establece tu consultorio',
          _orangeAccent,
          () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                        value: context.read<VeterinarioController>(),
                        child: const SeleccionarUbicacionScreen(),
                      ))),
        ),
        _modernOptionRow(
          Icons.lock_rounded,
          'Cambiar contraseña',
          'Actualiza tu seguridad',
          _purpleAccent,
          () => _showCambiarContrasena(context),
        ),
        _modernOptionRow(
          Icons.newspaper_rounded,
          'Enviar noticia',
          'Propón una noticia para publicar',
          const Color(0xFF7C6FCD),
          () => _showEnviarNoticia(context),
        ),
        _modernOptionRow(
          Icons.swap_horiz_rounded,
          'Cambiar a rol Usuario',
          'Accede como usuario regular',
          const Color(0xFF5B8FB9),
          () => _cambiarRol(context),
          isLast: true,
        ),      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODERN CARD TEMPLATE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _modernCard({
    required IconData icon,
    required String title,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la tarjeta
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.15),
                        accentColor.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                        letterSpacing: 0.1)),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            color: _dividerColor,
          ),
          ...children,
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODERN INFO ROW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _modernInfoRow(
      IconData icon, String label, String value, Color color,
      {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500)),
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
        ),
        if (!isLast)
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 58, right: 18),
            color: _dividerColor,
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODERN OPTION ROW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _modernOptionRow(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap, {
    bool isLast = false,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: isLast
                ? const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _dark)),
                        Text(subtitle,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: _textSecondary,
                                fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.chevron_right_rounded,
                        color: color.withValues(alpha: 0.6), size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 58, right: 18),
            color: _dividerColor,
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGOUT BUTTON
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLogoutButton(AuthController auth) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () async {
          await auth.logout();
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text('Cerrar Sesión',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES (sheets y diálogos - sin cambio de funcionalidad)
  // ═══════════════════════════════════════════════════════════════════════════

  void _showEnviarNoticia(BuildContext context) {
    final uid = context.read<AuthController>().currentUser?.id ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<NoticiaController>(),
        child: _EnviarNoticiaVetSheet(usuaId: uid),
      ),
    );
  }

  void _showEditSheet(BuildContext context, VeterinarioModel? vet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ServicioController>(),
        child: _VetEditSheet(vetActual: vet),
      ),
    );
  }

  void _showCambiarContrasena(BuildContext context) {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Cambiar Contraseña', style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: _dark)),
                const SizedBox(height: 6),
                Text('Ingresa tu nueva contraseña',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: _textSecondary)),
                const SizedBox(height: 18),
                _fieldForm('Nueva contraseña', passCtrl,
                    Icons.lock_outline_rounded, obscure: true,
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mínimo 6 caracteres' : null),
                const SizedBox(height: 12),
                _fieldForm('Confirmar contraseña', confirmCtrl,
                    Icons.lock_outline_rounded, obscure: true,
                    validator: (v) =>
                        v != passCtrl.text ? 'No coinciden' : null),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 52,
                  child: Consumer<AuthController>(
                    builder: (ctx, auth, _) => ElevatedButton(
                      onPressed: auth.isLoading ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        final ok = await auth.cambiarContrasena(passCtrl.text);
                        if (ok && context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('¡Contraseña actualizada!')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white, elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      child: auth.isLoading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('Actualizar', style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _cambiarRol(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _purpleAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  color: _purpleAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Cambiar Rol',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700, fontSize: 18)),
            ),
          ],
        ),
        content: Text(
            '¿Deseas cambiar tu rol a Usuario? Serás redirigido al panel de usuario.',
            style: GoogleFonts.poppins(
                fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(color: _textSecondary)),
          ),
          Consumer<AuthController>(
            builder: (ctx, auth, _) => ElevatedButton(
              onPressed: auth.isLoading ? null : () async {
                final ok = await auth.updateRol('usuario');
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/home');
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _purpleAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text('Confirmar',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldForm(String label, TextEditingController ctrl, IconData icon,
      {bool obscure = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      validator: validator,
      style: GoogleFonts.poppins(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: true, fillColor: const Color(0xFFF2F7F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _primary.withValues(alpha: 0.2), width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 2)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER PATTERN PAINTER - Decorative circles
// ═══════════════════════════════════════════════════════════════════════════════
class _HeaderPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    // Círculos decorativos
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.2), 80, paint);
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.7), 60, paint);

    paint.color = Colors.white.withValues(alpha: 0.03);
    canvas.drawCircle(
        Offset(size.width * 0.65, size.height * 0.8), 100, paint);
    canvas.drawCircle(
        Offset(size.width * 0.3, size.height * 0.15), 45, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// EDIT SHEET
// ═══════════════════════════════════════════════════════════════════════════════
class _VetEditSheet extends StatefulWidget {
  final VeterinarioModel? vetActual;
  const _VetEditSheet({this.vetActual});

  @override
  State<_VetEditSheet> createState() => _VetEditSheetState();
}

class _VetEditSheetState extends State<_VetEditSheet> {
  // Campos de tabla usuarios
  late TextEditingController _nombreCtrl;
  late TextEditingController _telefonoCtrl;
  // Campos de tabla veterinarios
  late TextEditingController _especialidadCtrl;
  late TextEditingController _experienciaCtrl;
  late TextEditingController _tarifaCtrl;
  bool _disponible = true;

  @override
  void initState() {
    super.initState();
    final v = widget.vetActual;
    final user = context.read<AuthController>().currentUser;
    _nombreCtrl = TextEditingController(text: user?.nombre ?? '');
    _telefonoCtrl = TextEditingController(text: user?.telefono ?? '');
    _especialidadCtrl = TextEditingController(text: v?.especialidad ?? '');
    _experienciaCtrl = TextEditingController(
        text: v?.experiencia?.toString() ?? '');
    _tarifaCtrl = TextEditingController(
        text: v?.tarifa?.toStringAsFixed(2) ?? '');
    _disponible = v?.disponible ?? true;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _especialidadCtrl.dispose();
    _experienciaCtrl.dispose();
    _tarifaCtrl.dispose();
    super.dispose();
  }

  void _guardar() async {
    final auth = context.read<AuthController>();
    final vetCtrl = context.read<VeterinarioController>();
    final uid = auth.currentUser?.id ?? '';

    if (_nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El nombre es obligatorio')));
      return;
    }

    // 1. Actualizar nombre y teléfono en tabla usuarios
    await auth.updateProfile(
        _nombreCtrl.text.trim(), _telefonoCtrl.text.trim());
    if (!mounted) return;

    // 2. Guardar/actualizar en tabla veterinarios
    final vetModel = VeterinarioModel(
      id: vetCtrl.perfil?.id ?? '',
      usuarioId: uid,
      especialidad: _especialidadCtrl.text.trim().isNotEmpty
          ? _especialidadCtrl.text.trim()
          : null,
      experiencia: int.tryParse(_experienciaCtrl.text.trim()),
      tarifa: double.tryParse(_tarifaCtrl.text.trim()),
      disponible: _disponible,
      // Preservar ubicación existente para no sobreescribirla al editar el perfil
      latitud: vetCtrl.perfil?.latitud,
      longitud: vetCtrl.perfil?.longitud,
      direccion: vetCtrl.perfil?.direccion,
    );

    final ok = await vetCtrl.guardarPerfil(vetModel);
    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Información actualizada correctamente'),
        backgroundColor: _primary,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(vetCtrl.errorMessage ?? 'Error al guardar')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vetCtrl = context.watch<VeterinarioController>();
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_note_rounded,
                        color: _primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Editar Información',
                          style: GoogleFonts.poppins(
                              fontSize: 20, fontWeight: FontWeight.w700,
                              color: _dark)),
                      Text('Datos personales y profesionales',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: _textSecondary)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // ── Datos tabla usuarios ──
              _sectionLabel('Datos Personales'),
              const SizedBox(height: 10),
              _field('Nombre completo *', _nombreCtrl,
                  Icons.person_outline_rounded),
              const SizedBox(height: 12),
              _field('Teléfono', _telefonoCtrl, Icons.phone_outlined,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 18),

              // ── Datos tabla veterinarios ──
              _sectionLabel('Datos Profesionales'),
              const SizedBox(height: 10),
              _field('Especialidad', _especialidadCtrl,
                  Icons.medical_services_outlined),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _field('Años de experiencia', _experienciaCtrl,
                      Icons.work_outline_rounded,
                      keyboard: TextInputType.number),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field('Tarifa (\$)', _tarifaCtrl,
                      Icons.attach_money_rounded,
                      keyboard: const TextInputType.numberWithOptions(
                          decimal: true)),
                ),
              ]),
              const SizedBox(height: 12),

              // Disponible toggle
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _disponible
                      ? _primary.withValues(alpha: 0.04)
                      : const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _disponible
                          ? _primary.withValues(alpha: 0.2)
                          : Colors.grey.shade200,
                      width: 1.2),
                ),
                child: Row(children: [
                  Icon(
                    _disponible
                        ? Icons.check_circle_rounded
                        : Icons.cancel_outlined,
                    color: _disponible ? _primary : _textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Disponible para citas',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _dark)),
                  ),
                  Switch(
                    value: _disponible,
                    onChanged: (v) => setState(() => _disponible = v),
                    activeColor: _primary,
                  ),
                ]),
              ),
              const SizedBox(height: 18),

              // ── Servicios que brinda ──
              _sectionLabel('Servicios que Brindo'),
              const SizedBox(height: 10),
              Consumer<ServicioController>(
                builder: (context, servCtrl, _) {
                  if (servCtrl.isLoading || servCtrl.isLoadingMisServicios) {
                    return const Center(
                        child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primary)));
                  }
                  if (servCtrl.servicios.isEmpty) {
                    return Text('Sin servicios disponibles',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade400));
                  }
                  return Column(
                    children: servCtrl.servicios.map((s) {
                      final asignado = servCtrl.tieneServicio(s.id);
                      final veseId = servCtrl.misServicios
                          .where((ms) => ms.servId == s.id)
                          .map((ms) => ms.id)
                          .firstOrNull;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: asignado
                              ? s.color.withValues(alpha: 0.06)
                              : const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: asignado
                                ? s.color.withValues(alpha: 0.3)
                                : Colors.grey.shade200,
                            width: 1.2,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: s.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(s.iconData, color: s.color, size: 18),
                          ),
                          title: Text(s.nombre,
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _dark)),
                          trailing: Switch(
                            value: asignado,
                            activeColor: s.color,
                            onChanged: (val) async {
                              final veteId = context
                                      .read<VeterinarioController>()
                                      .perfil
                                      ?.id ??
                                  '';
                              if (veteId.isEmpty) return;
                              if (val) {
                                await servCtrl.asignarServicio(
                                    veteId: veteId, servId: s.id);
                              } else if (veseId != null) {
                                await servCtrl.quitarServicio(veseId, veteId);
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: vetCtrl.isLoading ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: vetCtrl.isLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('Guardar Cambios',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(children: [
      Container(width: 4, height: 16,
          decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.poppins(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: _primaryDark)),
    ]);
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl, keyboardType: keyboard,
      style: GoogleFonts.poppins(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: true, fillColor: const Color(0xFFF2F7F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _primary.withValues(alpha: 0.2), width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 2)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AVATAR PICKER
// ═══════════════════════════════════════════════════════════════════════════════
class _VetAvatarPicker extends StatefulWidget {
  final String? fotoUrl;
  const _VetAvatarPicker({this.fotoUrl});

  @override
  State<_VetAvatarPicker> createState() => _VetAvatarPickerState();
}

class _VetAvatarPickerState extends State<_VetAvatarPicker>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

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
        backgroundColor: ok ? _primary : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fotoUrl = context.select<AuthController, String?>(
      (c) => c.currentUser?.fotoUrl,
    );
    final isLoading =
        context.select<AuthController, bool>((c) => c.isLoading);

    return GestureDetector(
      onTap: isLoading ? null : _seleccionarFoto,
      child: SizedBox(
        width: 110,
        height: 110,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Anillo animado
            AnimatedBuilder(
              animation: _ringController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _ringController.value * 2 * math.pi,
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.6),
                          _accent.withValues(alpha: 0.4),
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // Avatar principal
            Container(
              width: 98,
              height: 98,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
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
                            color: _primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                      )
                    : (fotoUrl != null && fotoUrl.isNotEmpty)
                        ? Image.network(
                            fotoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const Icon(
                              Icons.person_rounded,
                              size: 52,
                              color: _primary,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            size: 52,
                            color: _primary,
                          ),
              ),
            ),
            // Ícono de cámara
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primary, _primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sheet: Enviar Noticia (Veterinario)
// ═══════════════════════════════════════════════════════════════════════════════
class _EnviarNoticiaVetSheet extends StatefulWidget {
  final String usuaId;
  const _EnviarNoticiaVetSheet({required this.usuaId});

  @override
  State<_EnviarNoticiaVetSheet> createState() => _EnviarNoticiaVetSheetState();
}

class _EnviarNoticiaVetSheetState extends State<_EnviarNoticiaVetSheet> {
  final _tituloCtrl    = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  final _formKey       = GlobalKey<FormState>();
  String _categoria    = 'salud';
  File? _imagen;
  String? _extension;

  static const _categorias = [
    'salud', 'nutricion', 'bienestar', 'prevencion',
    'general', 'adopcion', 'perdidos', 'emergencias',
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

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            color: _textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: _primary, size: 20),
        filled: true,
        fillColor: const Color(0xFFF2F7F5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: _primary.withValues(alpha: 0.25), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Color(0xFFE53935), width: 1.2)),
      );

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
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                )),
                const SizedBox(height: 20),

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
                            fontSize: 11, color: _textSecondary)),
                  ]),
                ]),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _tituloCtrl,
                  style: GoogleFonts.poppins(fontSize: 14, color: _dark),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El título es requerido' : null,
                  decoration: _deco('Título de la noticia', Icons.title_rounded),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _contenidoCtrl,
                  maxLines: 4,
                  style: GoogleFonts.poppins(fontSize: 13, color: _dark),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El contenido es requerido' : null,
                  decoration: _deco('Descripción o contenido',
                      Icons.article_outlined),
                ),
                const SizedBox(height: 12),

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
                          color: sel ? _primary : Colors.grey.shade100,
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

                GestureDetector(
                  onTap: _pickImagen,
                  child: Container(
                    width: double.infinity,
                    height: _imagen != null ? 160 : 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F7F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _primary.withValues(alpha: 0.3), width: 1.2),
                    ),
                    child: _imagen != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(_imagen!, fit: BoxFit.cover))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_photo_alternate_outlined,
                                  color: _primary, size: 20),
                              const SizedBox(width: 8),
                              Text('Agregar imagen (opcional)',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: _primary)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

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
                        ctrl.isSubmitting
                            ? 'Enviando...'
                            : 'Enviar para revisión',
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
}
