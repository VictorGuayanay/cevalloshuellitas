import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/solicitud_adopcion_model.dart';
import '../../data/services/solicitud_adopcion_service.dart';
import '../../data/services/notificacion_local_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SolicitudAdopcionController extends ChangeNotifier {
  final SolicitudAdopcionService _service = SolicitudAdopcionService();

  List<SolicitudAdopcionModel> _misSolicitudes = [];
  List<SolicitudAdopcionModel> _solicitudesRecibidas = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ─── Notificaciones in-app ────────────────────────────────────────────────
  /// IDs de solicitudes ya vistas (para no repetir push ni badge)
  final Set<String> _idsSolicitusVistas = {};
  /// Solicitudes recibidas aún no vistas por el dueño.
  final List<SolicitudAdopcionModel> _notificacionesPendientes = [];

  RealtimeChannel? _realtimeChannel;
  Timer? _pollingTimer;

  List<SolicitudAdopcionModel> get misSolicitudes => _misSolicitudes;
  List<SolicitudAdopcionModel> get solicitudesRecibidas => _solicitudesRecibidas;
  List<SolicitudAdopcionModel> get notificacionesPendientes =>
      List.unmodifiable(_notificacionesPendientes);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get pendientesRecibidas =>
      _solicitudesRecibidas.where((s) => s.estado == 'Pendiente').length;

  int get totalNotificaciones => _notificacionesPendientes.length;

  // ─── Iniciar vigilancia: Realtime + Polling ───────────────────────────────

  /// Arranca Realtime + polling periódico para el [duenioId].
  /// Llama esto en el initState del HomeScreen.
  Future<void> iniciarVigilancia(String duenioId) async {
    // 1. Carga inicial (sin push, sin vibración)
    await _sincronizarSolicitudesPendientes(duenioId, dispararPush: false);

    // 2. Suscribir Realtime para INSERTs nuevos
    _suscribirRealtime(duenioId);

    // 3. Polling de respaldo cada 25 segundos (por si el Realtime falla)
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _sincronizarSolicitudesPendientes(duenioId, dispararPush: true);
    });
  }

  /// Detiene Realtime y polling.
  void detenerVigilancia() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // ─── Realtime ─────────────────────────────────────────────────────────────
  void _suscribirRealtime(String duenioId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = Supabase.instance.client
        .channel('adopciones_duenio_$duenioId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'solicitudes_adopcion',
          callback: (payload) async {
            final soliId = payload.newRecord['soli_id']?.toString() ?? '';
            if (soliId.isEmpty) return;
            debugPrint('Realtime INSERT adopcion soliId=$soliId');
            // Forzar sincronización inmediata con push
            await _procesarNuevaSolicitud(soliId, duenioId);
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Realtime adopciones: $status ${error ?? ""}');
        });
  }

  // ─── Lógica central de sincronización ────────────────────────────────────

  Future<void> _sincronizarSolicitudesPendientes(
      String duenioId, {required bool dispararPush}) async {
    try {
      // Solicitudes pendientes con datos completos del solicitante, filtrado por dueño de la mascota
      final rows = await Supabase.instance.client
          .from('solicitudes_adopcion')
          .select(
              '*, mascotas!inner(masc_nombre, masc_especie, masc_raza, masc_foto_url, usua_id), '
              'usuarios(usua_nombre, usua_correo, usua_telefono, usua_foto_url)')
          .eq('mascotas.usua_id', duenioId)
          .eq('soli_estado', 'Pendiente')
          .order('soli_fecha', ascending: false);

      bool hayNuevas = false;

      for (final row in rows) {
        final model = SolicitudAdopcionModel.fromJson(row);

        // Agregar a solicitudesRecibidas si no existe
        if (!_solicitudesRecibidas.any((s) => s.id == model.id)) {
          _solicitudesRecibidas.insert(0, model);
        }

        // Solo notificar si es nueva (no vista antes)
        if (!_idsSolicitusVistas.contains(model.id)) {
          if (!_notificacionesPendientes.any((n) => n.id == model.id)) {
            _notificacionesPendientes.insert(0, model);
          }

          if (dispararPush) {
            hayNuevas = true;
            final mascNombre = model.mascotaNombre ?? 'tu mascota';
            final solicitante = model.usuarioNombre ?? 'Alguien';
            final notifId =
                NotificacionLocalService.idDesde('adopcion_${model.id}');

            debugPrint('Push adopción: $solicitante → $mascNombre');

            // Marcar como vista ANTES de disparar para que el polling
            // no vuelva a enviar la misma notificación segundos después
            _idsSolicitusVistas.add(model.id);

            await NotificacionLocalService.instance.feedbackInApp(urgente: false);
            await NotificacionLocalService.instance.mostrarInmediata(
              id: notifId,
              titulo: '🐾 Nueva solicitud de adopción',
              cuerpo: '$solicitante quiere adoptar a $mascNombre.',
              urgente: false,
              subtext: mascNombre,
              payload: 'adopcion:${model.id}',
            );
          }
        }
      }

      if (hayNuevas || !dispararPush) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error en _sincronizarSolicitudesPendientes: $e');
    }
  }

  /// Procesa una solicitud específica recién llegada por Realtime.
  Future<void> _procesarNuevaSolicitud(String soliId, String duenioId) async {
    try {
      final row = await Supabase.instance.client
          .from('solicitudes_adopcion')
          .select(
              '*, mascotas(masc_nombre, masc_especie, masc_raza, masc_foto_url, usua_id), '
              'usuarios(usua_nombre, usua_correo, usua_telefono, usua_foto_url)')
          .eq('soli_id', soliId)
          .maybeSingle();

      if (row == null) return;

      final propId = (row['mascotas'] as Map?)?['usua_id']?.toString() ?? '';
      if (propId != duenioId) return;

      final model = SolicitudAdopcionModel.fromJson(row);

      bool esNueva = !_idsSolicitusVistas.contains(model.id);

      if (!_solicitudesRecibidas.any((s) => s.id == model.id)) {
        _solicitudesRecibidas.insert(0, model);
      }
      if (esNueva && !_notificacionesPendientes.any((n) => n.id == model.id)) {
        _notificacionesPendientes.insert(0, model);
      }

      if (esNueva) {
        final mascNombre = model.mascotaNombre ?? 'tu mascota';
        final solicitante = model.usuarioNombre ?? 'Alguien';
        final notifId =
            NotificacionLocalService.idDesde('adopcion_${model.id}');

        // Marcar como vista ANTES de disparar para que el polling
        // no vuelva a enviar la misma notificación segundos después
        _idsSolicitusVistas.add(model.id);

        await NotificacionLocalService.instance.feedbackInApp(urgente: false);
        await NotificacionLocalService.instance.mostrarInmediata(
          id: notifId,
          titulo: '🐾 Nueva solicitud de adopción',
          cuerpo: '$solicitante quiere adoptar a $mascNombre.',
          urgente: false,
          subtext: mascNombre,
          payload: 'adopcion:${model.id}',
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error procesando nueva solicitud $soliId: $e');
    }
  }

  // ─── Compatibilidad con código anterior ───────────────────────────────────

  /// Llama a iniciarVigilancia (compatibilidad con SolicitudesAdopcionScreen).
  void suscribirNotificaciones(String duenioId) {
    iniciarVigilancia(duenioId);
  }

  // ─── Gestión de notificaciones ────────────────────────────────────────────

  /// Marca una notificación como vista (la saca del badge pero no del historial).
  void marcarNotificacionVista(String soliId) {
    _idsSolicitusVistas.add(soliId);
    _notificacionesPendientes.removeWhere((n) => n.id == soliId);
    notifyListeners();
  }

  /// Limpia todas las notificaciones pendientes (badge → 0).
  void limpiarNotificaciones() {
    for (final n in _notificacionesPendientes) {
      _idsSolicitusVistas.add(n.id);
    }
    _notificacionesPendientes.clear();
    notifyListeners();
  }

  // ─── Solicitudes ─────────────────────────────────────────────────────────

  Future<bool> enviarSolicitud({
    required String usuaId,
    required String mascId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final nueva = await _service.enviarSolicitud(usuaId: usuaId, mascId: mascId);
      _misSolicitudes.insert(0, nueva);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> cargarMisSolicitudes(String usuaId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _misSolicitudes = await _service.obtenerPorUsuario(usuaId);
    } catch (e) {
      _errorMessage = 'Error al cargar solicitudes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cargarSolicitudesRecibidas(String duenioId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _solicitudesRecibidas = await _service.obtenerPorDueno(duenioId);
    } catch (e) {
      _errorMessage = 'Error al cargar solicitudes recibidas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmarAdopcion(SolicitudAdopcionModel solicitud) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final actualizada = await _service.confirmarAdopcion(solicitud);
      _actualizarEnListas(actualizada);
      _solicitudesRecibidas.removeWhere(
        (s) => s.mascId == solicitud.mascId && s.id != solicitud.id,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al confirmar adopción: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> rechazarSolicitud(String soliId) async {
    return _cambiarEstado(soliId, 'Rechazada');
  }

  Future<bool> cancelarSolicitud(String soliId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.cancelarSolicitud(soliId);
      _misSolicitudes.removeWhere((s) => s.id == soliId);
      _solicitudesRecibidas.removeWhere((s) => s.id == soliId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al cancelar: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> estadoSolicitud({
    required String usuaId,
    required String mascId,
  }) async {
    return _service.estadoSolicitud(usuaId: usuaId, mascId: mascId);
  }

  Future<bool> _cambiarEstado(String soliId, String nuevoEstado) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final actualizada = await _service.actualizarEstado(soliId, nuevoEstado);
      _actualizarEnListas(actualizada);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar estado: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _actualizarEnListas(SolicitudAdopcionModel actualizada) {
    final i1 = _misSolicitudes.indexWhere((s) => s.id == actualizada.id);
    if (i1 != -1) _misSolicitudes[i1] = actualizada;
    final i2 = _solicitudesRecibidas.indexWhere((s) => s.id == actualizada.id);
    if (i2 != -1) _solicitudesRecibidas[i2] = actualizada;
  }

  void limpiar() {
    detenerVigilancia();
    _misSolicitudes = [];
    _solicitudesRecibidas = [];
    _notificacionesPendientes.clear();
    _idsSolicitusVistas.clear();
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    detenerVigilancia();
    super.dispose();
  }
}
