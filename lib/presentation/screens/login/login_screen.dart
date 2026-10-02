import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../widgets/custom_text_field.dart';
import 'register_screen.dart';

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
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
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
          const _WaveBackground(),

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
                        _GoogleButton(onTap: _handleGoogleLogin),
                        const SizedBox(height: 14),

                        // Mensaje de error global
                        Consumer<AuthController>(
                          builder: (context, auth, _) {
                            if (auth.errorMessage != null) {
                              return Container(
                                margin: const EdgeInsets.only(top: 4, bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFEF9A9A)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        color: Color(0xFFE53935), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        auth.errorMessage!,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: const Color(0xFFE53935),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
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
            color: isActive
                ? const Color(0xFF5BBFBF)
                : const Color(0xFFDCEEF0),
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
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? const Color(0xFF5BBFBF)
                    : const Color(0xFF2D2D2D),
              ),
            ),
            const Spacer(),
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
// Widget: Botón de Google
// ────────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GoogleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        return GestureDetector(
          onTap: auth.isLoading ? null : onTap,
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFDCEEF0),
                width: 1.2,
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
                auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : SizedBox(
                        width: 22,
                        height: 22,
                        child: CustomPaint(
                          painter: _GoogleLogoPainter(),
                        ),
                      ),
                const SizedBox(width: 14),
                Text(
                  'Iniciar con Google',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2D2D2D),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
        builder: (_) => _RecuperarContrasenaScreen(
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
                if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$')
                    .hasMatch(value.trim())) {
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
                      disabledBackgroundColor:
                          const Color(0xFF5BBFBF).withValues(alpha: 0.5),
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

// ────────────────────────────────────────────────
// CustomPainter: Fondo con ondas lavanda
// ────────────────────────────────────────────────
class _WaveBackground extends StatelessWidget {
  const _WaveBackground();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _WavePainter(),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintTop = Paint()
      ..color = const Color(0xFFCBEBFC).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final paintBottom = Paint()
      ..color = const Color(0xFFD4EFFF).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final paintAccent = Paint()
      ..color = const Color(0xFFBBE5F9).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Blob superior izquierdo
    final pathTop = Path()
      ..moveTo(0, 0)
      ..cubicTo(size.width * 0.15, -size.height * 0.04,
          size.width * 0.55, size.height * 0.05, size.width * 0.4, size.height * 0.22)
      ..cubicTo(size.width * 0.28, size.height * 0.32,
          -size.width * 0.05, size.height * 0.25, 0, size.height * 0.15)
      ..close();
    canvas.drawPath(pathTop, paintTop);

    // Blob superior derecho
    final pathTopRight = Path()
      ..moveTo(size.width, 0)
      ..cubicTo(size.width * 0.85, size.height * 0.02,
          size.width * 0.65, size.height * 0.12, size.width * 0.75, size.height * 0.28)
      ..cubicTo(size.width * 0.82, size.height * 0.38,
          size.width * 1.05, size.height * 0.3, size.width, size.height * 0.18)
      ..close();
    canvas.drawPath(pathTopRight, paintAccent);

    // Blob inferior izquierdo
    final pathBottomLeft = Path()
      ..moveTo(0, size.height)
      ..cubicTo(size.width * 0.05, size.height * 0.82,
          size.width * 0.25, size.height * 0.78, size.width * 0.2, size.height * 0.88)
      ..cubicTo(size.width * 0.15, size.height * 0.95,
          size.width * 0.08, size.height * 1.02, 0, size.height)
      ..close();
    canvas.drawPath(pathBottomLeft, paintAccent);

    // Blob inferior derecho grande
    final pathBottom = Path()
      ..moveTo(size.width, size.height)
      ..cubicTo(size.width * 0.85, size.height * 0.92,
          size.width * 0.55, size.height * 0.88, size.width * 0.6, size.height * 0.75)
      ..cubicTo(size.width * 0.65, size.height * 0.65,
          size.width * 1.08, size.height * 0.7, size.width, size.height * 0.85)
      ..close();
    canvas.drawPath(pathBottom, paintBottom);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// ────────────────────────────────────────────────
// CustomPainter: Logo de Google
// ────────────────────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];

    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2 + (math.pi / 2) * i,
        math.pi / 2,
        true,
        Paint()..color = colors[i],
      );
    }

    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.58,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ────────────────────────────────────────────────
// Pantalla: Recuperar contraseña con código OTP
// ────────────────────────────────────────────────
class _RecuperarContrasenaScreen extends StatefulWidget {
  final String correoInicial;
  const _RecuperarContrasenaScreen({required this.correoInicial});

  @override
  State<_RecuperarContrasenaScreen> createState() =>
      _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState
    extends State<_RecuperarContrasenaScreen> {
  // Paso 1: ingresar correo y enviar OTP
  // Paso 2: ingresar código OTP + nueva contraseña
  int _paso = 1;

  final _correoCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _nuevaPassCtrl = TextEditingController();
  final _confirmarPassCtrl = TextEditingController();

  bool _obscureNueva = true;
  bool _obscureConfirmar = true;

  @override
  void initState() {
    super.initState();
    _correoCtrl.text = widget.correoInicial;
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    _otpCtrl.dispose();
    _nuevaPassCtrl.dispose();
    _confirmarPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    final correo = _correoCtrl.text.trim();
    if (correo.isEmpty ||
        !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(correo)) {
      _mostrarError('Ingresa un correo válido.');
      return;
    }
    final auth = context.read<AuthController>();
    final ok = await auth.recuperarContrasena(correo);
    if (!mounted) return;
    if (ok) {
      setState(() => _paso = 2);
    } else {
      _mostrarError(auth.errorMessage ??
          'No se encontró una cuenta con ese correo.');
    }
  }

  Future<void> _cambiarContrasena() async {
    final otp = _otpCtrl.text.trim();
    final nueva = _nuevaPassCtrl.text;
    final confirmar = _confirmarPassCtrl.text;

    if (otp.length < 6) {
      _mostrarError('El código debe tener 6 dígitos.');
      return;
    }
    if (nueva.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (nueva != confirmar) {
      _mostrarError('Las contraseñas no coinciden.');
      return;
    }

    final auth = context.read<AuthController>();
    final ok = await auth.verificarOtpYCambiarContrasena(
      correo: _correoCtrl.text.trim(),
      otp: otp,
      nuevaContrasena: nueva,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text('¡Contraseña actualizada correctamente!',
              style: GoogleFonts.poppins(fontSize: 13)),
        ]),
        backgroundColor: const Color(0xFF43B89C),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else {
      _mostrarError(auth.errorMessage ??
          'Código incorrecto o expirado. Solicita uno nuevo.');
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
      backgroundColor: const Color(0xFFE53935),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      body: Stack(
        children: [
          const _WaveBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // AppBar
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF5BBFBF), size: 22),
                      onPressed: () {
                        if (_paso == 2) {
                          setState(() => _paso = 1);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Ícono
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BBFBF).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset_rounded,
                        color: Color(0xFF5BBFBF), size: 40),
                  ),
                  const SizedBox(height: 20),

                  // Título y subtítulo
                  Text(
                    _paso == 1
                        ? 'Recuperar contraseña'
                        : 'Ingresa el código',
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _paso == 1
                        ? 'Te enviaremos un código de 6 dígitos\nal correo que ingreses.'
                        : 'Revisa tu correo ${_correoCtrl.text}\ny escribe el código de 6 dígitos.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.5),
                  ),
                  const SizedBox(height: 36),

                  // ── PASO 1: Correo ──
                  if (_paso == 1) ...[
                    _inputField(
                      controller: _correoCtrl,
                      label: 'Correo electrónico',
                      icon: Icons.email_outlined,
                      keyboard: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),
                    _botonPrincipal(
                      label: 'Enviar código',
                      icon: Icons.send_rounded,
                      onTap: _enviarCodigo,
                    ),
                  ],

                  // ── PASO 2: OTP + nueva contraseña ──
                  if (_paso == 2) ...[
                    // Campo código OTP
                    _inputField(
                      controller: _otpCtrl,
                      label: 'Código de 6 dígitos',
                      icon: Icons.pin_outlined,
                      keyboard: TextInputType.number,
                      maxLength: 6,
                      centerText: true,
                      fontSize: 22,
                      letterSpacing: 10,
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      controller: _nuevaPassCtrl,
                      label: 'Nueva contraseña',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscureNueva,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNueva
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNueva = !_obscureNueva),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _inputField(
                      controller: _confirmarPassCtrl,
                      label: 'Confirmar contraseña',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscureConfirmar,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmar
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscureConfirmar = !_obscureConfirmar),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _botonPrincipal(
                      label: 'Cambiar contraseña',
                      icon: Icons.check_rounded,
                      onTap: _cambiarContrasena,
                    ),
                    const SizedBox(height: 16),
                    // Reenviar código
                    GestureDetector(
                      onTap: () => setState(() {
                        _paso = 1;
                        _otpCtrl.clear();
                      }),
                      child: Text(
                        '¿No recibiste el código? Enviar de nuevo',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF5BBFBF),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFF5BBFBF)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    bool obscure = false,
    Widget? suffixIcon,
    int? maxLength,
    bool centerText = false,
    double fontSize = 14,
    double letterSpacing = 0,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      maxLength: maxLength,
      textAlign: centerText ? TextAlign.center : TextAlign.start,
      style: GoogleFonts.poppins(
          fontSize: fontSize,
          color: const Color(0xFF2D2D2D),
          letterSpacing: letterSpacing,
          fontWeight: centerText ? FontWeight.w700 : FontWeight.normal),
      decoration: InputDecoration(
        counterText: '',
        labelText: centerText ? null : label,
        hintText: centerText ? label : null,
        labelStyle:
            GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
        hintStyle:
            GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon:
            centerText ? null : Icon(icon, color: const Color(0xFF5BBFBF), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Color(0xFFDCEEF0), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Color(0xFF5BBFBF), width: 2)),
      ),
    );
  }

  Widget _botonPrincipal({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Consumer<AuthController>(
      builder: (ctx, auth, child) => SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: auth.isLoading ? null : onTap,
          icon: auth.isLoading
              ? const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Icon(icon, size: 20),
          label: Text(
            auth.isLoading ? 'Procesando…' : label,
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5BBFBF),
            foregroundColor: Colors.white,
            elevation: 0,
            disabledBackgroundColor:
                const Color(0xFF5BBFBF).withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }
}
