// veterinario_service.dart — Servicio de acceso a datos para veterinarios.
//
// Gestiona operaciones CRUD sobre la tabla `veterinarios` en Supabase.
// Siempre hace JOIN con `usuarios` para obtener nombre, foto y teléfono,
// ya que esos datos viven en la tabla de usuarios, no en veterinarios.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/veterinario_model.dart';

class VeterinarioService {
  final SupabaseClient _client = Supabase.instance.client;

  // Select con JOIN reutilizado para no repetirlo en cada método.
  static const _selectJoin =
      '*, usuarios(usua_nombre, usua_foto_url, usua_telefono)';

  // ── Consultas ─────────────────────────────────────────────────────────────

  /// Obtiene todos los veterinarios registrados, con datos del usuario asociado.
  Future<List<VeterinarioModel>> obtenerTodos() async {
    try {
      final response = await _client
          .from('veterinarios')
          .select(_selectJoin)
          .order('vete_id');
      return (response as List)
          .map((e) => VeterinarioModel.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('VeterinarioService.obtenerTodos error: $e');
      return []; // lista vacía para no romper la UI
    }
  }

  /// Busca el perfil de un veterinario por su usua_id.
  /// Retorna null si el usuario aún no tiene registro en la tabla veterinarios.
  Future<VeterinarioModel?> obtenerPorUsuarioId(String usuarioId) async {
    try {
      final response = await _client
          .from('veterinarios')
          .select(_selectJoin)
          .eq('usua_id', usuarioId)
          .maybeSingle(); // null si no existe, en lugar de lanzar excepción
      if (response == null) return null;
      return VeterinarioModel.fromJson(response);
    } catch (e) {
      debugPrint('VeterinarioService.obtenerPorUsuarioId error: $e');
      return null;
    }
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Crea un nuevo registro de veterinario en la BD.
  /// Retorna el modelo con el vete_id asignado por Supabase.
  Future<VeterinarioModel> crearVeterinario(VeterinarioModel vet) async {
    final response = await _client
        .from('veterinarios')
        .insert(vet.toInsertJson())
        .select(_selectJoin)
        .single();
    return VeterinarioModel.fromJson(response);
  }

  /// Actualiza el perfil del veterinario usando su vete_id.
  /// Retorna el modelo actualizado.
  Future<VeterinarioModel> actualizarVeterinario(VeterinarioModel vet) async {
    final response = await _client
        .from('veterinarios')
        .update(vet.toUpdateJson())
        .eq('vete_id', vet.id)
        .select(_selectJoin)
        .single();
    return VeterinarioModel.fromJson(response);
  }

  /// Actualiza únicamente el campo vete_disponible.
  /// Se separa del update general porque se llama frecuentemente (toggle).
  Future<void> actualizarDisponibilidad({
    required String veteId,
    required bool disponible,
  }) async {
    await _client
        .from('veterinarios')
        .update({'vete_disponible': disponible})
        .eq('vete_id', veteId);
  }

  /// Guarda la ubicación GPS del veterinario (latitud, longitud y dirección).
  Future<void> guardarUbicacion({
    required String veteId,
    required double latitud,
    required double longitud,
    String? direccion,
  }) async {
    await _client
        .from('veterinarios')
        .update({
          'vete_latitud': latitud,
          'vete_longitud': longitud,
          'vete_direccion': direccion,
        })
        .eq('vete_id', veteId);
  }
}
