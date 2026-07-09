import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../data/models/cita_model.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../../domain/controllers/cita_controller.dart';
import '../../../domain/controllers/veterinario_controller.dart';
import 'detalle_cita_screen.dart';

// ── Paleta ────────────────────────────────────────────────────────────────────
const _tealDark  = Color(0xFF126E82);
const _teal      = Color(0xFF1CB5C9);
const _green     = Color(0xFF43B89C);
const _orange    = Color(0xFFE58D57);
const _red       = Color(0xFFE53935);
const _purple    = Color(0xFF7C6FCD);
const _dark      = Color(0xFF1A1A2E);
const _grey      = Color(0xFF8A9BB0);
const _headerBg  = Color(0xFF126E82);

class VetCitasScreen extends StatefulWidget {
  const VetCitasScreen({super.key});

  @override
  State<VetCitasScreen> createState() => _VetCitasScreenState();
}

class _VetCitasScreenState extends State<VetCitasScreen> {
  DateTime _mesActual = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _diaSeleccionado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final citaCtrl = context.read<CitaController>();
      final vetCtrl  = context.read<VeterinarioController>();
      final uid      = context.read<AuthController>().currentUser?.id;

      citaCtrl.cargarCitasHoy();
      citaCtrl.cargarTodasLasCitas();

