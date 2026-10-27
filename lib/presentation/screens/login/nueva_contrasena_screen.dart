// nueva_contrasena_screen.dart — Pantalla para establecer nueva contraseña tras
// recuperación por enlace (RST-10).
//
// Composición: dos campos de contraseña + botón guardar.
// Validación local: ≥6 caracteres y coincidencia.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../widgets/wave_background.dart';

/// Pantalla para establecer nueva contraseña usando la sesión de recuperación activa.
/// Dos campos: nueva contraseña + confirmar, con validación local.
class NuevaContrasenaScreen extends StatefulWidget {
  const NuevaContrasenaScreen({super.key});

  @override
  State<NuevaContrasenaScreen> createState() => _NuevaContrasenaScreenState();
}

class _NuevaContrasenaScreenState extends State<NuevaContrasenaScreen> {
  final _nuevaPassCtrl = TextEditingController();
  final _confirmarPassCtrl = TextEditingController();
  bool _obscureNueva = true;
  bool _obscureConfirmar = true;
  String? _error;

  @override
  void dispose() {
    _nuevaPassCtrl.dispose();
    _confirmarPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nueva = _nuevaPassCtrl.text;
    final confirmar = _confirmarPassCtrl.text;

    // Validación local: ≥6 caracteres
    if (nueva.length < 6) {
      setState(
        () => _error = 'La contraseña debe tener al menos 6 caracteres.',
      );
      return;
    }

    // Validación local: coincidencia
    if (nueva != confirmar) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() => _error = null);

    final auth = context.read<AuthController>();
    final ok = await auth.restablecerContrasena(nueva);

    if (!mounted) return;

    if (ok) {
      // Éxito: SnackBar + el controlador hace signOut → Consumer raíz navega a /login
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                '¡Contraseña actualizada correctamente!',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF43B89C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      setState(
        () => _error =
            auth.errorMessage ?? 'No se pudo actualizar la contraseña.',
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
                      Icons.lock_outline_rounded,
                      color: Color(0xFF5BBFBF),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título
                  Text(
                    'Nueva contraseña',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa tu nueva contraseña y confírmala.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Campo: Nueva contraseña
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
                    errorText: _error,
                  ),
                  const SizedBox(height: 16),

                  // Campo: Confirmar contraseña
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
                        () => _obscureConfirmar = !_obscureConfirmar,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botón guardar
                  Consumer<AuthController>(
                    builder: (ctx, auth, _) {
                      return SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _guardar,
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
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  'Guardar',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),

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
    bool obscure = false,
    Widget? suffixIcon,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
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
        suffixIcon: suffixIcon,
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
          borderSide: const BorderSide(color: Color(0xFFE57373), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE57373), width: 2),
        ),
      ),
    );
  }
}
