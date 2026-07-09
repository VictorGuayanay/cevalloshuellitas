import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/solicitud_adopcion_model.dart';
import '../services/fcm_service.dart';

class SolicitudAdopcionService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _selectJoin = '''
    *,
    mascotas(masc_nombre, masc_especie, masc_raza, masc_foto_url, usua_id),
    usuarios(usua_nombre, usua_correo, usua_telefono, usua_foto_url)
  ''';

  /// Envía una solicitud de adopción.
  /// Lanza excepción si el solicitante es el dueño de la mascota.
  Future<SolicitudAdopcionModel> enviarSolicitud({
    required String usuaId,
    required String mascId,
  }) async {
    // Verificar que el solicitante NO sea el dueño de la mascota
    final mascota = await _client
        .from('mascotas')
        .select('usua_id')
        .eq('masc_id', mascId)
        .single();

    final duenioId = mascota['usua_id']?.toString() ?? '';
    if (duenioId == usuaId) {
      throw Exception('No puedes adoptar tu propia mascota.');
    }

    // Verificar si ya existe una solicitud pendiente, aprobada o rechazada
    final existente = await _client
        .from('solicitudes_adopcion')
        .select('soli_id, soli_estado')
        .eq('usua_id', usuaId)
        .eq('masc_id', mascId)
        .maybeSingle();

    if (existente != null) {
      final estado = existente['soli_estado']?.toString() ?? '';
      if (estado == 'Pendiente' || estado == 'Aprobada') {
        throw Exception('Ya tienes una solicitud $estado para esta mascota.');
      }
      if (estado == 'Rechazada') {
        throw Exception(
            'Tu solicitud fue rechazada. No puedes volver a solicitar la adopción de esta mascota.');
      }
    }

    final inserted = await _client
        .from('solicitudes_adopcion')
        .insert({'usua_id': usuaId, 'masc_id': mascId, 'soli_estado': 'Pendiente'})
        .select(_selectJoin)
        .single();

    final solicitud = SolicitudAdopcionModel.fromJson(inserted);

    // ── Push FCM al dueño de la mascota: alguien quiere adoptar ──────────
    if (duenioId.isNotEmpty) {
      FcmService.instance.enviarNotificacion(
        destinatarioUserId: duenioId,
        titulo: '🐾 ¡Solicitud de adopción!',
        cuerpo: 'Alguien está interesado en adoptar a ${solicitud.mascotaNombre}. Revisa tu panel de solicitudes.',
        tipo: 'adopcion',
        mascotaNombre: solicitud.mascotaNombre,
      );
    }
    return solicitud;
  }

  /// Confirma la adopción: cambia el dueño de la mascota al solicitante
  /// y actualiza el estado de la mascota a 'propio'.
  /// También marca la solicitud como 'Adoptado'.
  Future<SolicitudAdopcionModel> confirmarAdopcion(
      SolicitudAdopcionModel solicitud) async {
    // 1. Cambiar el dueño de la mascota y el estado a 'propio'
    await _client.from('mascotas').update({
      'usua_id': solicitud.usuaId,
      'masc_estado': 'propio',
    }).eq('masc_id', solicitud.mascId);

    // 2. Marcar la solicitud como 'Adoptado'
    final response = await _client
        .from('solicitudes_adopcion')
        .update({'soli_estado': 'Adoptado'})
        .eq('soli_id', solicitud.id)
        .select(_selectJoin)
        .single();

    return SolicitudAdopcionModel.fromJson(response);
  }

  /// Solicitudes enviadas por un usuario específico.
  Future<List<SolicitudAdopcionModel>> obtenerPorUsuario(String usuaId) async {
    try {
      final response = await _client
          .from('solicitudes_adopcion')
          .select(_selectJoin)
          .eq('usua_id', usuaId)
          .order('soli_fecha', ascending: false);
      return (response as List)
          .map((e) => SolicitudAdopcionModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error obtenerPorUsuario: $e');
      return [];
    }
  }

  /// Todas las solicitudes recibidas para mascotas de un dueño.
  Future<List<SolicitudAdopcionModel>> obtenerPorDueno(String duenioId) async {
    try {
      final response = await _client
          .from('solicitudes_adopcion')
          .select('''
            *,
            mascotas!inner(masc_nombre, masc_especie, masc_raza, masc_foto_url, usua_id),
            usuarios(usua_nombre, usua_correo, usua_telefono, usua_foto_url)
          ''')
          .eq('mascotas.usua_id', duenioId)
          .order('soli_fecha', ascending: false);

      return (response as List)
          .map((e) => SolicitudAdopcionModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error obtenerPorDueno: $e');
      return [];
    }
  }

  /// Actualiza el estado de una solicitud (Aprobada / Rechazada).
  Future<SolicitudAdopcionModel> actualizarEstado(
      String soliId, String nuevoEstado) async {
    final response = await _client
        .from('solicitudes_adopcion')
        .update({'soli_estado': nuevoEstado})
        .eq('soli_id', soliId)
        .select(_selectJoin)
        .single();
    final solicitud = SolicitudAdopcionModel.fromJson(response);

    // ── Push FCM al solicitante: respuesta del dueño ──────────────────────
    if (solicitud.usuaId.isNotEmpty &&
        (nuevoEstado == 'Aprobada' || nuevoEstado == 'Rechazada')) {
      final esAprobada = nuevoEstado == 'Aprobada';
      FcmService.instance.enviarNotificacion(
        destinatarioUserId: solicitud.usuaId,
        titulo: esAprobada
            ? '🎉 ¡Solicitud aprobada!'
            : '❌ Solicitud rechazada',
        cuerpo: esAprobada
            ? 'Tu solicitud para adoptar a ${solicitud.mascotaNombre} fue aprobada. ¡Felicitaciones!'
            : 'Lo sentimos, tu solicitud para adoptar a ${solicitud.mascotaNombre} fue rechazada.',
        tipo: 'adopcion',
        mascotaNombre: solicitud.mascotaNombre,
        urgente: false,
      );
    }
    return solicitud;
  }

  /// Cancela (elimina) una solicitud pendiente.
  Future<void> cancelarSolicitud(String soliId) async {
    await _client
        .from('solicitudes_adopcion')
        .delete()
        .eq('soli_id', soliId);
  }

  /// Verifica si el usuario ya envió solicitud para una mascota.
  Future<String?> estadoSolicitud({
    required String usuaId,
    required String mascId,
  }) async {
    try {
      final r = await _client
          .from('solicitudes_adopcion')
          .select('soli_estado')
          .eq('usua_id', usuaId)
          .eq('masc_id', mascId)
          .maybeSingle();
      return r?['soli_estado']?.toString();
    } catch (_) {
      return null;
    }
  }
}
