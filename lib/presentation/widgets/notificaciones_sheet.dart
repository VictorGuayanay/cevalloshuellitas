import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/models/notificacion_model.dart';
import '../../domain/controllers/notificacion_controller.dart';
import '../../core/app_colors.dart';

const _divider = Color(0xFFEEF1F6);

/// Sheet de notificaciones — solo muestra alertas de mascotas perdidas.
class NotificacionesSheet extends StatefulWidget {
  final ScrollController sc;
  final String rol;
  final VoidCallback onClose;

  const NotificacionesSheet({
    super.key,
    required this.sc,
    required this.rol,
    required this.onClose,
  });

  @override
  State<NotificacionesSheet> createState() => _NotificacionesSheetState();
}

class _NotificacionesSheetState extends State<NotificacionesSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _cats = ['Todas', 'Perdidos'];
  static const _catIcons = [
    Icons.notifications_rounded,
    Icons.location_off_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _cats.length, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  /// Filtra la lista según la pestaña activa.
  /// Tab 0 "Todas": devuelve todo. Tab 1 "Perdidos": solo mascotaPerdida.
  List<NotificacionModel> _filtrar(List<NotificacionModel> lista) {
    if (_tab.index == 0) return lista;
    return lista
        .where((n) => n.tipo == TipoNotificacion.mascotaPerdida)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Consumer<NotificacionController>(
        builder: (ctx, notifCtrl, _) {
          final todas = notifCtrl.notificaciones.toList()
            ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
          final noLeidas = todas.where((n) => !n.leida).length;
          final lista = _filtrar(todas);

          final urgentes =
              lista
                  .where(
                    (n) =>
                        n.prioridad == PrioridadNotificacion.alta && !n.leida,
                  )
                  .toList()
                ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
          final resto =
              lista
                  .where(
                    (n) =>
                        !(n.prioridad == PrioridadNotificacion.alta &&
                            !n.leida),
                  )
                  .toList()
                ..sort((a, b) => b.creadaEn.compareTo(a.creadaEn));

          return Column(
            children: [
              const SizedBox(height: 12),
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
              _buildCabecera(notifCtrl, todas, noLeidas),
              const SizedBox(height: 16),
              _buildTabs(todas),
              const SizedBox(height: 4),
              const Divider(height: 1, color: _divider),
              Expanded(
                child: lista.isEmpty
                    ? _EmptyState(tabIndex: _tab.index)
                    : ListView(
                        controller: widget.sc,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                        children: [
                          if (_tab.index == 0 && urgentes.isNotEmpty) ...[
                            _SectionHeader(
                              label: 'Requieren atención',
                              icon: Icons.priority_high_rounded,
                              color: AppColors.red,
                            ),
                            ...urgentes.map(
                              (n) => _NotifCard(
                                notif: n,
                                notifCtrl: notifCtrl,
                                destacada: true,
                              ),
                            ),
                            if (resto.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _SectionHeader(
                                label: 'Anteriores',
                                icon: Icons.history_rounded,
                                color: Colors.grey.shade400,
                              ),
                            ],
                            ...resto.map(
                              (n) => _NotifCard(notif: n, notifCtrl: notifCtrl),
                            ),
                          ] else
                            ...lista.map(
                              (n) => _NotifCard(notif: n, notifCtrl: notifCtrl),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCabecera(
    NotificacionController notifCtrl,
    List<NotificacionModel> todas,
    int noLeidas,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2FA3A3), Color(0xFF1A7A7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notificaciones',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkAlt,
                    letterSpacing: -0.3,
                  ),
                ),
                if (noLeidas > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$noLeidas sin leer',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.teal,
                      ),
                    ),
                  )
                else
                  Text(
                    'Todo al día ✓',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (noLeidas > 0)
                _ActionBtn(
                  label: 'Leer todo',
                  icon: Icons.done_all_rounded,
                  color: AppColors.green,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    for (final n in todas.where((n) => !n.leida)) {
                      notifCtrl.marcarNotificacionVista(n.id);
                    }
                  },
                ),
              if (todas.isNotEmpty) ...[
                const SizedBox(height: 4),
                _ActionBtn(
                  label: 'Limpiar',
                  icon: Icons.delete_sweep_rounded,
                  color: Colors.grey.shade500,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    notifCtrl.limpiarNotificaciones();
                    widget.onClose();
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(List<NotificacionModel> todas) {
    // Tab "Todas": total no leídas. Tab "Perdidos": solo las de tipo perdida no leídas.
    final noLeidosTodas = todas.where((n) => !n.leida).length;
    final noLeidosPerdidos = todas
        .where((n) => n.tipo == TipoNotificacion.mascotaPerdida && !n.leida)
        .length;
    final counts = [noLeidosTodas, noLeidosPerdidos];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: _tab,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: AppColors.teal,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade400,
        labelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        padding: EdgeInsets.zero,
        tabs: List.generate(_cats.length, (i) {
          return Tab(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_catIcons[i], size: 14),
                  const SizedBox(width: 5),
                  Text(_cats[i]),
                  if (counts[i] > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _tab.index == i
                            ? Colors.white.withValues(alpha: 0.3)
                            : AppColors.teal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${counts[i]}',
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
    );
  }
}

// ── Botón de acción compacto ──────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Encabezado de sección ─────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Estado vacío ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final int tabIndex;
  const _EmptyState({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_off_rounded,
              size: 40,
              color: AppColors.teal.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Sin alertas',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay mascotas perdidas\nreportadas por ahora.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta individual de notificación ────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final NotificacionModel notif;
  final NotificacionController notifCtrl;
  final bool destacada;

  const _NotifCard({
    required this.notif,
    required this.notifCtrl,
    this.destacada = false,
  });

  static const Map<TipoNotificacion, IconData> _icons = {
    TipoNotificacion.mascotaPerdida: Icons.location_off_rounded,
  };

  static const Map<TipoNotificacion, String> _etiquetas = {
    TipoNotificacion.mascotaPerdida: '🚨 Perdida',
  };

  void _eliminar() {
    HapticFeedback.lightImpact();
    notifCtrl.eliminarNotificacion(notif.id);
  }

  void _marcarLeida() {
    HapticFeedback.selectionClick();
    if (!notif.leida) notifCtrl.marcarNotificacionVista(notif.id);
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(notif.colorValue);
    final icon = _icons[notif.tipo] ?? Icons.notifications_rounded;
    final etiqueta = _etiquetas[notif.tipo] ?? '';
    final leida = notif.leida;

    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _eliminar(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: 3),
            Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: _marcarLeida,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: leida ? Colors.white : color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: leida
                  ? _divider
                  : color.withValues(alpha: destacada ? 0.45 : 0.22),
              width: destacada && !leida ? 1.8 : 1.0,
            ),
            boxShadow: leida
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: leida ? 0.07 : 0.15),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            icon,
                            color: leida ? color.withValues(alpha: 0.4) : color,
                            size: 24,
                          ),
                        ),
                        if (destacada && !leida)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.red,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  notif.titulo,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: leida
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                    color: leida
                                        ? Colors.grey.shade500
                                        : AppColors.darkAlt,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: leida
                                      ? Colors.grey.shade100
                                      : color.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  etiqueta,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: leida ? Colors.grey.shade400 : color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            notif.cuerpo,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              height: 1.45,
                              color: leida
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (notif.mascotaNombre != null)
                      _InfoChip(
                        icon: Icons.pets_rounded,
                        label: notif.mascotaNombre!,
                        color: leida ? Colors.grey.shade300 : color,
                      ),
                    const Spacer(),
                    Text(
                      notif.tiempoRelativo,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: leida
                            ? Colors.grey.shade300
                            : Colors.grey.shade400,
                      ),
                    ),
                    if (!leida) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Chip de información pequeño ───────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
