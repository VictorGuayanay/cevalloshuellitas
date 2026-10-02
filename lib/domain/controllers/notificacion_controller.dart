// notificacion_controller.dart — Controlador de notificaciones in-app.
//
// Escucha cambios en la tabla `mascotas` de Supabase mediante Realtime.
// Cuando una mascota pasa al estado 'perdido', crea una NotificacionModel
// y la agrega a la lista interna, notificando a la UI.
//
// También dispara la notificación local del sistema (banner + vibración)
// para alertar al usuario aunque tenga la app en segundo plano.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/notificacion_model.dart';
import '../../data/services/notificacion_local_service.dart';

class NotificacionController extends ChangeNotifier {
  final List<NotificacionModel> _notificaciones = [];

  RealtimeChannel? _realtimePerdidosChannel;

  final Set<String> _pushEnviadas = {};

  // ── Getters ──────────────────────────────────────────────────────────────

  /// Lista inmutable de notificaciones (la UI no debe modificarla directamente).
  List<NotificacionModel> get notificaciones =>
      List.unmodifiable(_notificaciones);

  /// Cantidad de notificaciones que el usuario aún no ha leído.
  int get totalNotificaciones =>
      _notificaciones.where((n) => !n.leida).length;

  // ── Suscripción Realtime ──────────────────────────────────────────────────

  /// Activa la escucha de mascotas perdidas en tiempo real.
  /// Si ya hay una suscripción activa, la cancela primero para evitar duplicados.
  void suscribirMascotasPerdidas() {
    _realtimePerdidosChannel?.unsubscribe();

    _realtimePerdidosChannel = Supabase.instance.client
        .channel('mascotas_perdidas_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // escucha INSERT, UPDATE y DELETE
          schema: 'public',
          table: 'mascotas',
          callback: (payload) async {
            final record = payload.newRecord;
            final estado = record['masc_estado']?.toString() ?? '';

            // Solo nos interesan mascotas en estado 'perdido'.
            if (estado.toLowerCase() != 'perdido') return;

            final mascotaId = record['masc_id']?.toString() ?? '';
            final notifId   = 'perdida_$mascotaId';

            // Si ya existe la notificación en la lista, no la duplicamos.
            if (_notificaciones.any((n) => n.id == notifId)) return;

            final mascotaNombre = record['masc_nombre']?.toString() ?? 'Mascota';
            final usuaId        = record['usua_id']?.toString() ?? '';

            // Intentamos obtener el nombre del dueño para el mensaje.
            String? duenioNombre;
            if (usuaId.isNotEmpty) {
              try {
                final duenio = await Supabase.instance.client
                    .from('usuarios')
                    .select('usua_nombre')
                    .eq('usua_id', usuaId)
                    .maybeSingle();
                duenioNombre = duenio?['usua_nombre'] as String?;
              } catch (_) {
                // No es crítico; el mensaje funciona sin el nombre del dueño.
              }
            }

            _agregarNotificacion(NotificacionModel.mascotaPerdida(
              mascotaId: mascotaId,
              mascotaNombre: mascotaNombre,
              duenioNombre: duenioNombre,
            ));
            notifyListeners();
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Canal mascotas_perdidas_realtime: $status / $error');
        });
  }

  /// Agrega una notificación a la lista y dispara el push del sistema.
  /// Si ya existe una con el mismo ID, la reemplaza (actualización).
  void _agregarNotificacion(NotificacionModel n) {
    // Eliminar la versión anterior si existía.
    _notificaciones.removeWhere((e) => e.id == n.id);
    // Insertar al principio para que aparezca primero en la lista.
    _notificaciones.insert(0, n);

    // No enviar push si ya lo hicimos antes para esta notificación.
    if (_pushEnviadas.contains(n.id)) return;
    _pushEnviadas.add(n.id);

    // Vibrar y mostrar banner del sistema.
    NotificacionLocalService.instance.feedbackInApp(urgente: true);
    NotificacionLocalService.instance.mostrarInmediata(
      id: NotificacionLocalService.idDesde(n.id),
      titulo: n.titulo,
      cuerpo: n.cuerpo,
      urgente: true,
      subtext: n.mascotaNombre,
      payload: 'home',
    );
  }

  // ── Gestión de notificaciones ─────────────────────────────────────────────

  /// Marca una notificación como leída por su ID.
  void marcarNotificacionVista(String id) {
    final idx = _notificaciones.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notificaciones[idx].leida = true;
      notifyListeners();
    }
  }

  /// Elimina una notificación de la lista por su ID.
  void eliminarNotificacion(String id) {
    _notificaciones.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Elimina todas las notificaciones de la lista.
  void limpiarNotificaciones() {
    _notificaciones.clear();
    notifyListeners();
  }

  /// Cancela la suscripción Realtime y limpia el registro de pushes enviadas.
  void desuscribir() {
    _realtimePerdidosChannel?.unsubscribe();
    _realtimePerdidosChannel = null;
    _pushEnviadas.clear();
  }

  /// dispose() se llama automáticamente cuando el Provider ya no es necesario.
  /// Aquí limpiamos recursos para evitar fugas de memoria.
  @override
  void dispose() {
    desuscribir();
    super.dispose();
  }
}
