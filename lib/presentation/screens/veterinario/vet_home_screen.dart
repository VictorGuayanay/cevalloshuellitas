import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../data/models/mascota_model.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../../domain/controllers/cita_controller.dart';
import '../../../domain/controllers/mascota_controller.dart';
import '../../../domain/controllers/veterinario_controller.dart';
import '../../../domain/controllers/solicitud_adopcion_controller.dart';
import '../../../domain/controllers/noticia_controller.dart';
import '../../../data/models/noticia_model.dart';
import '../../../presentation/widgets/notificaciones_sheet.dart';
import '../../../presentation/widgets/safe_network_image.dart';
import 'detalle_cita_screen.dart';
// â”€â”€â”€ Paleta verde veterinario â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _vetGreen = Color(0xFF4A9B7F);       // Acento principal verde
const _vetHeaderBg = Color(0xFFBAD1C2);    // Fondo de cabecera verde pastel
const _vetOrange = Color(0xFFE58D57);      // Naranja para badges y citas urgentes
const _vetDark = Color(0xFF1A2E25);        // Textos oscuros
const _vetGrey = Color(0xFF8A9BB0);        // Textos secundarios
const _vetBg = Color(0xFFF4F8F6);          // Fondo general

class VetHomeScreen extends StatefulWidget {
  const VetHomeScreen({super.key});

  @override
  State<VetHomeScreen> createState() => _VetHomeScreenState();
}

