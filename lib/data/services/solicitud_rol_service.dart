import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/solicitud_rol_model.dart';

/// Gestiona las solicitudes de cambio de rol a 'veterinario' desde la app móvil.
/// Solo expone la acción que puede realizar un usuario normal: enviar solicitud.
class SolicitudRolService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Envía una solicitud de cambio de rol.
  /// Lanza excepción si ya tiene una solicitud pendiente.
  Future<SolicitudRolModel> enviarSolicitud(String usuaId) async {
    // Verificar si ya tiene una solicitud pendiente
    final existente = await _client
        .from('solicitudes_rol')
        .select('srol_id, srol_estado')
        .eq('usua_id', usuaId)
        .eq('srol_estado', 'pendiente')
        .maybeSingle();

    if (existente != null) {
      throw Exception(
          'Ya tienes una solicitud pendiente. Espera la respuesta del administrador.');
    }

    final inserted = await _client
        .from('solicitudes_rol')
        .insert({'usua_id': usuaId, 'srol_estado': 'pendiente'})
        .select('srol_id, usua_id, srol_estado, srol_fecha')
        .single();

    return SolicitudRolModel.fromJson(inserted);
  }
}
