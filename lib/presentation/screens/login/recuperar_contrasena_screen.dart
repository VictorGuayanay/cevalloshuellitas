// recuperar_contrasena_screen.dart — Pantalla de recuperación por enlace (un solo paso).
//
// Convertida del flujo OTP en task 12.16. Ahora usa un solo paso:
// campo correo + botón "Restablecer contraseña" → envía enlace
// huellitas://password-recovery.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../widgets/wave_background.dart';

/// Pantalla de recuperación de contraseña (flujo por enlace, un solo paso).
/// Campo correo + botón "Restablecer contraseña" → envía enlace de recuperación.
class RecuperarContrasenaScreen extends StatefulWidget {
  final String correoInicial;

  const RecuperarContrasenaScreen({super.key, required this.correoInicial});

  @override
  State<RecuperarContrasenaScreen> createState() =>
      _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  final _correoCtrl = TextEditingController();
  String? _error;
  bool _enviado = false;

  @override
  void initState() {
    super.initState();
    _correoCtrl.text = widget.correoInicial;
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarEnlace() async {
    final correo = _correoCtrl.text.trim();
    if (correo.isEmpty ||
        !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(correo)) {
      setState(() => _error = 'Ingresa un correo válido.');
      return;
    }

    setState(() => _error = null);

    final auth = context.read<AuthController>();
    final ok = await auth.recuperarContrasena(correo);

    if (!mounted) return;

    if (ok) {
      // Mostramos el mensaje anti-enumeración M y el cooldown (ERR-07).
      setState(() => _enviado = true);
    } else {
      setState(
        () => _error = auth.errorMessage ?? 'No se pudo enviar el enlace.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      body: Stack(
        children: [
          const WaveBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // AppBar
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF5BBFBF),
                          size: 22,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ícono
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BBFBF).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: Color(0xFF5BBFBF),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título y subtítulo
                  Text(
                    'Recuperar contraseña',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa tu correo y te enviaremos un enlace para '
                    'restablecer tu contraseña.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── PASO ÚNICO: Correo ──
                  if (!_enviado) ...[
                    _inputField(
                      controller: _correoCtrl,
                      label: 'Correo electrónico',
                      icon: Icons.email_outlined,
                      keyboard: TextInputType.emailAddress,
                      errorText: _error,
                    ),
                    const SizedBox(height: 24),
                    _botonPrincipal(
                      label: 'Restablecer contraseña',
                      icon: Icons.send_rounded,
                      onTap: _enviarEnlace,
                      applyingCooldown: true,
                    ),
                  ],

                  // ── ESTADO DE ÉXITO: mensaje M + cooldown ──
                  if (_enviado) ...[
                    const Icon(
                      Icons.mark_email_read_rounded,
                      color: Color(0xFF43B89C),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '¡Listo!',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Si el correo existe, recibirás un enlace para '
                      'restablecer tu contraseña. Revisa tu correo y la '
                      'carpeta de spam.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Botón con cooldown (ERR-07): muestra "Reintentar en N s"
                    Consumer<AuthController>(
                      builder: (ctx, auth, _) {
                        final enfriando = !auth.puedeReenviarCodigo;
                        final etiqueta = enfriando
                            ? 'Reintentar en ${auth.cooldownRestante.inSeconds} s'
                            : 'Reenviar enlace';
                        return SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: enfriando ? null : _enviarEnlace,
                            icon: enfriando
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 20),
                            label: Text(
                              etiqueta,
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5BBFBF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              disabledBackgroundColor: const Color(
                                0xFF5BBFBF,
                              ).withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        );
                      },
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
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF2D2D2D)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: Colors.grey.shade500,
          fontSize: 13,
        ),
        errorText: errorText,
        errorStyle: GoogleFonts.poppins(fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF5BBFBF), size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDCEEF0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF5BBFBF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red, width: 2),
        ),
      ),
    );
  }

  Widget _botonPrincipal({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool applyingCooldown,
  }) {
    return Consumer<AuthController>(
      builder: (ctx, auth, child) {
        // ERR-07 (R3): el botón de envío respeta el cooldown
        final enfriando = applyingCooldown && !auth.puedeReenviarCodigo;
        final etiqueta = auth.isLoading
            ? 'Procesando…'
            : enfriando
            ? 'Reintentar en ${auth.cooldownRestante.inSeconds} s'
            : label;
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: (auth.isLoading || enfriando) ? null : onTap,
            icon: auth.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(icon, size: 20),
            label: Text(
              etiqueta,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5BBFBF),
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: const Color(
                0xFF5BBFBF,
              ).withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }
}