class _VetHomeScreenState extends State<VetHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CitaController? _citaCtrl; // Guardamos referencia para usar en dispose()

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final citaCtrl = context.read<CitaController>();
      _citaCtrl = citaCtrl; // Guardar referencia segura
      final vetCtrl = context.read<VeterinarioController>();
      final auth = context.read<AuthController>();
      final uid = auth.currentUser?.id;

      citaCtrl.cargarCitasHoy();
      citaCtrl.cargarTodasLasCitas();
      context.read<MascotaController>().cargarTodasLasMascotas();
      context.read<MascotaController>().cargarMascotasPerdidas();
      context.read<NoticiaController>().cargarNoticias();

      // Cargar citas del veterinario logueado
      if (uid != null) {
        await vetCtrl.cargarPerfil(uid);
        final veteId = vetCtrl.perfil?.id;
        if (veteId != null && veteId.isNotEmpty) {
          await citaCtrl.cargarCitasDeVeterinario(veteId);
          // Suscribir a notificaciones realtime de citas para veterinario
          citaCtrl.suscribirNotificaciones(entityId: veteId, rol: 'veterinario');
          // Programar recordatorios para citas confirmadas existentes
          citaCtrl.programarRecordatoriosExistentes(
              citaCtrl.citasDelVeterinario, 'veterinario');
          // Cargar notificaciones existentes (citas pendientes)
          citaCtrl.cargarNotificacionesExistentes(veteId, 'veterinario');
        }
      }
    });
  }

  @override
  void dispose() {
    _citaCtrl?.desuscribirNotificaciones(); // Usar referencia guardada, no context
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final nombre = auth.currentUser?.nombre ?? 'Veterinario';

    return Scaffold(
      backgroundColor: _vetBg,
      body: Stack(
        children: [
          // â”€â”€ Cabecera verde con curva wave â”€â”€
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipPath(
              clipper: _HeaderClipper(),
              child: Container(
                height: 200,
                color: _vetHeaderBg,
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Fila Logo, Urgencias y Campana
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              const Icon(Icons.local_hospital_rounded,
                                  color: _vetDark, size: 24),
                              const SizedBox(width: 8),
                              Text('Huellitas',
                                  style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: _vetDark)),
                            ]),
                            // Botones derechos: Urgencias + Campana
                            Row(
                              children: [
                                // BotÃ³n Urgencias
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(
                                      context, '/urgencias'),
                                  child: Container(
                                    width: 42, height: 42,
                                    decoration: BoxDecoration(
                                      color: _vetOrange.withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.emergency_rounded,
                                        color: _vetOrange, size: 22),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Campana de notificaciones
                                Consumer<CitaController>(
                                  builder: (ctx, citaCtrl, _) {
                                    final badge = citaCtrl.totalNotificaciones;
                                    return Stack(
                                      children: [
                                        Container(
                                          width: 42, height: 42,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.4),
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(
                                                Icons.notifications_none_rounded,
                                                color: _vetDark, size: 24),
                                            onPressed: () =>
                                                _mostrarNotificacionesSheet(context),
                                          ),
                                        ),
                                        if (badge > 0)
                                          Positioned(
                                            right: 0, top: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                  color: _vetOrange,
                                                  shape: BoxShape.circle),
                                              constraints: const BoxConstraints(
                                                  minWidth: 16, minHeight: 16),
                                              child: Center(
                                                child: Text('$badge',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Bienvenida + toggle disponibilidad
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bienvenido ðŸ‘‹',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: _vetDark.withValues(alpha: 0.7))),
                                  Text('Dr. $nombre',
                                      style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: _vetDark)),
                                ],
                              ),
                            ),
                            Consumer<VeterinarioController>(
                              builder: (ctx, vetCtrl, _) {
                                final disponible = vetCtrl.perfil?.disponible ?? true;
                                return GestureDetector(
                                  onTap: () async {
                                    final ok = await vetCtrl.toggleDisponible();
                                    if (!ok && ctx.mounted) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'No se pudo actualizar la disponibilidad',
                                            style: GoogleFonts.poppins(fontSize: 13),
                                          ),
                                          backgroundColor: const Color(0xFFE53935),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: disponible
                                          ? const Color(0xFF4A9B7F).withValues(alpha: 0.18)
                                          : Colors.black.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: disponible
                                            ? const Color(0xFF4A9B7F).withValues(alpha: 0.5)
                                            : Colors.white.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: disponible
                                                ? const Color(0xFF6FE5B8)
                                                : Colors.white.withValues(alpha: 0.5),
                                            boxShadow: disponible
                                                ? [BoxShadow(
                                                    color: const Color(0xFF6FE5B8)
                                                        .withValues(alpha: 0.6),
                                                    blurRadius: 4)]
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          disponible ? 'Disponible' : 'No disponible',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: disponible
                                                ? _vetDark
                                                : Colors.white.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // â”€â”€ Contenido scrollable debajo de la cabecera â”€â”€
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 170), // Espacio para la cabecera

                  // Contenido scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          // Gestión de Citas â€” tabs Pendientes / Completadas
                          Row(children: [
                            Icon(Icons.calendar_month_rounded,
                                color: _vetGreen, size: 20),
                            const SizedBox(width: 8),
                            Text('Gestión de Citas',
                                style: GoogleFonts.poppins(
                                    fontSize: 16, fontWeight: FontWeight.w700,
                                    color: _vetDark)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/vet_citas'),
                              child: Text('Ver todas',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: _vetGreen)),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          // Tab bar compacta
                          Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                  color: _vetGreen,
                                  borderRadius: BorderRadius.circular(10)),
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.grey.shade600,
                              dividerColor: Colors.transparent,
                              indicatorSize: TabBarIndicatorSize.tab,
                              labelStyle: GoogleFonts.poppins(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              tabs: const [
                                Tab(text: 'â³  Pendientes'),
                                Tab(text: 'âœ…  Completadas'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Tab content
                          Consumer<CitaController>(
                            builder: (ctx, ctrl, _) {
                              if (ctrl.isLoading) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(child: CircularProgressIndicator(
                                      color: _vetGreen)),
                                );
                              }
                              return AnimatedBuilder(
                                animation: _tabController,
                                builder: (ctx, _) {
                                  final pendientes = ctrl.citasDelVeterinario
                                      .where((c) =>
                                          c.estado.toLowerCase() == 'pendiente' ||
                                          c.estado.toLowerCase() == 'confirmada')
                                      .toList();
                                  final completadas = ctrl.citasDelVeterinario
                                      .where((c) =>
                                          c.estado.toLowerCase() == 'completada')
                                      .toList();
                                  final lista = _tabController.index == 0
                                      ? pendientes : completadas;

                                  if (lista.isEmpty) {
                                    return _emptyCard(
                                      _tabController.index == 0
                                          ? 'Sin citas pendientes' : 'Sin citas completadas',
                                      _tabController.index == 0
                                          ? Icons.event_available_rounded : Icons.task_alt_rounded,
                                    );
                                  }
                                  return Column(
                                    children: lista.take(5).map((c) =>
                                        _citaCardClickable(context, c)).toList(),
                                  );
                                },
                              );
                            },
                          ),




                          const SizedBox(height: 24),
                          // â”€â”€ Mascotas Perdidas en tiempo real â”€â”€
                          _buildMascotasPerdidas(context),

                          const SizedBox(height: 24),
                          // ── Noticias ──
                          _buildSeccionNoticias(),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Nav
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _bottomNav(context, auth),
          ),

          // FAB central
          Positioned(
            bottom: 25,
            left: MediaQuery.of(context).size.width / 2 - 35,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/vet_mascotas'),
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _vetGreen.withValues(alpha: 0.3),
                      blurRadius: 14, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: const BoxDecoration(
                      color: _vetGreen, shape: BoxShape.circle),
                  child: const Icon(Icons.pets_rounded,
                      color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // â”€â”€ Mascotas Perdidas (Realtime) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  // ── Noticias ──────────────────────────────────────────────────────────────
  Widget _buildSeccionNoticias() {
    return Consumer<NoticiaController>(
      builder: (ctx, ctrl, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _vetGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.newspaper_rounded, color: _vetGreen, size: 18),
              ),
              const SizedBox(width: 8),
              Text('Noticias', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: _vetDark)),
              const Spacer(),
              if (ctrl.isLoading)
                const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _vetGreen)),
            ]),
            const SizedBox(height: 12),
            if (!ctrl.isLoading && ctrl.noticias.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(children: [
                  Icon(Icons.newspaper_rounded, size: 36, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text('No hay noticias publicadas', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400)),
                ]),
              )
            else
              ...ctrl.noticias.map((n) => _noticiaVetCard(n)),
          ],
        );
      },
    );
  }

  Widget _noticiaVetCard(NoticiaModel n) {
    final colores = {
      'salud': const Color(0xFF4A9B7F), 'perdidos': const Color(0xFFE53935),
      'adopcion': const Color(0xFFE58D57), 'nutricion': const Color(0xFFE58D57),
      'bienestar': const Color(0xFF7C6FCD), 'prevencion': const Color(0xFF5BBFBF),
      'emergencias': const Color(0xFFE53935),
    };
    final color = colores[n.categoria.toLowerCase()] ?? _vetGreen;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n.imagenUrl != null && n.imagenUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(n.imagenUrl!, height: 140, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(n.categoria, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                ),
                const Spacer(),
                Text(n.tiempoRelativo, style: GoogleFonts.poppins(fontSize: 10, color: _vetGrey)),
              ]),
              const SizedBox(height: 6),
              Text(n.titulo, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: _vetDark, height: 1.3)),
              const SizedBox(height: 4),
              Text(n.contenido, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 11, color: _vetGrey, height: 1.4)),
              if (n.autorNombre != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.person_outline_rounded, size: 11, color: _vetGrey),
                  const SizedBox(width: 3),
                  Text(n.autorNombre!, style: GoogleFonts.poppins(fontSize: 10, color: _vetGrey)),
                ]),
              ],
            ]),
          ),
        ],
      ),
    );
  }
  Widget _buildMascotasPerdidas(BuildContext context) {
    return Consumer<MascotaController>(
      builder: (ctx, ctrl, _) {
        final perdidas = ctrl.mascotasPerdidas;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_off_rounded,
                      color: Color(0xFFE53935), size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  'Mascotas Perdidas',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _vetDark,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'En vivo',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Se actualiza automÃ¡ticamente',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: _vetGrey,
              ),
            ),
            const SizedBox(height: 12),

            // Estado cargando
            if (ctrl.isLoadingPerdidas)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(
                      color: Color(0xFFE53935)),
                ),
              )
            // Estado vacÃ­o
            else if (perdidas.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(Icons.location_off_rounded,
                        size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(
                      'No hay mascotas perdidas reportadas',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              )
            // Lista de mascotas perdidas
            else
              Column(
                children: perdidas
                    .map((m) => _mascotaPerdidaVetCard(m))
                    .toList(),
              ),
          ],
        );
      },
    );
  }

  Widget _mascotaPerdidaVetCard(MascotaModel m) {
    String tiempoRelativo = '';
    if (m.createdAt != null) {
      final diff = DateTime.now().difference(m.createdAt!);
      if (diff.inDays == 0) {
        tiempoRelativo =
            diff.inHours == 0 ? 'hace ${diff.inMinutes} min' : 'hace ${diff.inHours}h';
      } else if (diff.inDays < 7) {
        tiempoRelativo = 'hace ${diff.inDays}d';
      } else {
        final d = m.createdAt!;
        tiempoRelativo =
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: const Color(0xFFE53935), width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Foto
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: m.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SafeNetworkImage(
              url: m.fotoUrl,
              borderRadius: BorderRadius.circular(12),
              fallbackIcon: m.icon,
              fallbackColor: m.color,
              fallbackIconSize: 26,
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombre,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _vetDark,
                  ),
                ),
                Text(
                  '${m.especie} Â· ${m.raza}',
                  style: GoogleFonts.poppins(fontSize: 11, color: _vetGrey),
                ),
                if (m.descripcion != null && m.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    m.descripcion!,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: const Color(0xFFE53935),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Tiempo + datos contacto
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (tiempoRelativo.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.access_time_rounded,
                      size: 10, color: Colors.grey.shade400),
                  const SizedBox(width: 2),
                  Text(tiempoRelativo,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.grey.shade400)),
                ]),
              const SizedBox(height: 4),
              if (m.propietarioTelefono != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.phone_rounded,
                      size: 11, color: _vetGreen),
                  const SizedBox(width: 3),
                  Text(
                    m.propietarioTelefono!,
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: _vetGreen,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€ BotÃ³n de categorÃ­a estilo imagen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _categoryBtn(BuildContext context, IconData icon, String label, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _vetGreen.withValues(alpha: 0.18),
                  blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Icon(icon, color: _vetGreen, size: 34),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: _vetDark,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _citaCardClickable(BuildContext context, dynamic cita) {
    Color color;
    IconData icon;
    switch (cita.estado.toLowerCase()) {
      case 'completada':
        color = const Color(0xFF43B89C);
        icon = Icons.task_alt_rounded;
        break;
      case 'cancelada':
        color = const Color(0xFFE53935);
        icon = Icons.cancel_outlined;
        break;
      default:
        color = const Color(0xFFE58D57);
        icon = Icons.schedule_rounded;
    }
    return GestureDetector(
      onTap: () {
        final veteCtrl = context.read<VeterinarioController>();
        final citaCtrl = context.read<CitaController>();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetalleCitaScreen(cita: cita)),
        ).then((_) {
          final veteId = veteCtrl.perfil?.id;
          if (veteId != null) {
            citaCtrl.cargarCitasDeVeterinario(veteId);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(cita.mascotaNombre,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A2E))),
              Text(cita.motivo,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey.shade500)),
              if (cita.propietarioNombre.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.person_outline_rounded,
                      size: 11, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text(cita.propietarioNombre,
                      style: GoogleFonts.poppins(
                          fontSize: 10, color: Colors.grey.shade400)),
                ]),
              ],
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(cita.hora, style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(cita.fecha.split('-').reversed.join('/'),
                style: GoogleFonts.poppins(
                    fontSize: 10, color: Colors.grey.shade400)),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.grey, size: 18),
          ]),
        ]),
      ),
    );
  }

  Widget _emptyCard(String msg, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        Icon(icon, size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text(msg,
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey.shade400)),
      ]),
    );
  }

  Widget _bottomNav(BuildContext context, AuthController auth) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
              icon: const Icon(Icons.home_rounded,
                  color: _vetGreen, size: 30),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.calendar_today_outlined,
                  color: _vetGrey, size: 26),
              onPressed: () => Navigator.pushNamed(context, '/vet_citas')),
          const SizedBox(width: 50),
          IconButton(
              icon: const Icon(Icons.volunteer_activism_rounded,
                  color: _vetGrey, size: 28),
              onPressed: () => Navigator.pushNamed(context, '/adopciones')),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded,
                color: _vetGrey, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/vet_perfil'),
          ),
        ],
      ),
    );
  }

  void _mostrarNotificacionesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<CitaController>()),
          ChangeNotifierProvider.value(
              value: context.read<SolicitudAdopcionController>()),
        ],
        child: DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (_, sc) => NotificacionesSheet(
            sc: sc,
            rol: 'veterinario',
            onClose: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}

class _HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
        size.width / 2, size.height + 10, size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
