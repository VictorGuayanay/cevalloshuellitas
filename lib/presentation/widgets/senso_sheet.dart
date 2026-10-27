import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../data/models/senso_model.dart';
import '../../data/services/senso_service.dart';
import '../../domain/controllers/auth_controller.dart';

/// Abre el sheet de registro del censo pecuario.
void mostrarSensoSheet(BuildContext context) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AuthController>(),
      child: const _SensoSheet(),
    ),
  );
}

// ── Colores de acento para Senso ─────────────────────────────────────────────
const _accentColor = Color(0xFF4A9B7F); // verde pecuario
const _accentBg = Color(0xFFF0FAF6);

class _SensoSheet extends StatefulWidget {
  const _SensoSheet();

  @override
  State<_SensoSheet> createState() => _SensoSheetState();
}

class _SensoSheetState extends State<_SensoSheet> {
  final _especieCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _produccion = 'menores'; // "menores" | "mayores"
  String _alimentacion = 'mixto'; // "balanceado" | "mixto" | "natural"
  String _destinacion = 'consumo'; // "consumo" | "venta" | "ambos"
  bool _guardando = false;

  // Especies sugeridas por tipo
  static const _especiesMenores = [
    'Cerdos',
    'Gallinas',
    'Patos',
    'Cuyes',
    'Conejos',
    'Codornices',
    'Pavos',
    'Ovejas',
    'Cabras',
  ];
  static const _especiesMayores = [
    'Bovinos (vacas)',
    'Caballos',
    'Mulas',
    'Asnos',
    'Búfalos',
    'Llamas',
    'Alpacas',
  ];

  List<String> get _especiesSugeridas =>
      _produccion == 'menores' ? _especiesMenores : _especiesMayores;

  @override
  void dispose() {
    _especieCtrl.dispose();
    _numeroCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = context.read<AuthController>().currentUser?.id;
    if (uid == null) {
      _mostrarError(
        'No hay sesión activa. Por favor cierra y vuelve a abrir la app.',
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final senso = SensoModel(
        usuarioId: uid,
        produccion: _produccion,
        especie: _especieCtrl.text.trim(),
        numeroAnimales: int.tryParse(_numeroCtrl.text.trim()) ?? 0,
        alimentacion: _alimentacion,
        destinacion: _destinacion,
      );

      await SensoService().crearSenso(senso);

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '¡Censo registrado correctamente!',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ],
          ),
          backgroundColor: _accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      final msg = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('exception: ', '');
      _mostrarError(msg);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $msg', style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Encabezado
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accentBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _accentColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.agriculture_rounded,
                          color: _accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registro de Censo',
                              style: GoogleFonts.poppins(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkAlt,
                              ),
                            ),
                            Text(
                              'Censo Pecuario',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: _accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppColors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // ── 1. Producción de especies ──────────────────────────
                  _sectionLabel('1. Producción de especies'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _toggleBtn(
                          label: 'Animales Menores',
                          icon: Icons.cruelty_free_rounded,
                          selected: _produccion == 'menores',
                          onTap: () => setState(() {
                            _produccion = 'menores';
                            _especieCtrl.clear();
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _toggleBtn(
                          label: 'Animales Mayores',
                          icon: Icons.set_meal_rounded,
                          selected: _produccion == 'mayores',
                          onTap: () => setState(() {
                            _produccion = 'mayores';
                            _especieCtrl.clear();
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── 2. Especie / tipo de animal ────────────────────────
                  _sectionLabel('2. Especie (tipo de animal)'),
                  const SizedBox(height: 8),
                  // Chips de sugerencias
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _especiesSugeridas.map((e) {
                      final sel = _especieCtrl.text == e;
                      return GestureDetector(
                        onTap: () => setState(() => _especieCtrl.text = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 130),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: sel ? _accentColor : _accentBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? _accentColor
                                  : _accentColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            e,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : _accentColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  // Campo de texto libre
                  TextFormField(
                    controller: _especieCtrl,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.darkAlt,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa la especie o tipo de animal'
                        : null,
                    decoration: _inputDeco(
                      'O escribe la especie aquí...',
                      Icons.pets_rounded,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 3. Número de animales promedio ─────────────────────
                  _sectionLabel('3. Número de animales promedio'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _numeroCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.darkAlt,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingresa el número de animales';
                      }
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 1) {
                        return 'Debe ser un número mayor a 0';
                      }
                      return null;
                    },
                    decoration: _inputDeco(
                      'Ej. 25',
                      Icons.format_list_numbered_rounded,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── 4. Alimentación y nutrición ────────────────────────
                  _sectionLabel('4. Alimentación y nutrición'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _toggleBtn(
                          label: 'Balanceado',
                          icon: Icons.inventory_2_outlined,
                          selected: _alimentacion == 'balanceado',
                          onTap: () =>
                              setState(() => _alimentacion = 'balanceado'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _toggleBtn(
                          label: 'Mixto',
                          icon: Icons.blender_outlined,
                          selected: _alimentacion == 'mixto',
                          onTap: () => setState(() => _alimentacion = 'mixto'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _toggleBtn(
                          label: 'Natural',
                          icon: Icons.eco_outlined,
                          selected: _alimentacion == 'natural',
                          onTap: () =>
                              setState(() => _alimentacion = 'natural'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── 5. Consumo o venta ─────────────────────────────────
                  _sectionLabel('5. Consumo o venta'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _toggleBtn(
                          label: 'Consumo',
                          icon: Icons.home_rounded,
                          selected: _destinacion == 'consumo',
                          onTap: () => setState(() => _destinacion = 'consumo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _toggleBtn(
                          label: 'Venta',
                          icon: Icons.store_rounded,
                          selected: _destinacion == 'venta',
                          onTap: () => setState(() => _destinacion = 'venta'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _toggleBtn(
                          label: 'Ambos',
                          icon: Icons.swap_horiz_rounded,
                          selected: _destinacion == 'ambos',
                          onTap: () => setState(() => _destinacion = 'ambos'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Botón guardar ──────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 20),
                      label: Text(
                        _guardando ? 'Guardando...' : 'Registrar Censo',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        disabledBackgroundColor: _accentColor.withValues(
                          alpha: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.darkAlt,
      ),
    );
  }

  Widget _toggleBtn({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? _accentColor : _accentBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _accentColor
                : _accentColor.withValues(alpha: 0.25),
            width: selected ? 1.8 : 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? Colors.white : _accentColor),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(icon, color: _accentColor, size: 20),
      filled: true,
      fillColor: _accentBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _accentColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red, width: 2),
      ),
    );
  }
}
