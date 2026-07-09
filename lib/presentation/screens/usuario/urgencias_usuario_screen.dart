import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import '../../../data/models/cita_model.dart';
import '../../../data/models/mascota_model.dart';
import '../../../presentation/widgets/header_wave_clipper.dart';
import '../../../data/models/veterinario_model.dart';
import '../../../data/services/fcm_service.dart';
import '../../../domain/controllers/auth_controller.dart';
import '../../../domain/controllers/cita_controller.dart';
import '../../../domain/controllers/mascota_controller.dart';
import '../../../domain/controllers/veterinario_controller.dart';
import 'urgencia_espera_screen.dart';

// ── Paleta ───────────────────────────────────────────────────────────────────
const _red    = Color(0xFFE53935);
const _dark   = Color(0xFF262A2B);
const _grey   = Color(0xFF8A9BB0);
const _teal   = Color(0xFF1CB5C9);

class UrgenciasUsuarioScreen extends StatefulWidget {
  const UrgenciasUsuarioScreen({super.key});

  @override
  State<UrgenciasUsuarioScreen> createState() => _UrgenciasUsuarioScreenState();
}

class _UrgenciasUsuarioScreenState extends State<UrgenciasUsuarioScreen> {
  // Paso: 0 = síntomas/mascota, 1 = seleccionar veterinario, 2 = confirmar/ubicación
  int _paso = 0;

  // Selección mascota
  MascotaModel? _mascotaSeleccionada;
  final _nombreMascotaCtrl = TextEditingController();
  bool _esOtraMascota = false;

  // Síntomas — prioridad siempre CRÍTICA
  final _sintomasCtrl = TextEditingController();

  // Veterinario seleccionado manualmente
  VeterinarioModel? _veterinarioSeleccionado;

  // Modalidad de atención
  String _modalidad = 'local'; // 'local' | 'domicilio'

