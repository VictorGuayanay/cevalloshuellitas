// senso_service.dart — Servicio del Censo Pecuario (SENSO).
//
// Usa Supabase como todos los demás servicios de la app.
//
// Tabla: `sensos`
//   senso_id, usua_id, produccion, especie,
//   numero_animales, alimentacion, destinacion, created_at

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/senso_model.dart';

class SensoService {
  final SupabaseClient _client = Supabase.instance.client;

  // ── Crear ─────────────────────────────────────────────────────────────────

  /// Inserta un nuevo registro de senso y retorna el modelo con el ID asignado.
  Future<SensoModel> crearSenso(SensoModel senso) async {
    final response = await _client
        .from('sensos')
        .insert(senso.toInsertJson())
        .select()
        .single();
    return SensoModel.fromJson(response);
  }

  // ── Leer ──────────────────────────────────────────────────────────────────

  /// Obtiene todos los registros de senso de un productor,
  /// ordenados del más reciente al más antiguo.
  Future<List<SensoModel>> obtenerPorUsuario(String usuarioId) async {
    try {
      final response = await _client
          .from('sensos')
          .select()
          .eq('usua_id', usuarioId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((e) => SensoModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SensoService.obtenerPorUsuario error: $e');
      return [];
    }
  }

  // ── Eliminar ──────────────────────────────────────────────────────────────

  /// Elimina un registro de senso por su ID.
  Future<void> eliminarSenso(String sensoId) async {
    await _client.from('sensos').delete().eq('senso_id', sensoId);
  }
}
