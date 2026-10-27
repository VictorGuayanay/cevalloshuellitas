import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../domain/controllers/admin_controller.dart';
import '../../../../domain/controllers/auth_controller.dart';
import '../../../../data/models/noticia_model.dart';
import '../../../widgets/header_wave_clipper.dart';

class AdminNoticiasTab extends StatefulWidget {
  const AdminNoticiasTab({super.key});

  @override
  State<AdminNoticiasTab> createState() => _AdminNoticiasTabState();
}

class _AdminNoticiasTabState extends State<AdminNoticiasTab>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _filtros = ['Todas', 'Pendientes', 'Publicadas', 'Rechazadas'];
  static const _estados = ['', 'pendiente', 'publicada', 'rechazada'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _filtros.length, vsync: this);
    _tab.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminController>().cargarNoticiasPendientes();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<NoticiaModel> _filtradas(List<NoticiaModel> todas) {
    final estado = _estados[_tab.index];
    if (estado.isEmpty) return todas;
    return todas.where((n) => n.estado == estado).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminController>();
    final todas = ctrl.todasLasNoticias;
    final lista = _filtradas(todas);
    final pendientes = todas.where((n) => n.estado == 'pendiente').length;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormNoticia(context),
        backgroundColor: AppColors.tealLight,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Nueva noticia',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Cabecera ────────────────────────────────────────────────
          ClipPath(
            clipper: HeaderWaveClipper(),
            child: Container(
              height: 160,
              color: AppColors.tealBg,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Noticias',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkAlt,
                            ),
                          ),
                          Text(
                            '${todas.length} en total · $pendientes pendientes',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: pendientes > 0
                                  ? AppColors.orange
                                  : AppColors.darkAlt.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Tabs de filtro ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicator: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.grey,
              labelStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              padding: EdgeInsets.zero,
              tabs: List.generate(_filtros.length, (i) {
                final count = _estados[i].isEmpty
                    ? todas.length
                    : todas.where((n) => n.estado == _estados[i]).length;
                return Tab(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_filtros[i]),
                        if (count > 0) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _tab.index == i
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : AppColors.tealLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),

          // ── Lista ───────────────────────────────────────────────────
          Expanded(
            child: ctrl.cargandoNoticias
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.tealLight,
                    ),
                  )
                : lista.isEmpty
                ? _EmptyState(filtro: _filtros[_tab.index])
                : RefreshIndicator(
                    color: AppColors.tealLight,
                    onRefresh: () => ctrl.cargarNoticiasPendientes(),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: lista.length,
                      itemBuilder: (ctx, i) => _NoticiaCard(noticia: lista[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _abrirFormNoticia(BuildContext context, {NoticiaModel? noticia}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AdminController>(),
        child: _NoticiaFormSheet(noticia: noticia),
      ),
    );
  }
}

// ── Tarjeta de noticia ────────────────────────────────────────────────────────
class _NoticiaCard extends StatefulWidget {
  final NoticiaModel noticia;
  const _NoticiaCard({required this.noticia});

  @override
  State<_NoticiaCard> createState() => _NoticiaCardState();
}

class _NoticiaCardState extends State<_NoticiaCard> {
  bool _expandida = false;
  bool _procesando = false;

  static const Map<String, Color> _catColores = {
    'salud': AppColors.vetGreen,
    'perdidos': AppColors.red,
    'adopcion': AppColors.orange,
    'nutricion': AppColors.orange,
    'bienestar': AppColors.purple,
    'prevencion': AppColors.tealLight,
    'emergencias': AppColors.red,
  };

  Color get _catColor =>
      _catColores[widget.noticia.categoria.toLowerCase()] ??
      AppColors.tealLight;

  Color get _estadoColor {
    switch (widget.noticia.estado) {
      case 'publicada':
        return AppColors.green;
      case 'rechazada':
        return AppColors.red;
      default:
        return AppColors.orange;
    }
  }

  String get _estadoLabel {
    switch (widget.noticia.estado) {
      case 'publicada':
        return 'Publicada';
      case 'rechazada':
        return 'Rechazada';
      default:
        return 'Pendiente';
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _cambiarEstado(String estado) async {
    setState(() => _procesando = true);
    final ctrl = context.read<AdminController>();
    bool ok;
    if (estado == 'publicada') {
      ok = await ctrl.publicarNoticia(widget.noticia.id);
    } else {
      ok = await ctrl.rechazarNoticia(widget.noticia.id);
    }
    if (mounted) {
      setState(() => _procesando = false);
      _snack(
        ok
            ? (estado == 'publicada'
                  ? '✅ Noticia publicada'
                  : 'Noticia rechazada')
            : '❌ Error al actualizar',
        ok
            ? (estado == 'publicada' ? AppColors.green : AppColors.grey)
            : AppColors.red,
      );
    }
  }

  Future<void> _eliminar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          '¿Eliminar noticia?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Esta acción no se puede deshacer.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: AppColors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              elevation: 0,
            ),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _procesando = true);
    final ok = await context.read<AdminController>().eliminarNoticia(
      widget.noticia.id,
    );
    if (mounted) {
      setState(() => _procesando = false);
      _snack(
        ok ? 'Noticia eliminada' : '❌ Error al eliminar',
        ok ? AppColors.grey : AppColors.red,
      );
    }
  }

  void _editar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<AdminController>(),
        child: _NoticiaFormSheet(noticia: widget.noticia),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.noticia;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _catColor.withValues(alpha: 0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n.imagenUrl != null && n.imagenUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Image.network(
                n.imagenUrl!,
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _catColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        n.categoria.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _catColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _estadoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _estadoLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _estadoColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Editar
                    IconButton(
                      onPressed: _procesando ? null : _editar,
                      icon: const Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: AppColors.tealLight,
                      ),
                      tooltip: 'Editar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    // Eliminar
                    IconButton(
                      onPressed: _procesando ? null : _eliminar,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.red,
                      ),
                      tooltip: 'Eliminar',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Text(
                  n.titulo,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkAlt,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),

                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  firstChild: Text(
                    n.contenido,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.grey,
                      height: 1.5,
                    ),
                  ),
                  secondChild: Text(
                    n.contenido,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.grey,
                      height: 1.5,
                    ),
                  ),
                  crossFadeState: _expandida
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                ),
                GestureDetector(
                  onTap: () => setState(() => _expandida = !_expandida),
                  child: Text(
                    _expandida ? 'Ver menos' : 'Ver más',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.tealLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                if (n.autorNombre != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 12,
                        color: AppColors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        n.autorNombre!,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.grey,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        n.tiempoRelativo,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ],

                // Acciones solo para pendientes
                if (n.estado == 'pendiente') ...[
                  const SizedBox(height: 12),
                  _procesando
                      ? const Center(
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.tealLight,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _cambiarEstado('rechazada'),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: AppColors.red,
                                ),
                                label: Text(
                                  'Rechazar',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.red,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.red.withValues(alpha: 0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _cambiarEstado('publicada'),
                                icon: const Icon(
                                  Icons.publish_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Publicar',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.tealLight,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Formulario crear / editar noticia ─────────────────────────────────────────
class _NoticiaFormSheet extends StatefulWidget {
  final NoticiaModel? noticia;
  const _NoticiaFormSheet({this.noticia});

  @override
  State<_NoticiaFormSheet> createState() => _NoticiaFormSheetState();
}

class _NoticiaFormSheetState extends State<_NoticiaFormSheet> {
  final _tituloCtrl = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  final _imagenCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _categoria = 'general';
  bool _guardando = false;

  static const _categorias = [
    'general',
    'salud',
    'nutricion',
    'bienestar',
    'prevencion',
    'adopcion',
    'perdidos',
    'emergencias',
  ];

  bool get _esEdicion => widget.noticia != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final n = widget.noticia!;
      _tituloCtrl.text = n.titulo;
      _contenidoCtrl.text = n.contenido;
      _imagenCtrl.text = n.imagenUrl ?? '';
      _categoria = n.categoria;
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _contenidoCtrl.dispose();
    _imagenCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final ctrl = context.read<AdminController>();
    final autorId = context.read<AuthController>().currentUser?.id ?? '';
    bool ok;

    if (_esEdicion) {
      ok = await ctrl.editarNoticia(
        noticiaId: widget.noticia!.id,
        titulo: _tituloCtrl.text.trim(),
        contenido: _contenidoCtrl.text.trim(),
        categoria: _categoria,
        imagenUrl: _imagenCtrl.text.trim().isEmpty
            ? null
            : _imagenCtrl.text.trim(),
      );
    } else {
      ok = await ctrl.crearNoticia(
        titulo: _tituloCtrl.text.trim(),
        contenido: _contenidoCtrl.text.trim(),
        categoria: _categoria,
        imagenUrl: _imagenCtrl.text.trim().isEmpty
            ? null
            : _imagenCtrl.text.trim(),
        autorId: autorId,
      );
    }

    if (!mounted) return;
    setState(() => _guardando = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion
                ? '✅ Noticia actualizada'
                : '✅ Noticia creada y publicada',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Error al guardar',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
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
                  const SizedBox(height: 16),
                  Text(
                    _esEdicion ? 'Editar Noticia' : 'Nueva Noticia',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkAlt,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Título
                  TextFormField(
                    controller: _tituloCtrl,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'El título es obligatorio'
                        : null,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _deco('Título', Icons.title_rounded),
                  ),
                  const SizedBox(height: 14),

                  // Contenido
                  TextFormField(
                    controller: _contenidoCtrl,
                    maxLines: 5,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'El contenido es obligatorio'
                        : null,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _deco('Contenido', Icons.article_rounded),
                  ),
                  const SizedBox(height: 14),

                  // Categoría
                  DropdownButtonFormField<String>(
                    value: _categoria,
                    decoration: _deco('Categoría', Icons.label_outline_rounded),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.darkAlt,
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    items: _categorias
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c[0].toUpperCase() + c.substring(1)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _categoria = v ?? 'general'),
                  ),
                  const SizedBox(height: 14),

                  // URL imagen (opcional)
                  TextFormField(
                    controller: _imagenCtrl,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: _deco(
                      'URL de imagen (opcional)',
                      Icons.image_outlined,
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
                          : const Icon(
                              Icons.save_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                      label: Text(
                        _guardando
                            ? 'Guardando...'
                            : (_esEdicion
                                  ? 'Guardar cambios'
                                  : 'Crear y publicar'),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealLight,
                        elevation: 0,
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

  InputDecoration _deco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.tealLight, size: 20),
      filled: true,
      fillColor: const Color(0xFFF3FAFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.tealLight.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.tealLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red, width: 1.2),
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String filtro;
  const _EmptyState({required this.filtro});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.tealLight.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.newspaper_rounded,
              size: 44,
              color: AppColors.tealLight.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Sin noticias ($filtro)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