      if (uid != null) {
        await vetCtrl.cargarPerfil(uid);
        final veteId = vetCtrl.perfil?.id;
        if (veteId != null && veteId.isNotEmpty) {
          citaCtrl.cargarCitasDeVeterinario(veteId);
        }
      }
    });
  }

  // ── helpers ─────────────────────────────────────────────────────────────────
  String _fechaKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, List<CitaModel>> _agruparPorFecha(List<CitaModel> citas) {
    final Map<String, List<CitaModel>> mapa = {};
    for (final c in citas) {
      mapa.putIfAbsent(c.fecha, () => []).add(c);
    }
    return mapa;
  }

  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'confirmada':   return _teal;
      case 'completada':
      case 'finalizada':   return _green;
      case 'cancelada':
      case 'rechazada':    return _red;
      case 'en atención':  return _purple;
      default:             return _orange;
    }
  }

  IconData _iconEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'confirmada':   return Icons.check_circle_outline_rounded;
      case 'completada':
      case 'finalizada':   return Icons.task_alt_rounded;
      case 'cancelada':
      case 'rechazada':    return Icons.cancel_outlined;
      case 'en atención':  return Icons.play_circle_outline_rounded;
      default:             return Icons.schedule_rounded;
    }
  }

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNuevaCitaSheet(context),
        backgroundColor: _teal,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Nueva Cita',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Consumer<CitaController>(
        builder: (ctx, ctrl, _) {
          final mapa = _agruparPorFecha(ctrl.citasDelVeterinario);
          final citasDia = _diaSeleccionado != null
              ? (mapa[_fechaKey(_diaSeleccionado!)] ?? [])
              : <CitaModel>[];

          return Stack(
            children: [
              // Header
              ClipPath(
                clipper: _HeaderClipper(),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF126E82), Color(0xFF1CB5C9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    // AppBar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Column(children: [
                          const Icon(Icons.calendar_month_rounded,
                              color: Colors.white, size: 26),
                          Text('Gestión de Citas',
                              style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ]),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ]),
                    ),
                    // Stats chips
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        _statChip('${ctrl.citasPendientesHoy}',
                            'Pendientes hoy', _orange),
                        const SizedBox(width: 10),
                        _statChip('${ctrl.citasCompletadasHoy}',
                            'Completadas', _green),
                        const SizedBox(width: 10),
                        _statChip('${ctrl.citasDelVeterinario.length}',
                            'Mis citas', _purple),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // ── Contenido scrollable ─────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Calendario
                            _CalendarioCard(
                              mesActual: _mesActual,
                              diaSeleccionado: _diaSeleccionado,
                              mapaFechas: mapa,
                              onMesAnterior: () => setState(() {
                                _mesActual = DateTime(
                                    _mesActual.year, _mesActual.month - 1);
                                _diaSeleccionado = null;
                              }),
                              onMesSiguiente: () => setState(() {
                                _mesActual = DateTime(
                                    _mesActual.year, _mesActual.month + 1);
                                _diaSeleccionado = null;
                              }),
                              onDiaTap: (d) => setState(
                                  () => _diaSeleccionado =
                                      _diaSeleccionado != null &&
                                              _fechaKey(_diaSeleccionado!) ==
                                                  _fechaKey(d)
                                          ? null
                                          : d),
                              colorEstado: _colorEstado,
                            ),
                            const SizedBox(height: 16),

                            // Título sección lista
                            if (_diaSeleccionado != null) ...[
                              _tituloSeccion(
                                  _diaSeleccionado!, citasDia.length),
                              const SizedBox(height: 10),
                              if (ctrl.isLoading)
                                const Center(
                                    child: CircularProgressIndicator(
                                        color: _teal))
                              else if (citasDia.isEmpty)
                                _emptyDia()
                              else
                                ...citasDia.map((c) => _citaCard(c)),
                            ] else ...[
                              _seccionProximas(ctrl.citasDelVeterinario),
                            ],
                          ],
                        ),
                      ),
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

  // ── Widgets helper ───────────────────────────────────────────────────────────
  Widget _statChip(String numero, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(numero,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800,
                  color: Colors.white)),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                  height: 1.2)),
        ]),
      ),
    );
  }

  Widget _tituloSeccion(DateTime dia, int total) {
    final meses = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.event_note_rounded, color: _teal, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '${dia.day} de ${meses[dia.month]} ${dia.year}',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: _dark),
          ),
          Text(
            '$total cita${total == 1 ? '' : 's'}',
            style: GoogleFonts.poppins(fontSize: 12, color: _grey),
          ),
        ]),
      ),
    ]);
  }

  Widget _emptyDia() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Icon(Icons.event_available_rounded,
            size: 44, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text('Sin citas este día',
            style: GoogleFonts.poppins(
                fontSize: 13, color: Colors.grey.shade400)),
      ]),
    );
  }

  Widget _seccionProximas(List<CitaModel> todas) {
    final hoy = DateTime.now();
    final proximas = todas.where((c) {
      try {
        final parts = c.fecha.split('-');
        if (parts.length < 3) return false;
        final d = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        return !d.isBefore(DateTime(hoy.year, hoy.month, hoy.day)) &&
            (c.estado.toLowerCase() == 'pendiente' ||
                c.estado.toLowerCase() == 'confirmada');
      } catch (_) {
        return false;
      }
    }).toList()
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.upcoming_rounded, color: _orange, size: 18),
        ),
        const SizedBox(width: 10),
        Text('Próximas citas',
            style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w700, color: _dark)),
        const Spacer(),
        Text('${proximas.length} pendiente${proximas.length == 1 ? '' : 's'}',
            style: GoogleFonts.poppins(fontSize: 11, color: _grey)),
      ]),
      const SizedBox(height: 12),
      if (proximas.isEmpty)
        _emptyDia()
      else
        ...proximas.take(10).map((c) => _citaCard(c)),
    ]);
  }

  Widget _citaCard(CitaModel cita) {
    final color = _colorEstado(cita.estado);
    final icon  = _iconEstado(cita.estado);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalleCitaScreen(cita: cita)),
      ).then((_) {
        if (!context.mounted) return;
        final veteId = context.read<VeterinarioController>().perfil?.id;
        if (veteId != null) {
          context.read<CitaController>().cargarCitasDeVeterinario(veteId);
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(cita.mascotaNombre,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: _dark)),
                if (cita.propietarioNombre.isNotEmpty)
                  Text(cita.propietarioNombre,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: _grey)),
                const SizedBox(height: 4),
                Text(cita.motivo,
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(cita.hora,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(height: 2),
              Text(cita.fecha.split('-').reversed.join('/'),
                  style: GoogleFonts.poppins(
                      fontSize: 10, color: Colors.grey.shade400)),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.grey, size: 18),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showNuevaCitaSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NuevaCitaSheet(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Calendario interactivo
// ══════════════════════════════════════════════════════════════════════════════
class _CalendarioCard extends StatelessWidget {
  final DateTime mesActual;
  final DateTime? diaSeleccionado;
  final Map<String, List<CitaModel>> mapaFechas;
  final VoidCallback onMesAnterior;
  final VoidCallback onMesSiguiente;
  final void Function(DateTime) onDiaTap;
  final Color Function(String) colorEstado;

  const _CalendarioCard({
    required this.mesActual,
    required this.diaSeleccionado,
    required this.mapaFechas,
    required this.onMesAnterior,
    required this.onMesSiguiente,
    required this.onDiaTap,
    required this.colorEstado,
  });

  static const _meses = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  static const _dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final primerDia = DateTime(mesActual.year, mesActual.month, 1);
    // weekday: 1=lunes .. 7=domingo → offset para la cuadrícula
    final offset = (primerDia.weekday - 1) % 7;
    final diasEnMes =
        DateTime(mesActual.year, mesActual.month + 1, 0).day;
    final hoy = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // ── Navegación mes ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            IconButton(
              onPressed: onMesAnterior,
              icon: const Icon(Icons.chevron_left_rounded,
                  color: _tealDark, size: 26),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            Expanded(
              child: Text(
                '${_meses[mesActual.month]} ${mesActual.year}',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _dark),
              ),
            ),
            IconButton(
              onPressed: onMesSiguiente,
              icon: const Icon(Icons.chevron_right_rounded,
                  color: _tealDark, size: 26),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
        // ── Encabezado días semana ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _dias.map((d) => SizedBox(
              width: 36,
              child: Text(d,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _grey)),
            )).toList(),
          ),
        ),
        const SizedBox(height: 6),

        // ── Cuadrícula de días ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: offset + diasEnMes,
            itemBuilder: (ctx, index) {
              if (index < offset) return const SizedBox();
              final numDia = index - offset + 1;
              final fecha  = DateTime(mesActual.year, mesActual.month, numDia);
              final key    = _key(fecha);
              final citas  = mapaFechas[key] ?? [];
              final esHoy  = fecha.year == hoy.year &&
                  fecha.month == hoy.month &&
                  fecha.day == hoy.day;
              final esSel  = diaSeleccionado != null &&
                  _key(diaSeleccionado!) == key;

              // Colores de puntos (máx 3 únicos)
              final coloresPuntos = citas
                  .map((c) => colorEstado(c.estado))
                  .toSet()
                  .take(3)
                  .toList();

              return GestureDetector(
                onTap: () => onDiaTap(fecha),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: esSel
                        ? _teal
                        : esHoy
                            ? _teal.withValues(alpha: 0.12)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: esHoy && !esSel
                        ? Border.all(color: _teal, width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$numDia',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: esHoy || esSel
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: esSel
                              ? Colors.white
                              : esHoy
                                  ? _teal
                                  : _dark,
                        ),
                      ),
                      if (coloresPuntos.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: coloresPuntos.map((c) => Container(
                            width: 5, height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: esSel ? Colors.white : c,
                              shape: BoxShape.circle,
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ── Leyenda ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _leyendaItem(_orange, 'Pendiente'),
              const SizedBox(width: 14),
              _leyendaItem(_teal, 'Confirmada'),
              const SizedBox(width: 14),
              _leyendaItem(_green, 'Completada'),
              const SizedBox(width: 14),
              _leyendaItem(_red, 'Cancelada'),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _leyendaItem(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.poppins(fontSize: 9, color: _grey)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sheet: Nueva Cita
// ══════════════════════════════════════════════════════════════════════════════
class _NuevaCitaSheet extends StatefulWidget {
  const _NuevaCitaSheet();

  @override
  State<_NuevaCitaSheet> createState() => _NuevaCitaSheetState();
}

class _NuevaCitaSheetState extends State<_NuevaCitaSheet> {
  final _mascotaCtrl     = TextEditingController();
  final _propietarioCtrl = TextEditingController();
  final _motivoCtrl      = TextEditingController();
  String? _fechaSel;
  String? _horaSel;

  final List<String> _horas = [
    '08:00', '08:30', '09:00', '09:30', '10:00', '10:30',
    '11:00', '11:30', '14:00', '14:30', '15:00', '15:30', '16:00',
  ];

  @override
  void dispose() {
    _mascotaCtrl.dispose();
    _propietarioCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  void _guardar() async {
    if (_mascotaCtrl.text.trim().isEmpty ||
        _propietarioCtrl.text.trim().isEmpty ||
        _motivoCtrl.text.trim().isEmpty ||
        _fechaSel == null || _horaSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor completa todos los campos')));
      return;
    }
    final veteId = context.read<VeterinarioController>().perfil?.id ?? '';
    final cita = CitaModel(
      id: '',
      usuarioId: '',
      veteId: veteId.isNotEmpty ? veteId : null,
      mascotaId: null,
      mascotaNombre: _mascotaCtrl.text.trim(),
      propietarioNombre: _propietarioCtrl.text.trim(),
      motivo: _motivoCtrl.text.trim(),
      fecha: _fechaSel!,
      hora: _horaSel!,
      estado: 'confirmada',
    );
    final ok = await context.read<CitaController>().crearCita(cita);
    if (ok && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cita registrada exitosamente'),
        backgroundColor: _teal,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              Text('Nueva Cita',
                  style: GoogleFonts.poppins(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: _dark)),
              const SizedBox(height: 18),
              _field('Nombre de la mascota', _mascotaCtrl,
                  Icons.pets_rounded),
              const SizedBox(height: 12),
              _field('Nombre del propietario', _propietarioCtrl,
                  Icons.person_outline_rounded),
              const SizedBox(height: 12),
              _field('Motivo de consulta', _motivoCtrl,
                  Icons.medical_services_outlined),
              const SizedBox(height: 12),
              // Fecha
              GestureDetector(
                onTap: () async {
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    builder: (ctx, child) => Theme(
                      data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(
                              primary: _teal)),
                      child: child!,
                    ),
                  );
                  if (fecha != null) {
                    setState(() {
                      _fechaSel =
                          '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFBBEBF0), width: 1.2),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: _teal, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _fechaSel ?? 'Seleccionar fecha',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: _fechaSel != null
                              ? _dark
                              : Colors.grey.shade400),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Text('Horario',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: _dark)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _horas.map((h) {
                  final sel = _horaSel == h;
                  return GestureDetector(
                    onTap: () => setState(() => _horaSel = h),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? _teal : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(h,
                          style: GoogleFonts.poppins(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: sel
                                  ? Colors.white
                                  : Colors.grey.shade700)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 52,
                child: Consumer<CitaController>(
                  builder: (ctx, ctrl, _) => ElevatedButton(
                    onPressed: ctrl.isLoading ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: ctrl.isLoading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text('Registrar Cita',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF2D2D2D)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(
            color: Colors.grey.shade500, fontSize: 13),
        prefixIcon: Icon(icon, color: _teal, size: 20),
        filled: true,
        fillColor: const Color(0xFFF0FAFB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: Color(0xFFBBEBF0), width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _teal, width: 2)),
      ),
    );
  }
}

// ── Clipper cabecera ──────────────────────────────────────────────────────────
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
