import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../../domain/controllers/cita_controller.dart';
import '../../../domain/controllers/mascota_controller.dart';
import '../../../domain/controllers/solicitud_adopcion_controller.dart';
import '../../../domain/controllers/noticia_controller.dart';
import '../../../data/models/mascota_model.dart';
import '../../../data/models/noticia_model.dart';
import '../../../presentation/widgets/notificaciones_sheet.dart';
import '../../../presentation/widgets/safe_network_image.dart';
import '../../../presentation/widgets/header_wave_clipper.dart';

// Constante de color naranja para adopciones
const _adoptOrange = Color(0xFFE58D57);

// ─── Paleta de colores exacta de la imagen ────────────────────────────────────
const _teal = Color(0xFF2FA3A3);       // Botones de categoría, "Ver Perfil" y FAB
const _orange = Color(0xFFE58D57);     // Botón "¡Adopta Hoy!" y badge de notificaciones
const _headerBg = Color(0xFFBBE7EC);   // Fondo celeste pastel de la cabecera
const _bg = Color(0xFFF6FAFA);         // Fondo general de la app
const _dark = Color(0xFF262A2B);       // Títulos y textos principales
const _grey = Color(0xFF8A9BB0);       // Textos secundarios e íconos inactivos
const _white = Colors.white;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // Referencia guardada para usar en dispose() sin acceder a context
  SolicitudAdopcionController? _solicCtrl;

  @override
  void dispose() {
    // Usar referencia guardada, nunca context en dispose
    _solicCtrl?.detenerVigilancia();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<MascotaController>().cargarMascotasPerdidas();
      context.read<NoticiaController>().cargarNoticias();
      final uid = context.read<AuthController>().currentUser?.id;
      if (uid != null) {
        final solicCtrl = context.read<SolicitudAdopcionController>();
        _solicCtrl = solicCtrl; // guardar referencia para dispose
        // Inicia Realtime + polling de adopciones (carga + vigilancia activa)
        await solicCtrl.iniciarVigilancia(uid);
        if (!mounted) return;
        // Cargar historial completo de solicitudes
        solicCtrl.cargarMisSolicitudes(uid);
        solicCtrl.cargarSolicitudesRecibidas(uid);

        final citaCtrl = context.read<CitaController>();
        citaCtrl.suscribirNotificaciones(entityId: uid, rol: 'usuario');
        await citaCtrl.cargarCitasDeUsuario(uid);
        if (!mounted) return;
        citaCtrl.programarRecordatoriosExistentes(
            citaCtrl.citasDelUsuario, 'usuario');
        citaCtrl.cargarNotificacionesExistentes(uid, 'usuario');
      }
    });
  }

  // ── Panel de notificaciones unificadas ───────────────────────────────────
  void _showNotificacionesCitasSheet(BuildContext ctx, CitaController citaCtrl) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: citaCtrl),
          ChangeNotifierProvider.value(
              value: ctx.read<SolicitudAdopcionController>()),
        ],
        child: DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.9,
          minChildSize: 0.35,
          builder: (_, sc) => NotificacionesSheet(
            sc: sc,
            rol: 'usuario',
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
  }

  // ── Favoritos sheet ───────────────────────────────────────────────────────
  void _showFavoritosDialog(BuildContext context) {
    // Guardar referencia al context del HomeScreen para usarlo después del pop
    final homeContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<MascotaController>()),
          ChangeNotifierProvider.value(value: context.read<SolicitudAdopcionController>()),
        ],
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          minChildSize: 0.3,
          builder: (_, sc) => Container(
            decoration: const BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              const SizedBox(height: 12),
              // Handle bar
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
              // Title row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        color: Color(0xFFE53935), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mis Favoritos',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Consumer<MascotaController>(
                  builder: (sheetCtx, ctrl, _) {
                    final favs = ctrl.mascotasFavoritas;
                    if (favs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_border_rounded,
                                size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No tienes mascotas favoritas aún.',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: sc,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount: favs.length,
                      itemBuilder: (_, i) {
                        final m = favs[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8F8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFFFCDD2)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // Foto
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F9FA),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SafeNetworkImage(
                                    url: m.fotoUrl,
                                    borderRadius: BorderRadius.circular(12),
                                    fallbackIcon: Icons.pets_rounded,
                                    fallbackColor: _teal,
                                    fallbackIconSize: 28,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.nombre,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: _dark,
                                        ),
                                      ),
                                      Text(
                                        '${m.especie} · ${m.raza}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Botones: Ver Perfil + Adoptar
                                      Row(children: [
                                        // Ver Perfil
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.pop(sheetCtx);
                                              _showPerfil(homeContext, m);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: _teal.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                    color: _teal.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.visibility_outlined,
                                                      color: _teal, size: 11),
                                                  const SizedBox(width: 3),
                                                  Text('Perfil',
                                                      style: GoogleFonts.poppins(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          color: _teal)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Adoptar
                                        Expanded(
                                          child: Consumer<SolicitudAdopcionController>(
                                            builder: (sCtx, solicCtrl, _) {
                                              final rechazada = solicCtrl.misSolicitudes
                                                  .any((s) => s.mascId == m.id && s.estado == 'Rechazada');
                                              return GestureDetector(
                                                onTap: rechazada
                                                    ? null
                                                    : () {
                                                        Navigator.pop(sheetCtx);
                                                        _confirmarAdopcion(homeContext, m);
                                                      },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 8, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: rechazada
                                                        ? Colors.grey.withValues(alpha: 0.1)
                                                        : _adoptOrange.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                        color: rechazada
                                                            ? Colors.grey.withValues(alpha: 0.3)
                                                            : _adoptOrange.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(
                                                        rechazada
                                                            ? Icons.block_rounded
                                                            : Icons.volunteer_activism_rounded,
                                                        color: rechazada ? Colors.grey : _adoptOrange,
                                                        size: 11,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        rechazada ? 'No disp.' : 'Adoptar',
                                                        style: GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                            color: rechazada
                                                                ? Colors.grey
                                                                : _adoptOrange),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ]),
                                    ],
                                  ),
                                ),
                                // Corazón para quitar favorito
                                GestureDetector(
                                  onTap: () => ctrl.toggleFavorito(m.id),
                                  child: const Icon(Icons.favorite_rounded,
                                      color: Color(0xFFE53935), size: 24),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Sheet Próximamente (Tienda) ───────────────────────────────────────────
  void _showProximamenteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store_rounded, size: 48, color: _teal),
            ),
            const SizedBox(height: 20),
            Text(
              'Tienda',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _dark),
            ),
            const SizedBox(height: 8),
            Text(
              '¡Próximamente!',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _teal),
            ),
            const SizedBox(height: 10),
            Text(
              'Estamos preparando algo increíble para ti y tu mascota. ¡Pronto estará disponible!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: _grey, height: 1.5),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // ── Dialog perfil mascota ─────────────────────────────────────────────────
  void _showPerfil(BuildContext context, MascotaModel mascota) {
    showDialog(
      context: context,
      builder: (_) => _PerfilMascotaDialog(mascota: mascota),
    );
  }

  // ── Contactar dueño de mascota perdida ────────────────────────────────────
  void _mostrarContactoDuenio(BuildContext context, MascotaModel mascota) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_off_rounded,
                color: Color(0xFFE53935), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mascota perdida',
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _dark),
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto + nombre
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F9FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SafeNetworkImage(
                  url: mascota.fotoUrl,
                  borderRadius: BorderRadius.circular(12),
                  fallbackIcon: Icons.pets_rounded,
                  fallbackColor: _teal,
                  fallbackIconSize: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(mascota.nombre,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _dark)),
                  Text('${mascota.especie} · ${mascota.raza}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: Colors.grey.shade500)),
                ]),
              ),
            ]),
            if (mascota.descripcion != null &&
                mascota.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFFCDD2), width: 1),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFE53935), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mascota.descripcion!,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFFE53935),
                          height: 1.4),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            // Datos de contacto del dueño
            if (mascota.propietarioNombre != null) ...[
              Text('Dueño:',
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _grey,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.person_rounded, color: _teal, size: 16),
                const SizedBox(width: 6),
                Text(mascota.propietarioNombre!,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _dark,
                        fontWeight: FontWeight.w600)),
              ]),
            ],
            if (mascota.propietarioTelefono != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.phone_rounded, color: _teal, size: 16),
                const SizedBox(width: 6),
                Text(mascota.propietarioTelefono!,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: _dark)),
              ]),
            ],
            if (mascota.propietarioNombre == null &&
                mascota.propietarioTelefono == null)
              Text(
                'No hay datos de contacto disponibles.',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: _grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar',
                style: GoogleFonts.poppins(
                    color: _teal, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Confirmar y enviar solicitud de adopción ──────────────────────────────
  void _confirmarAdopcion(BuildContext context, MascotaModel mascota) {
    final uid = context.read<AuthController>().currentUser?.id;
    if (uid == null) return;

    // Bloquear si el usuario ya fue rechazado para esta mascota
    final solicitudExistente = context
        .read<SolicitudAdopcionController>()
        .misSolicitudes
        .where((s) => s.mascId == mascota.id)
        .firstOrNull;

    if (solicitudExistente?.estado == 'Rechazada') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.block_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tu solicitud fue rechazada. No puedes volver a solicitar la adopción de ${mascota.nombre}.',
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ),
          ]),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.volunteer_activism_rounded,
              color: _adoptOrange, size: 22),
          const SizedBox(width: 10),
          Text('Adoptar a ${mascota.nombre}',
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _dark)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Foto + nombre
          Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F9FA),
                  borderRadius: BorderRadius.circular(12)),
              child: SafeNetworkImage(
                url: mascota.fotoUrl,
                borderRadius: BorderRadius.circular(12),
                fallbackIcon: Icons.pets_rounded,
                fallbackColor: _teal,
                fallbackIconSize: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(mascota.nombre,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: _dark)),
                Text('${mascota.especie} · ${mascota.raza}',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade500)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _adoptOrange.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _adoptOrange.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: _adoptOrange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Se enviará una solicitud al dueño. Te notificaremos cuando responda.',
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: _adoptOrange, height: 1.4),
                ),
              ),
            ]),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ),
          Consumer<SolicitudAdopcionController>(
            builder: (_, solicCtrl, w) => ElevatedButton.icon(
              onPressed: solicCtrl.isLoading
                  ? null
                  : () async {
                      final ok = await solicCtrl.enviarSolicitud(
                          usuaId: uid, mascId: mascota.id);
                      if (!context.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Row(children: [
                          Icon(
                            ok
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ok
                                  ? '¡Solicitud enviada! El dueño te contactará pronto.'
                                  : (solicCtrl.errorMessage ?? 'Error al enviar'),
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          ),
                        ]),
                        backgroundColor: ok
                            ? const Color(0xFF43B89C)
                            : const Color(0xFFE53935),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    },
              icon: solicCtrl.isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.favorite_rounded, size: 16),
              label: Text('Enviar Solicitud',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _adoptOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
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
        child: _AddMascotaSheet(
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

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MascotaController>();
    final mascotas = ctrl.mascotasPerdidas;

    return Scaffold(
      backgroundColor: _bg,
      // ── FAB central con anillo exterior de la imagen ──
      floatingActionButton: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _teal.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4), // Espaciador para el anillo exterior blanco
        child: Container(
          decoration: const BoxDecoration(
            color: _teal,
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
                color: _headerBg,
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Fila Logo y Campana
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.pets_rounded,
                                  color: _dark,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Huellitas',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: _dark,
                                  ),
                                ),
                              ],
                            ),
                            // Campana de notificaciones — adopciones + citas
                            Consumer2<SolicitudAdopcionController, CitaController>(
                              builder: (ctx, solicCtrl, citaCtrl, _) {
                                final badgeSolic = solicCtrl.totalNotificaciones > 0
                                    ? solicCtrl.totalNotificaciones
                                    : solicCtrl.pendientesRecibidas;
                                final badgeCitas = citaCtrl.totalNotificaciones;
                                final totalBadge = badgeSolic + badgeCitas;
                                return Stack(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.notifications_none_rounded,
                                          color: _dark,
                                          size: 24,
                                        ),
                                        onPressed: () {
                                          // Siempre abre el nuevo panel de notificaciones
                                          _showNotificacionesCitasSheet(context, citaCtrl);
                                        },
                                      ),
                                    ),
                                    if (totalBadge > 0)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: _orange,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$totalBadge',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Fila de botones de categoría
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _categoryBtn(
                              context,
                              Icons.pets_rounded,
                              'Mis Mascotas',
                              '/mis_mascotas',
                            ),
                            // Botón Adopciones con badge de notificaciones
                            Consumer<SolicitudAdopcionController>(
                              builder: (ctx, solicCtrl, _) {
                                final badge = solicCtrl.totalNotificaciones > 0
                                    ? solicCtrl.totalNotificaciones
                                    : solicCtrl.pendientesRecibidas;
                                return GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, '/adopciones'),
                                  child: Column(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 68,
                                            height: 68,
                                            decoration: BoxDecoration(
                                              color: _teal,
                                              borderRadius: BorderRadius.circular(18),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _teal.withValues(alpha: 0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.volunteer_activism_rounded,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                          if (badge > 0)
                                            Positioned(
                                              top: -6,
                                              right: -6,
                                              child: Container(
                                                padding: const EdgeInsets.all(5),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFE53935),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  '$badge',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Adopciones',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: _dark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            _categoryBtn(
                              context,
                              Icons.medical_services_rounded,
                              'Servicios',
                              '/servicios',
                            ),
                            _categoryBtnRed(
                              context,
                              Icons.emergency_rounded,
                              'Urgencias',
                              '/urgencias_usuario',
                            ),
                          ],
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
                          color: _dark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 236,
                  child: ctrl.isLoadingPerdidas
                      ? const Center(
                          child: CircularProgressIndicator(color: _teal))
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
                      color: _teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.newspaper_rounded,
                        color: _teal, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Noticias',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const Spacer(),
                  if (ctrl.isLoading)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _teal),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Publicadas por el equipo de Huellitas',
                style: GoogleFonts.poppins(fontSize: 12, color: _grey),
              ),
              const SizedBox(height: 16),

              // Estado vacío
              if (!ctrl.isLoading && ctrl.noticias.isEmpty)
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
                ...ctrl.noticias.map((n) => _noticiaCard(n)),
            ],
          ),
        );
      },
    );
  }

  Widget _noticiaCard(NoticiaModel noticia) {
    // Color por categoría
    final colores = {
      'salud':     const Color(0xFF4A9B7F),
      'perdidos':  const Color(0xFFE53935),
      'adopcion':  const Color(0xFFE58D57),
      'nutricion': const Color(0xFFE58D57),
      'bienestar': const Color(0xFF7C6FCD),
      'prevencion':const Color(0xFF5BBFBF),
      'emergencias': const Color(0xFFE53935),
    };
    final color = colores[noticia.categoria.toLowerCase()] ?? _teal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
          color: color.withValues(alpha: 0.07),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen si existe
          if (noticia.imagenUrl != null && noticia.imagenUrl!.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
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
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.newspaper_rounded,
                      color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge categoría + tiempo
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            noticia.categoria,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          noticia.tiempoRelativo,
                          style: GoogleFonts.poppins(
                              fontSize: 10, color: _grey),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        noticia.titulo,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        noticia.contenido,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: _grey,
                          height: 1.4,
                        ),
                      ),
                      // Autor si existe
                      if (noticia.autorNombre != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 12, color: _grey),
                          const SizedBox(width: 4),
                          Text(
                            noticia.autorNombre!,
                            style: GoogleFonts.poppins(
                                fontSize: 10, color: _grey),
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
    );
  }

  // ── Botón de Categoría ──────────────────────────────────────────────────────
  Widget _categoryBtn(BuildContext context, IconData icon, String label, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _teal,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _teal.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
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
              color: _dark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Botón de Categoría Rojo (Urgencias) ──────────────────────────────────
  Widget _categoryBtnRed(BuildContext context, IconData icon, String label, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
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
              color: const Color(0xFFE53935),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de Mascota ────────────────────────────────────────────────────
  Widget _petCard(BuildContext context, MascotaModel mascota) {
    return Container(
      width: 156,
      margin: const EdgeInsets.only(right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F9FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SafeNetworkImage(
                    url: mascota.fotoUrl,
                    borderRadius: BorderRadius.circular(16),
                    fallbackIcon: Icons.pets_rounded,
                    fallbackColor: _teal,
                    fallbackIconSize: 48,
                    width: double.infinity,
                  ),
                ),
                // Badge "Perdido" en la esquina superior derecha
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off_rounded,
                            color: Colors.white, size: 9),
                        const SizedBox(width: 3),
                        Text(
                          'Perdido',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
                    mascota.nombre.toLowerCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  GestureDetector(
                    onTap: () => _showPerfil(context, mascota),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _teal,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          'Ver Perfil',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra de Navegación Inferior ──────────────────────────────────────────
  Widget _buildBottomBar(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: _white,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.1),
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
            _navBtn(Icons.store_rounded, 2,
                onTap: () => _showProximamenteSheet(context)),
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

  Widget _navBtn(IconData icon, int index, {required VoidCallback onTap}) {
    final active = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Icon(
          icon,
          size: 26,
          color: active ? _teal : _grey,
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
          backgroundColor: _white,
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
                      fallbackColor: _teal,
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
                    color: _dark,
                  ),
                ),
                Text(
                  '${mascota.especie} · ${mascota.raza}',
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _chip(mascota.edad, Icons.cake_outlined, _orange),
                  const SizedBox(width: 8),
                  _chip(mascota.genero, Icons.transgender_rounded, _teal),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _teal.withValues(alpha: 0.15)),
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
                    color: _teal.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _teal.withValues(alpha: 0.2)),
                  ),
                  child: _cargando
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: _teal, strokeWidth: 2),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.person_rounded,
                                  color: _teal, size: 16),
                              const SizedBox(width: 6),
                              Text('Datos del propietario',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _teal)),
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
                                    color: _teal.withValues(alpha: 0.12),
                                    border: Border.all(
                                        color: _teal.withValues(alpha: 0.35),
                                        width: 2),
                                  ),
                                  child: ClipOval(
                                    child: (_fotoDueno != null &&
                                            _fotoDueno!.isNotEmpty)
                                        ? Image.network(_fotoDueno!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(Icons.person_rounded,
                                                    size: 26, color: _teal))
                                        : const Icon(Icons.person_rounded,
                                            size: 26, color: _teal),
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
                                        const Icon(Icons.badge_outlined,
                                            color: _teal, size: 13),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            _nombreDueno?.isNotEmpty == true
                                                ? _nombreDueno!
                                                : 'No disponible',
                                            style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: _dark),
                                          ),
                                        ),
                                      ]),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        const Icon(Icons.phone_outlined,
                                            color: _teal, size: 13),
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
                                                    ? _dark
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
                      foregroundColor: _teal,
                      side: BorderSide(
                          color: _teal.withValues(alpha: 0.4), width: 1.5),
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

  void _mostrarDialogoAdopcion(
      BuildContext ctx, MascotaModel mascota, String uid) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.volunteer_activism_rounded,
              color: _orange, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Adoptar a ${mascota.nombre}',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
          ),
        ]),
        content: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _orange.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: _orange, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Se enviará una solicitud al dueño. Te notificaremos cuando responda.',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: _orange, height: 1.4),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(
                    color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
          ),
          Consumer<SolicitudAdopcionController>(
            builder: (_, solicCtrl, w) => ElevatedButton.icon(
              onPressed: solicCtrl.isLoading
                  ? null
                  : () async {
                      final ok = await solicCtrl.enviarSolicitud(
                          usuaId: uid, mascId: mascota.id);
                      if (!ctx.mounted) return;
                      Navigator.pop(dCtx);
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(
                          ok
                              ? '¡Solicitud enviada! El dueño te contactará pronto.'
                              : (solicCtrl.errorMessage ?? 'Error al enviar'),
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        backgroundColor: ok
                            ? const Color(0xFF43B89C)
                            : const Color(0xFFE53935),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    },
              icon: solicCtrl.isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.favorite_rounded, size: 16),
              label: Text('Confirmar',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet inline: Agregar Mascota (usado desde el FAB del HomeScreen)
// ─────────────────────────────────────────────────────────────────────────────
class _AddMascotaSheet extends StatefulWidget {
  final VoidCallback? onGuardado;
  const _AddMascotaSheet({this.onGuardado});

  @override
  State<_AddMascotaSheet> createState() => _AddMascotaSheetState();
}

class _AddMascotaSheetState extends State<_AddMascotaSheet> {
  final _nombreCtrl = TextEditingController();
  final _razaCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  String _especie = 'Perro';
  String _genero = 'Macho';
  String _estado = 'propio';
  bool _menorDeUnAnio = false;
  File? _imagenFisica;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _razaCtrl.dispose();
    _edadCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
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
  }

  void _guardar() async {
    final mascotaCtrl = context.read<MascotaController>();
    final authCtrl = context.read<AuthController>();
    final uid = authCtrl.currentUser?.id;
    if (uid == null) return;

    if (_nombreCtrl.text.trim().isEmpty ||
        _razaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y raza son obligatorios.')),
      );
      return;
    }

    // Calcular edad
    final String edadFinal;
    if (_menorDeUnAnio) {
      edadFinal = 'Menor de 1 año';
    } else {
      if (_edadCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa la edad de la mascota.')),
        );
        return;
      }
      final edadVal = int.tryParse(_edadCtrl.text.trim());
      if (edadVal == null || edadVal < 1 || edadVal > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La edad debe ser un número entre 1 y 100.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      edadFinal = _edadCtrl.text.trim();
    }

    String? fotoUrl;
    if (_imagenFisica != null) {
      final ext = _imagenFisica!.path.split('.').last.toLowerCase();
      fotoUrl = await mascotaCtrl.subirImagenMascota(_imagenFisica!, ext);
      if (!mounted) return;
      if (fotoUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mascotaCtrl.errorMessage ?? 'Error al subir imagen'),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }
    }

    final nueva = MascotaModel(
      id: '',
      usuarioId: uid,
      nombre: _nombreCtrl.text.trim(),
      especie: _especie,
      raza: _razaCtrl.text.trim(),
      genero: _genero,
      edad: edadFinal,
      estado: _estado,
      descripcion: (_estado == 'para adoptar' || _estado == 'perdido')
          ? _descripcionCtrl.text.trim()
          : null,
      fotoUrl: fotoUrl,
    );

    final ok = await mascotaCtrl.agregarMascota(nueva);

    if (ok && mounted) {
      widget.onGuardado?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('¡Mascota registrada exitosamente!'),
        backgroundColor: _teal,
      ));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mascotaCtrl.errorMessage ?? 'Error al guardar'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MascotaController>();

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                'Añadir Mascota',
                style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w700, color: _dark,
                ),
              ),
              const SizedBox(height: 20),

              _inputField('Nombre de la mascota', _nombreCtrl, Icons.pets_rounded),
              const SizedBox(height: 14),
              _dropdown('Especie', _especie,
                  ['Perro', 'Gato', 'Conejo', 'Ave', 'Otro'],
                  (v) => setState(() => _especie = v!)),
              const SizedBox(height: 14),
              _inputField('Raza', _razaCtrl, Icons.category_outlined),
              const SizedBox(height: 14),

              // ── Edad con opción menor de 1 año ──
              _edadField(),
              const SizedBox(height: 14),

              _dropdown('Género', _genero, ['Macho', 'Hembra'],
                  (v) => setState(() => _genero = v!)),
              const SizedBox(height: 14),
              _dropdown('Estado', _estado,
                  ['propio', 'para adoptar', 'perdido'],
                  (v) => setState(() => _estado = v!)),
              const SizedBox(height: 14),

              if (_estado == 'para adoptar' || _estado == 'perdido') ...[
                _inputField(
                    _estado == 'perdido'
                        ? 'Descripción (ej. lugar donde se perdió)'
                        : 'Descripción para adopción',
                    _descripcionCtrl,
                    Icons.description_outlined),
                const SizedBox(height: 14),
              ],

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
                  child: _imagenFisica != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_imagenFisica!, fit: BoxFit.cover))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                                color: _teal, size: 34),
                            const SizedBox(height: 8),
                            Text('Toca para subir una imagen',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: _teal)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón guardar
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: ctrl.isLoading ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
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
                      : Text('Registrar Mascota',
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

  Widget _edadField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Checkbox: Menor de 1 año
        GestureDetector(
          onTap: () => setState(() {
            _menorDeUnAnio = !_menorDeUnAnio;
            if (_menorDeUnAnio) _edadCtrl.clear();
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
                    fontWeight:
                        _menorDeUnAnio ? FontWeight.w600 : FontWeight.w400,
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
          _inputField('Edad en años (ej. 3)', _edadCtrl, Icons.cake_outlined,
              keyboard: TextInputType.number),
        ],
      ],
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF2D2D2D)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 13),
        prefixIcon: Icon(icon, color: _teal, size: 20),
        filled: true,
        fillColor: const Color(0xFFF3FAFD),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFFDCEEF0), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _teal, width: 2)),
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
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
}