  // Ubicación domicilio
  LatLng? _ubicacion;
  String? _direccionTexto;
  bool _cargandoUbicacion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthController>().currentUser?.id;
      if (uid != null) {
        context.read<MascotaController>().cargarMascotas(uid);
      }
      // Pre-cargar veterinarios (se usará para asignar uno disponible automáticamente)
      context.read<VeterinarioController>().cargarTodosLosVeterinarios();
    });
  }

  @override
  void dispose() {
    _nombreMascotaCtrl.dispose();
    _sintomasCtrl.dispose();
    super.dispose();
  }

  bool get _paso0Valido {
    final tieneNombre = _esOtraMascota
        ? _nombreMascotaCtrl.text.trim().isNotEmpty
        : _mascotaSeleccionada != null;
    return tieneNombre && _sintomasCtrl.text.trim().isNotEmpty;
  }

  bool get _paso1Valido => _veterinarioSeleccionado != null;

  bool get _paso2Valido {
    if (_modalidad == 'domicilio') return _ubicacion != null;
    return true;
  }

  String get _nombreMascota => _esOtraMascota
      ? _nombreMascotaCtrl.text.trim()
      : (_mascotaSeleccionada?.nombre ?? '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Stack(
        children: [
          // ── Cabecera roja con curva wave ──
          ClipPath(
            clipper: HeaderWaveClipper(),
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 22),
                      onPressed: () {
                        if (_paso > 0) setState(() => _paso--);
                        else Navigator.pop(context);
                      },
                    ),
                    const Spacer(),
                    Column(children: [
                      const Icon(Icons.emergency_rounded, color: Colors.white, size: 28),
                      Text('Urgencia Veterinaria',
                          style: GoogleFonts.poppins(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ]),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ]),
                ),
                // Indicador de pasos (3 pasos)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(children: [
                    _stepDot(0, 'Síntomas'),
                    Expanded(child: Container(height: 2,
                        color: _paso > 0 ? Colors.white : Colors.white.withValues(alpha: 0.3))),
                    _stepDot(1, 'Veterinario'),
                    Expanded(child: Container(height: 2,
                        color: _paso > 1 ? Colors.white : Colors.white.withValues(alpha: 0.3))),
                    _stepDot(2, 'Confirmar'),
                  ]),
                ),
                const SizedBox(height: 8),
                // Contenido por paso
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildPaso(),
                  ),
                ),
                // Botón siguiente/confirmar
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  color: Colors.white,
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _pasoActualValido() ? _avanzar : null,
                      icon: Icon(
                        _paso < 2 ? Icons.arrow_forward_rounded : Icons.emergency_rounded,
                        color: Colors.white),
                      label: Text(
                        _paso < 2 ? 'Siguiente' : 'Enviar Urgencia',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _red.withValues(alpha: 0.35),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _pasoActualValido() {
    if (_paso == 0) return _paso0Valido;
    if (_paso == 1) return _paso1Valido;
    return _paso2Valido;
  }

  void _avanzar() {
    if (_paso < 2) setState(() => _paso++);
    else _confirmarUrgencia();
  }

  Widget _stepDot(int step, String label) {
    final activo = _paso >= step;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activo ? Colors.white : Colors.white.withValues(alpha: 0.3),
        ),
        child: Center(
          child: Text('${step + 1}',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: activo ? _red : Colors.white.withValues(alpha: 0.6))),
        ),
      ),
      const SizedBox(height: 2),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 9,
              color: activo ? Colors.white : Colors.white.withValues(alpha: 0.5))),
    ]);
  }

  Widget _buildPaso() {
    switch (_paso) {
      case 0: return _buildPasoSintomas();
      case 1: return _buildPasoVeterinario();
      case 2: return _buildPasoConfirmar();
      default: return const SizedBox.shrink();
    }
  }

  // ── PASO 0: Síntomas y mascota ────────────────────────────────────────────
  Widget _buildPasoSintomas() {
    return SingleChildScrollView(
      key: const ValueKey(0),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Banner crítica
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFB71C1C).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB71C1C).withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.crisis_alert_rounded, color: Color(0xFFB71C1C), size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text('Esta solicitud se registrará como urgencia CRÍTICA.',
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: const Color(0xFFB71C1C)))),
          ]),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Describe los síntomas', Icons.notes_rounded),
        const SizedBox(height: 10),
        TextField(
          controller: _sintomasCtrl,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.poppins(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Ej: dificultad para respirar, convulsiones, sangrado...',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFFCDD2), width: 1.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _red, width: 2)),
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Mascota afectada', Icons.pets_rounded),
        const SizedBox(height: 10),
        Consumer<MascotaController>(
          builder: (_, ctrl, __) {
            if (ctrl.isLoading) {
              return const Center(child: CircularProgressIndicator(color: _red));
            }
            return Column(children: [
              ...ctrl.mascotas.map((m) => _mascotaCard(m)),
              _otraMascotaCard(),
              if (_esOtraMascota) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _nombreMascotaCtrl,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Nombre de la mascota *',
                    labelStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 12),
                    prefixIcon: const Icon(Icons.badge_outlined, color: _red, size: 18),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFFFCDD2), width: 1.2)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _red, width: 2)),
                  ),
                ),
              ],
            ]);
          },
        ),
      ]),
    );
  }

  Widget _mascotaCard(MascotaModel m) {
    final sel = _mascotaSeleccionada?.id == m.id && !_esOtraMascota;
    return GestureDetector(
      onTap: () => setState(() { _mascotaSeleccionada = m; _esOtraMascota = false; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFFEBEE) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? _red : Colors.grey.shade200, width: sel ? 2 : 1.2),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(m.icon, color: m.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.nombre, style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
            Text('${m.especie} · ${m.raza}',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          if (sel) const Icon(Icons.check_circle_rounded, color: _red, size: 22),
        ]),
      ),
    );
  }

  Widget _otraMascotaCard() {
    final sel = _esOtraMascota;
    return GestureDetector(
      onTap: () => setState(() { _esOtraMascota = true; _mascotaSeleccionada = null; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFFEBEE) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? _red : Colors.grey.shade200, width: sel ? 2 : 1.2),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.add_circle_outline_rounded, color: _red, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Otra mascota', style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
            Text('Ingresa el nombre manualmente',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          if (sel) const Icon(Icons.check_circle_rounded, color: _red, size: 22),
        ]),
      ),
    );
  }

  // ── PASO 1: Seleccionar veterinario ──────────────────────────────────────
  Widget _buildPasoVeterinario() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Banner info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _teal.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: _teal, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Selecciona el veterinario que atenderá tu urgencia.',
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _teal),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Veterinarios disponibles', Icons.medical_services_rounded),
        const SizedBox(height: 12),
        Consumer<VeterinarioController>(
          builder: (_, ctrl, __) {
            if (ctrl.isLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: _red));
            }
            final vets = ctrl.todos;
            if (vets.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(children: [
                  Icon(Icons.person_off_outlined,
                      size: 44, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text('No hay veterinarios registrados',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey.shade500)),
                ]),
              );
            }
            return Column(
              children: vets.map((v) => _vetCard(v)).toList(),
            );
          },
        ),
      ]),
    );
  }

  Widget _vetCard(VeterinarioModel v) {
    final sel = _veterinarioSeleccionado?.id == v.id;
    final nombre = (v.nombre != null && v.nombre!.isNotEmpty)
        ? v.nombre!
        : 'Veterinario';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: sel ? const Color(0xFFFFEBEE) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: sel ? _red : Colors.grey.shade200,
            width: sel ? 2 : 1.2),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          // Fila principal: avatar + info + check
          Row(children: [
            // Avatar
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: sel ? _red.withValues(alpha: 0.4) : _teal.withValues(alpha: 0.25),
                    width: 2),
              ),
              child: ClipOval(
                child: (v.fotoUrl != null && v.fotoUrl!.isNotEmpty)
                    ? Image.network(v.fotoUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_outline_rounded, size: 28, color: _teal))
                    : const Icon(Icons.person_outline_rounded,
                        size: 28, color: _teal),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('Dr/a. $nombre',
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: _dark),
                        overflow: TextOverflow.ellipsis),
                  ),
                  _badgeDisponible(v.disponible),
                ]),
                if (v.especialidad != null && v.especialidad!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(v.especialidad!,
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: _teal,
                          fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 4),
                Row(children: [
                  if (v.experiencia != null) ...[
                    const Icon(Icons.workspace_premium_rounded,
                        size: 12, color: _grey),
                    const SizedBox(width: 3),
                    Text('${v.experiencia} años',
                        style: GoogleFonts.poppins(fontSize: 10, color: _grey)),
                    const SizedBox(width: 10),
                  ],
                  if (v.tarifa != null) ...[
                    const Icon(Icons.attach_money_rounded,
                        size: 13, color: Color(0xFFE58D57)),
                    Text('\$${v.tarifa!.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: const Color(0xFFE58D57))),
                  ],
                ]),
              ]),
            ),
            if (sel)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.check_circle_rounded, color: _red, size: 24),
              ),
          ]),
          const SizedBox(height: 12),
          // Botones: Ver perfil + Seleccionar
          Row(children: [
            // Botón Ver perfil
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _mostrarPerfilVet(v),
                icon: const Icon(Icons.person_outlined, size: 15),
                label: Text('Ver perfil',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _teal,
                  side: const BorderSide(color: _teal, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Botón Seleccionar
            Expanded(
              child: ElevatedButton.icon(
                onPressed: v.disponible
                    ? () => setState(() => _veterinarioSeleccionado = v)
                    : null,
                icon: Icon(
                    sel ? Icons.check_rounded : Icons.emergency_share_rounded,
                    size: 15),
                label: Text(sel ? 'Seleccionado' : 'Seleccionar',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sel ? _red : _red.withValues(alpha: 0.85),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  disabledForegroundColor: Colors.grey.shade400,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _badgeDisponible(bool disponible) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: disponible ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: disponible ? Colors.green.shade400 : Colors.grey.shade400,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          disponible ? 'Disponible' : 'Ocupado',
          style: GoogleFonts.poppins(
            fontSize: 9, fontWeight: FontWeight.w600,
            color: disponible ? Colors.green.shade700 : Colors.grey.shade500,
          ),
        ),
      ]),
    );
  }

  void _mostrarPerfilVet(VeterinarioModel v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PerfilVetUrgenciaSheet(
        vet: v,
        onSeleccionar: v.disponible
            ? () {
                setState(() => _veterinarioSeleccionado = v);
                Navigator.pop(context);
              }
            : null,
      ),
    );
  }

  // ── PASO 2: Confirmar + modalidad + ubicación ─────────────────────────────
  Widget _buildPasoConfirmar() {
    final user = context.read<AuthController>().currentUser;
    final now = DateTime.now();
    final fechaStr = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final horaStr  = '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

    return SingleChildScrollView(
      key: const ValueKey(1),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Banner urgencia
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFB71C1C), _red]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.emergency_rounded, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Urgencia Crítica', style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('Se notificará al veterinario inmediatamente.',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
            ])),
          ]),
        ),
        const SizedBox(height: 16),

        // Resumen mascota / síntomas
        _resumenCard(
          icon: Icons.pets_rounded,
          color: _red,
          titulo: 'Mascota y síntomas',
          items: [
            _resumenRow('Mascota', _nombreMascota),
            _resumenRow('Síntomas', _sintomasCtrl.text.trim()),
            _resumenRow('Prioridad', 'CRÍTICA'),
          ],
        ),
        const SizedBox(height: 16),

        // Resumen veterinario seleccionado
        if (_veterinarioSeleccionado != null)
          _resumenCard(
            icon: Icons.medical_services_rounded,
            color: _teal,
            titulo: 'Veterinario asignado',
            items: [
              _resumenRow('Dr/a.',
                  _veterinarioSeleccionado!.nombre ?? 'Veterinario'),
              if (_veterinarioSeleccionado!.especialidad != null &&
                  _veterinarioSeleccionado!.especialidad!.isNotEmpty)
                _resumenRow('Especialidad',
                    _veterinarioSeleccionado!.especialidad!),
              if (_veterinarioSeleccionado!.tarifa != null)
                _resumenRow('Tarifa',
                    '\$${_veterinarioSeleccionado!.tarifa!.toStringAsFixed(0)}'),
            ],
          ),
        const SizedBox(height: 16),

        // Modalidad de atención
        _sectionTitle('¿Dónde se atenderá?', Icons.location_on_rounded),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _modalidadBtn(
            valor: 'local',
            icon: Icons.store_rounded,
            label: 'Al local',
            descripcion: 'Llevaré a mi mascota',
          )),
          const SizedBox(width: 12),
          Expanded(child: _modalidadBtn(
            valor: 'domicilio',
            icon: Icons.home_rounded,
            label: 'A domicilio',
            descripcion: 'El veterinario viene',
          )),
        ]),

        // Sección ubicación (solo si eligió domicilio)
        if (_modalidad == 'domicilio') ...[
          const SizedBox(height: 20),
          _sectionTitle('Ubicación de domicilio *', Icons.map_rounded),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: _red, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Debes indicar tu ubicación para continuar.',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFB71C1C)))),
            ]),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _abrirSelectorUbicacion,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _ubicacion != null ? _teal : _red.withValues(alpha: 0.5),
                    width: _ubicacion != null ? 2 : 1.5),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: _cargandoUbicacion
                ? const Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2))
                : Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: (_ubicacion != null ? _teal : _red).withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: Icon(
                        _ubicacion != null ? Icons.location_on_rounded : Icons.add_location_alt_rounded,
                        color: _ubicacion != null ? _teal : _red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _ubicacion != null
                      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_direccionTexto ?? 'Ubicación seleccionada',
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: _dark, fontWeight: FontWeight.w500),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text(
                            'Lat: ${_ubicacion!.latitude.toStringAsFixed(4)}  Lng: ${_ubicacion!.longitude.toStringAsFixed(4)}',
                            style: GoogleFonts.poppins(fontSize: 10, color: _grey)),
                        ])
                      : Text('Toca para seleccionar tu ubicación',
                          style: GoogleFonts.poppins(fontSize: 13, color: _red))),
                    Icon(_ubicacion != null ? Icons.edit_location_alt_rounded : Icons.chevron_right_rounded,
                        color: _ubicacion != null ? _teal : _grey, size: 20),
                  ]),
            ),
          ),
          // Mini mapa de previsualización si ya hay ubicación
          if (_ubicacion != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 160,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _ubicacion!,
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cevallos.huellitas',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: _ubicacion!,
                        width: 48, height: 60,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: _red, shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                            child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                          ),
                          CustomPaint(
                            painter: _TrianglePainter(color: _red),
                            size: const Size(14, 7),
                          ),
                        ]),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ],

        const SizedBox(height: 16),
        // Resumen fecha/propietario
        _resumenCard(
          icon: Icons.access_time_rounded,
          color: const Color(0xFF7C6FCD),
          titulo: 'Fecha y hora',
          items: [
            _resumenRow('Fecha', fechaStr.split('-').reversed.join('/')),
            _resumenRow('Hora', horaStr),
            _resumenRow('Propietario', user?.nombre ?? '—'),
          ],
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _modalidadBtn({
    required String valor,
    required IconData icon,
    required String label,
    required String descripcion,
  }) {
    final sel = _modalidad == valor;
    final color = valor == 'domicilio' ? _teal : const Color(0xFF43B89C);
    return GestureDetector(
      onTap: () => setState(() { _modalidad = valor; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? color : Colors.grey.shade200, width: sel ? 2 : 1.2),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: sel ? 0.15 : 0.08),
                shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 2),
          Text(descripcion, style: GoogleFonts.poppins(
              fontSize: 10, color: _grey), textAlign: TextAlign.center),
          if (sel) ...[
            const SizedBox(height: 6),
            Icon(Icons.check_circle_rounded, color: color, size: 18),
          ],
        ]),
      ),
    );
  }

  // ── Selector de ubicación inline (bottomSheet con mapa) ──────────────────
  Future<void> _abrirSelectorUbicacion() async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _UbicacionPickerSheet(),
    );
    if (result != null && mounted) {
      setState(() {
        _ubicacion = result['latLng'] as LatLng?;
        _direccionTexto = result['direccion'] as String?;
      });
    }
  }

  // ── Confirmar y crear la cita urgente ────────────────────────────────────
  Future<void> _confirmarUrgencia() async {
    final auth = context.read<AuthController>();
    final citaCtrl = context.read<CitaController>();
    final user = auth.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final minutos = (now.minute ~/ 5 + 1) * 5;
    final horaAjustada = now.add(Duration(minutes: minutos - now.minute));
    final fechaStr = '${horaAjustada.year}-${horaAjustada.month.toString().padLeft(2,'0')}-${horaAjustada.day.toString().padLeft(2,'0')}';
    final horaStr  = '${horaAjustada.hour.toString().padLeft(2,'0')}:${horaAjustada.minute.toString().padLeft(2,'0')}';

    final motivo = '[URGENCIA:CRÍTICA] ${_sintomasCtrl.text.trim()}';

    // Construir dirección de domicilio si aplica
    String? direccionFinal;
    if (_modalidad == 'domicilio' && _ubicacion != null) {
      final lat = _ubicacion!.latitude.toStringAsFixed(6);
      final lng = _ubicacion!.longitude.toStringAsFixed(6);
      direccionFinal = _direccionTexto != null
          ? '$_direccionTexto (${lat}, ${lng})'
          : 'Lat: $lat, Lng: $lng';
    }

    final cita = CitaModel(
      id: '',
      usuarioId: user.id,
      veteId: _veterinarioSeleccionado?.id,
      mascotaId: _mascotaSeleccionada?.id,
      mascotaNombre: _nombreMascota,
      propietarioNombre: user.nombre,
      motivo: motivo,
      fecha: fechaStr,
      hora: horaStr,
      estado: 'pendiente',
      direccion: direccionFinal,
    );

    final ok = await citaCtrl.crearCita(cita);
    if (!mounted) return;

    if (ok) {
      // Buscar la cita recién creada en la lista del usuario para obtener su ID real
      final citaCreada = citaCtrl.citasDelUsuario.isNotEmpty
          ? citaCtrl.citasDelUsuario.first
          : cita;

      // Enviar notificación push al veterinario seleccionado
      if (_veterinarioSeleccionado?.usuarioId != null &&
          _veterinarioSeleccionado!.usuarioId!.isNotEmpty) {
        FcmService.instance.enviarNotificacionUrgencia(
          veteUserId: _veterinarioSeleccionado!.usuarioId!,
          mascotaNombre: _nombreMascota,
          propietarioNombre: user.nombre,
          sintomas: _sintomasCtrl.text.trim(),
          modalidad: _modalidad,
          citaId: citaCreada.id,
          direccion: direccionFinal,
        );
      }

      // Navegar a la pantalla de espera (reemplaza la pantalla de urgencias)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: citaCtrl,
            child: UrgenciaEsperaScreen(cita: citaCreada),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(citaCtrl.errorMessage ?? 'Error al reportar la urgencia'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────
  Widget _resumenCard({required IconData icon, required Color color,
      required String titulo, required List<Widget> items}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(titulo, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 8),
        ...items,
      ]),
    );
  }

  Widget _resumenRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label, style: GoogleFonts.poppins(
            fontSize: 12, color: Colors.grey.shade500))),
        Expanded(child: Text(value, style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: _dark))),
      ]),
    );
  }

  Widget _sectionTitle(String t, IconData icon) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: _red, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(t, style: GoogleFonts.poppins(
          fontSize: 15, fontWeight: FontWeight.w700, color: _dark))),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sheet: Perfil del Veterinario (para urgencias)
