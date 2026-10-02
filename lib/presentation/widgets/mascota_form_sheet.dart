import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../data/models/mascota_model.dart';
import '../../domain/controllers/auth_controller.dart';
import '../../domain/controllers/mascota_controller.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/common_widgets.dart';

/// Sheet reutilizable para agregar o editar una mascota.
///
/// Parámetros:
/// - [mascota]: si se pasa, el formulario se abre en modo edición.
/// - [tituloEditar]: texto del título cuando se edita (default 'Editar Mascota').
/// - [tituloAgregar]: texto del título cuando se agrega (default 'Añadir Mascota').
/// - [labelGuardar]: texto del botón en modo agregar (default 'Registrar Mascota').
/// - [accentColor]: color del botón y acentos (default AppColors.tealLight).
/// - [onGuardado]: callback opcional que se ejecuta después de guardar con éxito.
///
/// Uso:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => const MascotaFormSheet(),
/// );
/// ```
class MascotaFormSheet extends StatefulWidget {
  final MascotaModel? mascota;
  final String tituloEditar;
  final String tituloAgregar;
  final String labelGuardar;
  final Color accentColor;
  final VoidCallback? onGuardado;

  const MascotaFormSheet({
    super.key,
    this.mascota,
    this.tituloEditar = 'Editar Mascota',
    this.tituloAgregar = 'Añadir Mascota',
    this.labelGuardar = 'Registrar Mascota',
    this.accentColor = const Color(0xFF5BBFBF),
    this.onGuardado,
  });

  @override
  State<MascotaFormSheet> createState() => _MascotaFormSheetState();
}

class _MascotaFormSheetState extends State<MascotaFormSheet> {
  final _nombreCtrl        = TextEditingController();
  final _razaCtrl          = TextEditingController();
  final _edadCtrl          = TextEditingController();
  final _descripcionCtrl   = TextEditingController();
  final _rasgoCtrl         = TextEditingController();
  final _colorCtrl         = TextEditingController();
  final _pesoCtrl          = TextEditingController();
  final _picker            = ImagePicker();

  String  _especie        = 'Perro';
  String  _genero         = 'Macho';
  String  _estado         = 'propio';
  String  _tamano         = 'Mediano';
  bool?   _esterilizado;
  bool    _menorDeUnAnio  = false;
  File?   _imagenFisica;

