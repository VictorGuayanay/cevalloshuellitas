import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/cita_model.dart';
import '../../data/models/notificacion_model.dart';
import '../../data/services/cita_service.dart';
import '../../data/services/notificacion_local_service.dart';

class CitaController extends ChangeNotifier {
  final CitaService _citaService = CitaService();

  List<CitaModel> _citasHoy = [];
  List<CitaModel> _todasLasCitas = [];
  List<CitaModel> _citasDelUsuario = [];
  List<CitaModel> _citasDelVeterinario = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ─── Notificaciones in-app unificadas ─────────────────────────────────────
  final List<NotificacionModel> _notificaciones = [];
  dynamic _realtimeChannel;

  // IDs de notificaciones push ya disparadas (evita duplicado por reconexión Realtime)
  final Set<String> _pushEnviadas = {};

  // Timers de recordatorio por citaId (30 min y hora exacta)
  final Map<String, Timer> _timers = {};

  /// Última cita de urgencia que recibió respuesta del veterinario.
  /// La pantalla de espera lo escucha para reaccionar al cambio.
  CitaModel? _ultimaRespuestaUrgencia;
  CitaModel? get ultimaRespuestaUrgencia => _ultimaRespuestaUrgencia;

  /// Limpia la última respuesta de urgencia (llamar después de mostrarla).
  void limpiarRespuestaUrgencia() {
    _ultimaRespuestaUrgencia = null;
  }

  List<NotificacionModel> get notificaciones =>
      List.unmodifiable(_notificaciones);
  int get totalNotificaciones =>
      _notificaciones.where((n) => !n.leida).length;

  // Compatibilidad con código existente que usa notificacionesCitas
  List<CitaModel> get notificacionesCitas {
    return _notificaciones
        .where((n) =>
            n.tipo == TipoNotificacion.citaConfirmada ||
            n.tipo == TipoNotificacion.citaRechazada ||
            n.tipo == TipoNotificacion.nuevaCita)
        .map((n) {
      // Buscar la cita real en las listas
      return _citasDelUsuario.firstWhere(
        (c) => c.id == n.citaId,
        orElse: () => _citasDelVeterinario.firstWhere(
          (c) => c.id == n.citaId,
          orElse: () => CitaModel(
            id: n.citaId ?? '',
            usuarioId: '',
            mascotaNombre: n.mascotaNombre ?? '',
            propietarioNombre: '',
            motivo: n.cuerpo,
            fecha: n.fecha ?? '',
            hora: n.hora ?? '',
            estado: n.tipo == TipoNotificacion.citaConfirmada
                ? 'confirmada'
                : 'rechazada',
          ),
        ),
      );
    }).toList();
  }

  List<CitaModel> get citasHoy => _citasHoy;
  List<CitaModel> get todasLasCitas => _todasLasCitas;
  List<CitaModel> get citasDelUsuario => _citasDelUsuario;
  List<CitaModel> get citasDelVeterinario => _citasDelVeterinario;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get citasPendientesHoy =>
      _citasHoy
          .where((c) => c.estado == 'pendiente' || c.estado == 'confirmada')
          .length;
  int get citasCompletadasHoy =>
      _citasHoy.where((c) => c.estado == 'completada').length;

