import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../../domain/controllers/mascota_controller.dart';
import '../../../data/models/mascota_model.dart';
import '../../../presentation/widgets/safe_network_image.dart';

// ─── Paleta de colores Premium de la imagen ───────────────────────────────────
const _teal = Color(0xFF2FA3A3);       // Botón FAB, botones de acción y guardado
const _orange = Color(0xFFE58D57);     // Tag "para adoptar" y badge naranja
const _headerBg = Color(0xFFBBE7EC);   // Fondo celeste pastel de la cabecera
const _bg = Color(0xFFF6FAFA);         // Fondo general
const _dark = Color(0xFF262A2B);       // Textos principales
const _grey = Color(0xFF8A9BB0);       // Textos e íconos secundarios

class MisMascotasScreen extends StatefulWidget {
  const MisMascotasScreen({super.key});

  @override
  State<MisMascotasScreen> createState() => _MisMascotasScreenState();
}

class _MisMascotasScreenState extends State<MisMascotasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authController = context.read<AuthController>();
      final mascotaController = context.read<MascotaController>();
      if (authController.currentUser != null) {
        mascotaController.cargarMascotas(authController.currentUser!.id);
      }
    });
  }

  void _showAddMascotaSheet(BuildContext context, {MascotaModel? mascota}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMascotaSheet(mascota: mascota),
    );
  }

  void _confirmarEliminar(BuildContext context, MascotaModel mascota) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFE53935), size: 22),
          ),
          const SizedBox(width: 12),
          Text('Eliminar mascota',
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _dark)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro que deseas eliminar a ',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
            ),
            Text(
              '"${mascota.nombre}"?',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _dark),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta acción no se puede deshacer.',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFE53935),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ),
          Consumer<MascotaController>(
            builder: (context, ctrl, _) => ElevatedButton(
              onPressed: ctrl.isLoading
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final mascotaCtrl = context.read<MascotaController>();
                      final ok = await mascotaCtrl.eliminarMascota(mascota.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? '"${mascota.nombre}" eliminada correctamente'
                            : (mascotaCtrl.errorMessage ?? 'Error al eliminar')),
                        backgroundColor:
                            ok ? const Color(0xFF43B89C) : const Color(0xFFE53935),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Eliminar',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mascotaController = context.watch<MascotaController>();
    final mascotas = mascotaController.mascotas;

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMascotaSheet(context),
        backgroundColor: _teal,
        elevation: 6,
        hoverElevation: 8,
        label: Text(
          'Agregar Mascota',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Cabecera celeste con curva convexa ──
          SliverToBoxAdapter(
            child: ClipPath(
              clipper: _HeaderWaveClipper(),
              child: Container(
                height: 180,
                color: _headerBg,
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Fila con botón de retroceso y título
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _dark, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            Text(
                              'Mis Mascotas',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _dark,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48), // Equilibrar el botón de retroceso
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${mascotas.length} registradas en tu cuenta',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _dark.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Contenido de la lista ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            sliver: mascotaController.isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: _teal),
                    ),
                  )
                : mascotas.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.pets_rounded, size: 64, color: _grey.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text(
                                'No tienes mascotas registradas.',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Toca "Agregar Mascota" para registrar una.',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: _grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final mascota = mascotas[index];
                            return _buildMascotaCard(mascota);
                          },
                          childCount: mascotas.length,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMascotaCard(MascotaModel mascota) {
    final esParaAdoptar = mascota.estado.toLowerCase() == 'para adoptar';
    final esFav = context.read<MascotaController>().esFavorito(mascota.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Foto o ícono
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: mascota.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SafeNetworkImage(
                url: mascota.fotoUrl,
                borderRadius: BorderRadius.circular(16),
                fallbackIcon: mascota.icon,
                fallbackColor: mascota.color,
                fallbackIconSize: 36,
              ),
            ),
            const SizedBox(width: 14),
            // Información principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mascota.nombre,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  Text(
                    '${mascota.especie} · ${mascota.raza}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildChip(mascota.edad, Icons.cake_outlined, _teal),
                      _buildEstadoChip(mascota.estado),
                    ],
                  ),
                ],
              ),
            ),
            // Botones de acción
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Editar
                GestureDetector(
                  onTap: () => _showAddMascotaSheet(context, mascota: mascota),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_rounded, color: _teal, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                // Eliminar
                GestureDetector(
                  onTap: () => _confirmarEliminar(context, mascota),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFE53935), size: 18),
                  ),
                ),
                if (esParaAdoptar) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => context.read<MascotaController>().toggleFavorito(mascota.id),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: esFav ? const Color(0xFFFFEBEE) : _bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        esFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: esFav ? const Color(0xFFE53935) : _grey,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoChip(String estado) {
    Color color;
    switch (estado.toLowerCase()) {
      case 'para adoptar':
        color = _orange;
        break;
      case 'perdido':
        color = const Color(0xFFE53935);
        break;
      default:
        color = _teal;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
// Sheet: Agregar / Editar Mascota
// ────────────────────────────────────────────────
class _AddMascotaSheet extends StatefulWidget {
  final MascotaModel? mascota;
  const _AddMascotaSheet({this.mascota});

  @override
  State<_AddMascotaSheet> createState() => _AddMascotaSheetState();
}

class _AddMascotaSheetState extends State<_AddMascotaSheet> {
  final _nombreController = TextEditingController();
  final _razaController = TextEditingController();
  final _edadController = TextEditingController();
  final _descripcionController = TextEditingController();
  String _especie = 'Perro';
  String _genero = 'Macho';
  String _estado = 'propio';
  File? _imagenFisica;
  final ImagePicker _picker = ImagePicker();

  bool _menorDeUnAnio = false;

  @override
  void initState() {
    super.initState();
    if (widget.mascota != null) {
      final m = widget.mascota!;
      _nombreController.text = m.nombre;
      _razaController.text = m.raza;
      _descripcionController.text = m.descripcion ?? '';
      _especie = m.especie.isNotEmpty ? m.especie : 'Perro';
      _genero = m.genero.isNotEmpty ? m.genero : 'Macho';
      _estado = m.estado.isNotEmpty ? m.estado : 'propio';
      // Detectar si la edad guardada es "Menor de 1 año"
      if (m.edad.toLowerCase() == 'menor de 1 año' || m.edad == '0') {
        _menorDeUnAnio = true;
        _edadController.text = '';
      } else {
        _menorDeUnAnio = false;
        _edadController.text = m.edad;
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _razaController.dispose();
    _edadController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final extension = pickedFile.path.split('.').last.toLowerCase();
      const formatosPermitidos = ['jpg', 'jpeg', 'png', 'webp'];
      if (!formatosPermitidos.contains(extension)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Formato no permitido: .$extension\nSolo se aceptan: JPG, JPEG, PNG, WEBP',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      setState(() {
        _imagenFisica = File(pickedFile.path);
      });
    }
  }

  void _guardarMascota() async {
    final mascotaController = context.read<MascotaController>();
    final authController = context.read<AuthController>();
    final usuarioId = authController.currentUser?.id;

    if (usuarioId == null) return;

    if (_nombreController.text.trim().isEmpty ||
        _razaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa los campos requeridos.')),
      );
      return;
    }

    // Calcular la edad según si es menor de un año o no
    final String edadFinal;
    if (_menorDeUnAnio) {
      edadFinal = 'Menor de 1 año';
    } else {
      if (_edadController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, completa los campos requeridos.')),
        );
        return;
      }
      final edadVal = int.tryParse(_edadController.text.trim());
      if (edadVal == null || edadVal < 0 || edadVal > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La edad debe ser un número entre 1 y 100.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      edadFinal = _edadController.text.trim();
    }

    String? fotoUrl = widget.mascota?.fotoUrl;
    if (_imagenFisica != null) {
      final ext = _imagenFisica!.path.split('.').last.toLowerCase();
      final controller = context.read<MascotaController>();
      fotoUrl = await controller.subirImagenMascota(_imagenFisica!, ext);

      if (!mounted) return;

      if (fotoUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.errorMessage ?? 'Error al subir la imagen'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    final nuevaMascota = MascotaModel(
      id: widget.mascota?.id ?? '',
      usuarioId: usuarioId,
      nombre: _nombreController.text.trim(),
      especie: _especie,
      raza: _razaController.text.trim(),
      genero: _genero,
      edad: edadFinal,
      estado: _estado,
      descripcion: (_estado == 'para adoptar' || _estado == 'perdido') ? _descripcionController.text.trim() : null,
      fotoUrl: fotoUrl,
    );

    bool success;
    if (widget.mascota != null) {
      success = await mascotaController.actualizarMascota(nuevaMascota);
    } else {
      success = await mascotaController.agregarMascota(nuevaMascota);
    }

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.mascota != null
              ? 'Mascota actualizada correctamente'
              : 'Mascota registrada exitosamente'),
          backgroundColor: _teal,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mascotaController.errorMessage ?? 'Error al guardar'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mascotaController = context.watch<MascotaController>();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                widget.mascota != null ? 'Editar Mascota' : 'Añadir Mascota',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 20),

              _buildInputField('Nombre de la mascota', _nombreController, Icons.pets_rounded),
              const SizedBox(height: 14),

              _buildDropdown('Especie', _especie, ['Perro', 'Gato', 'Conejo', 'Ave', 'Otro'],
                  (val) => setState(() => _especie = val!)),
              const SizedBox(height: 14),

              _buildInputField('Raza', _razaController, Icons.category_outlined),
              const SizedBox(height: 14),

              // ── Campo Edad con opción "Menor de 1 año" ──
              _buildEdadField(),
              const SizedBox(height: 14),

              _buildDropdown('Género', _genero, ['Macho', 'Hembra'],
                  (val) => setState(() => _genero = val!)),
              const SizedBox(height: 14),

              _buildDropdown('Estado', _estado, ['propio', 'para adoptar', 'perdido'],
                  (val) => setState(() => _estado = val!)),
              const SizedBox(height: 14),

              if (_estado == 'para adoptar' || _estado == 'perdido') ...[
                _buildInputField(
                    _estado == 'perdido'
                        ? 'Descripción (ej. lugar donde se perdió)'
                        : 'Descripción para adopción',
                    _descripcionController,
                    Icons.description_outlined),
                const SizedBox(height: 14),
              ],

              Text('Foto de la mascota',
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _seleccionarImagen,
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3FAFD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDCEEF0), width: 1.2),
                  ),
                  child: _imagenFisica != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_imagenFisica!, fit: BoxFit.cover),
                        )
                      : (widget.mascota?.fotoUrl != null &&
                              widget.mascota!.fotoUrl!.isNotEmpty)
                          ? SafeNetworkImage(
                              url: widget.mascota!.fotoUrl,
                              borderRadius: BorderRadius.circular(14),
                              fallbackIcon: Icons.pets_rounded,
                              fallbackColor: const Color(0xFF1CB5C9),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate_outlined,
                                    color: _teal, size: 36),
                                const SizedBox(height: 8),
                                Text('Toca para subir una imagen',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: _teal)),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: mascotaController.isLoading ? null : _guardarMascota,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: mascotaController.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          widget.mascota != null ? 'Guardar Cambios' : 'Registrar Mascota',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEdadField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox: Menor de 1 año
        GestureDetector(
          onTap: () => setState(() {
            _menorDeUnAnio = !_menorDeUnAnio;
            if (_menorDeUnAnio) _edadController.clear();
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _menorDeUnAnio
                  ? _teal.withValues(alpha: 0.08)
                  : const Color(0xFFF3FAFD),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _menorDeUnAnio ? _teal : const Color(0xFFDCEEF0),
                width: _menorDeUnAnio ? 1.8 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _menorDeUnAnio
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  color: _menorDeUnAnio ? _teal : _grey,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Menor de 1 año',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _menorDeUnAnio ? _teal : const Color(0xFF2D2D2D),
                    fontWeight: _menorDeUnAnio ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const Spacer(),
                Icon(Icons.cake_outlined,
                    color: _menorDeUnAnio ? _teal : _grey, size: 20),
              ],
            ),
          ),
        ),
        // Campo numérico — solo si no es menor de 1 año
        if (!_menorDeUnAnio) ...[
          const SizedBox(height: 10),
          _buildInputField(
            'Edad en años (ej. 3)',
            _edadController,
            Icons.cake_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _MaxValueFormatter(100),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF2D2D2D)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
        prefixIcon: Icon(icon, color: _teal, size: 20),
        filled: true,
        fillColor: const Color(0xFFF3FAFD),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDCEEF0), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _teal, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown(
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
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFFDCEEF0), width: 1.2),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
        ),
        style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF2D2D2D)),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _MaxValueFormatter extends TextInputFormatter {
  final int max;
  _MaxValueFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final val = int.tryParse(newValue.text);
    if (val == null || val > max) return oldValue;
    return newValue;
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