  @override
  void initState() {
    super.initState();
    final m = widget.mascota;
    if (m != null) {
      _nombreCtrl.text      = m.nombre;
      _razaCtrl.text        = m.raza;
      _descripcionCtrl.text = m.descripcion ?? '';
      _rasgoCtrl.text       = m.rasgoDistintivo ?? '';
      _colorCtrl.text       = m.colorMascota ?? '';
      _pesoCtrl.text        = m.peso ?? '';
      _especie = m.especie.isNotEmpty ? m.especie : 'Perro';
      _genero  = m.genero.isNotEmpty  ? m.genero  : 'Macho';
      _estado  = m.estado.isNotEmpty  ? m.estado  : 'propio';
      _tamano  = (m.tamano?.isNotEmpty == true) ? m.tamano! : 'Mediano';
      _esterilizado = m.esterilizado;
      if (m.edad.toLowerCase() == 'menor de 1 año' || m.edad == '0') {
        _menorDeUnAnio = true;
      } else {
        _edadCtrl.text = m.edad;
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _razaCtrl.dispose();
    _edadCtrl.dispose();
    _descripcionCtrl.dispose();
    _rasgoCtrl.dispose();
    _colorCtrl.dispose();
    _pesoCtrl.dispose();
    super.dispose();
  }

  // ── Imagen ────────────────────────────────────────────────────────────────

  Future<void> _seleccionarImagen() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final ext = picked.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Formato .$ext no permitido. Usa JPG, PNG o WEBP.'),
          backgroundColor: Colors.redAccent,
        ));
      }
      return;
    }
    setState(() => _imagenFisica = File(picked.path));
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  void _guardar() async {
    final mascotaCtrl = context.read<MascotaController>();
    final authCtrl    = context.read<AuthController>();
    final uid         = authCtrl.currentUser?.id;
    if (uid == null) return;

    if (_nombreCtrl.text.trim().isEmpty || _razaCtrl.text.trim().isEmpty) {
      _snack('Nombre y raza son obligatorios.');
      return;
    }

    final String edadFinal;
    if (_menorDeUnAnio) {
      edadFinal = 'Menor de 1 año';
    } else {
      if (_edadCtrl.text.trim().isEmpty) {
        _snack('Ingresa la edad de la mascota.');
        return;
      }
      final edadVal = int.tryParse(_edadCtrl.text.trim());
      if (edadVal == null || edadVal < 1 || edadVal > 100) {
        _snack('La edad debe ser un número entre 1 y 100.',
            color: Colors.redAccent);
        return;
      }
      edadFinal = _edadCtrl.text.trim();
    }

    String? fotoUrl = widget.mascota?.fotoUrl;
    if (_imagenFisica != null) {
      final ext = _imagenFisica!.path.split('.').last.toLowerCase();
      fotoUrl = await mascotaCtrl.subirImagenMascota(_imagenFisica!, ext);
      if (!mounted) return;
      if (fotoUrl == null) {
        _snack(mascotaCtrl.errorMessage ?? 'Error al subir la imagen',
            color: Colors.redAccent);
        return;
      }
    }

    final mascota = MascotaModel(
      id:               widget.mascota?.id ?? '',
      usuarioId:        uid,
      nombre:           _nombreCtrl.text.trim(),
      especie:          _especie,
      raza:             _razaCtrl.text.trim(),
      genero:           _genero,
      edad:             edadFinal,
      estado:           _estado,
      descripcion: _estado == 'perdido'
          ? _descripcionCtrl.text.trim()
          : null,
      fotoUrl:          fotoUrl,
      rasgoDistintivo:  _rasgoCtrl.text.trim().isEmpty ? null : _rasgoCtrl.text.trim(),
      colorMascota:     _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
      tamano:           _tamano,
      peso:             _pesoCtrl.text.trim().isEmpty ? null : _pesoCtrl.text.trim(),
      esterilizado:     _esterilizado,
    );

    final bool ok;
    if (widget.mascota != null) {
      ok = await mascotaCtrl.actualizarMascota(mascota);
    } else {
      ok = await mascotaCtrl.agregarMascota(mascota);
    }

    if (!mounted) return;

    if (ok) {
      // Recargar la lista del usuario actual
      await mascotaCtrl.cargarMascotas(uid);
      if (!mounted) return;
      widget.onGuardado?.call();
      Navigator.pop(context);
      _snack(
        widget.mascota != null
            ? 'Mascota actualizada correctamente'
            : '¡Mascota registrada exitosamente!',
        color: widget.accentColor,
      );
    } else {
      _snack(mascotaCtrl.errorMessage ?? 'Error al guardar',
          color: Colors.redAccent);
    }
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MascotaController>();
    final esEdicion = widget.mascota != null;

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28),
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
                esEdicion ? widget.tituloEditar : widget.tituloAgregar,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkAlt,
                ),
              ),
              const SizedBox(height: 20),

              _field('Nombre de la mascota', _nombreCtrl, Icons.pets_rounded),
              const SizedBox(height: 14),
              _dropdown('Especie', _especie,
                  ['Perro', 'Gato', 'Conejo', 'Ave', 'Reptil', 'Otro'],
                  (v) => setState(() => _especie = v!)),
              const SizedBox(height: 14),
              _field('Raza', _razaCtrl, Icons.category_outlined),
              const SizedBox(height: 14),
              _edadField(),
              const SizedBox(height: 14),
              _dropdown('Género', _genero, ['Macho', 'Hembra'],
                  (v) => setState(() => _genero = v!)),
              const SizedBox(height: 14),
              _dropdown('Estado', _estado,
                  ['propio', 'perdido'],
                  (v) => setState(() => _estado = v!)),
              const SizedBox(height: 14),

              if (_estado == 'perdido') ...[
                _field(
                  'Descripción (ej. lugar donde se perdió)',
                  _descripcionCtrl,
                  Icons.description_outlined,
                ),
                const SizedBox(height: 14),
              ],

              // ── Nuevos campos ──────────────────────────────────────────────
              _field('Color (ej. negro con blanco)', _colorCtrl,
                  Icons.palette_outlined),
              const SizedBox(height: 14),
              _dropdown(
                'Tamaño',
                _tamano,
                ['Pequeño', 'Mediano', 'Grande', 'Extra grande'],
                (v) => setState(() => _tamano = v!),
              ),
              const SizedBox(height: 14),
              _field('Peso (kg, ej. 4.5)', _pesoCtrl,
                  Icons.monitor_weight_outlined,
                  keyboard: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 14),
              _field('Rasgos distintivos (ej. mancha ojo izq.)', _rasgoCtrl,
                  Icons.remove_red_eye_outlined),
              const SizedBox(height: 14),
              _esterilizadoField(),
              const SizedBox(height: 14),

              // Foto
              Text('Foto de la mascota',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _seleccionarImagen,
                child: Container(
                  height: 130, width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3FAFD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFDCEEF0), width: 1.2),
                  ),
                  child: _fotoWidget(),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: ctrl.isLoading ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: ctrl.isLoading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          esEdicion ? 'Guardar Cambios' : widget.labelGuardar,
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets helpers ───────────────────────────────────────────────────────

  Widget _fotoWidget() {
    if (_imagenFisica != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.file(_imagenFisica!, fit: BoxFit.cover),
      );
    }
    final url = widget.mascota?.fotoUrl;
    if (url != null && url.isNotEmpty) {
      return SafeNetworkImage(
        url: url,
        borderRadius: BorderRadius.circular(14),
        fallbackIcon: Icons.pets_rounded,
        fallbackColor: widget.accentColor,
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            color: widget.accentColor, size: 34),
        const SizedBox(height: 8),
        Text('Toca para subir una imagen',
            style: GoogleFonts.poppins(
                fontSize: 12, color: widget.accentColor)),
      ],
    );
  }

  Widget _edadField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _menorDeUnAnio = !_menorDeUnAnio;
            if (_menorDeUnAnio) _edadCtrl.clear();
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _menorDeUnAnio
                  ? widget.accentColor.withValues(alpha: 0.08)
                  : const Color(0xFFF3FAFD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _menorDeUnAnio
                    ? widget.accentColor
                    : const Color(0xFFDCEEF0),
                width: _menorDeUnAnio ? 1.8 : 1.2,
              ),
            ),
            child: Row(children: [
              Icon(
                _menorDeUnAnio
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: _menorDeUnAnio ? widget.accentColor : AppColors.grey,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Menor de 1 año',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _menorDeUnAnio
                      ? widget.accentColor
                      : const Color(0xFF2D2D2D),
                  fontWeight: _menorDeUnAnio
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
              const Spacer(),
              Icon(Icons.cake_outlined,
                  color: _menorDeUnAnio ? widget.accentColor : AppColors.grey,
                  size: 20),
            ]),
          ),
        ),
        if (!_menorDeUnAnio) ...[
          const SizedBox(height: 10),
          _field('Edad en años (ej. 3)', _edadCtrl, Icons.cake_outlined,
              keyboard: TextInputType.number,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                _MaxValueFormatter(100),
              ]),
        ],
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: formatters,
      style: GoogleFonts.poppins(
          fontSize: 14, color: const Color(0xFF2D2D2D)),
      decoration: appInputDeco(label, icon, accentColor: widget.accentColor),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCEEF0), width: 1.2),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: GoogleFonts.poppins(
              color: Colors.grey.shade500, fontSize: 13),
        ),
        style: GoogleFonts.poppins(
            fontSize: 14, color: const Color(0xFF2D2D2D)),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _esterilizadoField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3FAFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCEEF0), width: 1.2),
      ),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.medical_services_outlined,
              color: widget.accentColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('¿Está esterilizado/a?',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: const Color(0xFF2D2D2D))),
        ),
        _esterilizadoBtn('Sí', true),
        _esterilizadoBtn('No', false),
        _esterilizadoBtn('N/A', null),
        const SizedBox(width: 8),
      ]),
    );
  }

  Widget _esterilizadoBtn(String label, bool? value) {
    final selected = _esterilizado == value;
    return GestureDetector(
      onTap: () => setState(() => _esterilizado = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? widget.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.grey,
          ),
        ),
      ),
    );
  }
}

// ── Validador de rango para el campo edad ────────────────────────────────────
class _MaxValueFormatter extends TextInputFormatter {
  final int max;
  const _MaxValueFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final val = int.tryParse(newValue.text);
    if (val == null || val > max) return oldValue;
    return newValue;
  }
}