  // ── Cargas ────────────────────────────────────────────────────────────────
  Future<void> cargarCitasHoy() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _citasHoy = await _citaService.obtenerCitasHoy();
    } catch (e) {
      _errorMessage = 'Error al cargar citas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cargarTodasLasCitas() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _todasLasCitas = await _citaService.obtenerTodasLasCitas();
    } catch (e) {
      _errorMessage = 'Error al cargar historial: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cargarCitasDeUsuario(String usuarioId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _citasDelUsuario = await _citaService.obtenerCitasPorUsuario(usuarioId);
    } catch (e) {
      _errorMessage = 'Error al cargar historial: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cargarCitasDeVeterinario(String veteId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _citasDelVeterinario =
          await _citaService.obtenerCitasPorVeterinario(veteId);
    } catch (e) {
      _errorMessage = 'Error al cargar historial: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtiene los horarios ocupados para un veterinario en una fecha específica.
  Future<Set<String>> obtenerHorasOcupadas({
    required String veteId,
    required String fecha,
  }) async {
    return _citaService.obtenerHorasOcupadas(veteId: veteId, fecha: fecha);
  }

  Future<bool> crearCita(CitaModel cita) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final nueva = await _citaService.crearCita(cita);
      _citasHoy.add(nueva);
      _citasDelUsuario.insert(0, nueva);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      _errorMessage = msg;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarEstado(String citaId, String nuevoEstado) async {
    try {
      final actualizada =
          await _citaService.actualizarEstadoCita(citaId, nuevoEstado);
      _actualizarEnListas(actualizada);
      notifyListeners();
      return true;
    } catch (e) {
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      _errorMessage = msg;
      notifyListeners();
      return false;
    }
  }

  Future<bool> guardarConsulta({
    required String citaId,
    required String estado,
    String? descripcion,
    String? receta,
    String? mascotaId,
    String? veteId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final actualizada = await _citaService.guardarConsulta(
        citaId: citaId,
        estado: estado,
        descripcion: descripcion,
        receta: receta,
        mascotaId: mascotaId,
        veteId: veteId,
      );
      _actualizarEnListas(actualizada);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      _errorMessage = msg;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _actualizarEnListas(CitaModel actualizada) {
    final id = actualizada.id;
    final idx0 = _citasHoy.indexWhere((c) => c.id == id);
    if (idx0 != -1) _citasHoy[idx0] = actualizada;
    final idx1 = _todasLasCitas.indexWhere((c) => c.id == id);
    if (idx1 != -1) _todasLasCitas[idx1] = actualizada;
    final idx2 = _citasDelVeterinario.indexWhere((c) => c.id == id);
    if (idx2 != -1) _citasDelVeterinario[idx2] = actualizada;
    final idx3 = _citasDelUsuario.indexWhere((c) => c.id == id);
    if (idx3 != -1) _citasDelUsuario[idx3] = actualizada;
  }


  // ── Realtime + Recordatorios ──────────────────────────────────────────────

  /// Suscribe al canal Realtime.
  /// - veterinario: INSERT en citas donde vete_id == entityId
  /// - usuario:     UPDATE en citas donde usua_id == entityId
  void suscribirNotificaciones({
    required String entityId,
    required String rol,
  }) {
    _realtimeChannel?.unsubscribe();

    _realtimeChannel = Supabase.instance.client
        .channel('citas_realtime_$entityId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'citas',
          callback: (payload) async {
            final eventType = payload.eventType;
            final record = payload.newRecord;

            if (rol == 'veterinario') {
              // ── Nueva solicitud de cita (INSERT) ──────────────────────────
              if (eventType == PostgresChangeEvent.insert) {
                final veteId = record['vete_id']?.toString() ?? '';
                if (veteId == entityId) {
                  try {
                    final full = await _fetchCitaCompleta(
                        record['cita_id'].toString());
                    final model = CitaModel.fromJson(full);

                    // Detectar si es urgencia crítica
                    final esUrgencia = model.motivo.startsWith('[URGENCIA:');

                    if (esUrgencia) {
                      // Notificación push urgente con canal de alta prioridad
                      final sintomas = model.motivo
                          .replaceAll(RegExp(r'\[URGENCIA:\w+\]\s*'), '');
                      _agregarNotificacion(NotificacionModel.urgencia(
                        citaId: model.id,
                        propietarioNombre: model.propietarioNombre,
                        mascotaNombre: model.mascotaNombre,
                        sintomas: sintomas,
                        fecha: model.fecha,
                        hora: model.hora,
                      ));
                    } else {
                      _agregarNotificacion(NotificacionModel.nuevaCita(
                        citaId: model.id,
                        propietarioNombre: model.propietarioNombre,
                        mascotaNombre: model.mascotaNombre,
                        fecha: model.fecha,
                        hora: model.hora,
                      ));
                    }

                    if (!_citasDelVeterinario.any((c) => c.id == model.id)) {
                      _citasDelVeterinario.insert(0, model);
                    }
                    notifyListeners();
                  } catch (e) {
                    debugPrint('Error realtime INSERT: $e');
                  }
                }
              }

              // ── Cita confirmada → programar recordatorios para el vet ─────
              if (eventType == PostgresChangeEvent.update) {
                final veteId = record['vete_id']?.toString() ?? '';
                if (veteId == entityId) {
                  final nuevoEstado = record['cita_estado']?.toString() ?? '';
                  final oldRecord = payload.oldRecord;
                  final antiguoEstado =
                      oldRecord['cita_estado']?.toString();
                  if (nuevoEstado == 'confirmada' &&
                      nuevoEstado != antiguoEstado) {
                    try {
                      final full = await _fetchCitaCompleta(
                          record['cita_id'].toString());
                      final model = CitaModel.fromJson(full);
                      _actualizarEnListas(model);
                      _programarRecordatorios(model, 'veterinario');
                      notifyListeners();
                    } catch (e) {
                      debugPrint('Error realtime UPDATE (vet confirm): $e');
                    }
                  }
                }
              }
            } else if (rol == 'usuario') {
              // ── Cambio de estado de cita del usuario (UPDATE) ─────────────
              if (eventType == PostgresChangeEvent.update) {
                final usuaId = record['usua_id']?.toString() ?? '';
                if (usuaId == entityId) {
                  final nuevoEstado = record['cita_estado']?.toString() ?? '';
                  final oldRecord = payload.oldRecord;
                  final antiguoEstado =
                      oldRecord['cita_estado']?.toString();

                  if (nuevoEstado != antiguoEstado &&
                      (nuevoEstado == 'confirmada' ||
                          nuevoEstado == 'rechazada')) {
                    try {
                      final full = await _fetchCitaCompleta(
                          record['cita_id'].toString());
                      final model = CitaModel.fromJson(full);
                      _actualizarEnListas(model);

                      // Detectar si la cita era una urgencia
                      final esUrgencia =
                          model.motivo.startsWith('[URGENCIA:');

                      if (nuevoEstado == 'confirmada') {
                        if (esUrgencia) {
                          _agregarNotificacion(NotificacionModel.citaConfirmada(
                            citaId: model.id,
                            mascotaNombre: model.mascotaNombre,
                            fecha: model.fecha,
                            hora: model.hora,
                            esUrgencia: true,
                            idPrefix: 'urgencia_confirmada',
                          ));
                        } else {
                          _agregarNotificacion(NotificacionModel.citaConfirmada(
                            citaId: model.id,
                            mascotaNombre: model.mascotaNombre,
                            fecha: model.fecha,
                            hora: model.hora,
                          ));
                          // Recordatorios solo para citas normales
                          _programarRecordatorios(model, 'usuario');
                        }
                      } else {
                        if (esUrgencia) {
                          _agregarNotificacion(NotificacionModel.citaRechazada(
                            citaId: model.id,
                            mascotaNombre: model.mascotaNombre,
                            fecha: model.fecha,
                            hora: model.hora,
                            esUrgencia: true,
                            idPrefix: 'urgencia_rechazada',
                          ));
                        } else {
                          _agregarNotificacion(NotificacionModel.citaRechazada(
                            citaId: model.id,
                            mascotaNombre: model.mascotaNombre,
                            fecha: model.fecha,
                            hora: model.hora,
                          ));
                        }
                      }
                      // Notificar a la pantalla de espera de urgencias
                      _ultimaRespuestaUrgencia = model;
                      notifyListeners();
                    } catch (e) {
                      debugPrint('Error realtime UPDATE (usuario): $e');
                    }
                  }
                }
              }
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Canal citas status: $status error: $error');
        });
  }

  /// Programa recordatorios in-app + notificaciones del sistema para una cita confirmada.
  /// Crea un Timer a los 30 min antes y otro a la hora exacta, y también
  /// programa notificaciones locales que aparecen aunque la app esté cerrada.
  void _programarRecordatorios(CitaModel cita, String rol) {
    // Cancelar timers previos si existían para esta cita
    _timers['${cita.id}_30min']?.cancel();
    _timers['${cita.id}_ahora']?.cancel();

    // Cancelar notificaciones del sistema previas para esta cita
    NotificacionLocalService.instance
        .cancelar(NotificacionLocalService.idDesde('recuerdo30_${cita.id}'));
    NotificacionLocalService.instance
        .cancelar(NotificacionLocalService.idDesde('recuerdoAhora_${cita.id}'));

    DateTime? citaDt;
    try {
      citaDt = DateTime.parse('${cita.fecha}T${cita.hora}:00');
    } catch (_) {
      return;
    }

    final ahora = DateTime.now();
    final prefix = rol == 'veterinario' ? '🐾 Paciente' : '🐾 Tu mascota';

    // ── Recordatorio 30 minutos antes ─────────────────────────────────────
    final momentoRecord30 = citaDt.subtract(const Duration(minutes: 30));
    final delay30 = momentoRecord30.difference(ahora);

    if (!delay30.isNegative && delay30.inHours < 48) {
      // Notificación del sistema — canal normal (1 sola vez, programada)
      NotificacionLocalService.instance.programar(
        id: NotificacionLocalService.idDesde('recuerdo30_${cita.id}'),
        titulo: '⏰ Cita en 30 minutos',
        cuerpo: '$prefix ${cita.mascotaNombre} tiene cita a las ${cita.hora}.',
        fechaHora: momentoRecord30,
        urgente: false,
        subtext: cita.mascotaNombre,
      );

      // Timer in-app: solo agrega al panel visual, SIN disparar otra push
      // (la notificación del sistema ya fue programada arriba)
      _timers['${cita.id}_30min'] = Timer(delay30, () {
        _agregarNotificacionSilenciosa(NotificacionModel.recordatorio30min(
          citaId: cita.id,
          mascotaNombre: cita.mascotaNombre,
          prefixRol: prefix,
          fecha: cita.fecha,
          hora: cita.hora,
        ));
        NotificacionLocalService.instance.feedbackInApp(urgente: false);
        notifyListeners();
      });
    }

    // ── Recordatorio a la hora de la cita ─────────────────────────────────
    final delayAhora = citaDt.difference(ahora);
    if (!delayAhora.isNegative && delayAhora.inHours < 48) {
      // Notificación del sistema — canal URGENTE (1 sola vez, programada)
      NotificacionLocalService.instance.programar(
        id: NotificacionLocalService.idDesde('recuerdoAhora_${cita.id}'),
        titulo: '🔔 ¡Es la hora de la cita!',
        cuerpo:
            '$prefix ${cita.mascotaNombre} — cita comenzando ahora (${cita.hora}).',
        fechaHora: citaDt,
        urgente: true,
        subtext: cita.mascotaNombre,
      );

      // Timer in-app: solo agrega al panel visual, SIN disparar otra push
      _timers['${cita.id}_ahora'] = Timer(delayAhora, () {
        _agregarNotificacionSilenciosa(NotificacionModel.recordatorioAhora(
          citaId: cita.id,
          mascotaNombre: cita.mascotaNombre,
          prefixRol: prefix,
          fecha: cita.fecha,
          hora: cita.hora,
        ));
        NotificacionLocalService.instance.feedbackInApp(urgente: true);
        notifyListeners();
      });
    }
  }

  /// También permite programar recordatorios para citas ya confirmadas
  /// (útil al iniciar la app y cargar citas existentes).
  void programarRecordatoriosExistentes(
      List<CitaModel> citas, String rol) {
    for (final c in citas) {
      if (c.estado.toLowerCase() == 'confirmada') {
        _programarRecordatorios(c, rol);
      }
    }
  }

  /// Carga notificaciones in-app para el estado actual de las citas existentes
  /// al abrir la app, sin disparar push ni vibración.
  Future<void> cargarNotificacionesExistentes(
      String entityId, String rol) async {
    try {
      if (rol == 'usuario') {
        // Citas confirmadas, rechazadas Y pendientes del usuario
        final rows = await Supabase.instance.client
            .from('citas')
            .select('*, mascotas(masc_nombre), usuarios(usua_nombre)')
            .eq('usua_id', entityId)
            .inFilter('cita_estado', ['confirmada', 'rechazada', 'pendiente']);

        for (final row in rows) {
          final model = CitaModel.fromJson(row);
          if (model.estado.toLowerCase() == 'confirmada') {
            _agregarNotificacionSilenciosa(NotificacionModel(
              id: 'confirmada_${model.id}',
              tipo: TipoNotificacion.citaConfirmada,
              titulo: '¡Cita confirmada! 🎉',
              cuerpo:
                  'Tu cita para ${model.mascotaNombre} el ${model.fecha.split('-').reversed.join('/')} a las ${model.hora} fue confirmada.',
              citaId: model.id,
              mascotaNombre: model.mascotaNombre,
              fecha: model.fecha,
              hora: model.hora,
            ));
          } else if (model.estado.toLowerCase() == 'rechazada') {
            _agregarNotificacionSilenciosa(NotificacionModel(
              id: 'rechazada_${model.id}',
              tipo: TipoNotificacion.citaRechazada,
              titulo: 'Cita rechazada',
              cuerpo:
                  'Tu cita para ${model.mascotaNombre} el ${model.fecha.split('-').reversed.join('/')} no pudo ser agendada.',
              citaId: model.id,
              mascotaNombre: model.mascotaNombre,
              fecha: model.fecha,
              hora: model.hora,
            ));
          } else if (model.estado.toLowerCase() == 'pendiente') {
            _agregarNotificacionSilenciosa(NotificacionModel(
              id: 'pendiente_${model.id}',
              tipo: TipoNotificacion.citaPendiente,
              titulo: 'Cita en espera ⏳',
              cuerpo:
                  'Tu cita para ${model.mascotaNombre} el ${model.fecha.split('-').reversed.join('/')} a las ${model.hora} está pendiente de confirmación.',
              citaId: model.id,
              mascotaNombre: model.mascotaNombre,
              fecha: model.fecha,
              hora: model.hora,
            ));
          }
        }
      } else if (rol == 'veterinario') {
        // Citas pendientes para el veterinario
        final rows = await Supabase.instance.client
            .from('citas')
            .select('*, mascotas(masc_nombre), usuarios(usua_nombre)')
            .eq('vete_id', entityId)
            .eq('cita_estado', 'pendiente');

        for (final row in rows) {
          final model = CitaModel.fromJson(row);
          _agregarNotificacionSilenciosa(NotificacionModel(
            id: 'nueva_${model.id}',
            tipo: TipoNotificacion.nuevaCita,
            titulo: 'Nueva solicitud de cita',
            cuerpo:
                '${model.propietarioNombre} solicita cita para ${model.mascotaNombre}',
            citaId: model.id,
            mascotaNombre: model.mascotaNombre,
            fecha: model.fecha,
            hora: model.hora,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error al cargar notificaciones existentes: $e');
    }
    notifyListeners();
  }

  /// Agrega una notificación a la lista sin disparar push ni vibración.
  void _agregarNotificacionSilenciosa(NotificacionModel n) {
    _notificaciones.removeWhere((e) => e.id == n.id);
    _notificaciones.add(n);
  }

  Future<Map<String, dynamic>> _fetchCitaCompleta(String citaId) async {
    return await Supabase.instance.client
        .from('citas')
        .select('*, mascotas(masc_nombre), usuarios(usua_nombre)')
        .eq('cita_id', citaId)
        .single();
  }

  void _agregarNotificacion(NotificacionModel n) {
    // Evitar duplicados por id en la lista visual
    _notificaciones.removeWhere((e) => e.id == n.id);
    _notificaciones.insert(0, n);

    // Si ya se envió la push para este id, no repetir
    if (_pushEnviadas.contains(n.id)) return;
    _pushEnviadas.add(n.id);

    // Determinar si es urgente
    final urgente = n.prioridad == PrioridadNotificacion.alta;

    // Feedback in-app (vibración) cuando la app está abierta
    NotificacionLocalService.instance.feedbackInApp(urgente: urgente);

    // Notificación push del sistema (1 sola vez)
    NotificacionLocalService.instance.mostrarInmediata(
      id: NotificacionLocalService.idDesde(n.id),
      titulo: n.titulo,
      cuerpo: n.cuerpo,
      urgente: urgente,
      subtext: n.mascotaNombre,
      payload: _payloadParaTipo(n.tipo),
    );
  }

  /// Devuelve el payload de navegación según el tipo de notificación.
  /// Este payload lo usa main.dart para navegar a la pantalla correcta
  /// cuando el usuario toca la notificación push.
  String _payloadParaTipo(TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.nuevaCita:
        return 'vet_citas';
      case TipoNotificacion.citaConfirmada:
      case TipoNotificacion.citaRechazada:
      case TipoNotificacion.recordatorio30min:
      case TipoNotificacion.recordatorioAhora:
        return 'historial_citas';
      case TipoNotificacion.urgencia:
        return 'vet_home';
      case TipoNotificacion.solicitudAdopcion:
        return 'solicitudes_adopcion';
      case TipoNotificacion.citaPendiente:
        return 'historial_citas';
    }
  }

  // ── Gestión de notificaciones ─────────────────────────────────────────────
  void marcarNotificacionVista(String id) {
    final idx = _notificaciones.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notificaciones[idx].leida = true;
      notifyListeners();
    }
  }

  void eliminarNotificacion(String id) {
    _notificaciones.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void limpiarNotificaciones() {
    _notificaciones.clear();
    notifyListeners();
  }

  void desuscribirNotificaciones() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _pushEnviadas.clear();
  }

  @override
  void dispose() {
    desuscribirNotificaciones();
    super.dispose();
  }
}
