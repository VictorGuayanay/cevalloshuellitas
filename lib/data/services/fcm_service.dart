import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notificacion_local_service.dart';

/// Handler de mensajes en segundo plano (debe ser top-level).
///
/// Se ejecuta en un isolate separado, por eso se inicializa
/// firebase_core y flutter_local_notifications aquí mismo.
/// Solo es necesario para mensajes **data-only** (sin campo `notification`).
/// Cuando el payload incluye `notification`, FCM/Android lo muestra
/// automáticamente sin pasar por este handler.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase puede no estar inicializado en el isolate de background
  await Firebase.initializeApp();

  debugPrint('FCM background: ${message.notification?.title ?? message.data['titulo']}');

  // Si el mensaje ya trae objeto notification, el sistema Android lo muestra
  // automáticamente: no hacemos nada más para evitar duplicados.
  if (message.notification != null) return;

  // Mensaje data-only: mostramos la notificación manualmente.
  final titulo = message.data['titulo'] ?? message.data['title'] ?? '🐾 Huellitas';
  final cuerpo = message.data['cuerpo'] ?? message.data['body'] ?? '';
  if (cuerpo.isEmpty) return;

  await NotificacionLocalService.instance.init();
  await NotificacionLocalService.instance.mostrarInmediata(
    id: NotificacionLocalService.idDesde(
        message.messageId ?? message.data['id'] ?? titulo),
    titulo: titulo,
    cuerpo: cuerpo,
    urgente: message.data['urgente'] == 'true',
    subtext: message.data['mascota'],
    payload: message.data['payload'],
  );
}

