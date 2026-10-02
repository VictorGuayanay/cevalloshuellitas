import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../domain/controllers/auth_controller.dart';

/// Sheet reutilizable para cambiar la contraseña del usuario autenticado.
///
/// Usa [AuthController.cambiarContrasena] internamente.
/// El color del botón se puede personalizar con [accentColor].
///
/// Uso:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => const CambiarContrasenaSheet(),
/// );
/// ```
class CambiarContrasenaSheet extends StatefulWidget {
  final Color accentColor;

  const CambiarContrasenaSheet({
    super.key,
    this.accentColor = const Color(0xFF5BBFBF),
  });

  @override
  State<CambiarContrasenaSheet> createState() => _CambiarContrasenaSheetState();
}

class _CambiarContrasenaSheetState extends State<CambiarContrasenaSheet> {
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
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
                Text(
                  'Cambiar Contraseña',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkAlt,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ingresa tu nueva contraseña',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 20),

                _passwordField(
                  controller: _passCtrl,
                  label: 'Nueva contraseña',
                  obscure: _obscurePass,
                  onToggle: () =>
                      setState(() => _obscurePass = !_obscurePass),
                  accentColor: widget.accentColor,
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 14),
                _passwordField(
                  controller: _confirmCtrl,
                  label: 'Confirmar contraseña',
                  obscure: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  accentColor: widget.accentColor,
                  validator: (v) =>
                      v != _passCtrl.text ? 'Las contraseñas no coinciden' : null,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: Consumer<AuthController>(
                    builder: (ctx, auth, _) => ElevatedButton(
                      onPressed: auth.isLoading ? null : () async {
                        if (!_formKey.currentState!.validate()) return;
                        final ok =
                            await auth.cambiarContrasena(_passCtrl.text);
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    '¡Contraseña actualizada correctamente!')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(auth.errorMessage ??
                                    'Error al cambiar contraseña')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              'Actualizar contraseña',
                              style: GoogleFonts.poppins(
                                  fontSize: 16, fontWeight: FontWeight.w600),
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

// ── Campo de contraseña con toggle de visibilidad ────────────────────────────
Widget _passwordField({
  required TextEditingController controller,
  required String label,
  required bool obscure,
  required VoidCallback onToggle,
  required Color accentColor,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: controller,
    obscureText: obscure,
    validator: validator,
    style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF2D2D2D)),
    decoration: InputDecoration(
      labelText: label,
      labelStyle:
          GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
      prefixIcon:
          Icon(Icons.lock_outline_rounded, color: accentColor, size: 20),
      suffixIcon: IconButton(
        icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey.shade400,
            size: 20),
        onPressed: onToggle,
      ),
      filled: true,
      fillColor: const Color(0xFFF3FAFD),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFDCEEF0), width: 1.2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor, width: 2)),
    ),
  );
}