// ═══════════════════════════════════════════════════════════════════════════
class _PerfilVetUrgenciaSheet extends StatelessWidget {
  final VeterinarioModel vet;
  final VoidCallback? onSeleccionar;

  const _PerfilVetUrgenciaSheet({
    required this.vet,
    this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final nombre =
        (vet.nombre != null && vet.nombre!.isNotEmpty) ? vet.nombre! : 'Veterinario';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Cabecera: avatar + nombre + especialidad
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(children: [
              // Avatar
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _teal.withValues(alpha: 0.35), width: 2.5),
                ),
                child: ClipOval(
                  child: (vet.fotoUrl != null && vet.fotoUrl!.isNotEmpty)
                      ? Image.network(vet.fotoUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person_rounded, size: 36, color: _teal))
                      : const Icon(Icons.person_rounded, size: 36, color: _teal),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Dr/a. $nombre',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
                  if (vet.especialidad != null && vet.especialidad!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _teal, borderRadius: BorderRadius.circular(20)),
                      child: Text(vet.especialidad!,
                          style: GoogleFonts.poppins(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Badge disponible
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: vet.disponible
                          ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: vet.disponible
                              ? Colors.green.shade400 : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        vet.disponible ? 'Disponible' : 'No disponible',
                        style: GoogleFonts.poppins(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: vet.disponible
                              ? Colors.green.shade700 : Colors.grey.shade500,
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade100, height: 1),

          // Contenido scrollable
          Expanded(
            child: ListView(
              controller: sc,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                // Stats
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6FAFA),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem(
                        icon: Icons.workspace_premium_rounded,
                        color: _teal,
                        value: vet.experiencia != null
                            ? '${vet.experiencia} años' : 'N/D',
                        label: 'Experiencia',
                      ),
                      Container(width: 1, height: 44, color: Colors.grey.shade200),
                      _statItem(
                        icon: Icons.attach_money_rounded,
                        color: const Color(0xFFE58D57),
                        value: vet.tarifa != null
                            ? '\$${vet.tarifa!.toStringAsFixed(0)}' : 'N/D',
                        label: 'Tarifa',
                      ),
                      Container(width: 1, height: 44, color: Colors.grey.shade200),
                      _statItem(
                        icon: Icons.location_on_rounded,
                        color: _red,
                        value: vet.direccion != null &&
                                vet.direccion!.isNotEmpty
                            ? 'Con dirección' : 'Sin dirección',
                        label: 'Ubicación',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Acerca del profesional
                _infoCard(
                  title: 'Acerca del profesional',
                  icon: Icons.info_outline_rounded,
                  color: _teal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _profileRow(
                        Icons.school_outlined,
                        'Especialidad',
                        (vet.especialidad != null && vet.especialidad!.isNotEmpty)
                            ? vet.especialidad!
                            : 'Medicina general veterinaria',
                        _teal,
                      ),
                      if (vet.experiencia != null) ...[
                        const SizedBox(height: 10),
                        _profileRow(
                          Icons.workspace_premium_rounded,
                          'Experiencia',
                          '${vet.experiencia} años de práctica clínica',
                          _teal,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _profileRow(
                        Icons.verified_outlined,
                        'Registro',
                        'Veterinario certificado y habilitado',
                        _teal,
                      ),
                      if (vet.direccion != null && vet.direccion!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _profileRow(
                          Icons.location_on_outlined,
                          'Dirección',
                          vet.direccion!,
                          _red,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Botón seleccionar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16, offset: const Offset(0, -4))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onSeleccionar,
                icon: const Icon(Icons.emergency_share_rounded, size: 20),
                label: Text(
                  vet.disponible ? 'Seleccionar para urgencia' : 'No disponible',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  disabledForegroundColor: Colors.grey.shade400,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(height: 5),
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w700, color: _dark),
          textAlign: TextAlign.center),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10, color: _grey, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(title.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: _grey, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _profileRow(IconData icon, String label, String value, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 10, color: _grey, fontWeight: FontWeight.w500)),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600, color: _dark)),
      ])),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sheet: Selector de Ubicación para Domicilio
// ═══════════════════════════════════════════════════════════════════════════
class _UbicacionPickerSheet extends StatefulWidget {
  const _UbicacionPickerSheet();
  @override
  State<_UbicacionPickerSheet> createState() => _UbicacionPickerSheetState();
}

class _UbicacionPickerSheetState extends State<_UbicacionPickerSheet> {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();

  LatLng? _pin;
  String? _direccion;
  bool _buscando = false;
  bool _locating = false;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  static const LatLng _centroInicial = LatLng(-1.8312, -78.1834);

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    // Intentar obtener ubicación actual al abrir
    WidgetsBinding.instance.addPostFrameCallback((_) => _obtenerUbicacionActual());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _obtenerDireccion(LatLng punto) async {
    setState(() => _buscando = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${punto.latitude}&lon=${punto.longitude}&format=json&accept-language=es',
      );
      final resp = await http.get(url, headers: {'User-Agent': 'HuellitasCevallos/1.0'});
      if (resp.statusCode == 200) {
        final data = convert.json.decode(resp.body);
        setState(() => _direccion = data['display_name'] as String?);
      }
    } catch (_) {
      setState(() => _direccion = null);
    } finally {
      setState(() => _buscando = false);
    }
  }

  Future<void> _buscarDireccion(String query) async {
    if (query.trim().isEmpty) { setState(() => _searchResults = []); return; }
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1',
      );
      final resp = await http.get(url, headers: {'User-Agent': 'HuellitasCevallos/1.0'});
      if (resp.statusCode == 200) {
        final data = convert.json.decode(resp.body);
        if (data is List) setState(() => _searchResults = data);
      }
    } catch (_) {} finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _obtenerUbicacionActual() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) { setState(() => _locating = false); return; }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) { setState(() => _locating = false); return; }
      }
      if (perm == LocationPermission.deniedForever) { setState(() => _locating = false); return; }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _pin = ll);
      _mapController.move(ll, 16);
      _obtenerDireccion(ll);
    } catch (_) {} finally {
      setState(() => _locating = false);
    }
  }

  void _onTap(TapPosition _, LatLng punto) {
    setState(() { _pin = punto; _searchResults = []; });
    _obtenerDireccion(punto);
  }

  void _confirmar() {
    if (_pin == null) return;
    Navigator.pop(context, {'latLng': _pin, 'direccion': _direccion});
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      height: screenH * 0.88,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // Mapa
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _centroInicial,
                initialZoom: 6,
                onTap: _onTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.cevallos.huellitas',
                ),
                if (_pin != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _pin!,
                      width: 48, height: 60,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: _red, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [BoxShadow(
                                color: _red.withValues(alpha: 0.4),
                                blurRadius: 12, spreadRadius: 2)],
                          ),
                          child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                        ),
                        CustomPaint(
                          painter: _TrianglePainter(color: _red),
                          size: const Size(14, 7),
                        ),
                      ]),
                    ),
                  ]),
              ],
            ),
          ),

          // Barra superior + buscador
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Handle
                Center(child: Container(
                  width: 38, height: 4, margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(2)),
                )),
                Row(children: [
                  _MapBtn(icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12, offset: const Offset(0, 3))],
                      ),
                      child: Row(children: [
                        const SizedBox(width: 12),
                        const Icon(Icons.search_rounded, color: _teal, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(
                          controller: _searchCtrl,
                          style: GoogleFonts.poppins(fontSize: 13, color: _dark),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Buscar dirección...',
                            hintStyle: GoogleFonts.poppins(fontSize: 13, color: _grey),
                            border: InputBorder.none, isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onSubmitted: _buscarDireccion,
                        )),
                        if (_searchCtrl.text.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () { _searchCtrl.clear(); setState(() => _searchResults = []); },
                            child: const Icon(Icons.close_rounded, size: 16, color: _grey)),
                          const SizedBox(width: 8),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _MapBtn(
                    icon: _locating ? Icons.sync_rounded : Icons.my_location_rounded,
                    iconColor: _pin != null ? _red : _grey,
                    loading: _locating,
                    onTap: _obtenerUbicacionActual,
                  ),
                ]),
                // Resultados búsqueda
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6, left: 52),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 14, offset: const Offset(0, 4))],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
                      itemBuilder: (_, i) {
                        final item = _searchResults[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_rounded, color: _red, size: 16),
                          title: Text(item['display_name'] ?? '',
                              style: GoogleFonts.poppins(fontSize: 12, color: _dark),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            final lat = double.tryParse(item['lat']?.toString() ?? '');
                            final lon = double.tryParse(item['lon']?.toString() ?? '');
                            if (lat != null && lon != null) {
                              final ll = LatLng(lat, lon);
                              setState(() { _pin = ll; _searchResults = []; });
                              _mapController.move(ll, 15);
                              _obtenerDireccion(ll);
                              FocusScope.of(context).unfocus();
                            }
                          },
                        );
                      },
                    ),
                  ),
              ]),
            ),
          ),

          // Panel inferior
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(child: Container(
                  width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2)),
                )),
                if (_pin == null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _red.withValues(alpha: 0.2))),
                    child: Row(children: [
                      const Icon(Icons.touch_app_rounded, color: _red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Toca el mapa o usa el GPS\npara marcar tu domicilio',
                          style: GoogleFonts.poppins(fontSize: 12, color: _grey, height: 1.4))),
                    ]),
                  ),
                ] else ...[
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.home_rounded, color: _red, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _buscando
                      ? Row(children: [
                          SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey.shade400)),
                          const SizedBox(width: 8),
                          Text('Obteniendo dirección...', style: GoogleFonts.poppins(fontSize: 12, color: _grey)),
                        ])
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_direccion ?? 'Ubicación seleccionada',
                              style: GoogleFonts.poppins(fontSize: 12, color: _dark, fontWeight: FontWeight.w500),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          Text('Lat: ${_pin!.latitude.toStringAsFixed(5)}  Lng: ${_pin!.longitude.toStringAsFixed(5)}',
                              style: GoogleFonts.poppins(fontSize: 10, color: _grey)),
                        ])),
                    GestureDetector(
                      onTap: () => setState(() { _pin = null; _direccion = null; }),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: Colors.grey.shade100, shape: BoxShape.circle),
                        child: Icon(Icons.close_rounded, size: 14, color: Colors.grey.shade500),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _pin == null ? null : _confirmar,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text('Confirmar ubicación',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade100,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers gráficos ─────────────────────────────────────────────────────────
class _MapBtn extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final bool loading;

  const _MapBtn({required this.icon, this.iconColor, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: loading
          ? const Center(child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _teal)))
          : Icon(icon, color: iconColor ?? _teal, size: 20),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
