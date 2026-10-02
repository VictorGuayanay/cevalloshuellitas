// solicitud_rol_service.dart — Servicio para solicitudes de cambio de rol.
//
// Solo expone la acción que puede hacer un usuario normal: enviar solicitud.
// Las acciones del admin (aprobar/rechazar) están en AdminService.
// Los datos se gestionan en la tabla `solicitudes_rol` de Supabase.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/solicitud_rol_model.dart';

class SolicitudRolService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Envía una solicitud de cambio de rol a 'veterinario'.
  ///
  /// Lanza excepción si el usuario ya tiene una solicitud pendiente,
  /// para evitar duplicados en la BD.
  Future<SolicitudRolModel> enviarSolicitud(String usuaId) async {
    // 1. Verificar si ya existe una solicitud pendiente para este usuario.
    final existente = await _client
        .from('solicitudes_rol')
        .select('srol_id, srol_estado')
        .eq('usua_id', usuaId)
        .eq('srol_estado', 'pendiente')
        .maybeSingle(); // null si no existe, sin lanzar excepción

    if (existente != null) {
      throw Exception(
          'Ya tienes una solicitud pendiente. '
          'Espera la respuesta del administrador.');
    }

    // 2. Insertar la solicitud y retornar la fila creada.
    final inserted = await _client
        .from('solicitudes_rol')
        .insert({'usua_id': usuaId, 'srol_estado': 'pendiente'})
        .select('srol_id, usua_id, srol_estado, srol_fecha')
        .single();

    return SolicitudRolModel.fromJson(inserted);
  }
}
