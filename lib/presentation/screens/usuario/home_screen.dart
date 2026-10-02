import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../../domain/controllers/mascota_controller.dart';
import '../../../domain/controllers/noticia_controller.dart';
import '../../../domain/controllers/notificacion_controller.dart';
import '../../../data/models/mascota_model.dart';
import '../../../data/models/noticia_model.dart';
import '../../../presentation/widgets/notificaciones_sheet.dart';
import '../../../presentation/widgets/safe_network_image.dart';
import '../../../presentation/widgets/header_wave_clipper.dart';
import '../../../core/app_colors.dart';
import '../../../presentation/widgets/mascota_form_sheet.dart';
import '../../../presentation/widgets/senso_sheet.dart';
import 'noticia_detalle_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<MascotaController>().cargarMascotasPerdidas();
      context.read<NoticiaController>().cargarNoticias();
    });
  }

  // ── Favoritos sheet ───────────────────────────────────────────────────────
  // ── Dialog perfil mascota ─────────────────────────────────────────────────
  void _showPerfil(BuildContext context, MascotaModel mascota) {
    showDialog(
      context: context,
      builder: (_) => _PerfilMascotaDialog(mascota: mascota),
    );
  }

  // ── Sheet para agregar una nueva mascota directamente desde el FAB ────────
  void _showAddMascotaSheet(BuildContext context) {
    final uid = context.read<AuthController>().currentUser?.id;
    if (uid == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<MascotaController>()),
          ChangeNotifierProvider.value(value: context.read<AuthController>()),
        ],
        child: MascotaFormSheet(
          onGuardado: () {
            // Recargar la lista de mascotas del usuario tras guardar
            if (mounted) {
              context.read<MascotaController>().cargarMascotas(uid);
            }
          },
        ),
      ),
    );
  }

  // ── Sheet de notificaciones ───────────────────────────────────────────────
  void _showNotificacionesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, sc) => NotificacionesSheet(
          sc: sc,
          rol: 'usuario',
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MascotaController>();
    final mascotas = ctrl.mascotasPerdidas;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      // ── FAB central con anillo exterior de la imagen ──
      floatingActionButton: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.tealLight.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4), // Espaciador para el anillo exterior blanco
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            shape: BoxShape.circle,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _showAddMascotaSheet(context),
              child: const Icon(
                Icons.pets_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom bar ──
      bottomNavigationBar: _buildBottomBar(context),

      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Cabecera celeste con curva exacta ──
          SliverToBoxAdapter(
            child: ClipPath(
              clipper: HeaderWaveClipper(),
              child: Container(
                height: 250,
                color: AppColors.tealBg,
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Fila Logo
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Icon(
                              Icons.pets_rounded,
                              color: AppColors.darkAlt,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Huellitas',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkAlt,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Fila de botones de categoría
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Consumer<AuthController>(
                          builder: (ctx, auth, _) {
                            final esProductor =
                                auth.currentUser?.esProductor == true;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _categoryBtn(
                                  context,
                                  Icons.pets_rounded,
                                  'Mis Mascotas',
                                  '/mis_mascotas',
                                ),
                                _categoryBtn(
                                  context,
                                  Icons.medical_services_rounded,
                                  'Servicios',
                                  '/servicios',
                                ),
                                _sensoBtn(context, esProductor),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Sección Mascotas Perdidas ──
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off_rounded,
                          color: Color(0xFFE53935), size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Mascotas Perdidas',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkAlt,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 236,
                  child: ctrl.isLoadingPerdidas
                      ? const _MascotasSkeletonLoader()
                      : mascotas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.pets_rounded,
                                      size: 52,
                                      color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No hay mascotas perdidas reportadas.',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey.shade400,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: mascotas.length,
                              itemBuilder: (context, i) =>
                                  _petCard(context, mascotas[i]),
                            ),
                ),

                const SizedBox(height: 28),

                // ── Sección Noticias ──
                _buildSeccionNoticias(),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sección Noticias ────────────────────────────────────────────────────────
  Widget _buildSeccionNoticias() {
    return Consumer<NoticiaController>(
      builder: (ctx, ctrl, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.newspaper_rounded,
                        color: AppColors.tealLight, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Noticias',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkAlt,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Publicadas por el equipo de Huellitas',
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.grey),
              ),
              const SizedBox(height: 16),

              // Skeleton mientras carga
              if (ctrl.isLoading)
                const _NoticiasSkeletonLoader()
              // Estado vacío
              else if (ctrl.noticias.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(children: [
                    Icon(Icons.newspaper_rounded,
                        size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('No hay noticias publicadas aún',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: Colors.grey.shade400)),
                  ]),
                )
              else
                ...ctrl.noticias.map((n) => _noticiaCard(n)),            ],
          ),
        );
      },
    );
  }

  Widget _noticiaCard(NoticiaModel noticia) {
    // Color por categoría
    final colores = {
      'salud':       const Color(0xFF4A9B7F),
      'perdidos':    const Color(0xFFE53935),
      'adopcion':    const Color(0xFFE58D57),
      'nutricion':   const Color(0xFFE58D57),
      'bienestar':   const Color(0xFF7C6FCD),
      'prevencion':  const Color(0xFF5BBFBF),
      'emergencias': const Color(0xFFE53935),
    };
    final color = colores[noticia.categoria.toLowerCase()] ?? AppColors.tealLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoticiaDetalleScreen(noticia: noticia),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen si existe
              if (noticia.imagenUrl != null && noticia.imagenUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  child: Image.network(
                    noticia.imagenUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícono categoría
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
                      ),
                      child: Icon(Icons.newspaper_rounded, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge categoría + tiempo
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
                              ),
                              child: Text(
                                noticia.categoria.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(children: [
                              Icon(Icons.schedule_rounded, size: 12,
                                  color: AppColors.grey.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Text(
                                noticia.tiempoRelativo,
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AppColors.grey,
                                    fontWeight: FontWeight.w500),
                              ),
                            ]),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            noticia.titulo,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkAlt,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            noticia.contenido,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.grey,
                              height: 1.45,
                            ),
                          ),
                          // Autor si existe
                          if (noticia.autorNombre != null) ...[
                            const SizedBox(height: 8),
                            Row(children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 13, color: AppColors.grey),
                              const SizedBox(width: 4),
                              Text(
                                noticia.autorNombre!,
                                style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.grey,
                                    fontWeight: FontWeight.w500),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Botón SENSO (solo activo si es productor) ────────────────────────────
  Widget _sensoBtn(BuildContext context, bool habilitado) {
    const activeColor = Color(0xFF4A9B7F);
    const disabledColor = Color(0xFFB0BEC5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: habilitado
            ? () => mostrarSensoSheet(context)
            : () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Solo disponible para productores pecuarios.',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                  ]),
                  backgroundColor: disabledColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                ));
              },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: habilitado
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF5DB898),
                                Color(0xFF4A9B7F),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: habilitado ? null : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: habilitado
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      boxShadow: habilitado
                          ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.28),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(Icons.bar_chart_rounded,
                        color: habilitado ? Colors.white : disabledColor,
                        size: 28),
                  ),
                  // Candado si está deshabilitado
                  if (!habilitado)
                    Positioned(
                      right: -4, top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.lock_rounded,
                            color: Colors.white, size: 10),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Censo',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: habilitado ? AppColors.darkAlt : disabledColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Botón de Categoría ──────────────────────────────────────────────────────
  Widget _categoryBtn(BuildContext context, IconData icon, String label, String route) {    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.tealLight,
                      HSLColor.fromColor(AppColors.tealLight)
                          .withLightness((HSLColor.fromColor(AppColors.tealLight).lightness - 0.06).clamp(0.0, 1.0))
                          .toColor(),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.tealLight.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.darkAlt,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tarjeta de Mascota Perdida ──────────────────────────────────────────────
  Widget _petCard(BuildContext context, MascotaModel mascota) {
    final nombreCapitalizado = mascota.nombre.isNotEmpty
        ? mascota.nombre[0].toUpperCase() + mascota.nombre.substring(1)
        : 'Mascota';

    return Container(
      width: 162,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.tealLight.withValues(alpha: 0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.tealLight.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _showPerfil(context, mascota),
          child: Column(
            children: [
              Expanded(
                flex: 6,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F9FA),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: SafeNetworkImage(
                        url: mascota.fotoUrl,
                        borderRadius: BorderRadius.circular(18),
                        fallbackIcon: Icons.pets_rounded,
                        fallbackColor: AppColors.tealLight,
                        fallbackIconSize: 44,
                        width: double.infinity,
                      ),
                    ),
                    // Badge "Perdido" refinado en la esquina superior derecha
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF5350), Color(0xFFD32F2F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_off_rounded,
                                color: Colors.white, size: 10),
                            const SizedBox(width: 3),
                            Text(
                              'PERDIDO',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        nombreCapitalizado,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkAlt,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.tealLight,
                              HSLColor.fromColor(AppColors.tealLight)
                                  .withLightness((HSLColor.fromColor(AppColors.tealLight).lightness - 0.05).clamp(0.0, 1.0))
                                  .toColor(),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.tealLight.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.visibility_outlined, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Ver Perfil',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Barra de Navegación Inferior ──────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppColors.white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navBtn(Icons.home_rounded, 0, onTap: () {}),
            _navBtn(Icons.map_outlined, 1,
                onTap: () async {
                  await Navigator.pushNamed(context, '/mapa_veterinarios');
                  setState(() => _selectedIndex = 0);
                }),
            const SizedBox(width: 48), // Espacio para el FAB central
            // Notificaciones con badge de no leídas
            _notifNavBtn(context),
            _navBtn(Icons.person_outline_rounded, 3,
                onTap: () async {
                  await Navigator.pushNamed(context, '/perfil');
                  setState(() => _selectedIndex = 0);
                }),
          ],
        ),
      ),
    );
  }

  /// Botón de notificaciones con badge que muestra el conteo de no leídas.
  Widget _notifNavBtn(BuildContext context) {
    return Consumer<NotificacionController>(
      builder: (ctx, notifCtrl, _) {
        final noLeidas = notifCtrl.totalNotificaciones;
        final active = _selectedIndex == 2;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedIndex = 2);
            _showNotificacionesSheet(context);
            // Regresar al índice 0 cuando se cierre el sheet
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _selectedIndex = 0);
            });
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.tealLight.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 24,
                  color: active
                      ? AppColors.tealLight
                      : AppColors.grey.withValues(alpha: 0.7),
                ),
                if (noLeidas > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        noLeidas > 99 ? '99+' : '$noLeidas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _navBtn(IconData icon, int index, {required VoidCallback onTap}) {
    final active = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.tealLight.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          size: 24,
          color: active ? AppColors.tealLight : AppColors.grey.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

// ── Dialog: Perfil de mascota con datos del dueño real (desde Supabase) ──────
class _PerfilMascotaDialog extends StatefulWidget {
  final MascotaModel mascota;
  const _PerfilMascotaDialog({required this.mascota});

  @override
  State<_PerfilMascotaDialog> createState() => _PerfilMascotaDialogState();
}

class _PerfilMascotaDialogState extends State<_PerfilMascotaDialog> {
  String? _nombreDueno;
  String? _telefonoDueno;
  String? _fotoDueno;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosDueno();
  }

  Future<void> _cargarDatosDueno() async {
    final usuarioId = widget.mascota.usuarioId;
    if (usuarioId.isEmpty) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    try {
      final result = await Supabase.instance.client
          .from('usuarios')
          .select('usua_nombre, usua_telefono, usua_foto_url')
          .eq('usua_id', usuarioId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _nombreDueno  = result?['usua_nombre']    as String?;
          _telefonoDueno = result?['usua_telefono'] as String?;
          _fotoDueno    = result?['usua_foto_url']  as String?;
          _cargando     = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mascota = widget.mascota;
    return Consumer<MascotaController>(
      builder: (ctx, ctrl, _) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: AppColors.white,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Foto
                Stack(children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F9FA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: SafeNetworkImage(
                      url: mascota.fotoUrl,
                      borderRadius: BorderRadius.circular(18),
                      fallbackIcon: Icons.pets_rounded,
                      fallbackColor: AppColors.tealLight,
                      fallbackIconSize: 80,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(
                  mascota.nombre,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkAlt,
                  ),
                ),
                Text(
                  '${mascota.especie} · ${mascota.raza}',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _chip(mascota.edad, Icons.cake_outlined, AppColors.orange),
                  const SizedBox(width: 8),
                  _chip(mascota.genero, Icons.transgender_rounded, AppColors.tealLight),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgApp,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.tealLight.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    mascota.descripcion ?? 'Sin descripción disponible.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
                // ── Datos del dueño real ──
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.tealLight.withValues(alpha: 0.2)),
                  ),
                  child: _cargando
                      ? Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: AppColors.tealLight, strokeWidth: 2),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.person_rounded,
                                  color: AppColors.tealLight, size: 16),
                              const SizedBox(width: 6),
                              Text('Datos del propietario',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.tealLight)),
                            ]),
                            const SizedBox(height: 10),
                            // ── Foto + info en fila ──────────────────────
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar del dueño
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.tealLight.withValues(alpha: 0.12),
                                    border: Border.all(
                                        color: AppColors.tealLight.withValues(alpha: 0.35),
                                        width: 2),
                                  ),
                                  child: ClipOval(
                                    child: (_fotoDueno != null &&
                                            _fotoDueno!.isNotEmpty)
                                        ? Image.network(_fotoDueno!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Icon(Icons.person_rounded,
                                                    size: 26, color: AppColors.tealLight))
                                        : Icon(Icons.person_rounded,
                                            size: 26, color: AppColors.tealLight),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Nombre + teléfono
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Icon(Icons.badge_outlined,
                                            color: AppColors.tealLight, size: 13),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            _nombreDueno?.isNotEmpty == true
                                                ? _nombreDueno!
                                                : 'No disponible',
                                            style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.darkAlt),
                                          ),
                                        ),
                                      ]),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Icon(Icons.phone_outlined,
                                            color: AppColors.tealLight, size: 13),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            (_telefonoDueno?.isNotEmpty ==
                                                    true)
                                                ? _telefonoDueno!
                                                : 'Teléfono no registrado',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: (_telefonoDueno
                                                            ?.isNotEmpty ==
                                                        true)
                                                    ? AppColors.darkAlt
                                                    : Colors.grey.shade400),
                                          ),
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ]),
                ),
                const SizedBox(height: 18),
                // ── Botón: Cerrar ──────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.tealLight,
                      side: BorderSide(
                          color: AppColors.tealLight.withValues(alpha: 0.4), width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('Cerrar',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────

// ── Shimmer base ──────────────────────────────────────────────────────────────
//
// Widget reutilizable que anima un gradiente de izquierda a derecha
// sobre cualquier contenedor con forma de rectángulo redondeado.
// Se usa como bloque de construcción para los skeletons.
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(_anim.value - 1, 0),
              end: Alignment(_anim.value + 1, 0),
              colors: const [
                Color(0xFFECEFF1),
                Color(0xFFF5F7F8),
                Color(0xFFECEFF1),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ── Skeleton: lista horizontal de mascotas perdidas ───────────────────────────
//
// Replica exactamente el tamaño de las tarjetas reales (width 162, height 236)
// para que el layout no salte cuando lleguen los datos.
class _MascotasSkeletonLoader extends StatelessWidget {
  const _MascotasSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        width: 162,
        margin: const EdgeInsets.only(right: 16, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            // Imagen placeholder
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: _ShimmerBox(
                  width: double.infinity,
                  height: double.infinity,
                  radius: 18,
                ),
              ),
            ),
            // Nombre + botón
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ShimmerBox(width: 90, height: 14, radius: 6),
                    _ShimmerBox(
                        width: double.infinity, height: 30, radius: 14),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton: lista vertical de noticias ─────────────────────────────────────
//
// Muestra 2 tarjetas placeholder que replican la estructura de _noticiaCard:
// ícono cuadrado + líneas de texto a la derecha.
class _NoticiasSkeletonLoader extends StatelessWidget {
  const _NoticiasSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(2, (_) => _NoticiaSkeleton()),
    );
  }
}

class _NoticiaSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono categoría placeholder
          _ShimmerBox(width: 46, height: 46, radius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge + tiempo
                Row(children: [
                  _ShimmerBox(width: 60, height: 16, radius: 10),
                  const Spacer(),
                  _ShimmerBox(width: 50, height: 12, radius: 6),
                ]),
                const SizedBox(height: 10),
                // Título
                _ShimmerBox(width: double.infinity, height: 15, radius: 6),
                const SizedBox(height: 6),
                _ShimmerBox(width: 180, height: 15, radius: 6),
                const SizedBox(height: 10),
                // Cuerpo
                _ShimmerBox(width: double.infinity, height: 12, radius: 5),
                const SizedBox(height: 5),
                _ShimmerBox(width: double.infinity, height: 12, radius: 5),
                const SizedBox(height: 5),
                _ShimmerBox(width: 140, height: 12, radius: 5),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
