import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../domain/controllers/admin_controller.dart';
import '../../../widgets/header_wave_clipper.dart';

class AdminSolicitudesTab extends StatefulWidget {
  const AdminSolicitudesTab({super.key});

  @override
  State<AdminSolicitudesTab> createState() => _AdminSolicitudesTabState();
}

class _AdminSolicitudesTabState extends State<AdminSolicitudesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _filtros = ['Todas', 'Pendientes', 'Aprobadas', 'Rechazadas'];
  static const _estados = ['', 'pendiente', 'aprobada', 'rechazada'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _filtros.length, vsync: this);
    _tab.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminController>().cargarSolicitudesPendientes();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtradas(List<Map<String, dynamic>> todas) {
    final estado = _estados[_tab.index];
    if (estado.isEmpty) return todas;
    return todas.where((s) => s['srol_estado']?.toString() == estado).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminController>();
    final todas = ctrl.todasLasSolicitudes;
    final lista = _filtradas(todas);
    final pendientes = todas
        .where((s) => s['srol_estado'] == 'pendiente')
        .length;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Column(
        children: [
          // ── Cabecera ─────────────────────────────────────────────────
          ClipPath(
            clipper: HeaderWaveClipper(),
            child: Container(
              height: 160,
              color: AppColors.tealBg,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solicitudes de Rol',
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
                              ? AppColors.red
                              : AppColors.darkAlt.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Tabs de filtro ────────────────────────────────────────────
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
                    : todas
                          .where(
                            (s) => s['srol_estado']?.toString() == _estados[i],
                          )
                          .length;
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

          // ── Lista ─────────────────────────────────────────────────────
          Expanded(
            child: ctrl.cargandoSolicitudes
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.tealLight,
                    ),
                  )
                : lista.isEmpty
                ? _EmptyState(filtro: _filtros[_tab.index])
                : RefreshIndicator(
                    color: AppColors.tealLight,
                    onRefresh: () => ctrl.cargarSolicitudesPendientes(),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: lista.length,
                      itemBuilder: (ctx, i) =>
                          _SolicitudCard(solicitud: lista[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de solicitud ──────────────────────────────────────────────────────
class _SolicitudCard extends StatefulWidget {
  final Map<String, dynamic> solicitud;
  const _SolicitudCard({required this.solicitud});

  @override
  State<_SolicitudCard> createState() => _SolicitudCardState();
}

class _SolicitudCardState extends State<_SolicitudCard> {
  bool _procesando = false;

  Map<String, dynamic>? get _usuario =>
      widget.solicitud['usuarios'] as Map<String, dynamic>?;

  String get _nombre => _usuario?['usua_nombre'] as String? ?? 'Usuario';
  String get _correo => _usuario?['usua_correo'] as String? ?? '';
  String? get _fotoUrl => _usuario?['usua_foto_url'] as String?;
  String get _solicitudId => widget.solicitud['srol_id']?.toString() ?? '';
  String get _usuarioId => widget.solicitud['usua_id']?.toString() ?? '';
  String get _estadoActual =>
      widget.solicitud['srol_estado']?.toString() ?? 'pendiente';

  String get _fecha {
    final raw = widget.solicitud['srol_fecha'];
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color get _estadoColor {
    switch (_estadoActual) {
      case 'aprobada':
        return AppColors.green;
      case 'rechazada':
        return AppColors.red;
      default:
        return AppColors.orange;
    }
  }

  String get _estadoLabel {
    switch (_estadoActual) {
      case 'aprobada':
        return 'Aprobada';
      case 'rechazada':
        return 'Rechazada';
      default:
        return 'Pendiente';
    }
  }

  Future<void> _aprobar() async {
    setState(() => _procesando = true);
    final ok = await context.read<AdminController>().aprobarSolicitud(
      solicitudId: _solicitudId,
      usuarioId: _usuarioId,
    );
    if (mounted) {
      setState(() => _procesando = false);
      _snack(
        ok
            ? '✅ Solicitud aprobada — rol Veterinario asignado'
            : '❌ Error al aprobar',
        ok ? AppColors.green : AppColors.red,
      );
    }
  }

  Future<void> _rechazar() async {
    setState(() => _procesando = true);
    final ok = await context.read<AdminController>().rechazarSolicitud(
      _solicitudId,
    );
    if (mounted) {
      setState(() => _procesando = false);
      _snack(
        ok ? 'Solicitud rechazada' : '❌ Error al rechazar',
        ok ? AppColors.grey : AppColors.red,
      );
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _estadoColor.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera ───────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.vetGreen.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.vetGreen.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: _fotoUrl != null && _fotoUrl!.isNotEmpty
                        ? Image.network(
                            _fotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              color: AppColors.vetGreen,
                              size: 24,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: AppColors.vetGreen,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nombre,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkAlt,
                        ),
                      ),
                      Text(
                        _correo,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de estado
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _estadoColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _estadoColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _estadoLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _estadoColor,
                    ),
                  ),
                ),
              ],
            ),

            // ── Detalle ────────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgApp,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.medical_services_rounded,
                    color: AppColors.vetGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Solicita acceso como Veterinario',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.darkAlt,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_fecha.isNotEmpty)
                    Text(
                      _fecha,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.grey,
                      ),
                    ),
                ],
              ),
            ),

            // ── Acciones (solo para pendientes) ────────────────────────
            if (_estadoActual == 'pendiente') ...[
              const SizedBox(height: 14),
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
                            onPressed: _rechazar,
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _aprobar,
                            icon: const Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Aprobar',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.vetGreen,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          ],
        ),
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
              color: AppColors.green.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 44,
              color: AppColors.green.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Sin solicitudes ($filtro)',
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