/// Servicio que gestiona Firebase Cloud Messaging.
/// - Solicita permisos al usuario
/// - Obtiene y guarda el token FCM en Supabase (tabla usuarios)
/// - Escucha mensajes en primer plano y los convierte en notificaciones locales
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Inicializa FCM: permisos, token, y listeners.
  /// Llama esto una vez en main() después de inicializar Firebase.
  Future<void> init() async {
    // Verificar que Firebase esté disponible antes de usar FCM
    try {
      Firebase.app(); // lanza FirebaseException si no hay app inicializada
    } on FirebaseException catch (e) {
      debugPrint('FcmService.init() abortado — Firebase no disponible: $e');
      return;
    }
    // 1. Registrar handler de background (antes de cualquier otra cosa)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Solicitar permisos en iOS (Android 13+ se pide en NotificacionLocalService)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // 3. Configurar presentación en primer plano (iOS)
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Escuchar mensajes cuando la app está en PRIMER PLANO
    FirebaseMessaging.onMessage.listen(_onMensajePrimerPlano);

    // 5. Escuchar cuando el usuario toca la notificación desde background
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificacionAbierta);

    debugPrint('FcmService inicializado.');
  }

  /// Obtiene el token FCM actual y lo guarda en Supabase para el usuario [userId].
  Future<void> guardarToken(String userId) async {
    try {
      Firebase.app(); // guard: abortar si Firebase no está inicializado
    } on FirebaseException {
      debugPrint('guardarToken abortado — Firebase no disponible.');
      return;
    }
    try {
      // En Android el token puede tardar un momento
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM: token nulo, reintentando...');
        return;
      }
      debugPrint('FCM token: $token');

      // Guardar en la columna fcm_token de la tabla usuarios
      await Supabase.instance.client
          .from('usuarios')
          .update({'fcm_token': token})
          .eq('usua_id', userId);

      debugPrint('FCM token guardado en Supabase para $userId');

      // Escuchar renovación de token y actualizarlo en Supabase
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _fcm.onTokenRefresh.listen((nuevoToken) async {
        await Supabase.instance.client
            .from('usuarios')
            .update({'fcm_token': nuevoToken})
            .eq('usua_id', userId);
        debugPrint('FCM token renovado para $userId');
      });
    } catch (e) {
      debugPrint('Error guardando token FCM: $e');
    }
  }

  /// Envía una notificación push genérica a un token FCM.
  /// Úsalo para confirmaciones, rechazos, nuevas citas, adopciones, etc.
  Future<void> enviarNotificacion({
    required String destinatarioUserId,
    required String titulo,
    required String cuerpo,
    required String tipo,       // 'cita_confirmada' | 'cita_rechazada' | 'nueva_cita' | 'adopcion' | 'urgencia'
    String? citaId,
    String? mascotaNombre,
    bool urgente = false,
  }) async {
    try {
      Firebase.app();
    } on FirebaseException {
      debugPrint('enviarNotificacion abortado — Firebase no disponible.');
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('usuarios')
          .select('fcm_token')
          .eq('usua_id', destinatarioUserId)
          .maybeSingle();

      final token = row?['fcm_token'] as String?;
      if (token == null || token.isEmpty) {
        debugPrint('enviarNotificacion: usuario $destinatarioUserId sin fcm_token');
        return;
      }

      // Payload de navegación: al tocar la push, la app sabe a dónde ir
      String payload;
      switch (tipo) {
        case 'nueva_cita':
          payload = 'vet_citas';
          break;
        case 'cita_confirmada':
        case 'cita_rechazada':
          payload = 'historial_citas';
          break;
        case 'adopcion':
          payload = 'solicitudes_adopcion';
          break;
        case 'urgencia':
          payload = 'vet_home';
          break;
        default:
          payload = 'home';
      }

      await Supabase.instance.client.functions.invoke(
        'send-push-notification',
        body: {
          'token': token,
          'title': titulo,
          'body': cuerpo,
          'data': {
            'tipo': tipo,
            'citaId': citaId ?? '',
            'mascota': mascotaNombre ?? '',
            'urgente': urgente ? 'true' : 'false',
            'payload': payload,
          },
        },
      );
      debugPrint('Push enviada a $destinatarioUserId — tipo: $tipo');
    } catch (e) {
      debugPrint('Error enviando notificación FCM: $e');
    }
  }

  /// Envía una notificación push de urgencia al veterinario seleccionado.
  /// Requiere que el veterinario tenga fcm_token guardado en la tabla usuarios.
  Future<void> enviarNotificacionUrgencia({
    required String veteUserId,
    required String mascotaNombre,
    required String propietarioNombre,
    required String sintomas,
    required String modalidad,
    required String citaId,
    String? direccion,
  }) async {
    try {
      Firebase.app();
    } on FirebaseException {
      debugPrint('enviarNotificacionUrgencia abortado — Firebase no disponible.');
      return;
    }
    try {
      // Obtener el fcm_token del veterinario desde Supabase
      final row = await Supabase.instance.client
          .from('usuarios')
          .select('fcm_token')
          .eq('usua_id', veteUserId)
          .maybeSingle();

      final token = row?['fcm_token'] as String?;
      if (token == null || token.isEmpty) {
        debugPrint('enviarNotificacionUrgencia: veterinario sin fcm_token');
        return;
      }

      final lugar = modalidad == 'domicilio' ? 'A domicilio' : 'En el local';
      final cuerpo = '$propietarioNombre • $mascotaNombre • $lugar';

      // Llamar a la Edge Function de Supabase para enviar via FCM
      await Supabase.instance.client.functions.invoke(
        'send-push-notification',
        body: {
          'token': token,
          'title': '🚨 Urgencia Crítica',
          'body': cuerpo,
          'data': {
            'tipo': 'urgencia',
            'citaId': citaId,
            'mascota': mascotaNombre,
            'propietario': propietarioNombre,
            'modalidad': modalidad,
            'sintomas': sintomas,
            'direccion': direccion ?? '',
            'urgente': 'true',
            'payload': 'urgencia:$citaId',
          },
        },
      );
      debugPrint('Notificación push de urgencia enviada al token: $token');
    } catch (e) {
      debugPrint('Error enviando notificación push de urgencia: $e');
    }
  }

  /// Elimina el token FCM del usuario al cerrar sesión.
  Future<void> limpiarToken(String userId) async {
    try {
      Firebase.app(); // guard: abortar si Firebase no está inicializado
    } on FirebaseException {
      debugPrint('limpiarToken abortado — Firebase no disponible.');
      return;
    }
    try {
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;

      await Supabase.instance.client
          .from('usuarios')
          .update({'fcm_token': null})
          .eq('usua_id', userId);
      await _fcm.deleteToken();
      debugPrint('FCM token eliminado para $userId');
    } catch (e) {
      debugPrint('Error limpiando token FCM: $e');
    }
  }

  // ── Handlers de mensajes ──────────────────────────────────────────────────

  /// Cuando llega un mensaje con la app en PRIMER PLANO, lo mostramos
  /// como notificación local (FCM no la muestra automáticamente en foreground).
  Future<void> _onMensajePrimerPlano(RemoteMessage message) async {
    debugPrint('FCM foreground: ${message.notification?.title ?? message.data['titulo']}');

    // Extraer título y cuerpo: primero del objeto notification, luego del data
    final notif = message.notification;
    final titulo = notif?.title ?? message.data['titulo'] ?? message.data['title'] ?? '🐾 Huellitas';
    final cuerpo = notif?.body  ?? message.data['cuerpo'] ?? message.data['body'] ?? '';
    if (cuerpo.isEmpty && notif == null) return;

    final esAdopcion = message.data['tipo'] == 'adopcion';
    final urgente   = message.data['urgente'] == 'true';

    await NotificacionLocalService.instance.mostrarInmediata(
      id: NotificacionLocalService.idDesde(message.messageId ?? titulo),
      titulo: titulo,
      cuerpo: cuerpo,
      urgente: urgente,
      subtext: message.data['mascota'],
      payload: message.data['payload'],
    );

    // Vibración según tipo
    await NotificacionLocalService.instance.feedbackInApp(urgente: !esAdopcion && urgente);
  }

  /// Cuando el usuario toca la notificación desde background/terminado.
  void _onNotificacionAbierta(RemoteMessage message) {
    debugPrint('FCM notificación abierta: ${message.data}');
    // La navegación se maneja desde el onTap del NotificacionLocalService
    // que ya está configurado en main.dart
  }
}
