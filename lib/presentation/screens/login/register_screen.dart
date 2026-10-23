import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRol = 'usuario';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    // ERR-01 / AMD-2026-10-23-01: choke point único al entrar en la pantalla
    // de registro — un banner heredado de un fallo previo (login u otra
    // operación) nunca debe renderizarse aquí. `limpiarError()` notifica a
    // los listeners, y `initState` corre dentro de la fase de build: marcar
    // el provider como sucio en ese momento viola el framework
    // (setState()/markNeedsBuild() during build), así que la limpieza se
    // difiere al primer frame — el Consumer ya no pinta el banner obsoleto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthController>().limpiarError();
    });
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authController = context.read<AuthController>();
    final success = await authController.register(
      nombre: _nombreController.text,
      correo: _emailController.text,
      password: _passwordController.text,
      telefono: _telefonoController.text.isNotEmpty
          ? _telefonoController.text
          : null,
      rol: _selectedRol,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      body: Stack(
        children: [
          // Fondo con ondas decorativas
          SizedBox.expand(child: CustomPaint(painter: _RegisterWavePainter())),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // ── Top bar con botón retroceso ──
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFDCEEF0),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF5BBFBF,
                                      ).withValues(alpha: 0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 18,
                                  color: Color(0xFF5BBFBF),
                                ),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Logo de la app (más grande)
                        Image.asset(
                          'asest/logohome.png',
                          width: 150,
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),

                        // Título
                        Text(
                          'Crear Cuenta',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Únete a la familia Huellitas',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Card del formulario
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFDCEEF0),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF5BBFBF,
                                ).withValues(alpha: 0.07),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Nombre
                                CustomTextField(
                                  label: 'Nombre completo',
                                  icon: Icons.person_outline_rounded,
                                  controller: _nombreController,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Ingresa tu nombre';
                                    }
                                    if (value.trim().length < 3) {
                                      return 'Mínimo 3 caracteres';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Email
                                CustomTextField(
                                  label: 'Correo electrónico',
                                  icon: Icons.email_outlined,
                                  controller: _emailController,
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

                                // Teléfono
                                CustomTextField(
                                  label: 'Teléfono (opcional)',
                                  icon: Icons.phone_outlined,
                                  controller: _telefonoController,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 14),

                                // Selector de rol
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3FAFD),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFDCEEF0),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedRol,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      icon: Icon(
                                        Icons.badge_outlined,
                                        color: Color(0xFF5BBFBF),
                                        size: 22,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF2D2D2D),
                                      fontSize: 15,
                                    ),
                                    dropdownColor: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'usuario',
                                        child: Text('Usuario'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedRol = value!;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Contraseña
                                CustomTextField(
                                  label: 'Contraseña',
                                  icon: Icons.lock_outline_rounded,
                                  controller: _passwordController,
                                  obscureText: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Ingresa una contraseña';
                                    }
                                    if (value.length < 6) {
                                      return 'Mínimo 6 caracteres';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Confirmar contraseña
                                CustomTextField(
                                  label: 'Confirmar contraseña',
                                  icon: Icons.lock_outline_rounded,
                                  controller: _confirmPasswordController,
                                  obscureText: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Confirma tu contraseña';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Las contraseñas no coinciden';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 22),

                                // Mensaje de error
                                Consumer<AuthController>(
                                  builder: (context, auth, _) {
                                    if (auth.errorMessage != null) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 14,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFEBEE),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFEF9A9A),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.error_outline_rounded,
                                                color: Color(0xFFE53935),
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  auth.errorMessage!,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: const Color(
                                                      0xFFE53935,
                                                    ),
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

                                // Botón Crear Cuenta
                                Consumer<AuthController>(
                                  builder: (context, auth, _) {
                                    return SizedBox(
                                      height: 54,
                                      child: ElevatedButton(
                                        onPressed: auth.isLoading
                                            ? null
                                            : _handleRegister,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF5BBFBF,
                                          ),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          disabledBackgroundColor: const Color(
                                            0xFF5BBFBF,
                                          ).withValues(alpha: 0.5),
                                        ),
                                        child: auth.isLoading
                                            ? const SizedBox(
                                                height: 22,
                                                width: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.5,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : Text(
                                                'Crear Cuenta',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
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
                        ),
                        const SizedBox(height: 24),

                        // Link a login
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            '¿Ya tienes cuenta? Iniciar sesión',
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
// CustomPainter: Fondo con ondas lavanda para Registro
// ────────────────────────────────────────────────
class _RegisterWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintTop = Paint()
      ..color = const Color(0xFFCBEBFC).withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final paintBottom = Paint()
      ..color = const Color(0xFFD4EFFF).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    final paintAccent = Paint()
      ..color = const Color(0xFFBBE5F9).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final pathTop = Path()
      ..moveTo(0, 0)
      ..cubicTo(
        size.width * 0.4,
        -size.height * 0.02,
        size.width * 0.7,
        size.height * 0.08,
        size.width * 0.5,
        size.height * 0.18,
      )
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.28,
        -size.width * 0.05,
        size.height * 0.2,
        0,
        size.height * 0.1,
      )
      ..close();
    canvas.drawPath(pathTop, paintTop);

    final pathRight = Path()
      ..moveTo(size.width, 0)
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.04,
        size.width * 0.6,
        size.height * 0.15,
        size.width * 0.72,
        size.height * 0.26,
      )
      ..cubicTo(
        size.width * 0.85,
        size.height * 0.36,
        size.width * 1.08,
        size.height * 0.28,
        size.width,
        size.height * 0.16,
      )
      ..close();
    canvas.drawPath(pathRight, paintAccent);

    final pathBottom = Path()
      ..moveTo(size.width, size.height)
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.9,
        size.width * 0.5,
        size.height * 0.86,
        size.width * 0.58,
        size.height * 0.76,
      )
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.67,
        size.width * 1.1,
        size.height * 0.72,
        size.width,
        size.height * 0.86,
      )
      ..close();
    canvas.drawPath(pathBottom, paintBottom);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
