import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../data/models/cita_model.dart';
import '../../../data/models/calificacion_model.dart';
import '../../../data/services/calificacion_service.dart';
import '../../../domain/controllers/cita_controller.dart';

// ── Paleta ──────────────────────────────────────────────────────────────────
const _teal      = Color(0xFF1CB5C9);
const _tealDark  = Color(0xFF126E82);
const _green     = Color(0xFF43B89C);
const _orange    = Color(0xFFE58D57);
const _red       = Color(0xFFE53935);
const _purple    = Color(0xFF7C6FCD);
const _dark      = Color(0xFF1A1A2E);
const _grey      = Color(0xFF8A9BB0);
const _headerBg  = Color(0xFF126E82);
const _bgColor   = Color(0xFFF5F6FA);

/// Modo: 'usuario' carga citasDelUsuario, 'veterinario' carga citasDelVeterinario
class HistorialCitasScreen extends StatefulWidget {
  final String modo;
  final String entityId;

  const HistorialCitasScreen({
    super.key,
    required this.modo,
    required this.entityId,
  });

  @override
  State<HistorialCitasScreen> createState() => _HistorialCitasScreenState();
}

class _HistorialCitasScreenState extends State<HistorialCitasScreen> {
  String _filtro = 'todos';
  final CalificacionService _calificacionService = CalificacionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<CitaController>();
      if (widget.modo == 'usuario') {
        ctrl.cargarCitasDeUsuario(widget.entityId);
      } else {
        ctrl.cargarCitasDeVeterinario(widget.entityId);
      }
    });
  }

  List<CitaModel> get _citas {
    final ctrl = context.read<CitaController>();
    final lista = widget.modo == 'usuario'
        ? ctrl.citasDelUsuario
        : ctrl.citasDelVeterinario;
    if (_filtro == 'todos') return lista;
    if (_filtro == 'completada') {
      return lista
          .where((c) =>
              c.estado.toLowerCase() == 'completada' ||
              c.estado.toLowerCase() == 'finalizada')
          .toList();
    }
    return lista.where((c) => c.estado.toLowerCase() == _filtro).toList();
  }

  Color _colorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'completada':
      case 'finalizada':   return _green;
      case 'confirmada':   return _teal;
      case 'en atención':  return _purple;
      case 'cancelada':
      case 'rechazada':    return _red;
      default:             return _orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // Header gradient
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_headerBg, _teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Column(children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Column(children: [
                    const Icon(Icons.history_rounded,
                        color: Colors.white, size: 24),
                    Text('Historial de Citas',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ]),
                  const Spacer(),
                  const SizedBox(width: 48),
                ]),
              ),
              const SizedBox(height: 6),
              // Filtros chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  _chip('todos',     'Todos',       Icons.list_rounded),
                  const SizedBox(width: 8),
                  _chip('pendiente', 'Pendientes',  Icons.schedule_rounded),
                  const SizedBox(width: 8),
                  _chip('confirmada','Confirmadas', Icons.check_circle_outline_rounded),
                  const SizedBox(width: 8),
                  _chip('completada','Completadas', Icons.task_alt_rounded),
                  const SizedBox(width: 8),
                  _chip('cancelada', 'Canceladas',  Icons.cancel_outlined),
                ]),
              ),
              const SizedBox(height: 10),
              // Tabla
              Expanded(
                child: Consumer<CitaController>(
                  builder: (ctx, ctrl, _) {
                    if (ctrl.isLoading) {
                      return const Center(
                          child: CircularProgressIndicator(color: _teal));
                    }
                    final lista = _citas;
                    if (lista.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy_rounded,
                                size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('No hay citas en esta categoría',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade500)),
                          ],
                        ),
                      );
                    }
                    return _TablaHistorial(
                      citas: lista,
                      modo: widget.modo,
                      calificacionService: _calificacionService,
                      colorEstado: _colorEstado,
                    );
                  },
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _chip(String key, String label, IconData icon) {
    final activo = _filtro == key;
    return GestureDetector(
      onTap: () => setState(() => _filtro = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 13,
              color: activo ? _tealDark : Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: activo ? _tealDark : Colors.white)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tabla estilo Excel
// ══════════════════════════════════════════════════════════════════════════════
class _TablaHistorial extends StatelessWidget {
  final List<CitaModel> citas;
  final String modo;
  final CalificacionService calificacionService;
  final Color Function(String) colorEstado;

  const _TablaHistorial({
    required this.citas,
    required this.modo,
    required this.calificacionService,
    required this.colorEstado,
  });

  // Anchos de columna
  static const double _wFecha      = 100;
  static const double _wHora       = 70;
  static const double _wMascota    = 120;
  static const double _wMotivo     = 150;
  static const double _wVet        = 140;
  static const double _wEstado     = 110;
  static const double _wAccion     = 60;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Contador
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${citas.length} cita${citas.length == 1 ? '' : 's'}',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _teal),
              ),
            ),
            const Spacer(),
            Text('Toca una fila para ver detalles',
                style: GoogleFonts.poppins(fontSize: 10, color: _grey)),
          ]),
        ),

        // Tabla con scroll horizontal + vertical
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: _wFecha + _wHora + _wMascota + _wMotivo +
                      (modo == 'usuario' ? _wVet : 0) +
                      _wEstado + _wAccion + 12,
                  child: Column(
                    children: [
                      // Encabezado fijo
                      _encabezado(modo),
                      // Filas scrollables verticalmente
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: citas.length,
                          itemBuilder: (ctx, i) => _fila(
                            context,
                            citas[i],
                            i.isEven,
                            modo,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _encabezado(String modo) {
    return Container(
      color: _headerBg,
      child: Row(children: [
        _th('Fecha',    _wFecha),
        _div(),
        _th('Hora',     _wHora),
        _div(),
        _th('Mascota',  _wMascota),
        _div(),
        _th('Motivo',   _wMotivo),
        _div(),
        if (modo == 'usuario') ...[
          _th('Veterinario', _wVet),
          _div(),
        ],
        _th('Estado',   _wEstado),
        _div(),
        _th('Ver',      _wAccion),
      ]),
    );
  }

  Widget _fila(BuildContext context, CitaModel c, bool par, String modo) {
    final color = colorEstado(c.estado);
    return GestureDetector(
      onTap: () => _mostrarDetalle(context, c),
      child: Container(
        color: par ? Colors.white : const Color(0xFFF8FBFC),
        child: Row(children: [
          // Fecha
          _tc(
            _wFecha,
            Text(
              c.fecha.isNotEmpty
                  ? c.fecha.split('-').reversed.join('/')
                  : '—',
              style: GoogleFonts.poppins(fontSize: 12, color: _dark),
              textAlign: TextAlign.center,
            ),
          ),
          _rdiv(),
          // Hora
          _tc(
            _wHora,
            Text(
              c.hora.isNotEmpty ? c.hora : '—',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _teal),
              textAlign: TextAlign.center,
            ),
          ),
          _rdiv(),
          // Mascota
          _tc(
            _wMascota,
            Row(children: [
              const Icon(Icons.pets_rounded, size: 11, color: _teal),
              const SizedBox(width: 4),
              Flexible(
                child: Text(c.mascotaNombre,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _dark)),
              ),
            ]),
          ),
          _rdiv(),
          // Motivo
          _tc(
            _wMotivo,
            Text(c.motivo.isNotEmpty ? c.motivo : '—',
                overflow: TextOverflow.ellipsis, maxLines: 2,
                style: GoogleFonts.poppins(fontSize: 11, color: _grey)),
          ),
          _rdiv(),
          // Veterinario (solo modo usuario)
          if (modo == 'usuario') ...[
            _tc(
              _wVet,
              Text(
                c.veterinarioNombre.isNotEmpty ? c.veterinarioNombre : '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 11, color: _dark),
              ),
            ),
            _rdiv(),
          ],
          // Estado
          _tc(
            _wEstado,
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: color.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  _capitalizar(c.estado),
                  style: GoogleFonts.poppins(
                      fontSize: 10, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ),
          ),
          _rdiv(),
          // Botón ver
          _tc(
            _wAccion,
            Center(
              child: GestureDetector(
                onTap: () => _mostrarDetalle(context, c),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: _teal.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.open_in_new_rounded,
                      color: _teal, size: 14),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _mostrarDetalle(BuildContext context, CitaModel c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleCitaSheet(
        cita: c,
        modo: modo,
        calificacionService: calificacionService,
        colorEstado: colorEstado,
      ),
    );
  }

  // ── helpers de celdas ────────────────────────────────────────────────────
  Widget _th(String label, double w) {
    return SizedBox(
      width: w, height: 44,
      child: Center(
        child: Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2)),
      ),
    );
  }

  Widget _tc(double w, Widget child) {
    return Container(
        width: w, height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(alignment: Alignment.centerLeft, child: child));
  }

  Widget _div() => Container(
      width: 1, height: 44, color: Colors.white.withValues(alpha: 0.15));

  Widget _rdiv() => Container(
      width: 1, height: 52, color: const Color(0xFFE8EDF2));

  String _capitalizar(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ══════════════════════════════════════════════════════════════════════════════
// Sheet de detalle de cita
// ══════════════════════════════════════════════════════════════════════════════
class _DetalleCitaSheet extends StatelessWidget {
  final CitaModel cita;
  final String modo;
  final CalificacionService calificacionService;
  final Color Function(String) colorEstado;

  const _DetalleCitaSheet({
    required this.cita,
    required this.modo,
    required this.calificacionService,
    required this.colorEstado,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorEstado(cita.estado);
    final esCompletada = cita.estado.toLowerCase() == 'completada' ||
        cita.estado.toLowerCase() == 'finalizada';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
            // Header con color de estado
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.event_note_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cita.mascotaNombre,
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _dark)),
                      Text(cita.motivo,
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: _grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: color.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Text(
                    cita.estado[0].toUpperCase() + cita.estado.substring(1),
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
              ]),
            ),

            // Cuerpo scrollable
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // Fecha y hora
                  _seccion('Fecha y Hora', Icons.calendar_month_rounded, _teal),
                  _filaDetalle('Fecha',
                      cita.fecha.isNotEmpty
                          ? cita.fecha.split('-').reversed.join('/')
                          : '—',
                      Icons.calendar_today_outlined),
                  _filaDetalle('Hora',
                      cita.hora.isNotEmpty ? cita.hora : '—',
                      Icons.access_time_rounded),
                  const SizedBox(height: 12),

                  // Participantes
                  _seccion('Participantes', Icons.people_rounded, _purple),
                  if (cita.propietarioNombre.isNotEmpty)
                    _filaDetalle('Propietario', cita.propietarioNombre,
                        Icons.person_outline_rounded),
                  if (cita.veterinarioNombre.isNotEmpty)
                    _filaDetalle('Veterinario', cita.veterinarioNombre,
                        Icons.medical_services_outlined),
                  if (cita.propietarioNombre.isEmpty &&
                      cita.veterinarioNombre.isEmpty)
                    _filaDetalle('—', '—', Icons.person_outline_rounded),
                  const SizedBox(height: 12),

                  // Ubicación
                  if (cita.direccion != null &&
                      cita.direccion!.isNotEmpty) ...[
                    _seccion('Ubicación', Icons.location_on_rounded, _orange),
                    _filaDetalle('Dirección', cita.direccion!,
                        Icons.location_on_outlined),
                    const SizedBox(height: 12),
                  ],

                  // Notas del veterinario
                  if (cita.descripcion != null &&
                      cita.descripcion!.isNotEmpty) ...[
                    _seccion('Notas del Veterinario',
                        Icons.description_outlined, _green),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _green.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        cita.descripcion!,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: _dark, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Receta
                  if (cita.receta != null && cita.receta!.isNotEmpty) ...[
                    _seccion('Receta / Tratamiento',
                        Icons.medication_rounded, _purple),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _purple.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _purple.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        cita.receta!,
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: _dark, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Calificar (solo usuario + completada)
                  if (modo == 'usuario' &&
                      esCompletada &&
                      cita.veteId != null) ...[
                    _seccion('Calificación', Icons.star_rounded,
                        const Color(0xFFFFB300)),
                    _BotonCalificar(
                      cita: cita,
                      calificacionService: calificacionService,
                    ),
                  ],

                  const SizedBox(height: 8),
                  // Cerrar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _teal,
                        side: BorderSide(
                            color: _teal.withValues(alpha: 0.4), width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Cerrar',
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _dark)),
      ]),
    );
  }

  Widget _filaDetalle(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Row(children: [
        Icon(icon, size: 15, color: _grey),
        const SizedBox(width: 10),
        Text('$label:  ',
            style: GoogleFonts.poppins(
                fontSize: 12, color: _grey, fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _dark,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Botón de calificación (sin cambios de lógica)
// ══════════════════════════════════════════════════════════════════════════════
class _BotonCalificar extends StatefulWidget {
  final CitaModel cita;
  final CalificacionService calificacionService;

  const _BotonCalificar({
    required this.cita,
    required this.calificacionService,
  });

  @override
  State<_BotonCalificar> createState() => _BotonCalificarState();
}

class _BotonCalificarState extends State<_BotonCalificar> {
  CalificacionModel? _calificacion;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final veteId = widget.cita.veteId;
    final usuaId = widget.cita.usuarioId;
    if (veteId == null || veteId.isEmpty || usuaId.isEmpty) {
      if (mounted) setState(() => _cargando = false);
      return;
    }
    final cal = await widget.calificacionService.obtenerCalificacion(
      usuaId: usuaId,
      veteId: veteId,
    );
    if (mounted) setState(() { _calificacion = cal; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFFFFB300)),
          ),
        ),
      );
    }

    if (_calificacion != null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          ...List.generate(5, (i) => Icon(
            i < _calificacion!.puntuacion
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            color: const Color(0xFFFFB300), size: 20)),
          const SizedBox(width: 8),
          Text('Tu calificación',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: Colors.grey.shade500)),
        ]),
      );
    }

    return GestureDetector(
      onTap: () => _mostrarDialogo(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFFFB300).withValues(alpha: 0.5), width: 1.2),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.star_outline_rounded,
              color: Color(0xFFFFB300), size: 20),
          const SizedBox(width: 8),
          Text('Calificar atención',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFFB300))),
        ]),
      ),
    );
  }

  void _mostrarDialogo(BuildContext context) {
    int puntaje = 0;
    final comentarioCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Calificar atención',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: _dark)),
                const SizedBox(height: 4),
                Text('¿Cómo fue la atención del veterinario?',
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: Colors.grey.shade500)),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) => GestureDetector(
                    onTap: () => setModal(() => puntaje = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        i < puntaje ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFFFB300), size: 40),
                    ),
                  )),
                ),
                const SizedBox(height: 6),
                Center(child: Text(
                  puntaje == 0 ? 'Toca una estrella'
                      : ['', 'Muy malo', 'Malo', 'Regular', 'Bueno', 'Excelente'][puntaje],
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFB300)))),
                const SizedBox(height: 16),
                TextField(
                  controller: comentarioCtrl, maxLines: 3,
                  style: GoogleFonts.poppins(fontSize: 13, color: _dark),
                  decoration: InputDecoration(
                    hintText: 'Comentario opcional…',
                    hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                    filled: true, fillColor: const Color(0xFFF5F6FA),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFBBEBF0), width: 1.2)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFFFB300), width: 2)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: puntaje == 0 ? null : () async {
                      final cal = CalificacionModel(
                        id: '',
                        usuaId: widget.cita.usuarioId,
                        veteId: widget.cita.veteId!,
                        puntuacion: puntaje,
                        comentario: comentarioCtrl.text.trim().isNotEmpty
                            ? comentarioCtrl.text.trim() : null,
                      );
                      try {
                        final guardada = await widget.calificacionService
                            .guardarCalificacion(cal);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (mounted) {
                          setState(() => _calificacion = guardada);
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('¡Gracias por tu calificación!',
                                style: GoogleFonts.poppins(fontSize: 13)),
                            backgroundColor: _green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ));
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.redAccent));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade200,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Enviar calificación',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
