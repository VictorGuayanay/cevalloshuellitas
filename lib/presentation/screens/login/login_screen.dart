import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/google_button.dart';
import '../../widgets/wave_background.dart';
import 'register_screen.dart';
import 'recuperar_contrasena_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _entranceController;
  late AnimationController _formExpandController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _formAnim;

  bool _showEmailForm = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _formExpandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
    _formAnim = CurvedAnimation(
      parent: _formExpandController,
      curve: Curves.easeInOut,
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entranceController.dispose();
    _formExpandController.dispose();
    super.dispose();
  }

  void _toggleEmailForm() {
    setState(() => _showEmailForm = !_showEmailForm);
    if (_showEmailForm) {
      _formExpandController.forward();
    } else {
      _formExpandController.reverse();
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final authController = context.read<AuthController>();
    final success = await authController.login(
      _emailController.text,
      _passwordController.text,
    );
    if (success && mounted) {
      final rol = authController.currentUser?.rol;
      if (rol == 'administrador') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    final authController = context.read<AuthController>();
    final success = await authController.loginWithGoogle();
    if (success && mounted) {
      final rol = authController.currentUser?.rol;
      if (rol == 'administrador') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      body: Stack(
        children: [
          // Fondo con ondas decorativas
          const WaveBackground(),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        const SizedBox(height: 56),

                        // Logo de la app
                        Image.asset(
                          'asest/logohome.png',
                          width: 150,
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 22),

                        // Título
                        Text(
                          'Huellitas',
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A2E),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Inicio de sesión',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 44),

                        // Botón: Iniciar con correo
                        _MethodButton(
                          icon: Icons.email_outlined,
                          label: 'Iniciar sesión con correo',
                          onTap: _toggleEmailForm,
                          isActive: _showEmailForm,
                        ),

                        // Formulario expandible de email/password
                        SizeTransition(
                          sizeFactor: _formAnim,
                          child: FadeTransition(
                            opacity: _formAnim,
                            child: _EmailForm(
                              formKey: _formKey,
                              emailController: _emailController,
                              passwordController: _passwordController,
                              onLogin: _handleLogin,
                              onRegister: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Botón: Iniciar con Google
                        GoogleButton(onTap: _handleGoogleLogin),
                        const SizedBox(height: 14),

                        // Mensaje de error global
                        Consumer<AuthController>(
                          builder: (context, auth, _) {
                            if (auth.errorMessage != null) {
                              // ERR-07/R1: liveRegion propio para que los
                              // lectores de pantalla anuncien el banner.
                              return Semantics(
                                container: true,
                                liveRegion: true,
                                child: Container(
                                  margin: const EdgeInsets.only(
                                    top: 4,
                                    bottom: 8,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.redBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.red),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: AppColors.red,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          auth.errorMessage!,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            // R1: redDark sobre redBg =
                                            // 6.14:1 ≥ 4.5 (rojo puro
                                            // daría 3.95:1 y no cumple).
                                            color: AppColors.redDark,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        const SizedBox(height: 32),

                        // Footer: Crear cuenta
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                          child: Text(
                            '¿No tienes cuenta? Crear cuenta',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF5BBFBF),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: const Color(0xFF5BBFBF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Widget: Botón de método de ingreso
// ────────────────────────────────────────────────
class _MethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _MethodButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF5BBFBF).withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFF5BBFBF) : const Color(0xFFDCEEF0),
            width: isActive ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5BBFBF).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            Icon(
              icon,
              size: 22,
              color: isActive
                  ? const Color(0xFF5BBFBF)
                  : const Color(0xFF555555),
            ),
            const SizedBox(width: 14),
            // Expanded + ellipsis: en pantallas angostas la etiqueta encoge
            // y se recorta en lugar de desbordar el RenderFlex (defecto
            // observado en vivo en :325), y sigue empujando la flecha a la
            // derecha (aquí reemplaza al Spacer, que no dejaba encoger al
            // texto). En pantallas anchas el diseño no cambia: la etiqueta
            // ocupa su ancho natural y la flecha queda a la derecha.
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? const Color(0xFF5BBFBF)
                      : const Color(0xFF2D2D2D),
                ),
              ),
            ),
            Icon(
              isActive ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: const Color(0xFFAAAAAA),
              size: 20,
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Widget: Formulario expandible email/password
// ────────────────────────────────────────────────
class _EmailForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _EmailForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.onRegister,
  });

  void _showRecuperarContrasena(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecuperarContrasenaScreen(
          correoInicial: emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCEEF0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5BBFBF).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              label: 'Correo electrónico',
              icon: Icons.email_outlined,
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa tu correo electrónico';
                }
                if (!RegExp(
                  r'^[\w\.-]+@[\w\.-]+\.\w+$',
                ).hasMatch(value.trim())) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Contraseña',
              icon: Icons.lock_outline_rounded,
              controller: passwordController,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa tu contraseña';
                }
                if (value.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 10),
            // ── Link: ¿Olvidaste tu contraseña? ──
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _showRecuperarContrasena(context),
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF339D9D),
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFF339D9D),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Consumer<AuthController>(
              builder: (context, auth, _) {
                return SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : onLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5BBFBF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor: const Color(
                        0xFF5BBFBF,
                      ).withValues(alpha: 0.5),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Ingresar',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
