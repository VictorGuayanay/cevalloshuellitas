// mascota_service.dart — Servicio de acceso a datos para mascotas.
//
// Todas las operaciones usan Supabase como base de datos.
// El Storage de Supabase se usa para las imágenes de las mascotas.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mascota_model.dart';

class MascotaService {
  // Cliente de Supabase singleton.
  final SupabaseClient _client = Supabase.instance.client;

  // ── Consultas ─────────────────────────────────────────────────────────────

  /// Obtiene todas las mascotas de un usuario específico.
  /// Incluye join con usuarios para mostrar datos del propietario.
  Future<List<MascotaModel>> obtenerMascotasPorUsuario(String usuarioId) async {
    final response = await _client
        .from('mascotas')
        .select('*, usuarios(usua_nombre, usua_telefono, usua_foto_url)')
        .eq('usua_id', usuarioId);

    return (response as List<dynamic>)
        .map((e) => MascotaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene todas las mascotas de la plataforma (para la vista del veterinario).
  Future<List<MascotaModel>> obtenerTodasLasMascotas() async {
    final response = await _client
        .from('mascotas')
        .select()
        .order('masc_nombre');
    return (response as List<dynamic>)
        .map((e) => MascotaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene las mascotas en estado "para adoptar".
  /// Incluye datos del propietario para que el interesado pueda contactarlo.
  Future<List<MascotaModel>> obtenerMascotasParaAdopcion() async {
    final response = await _client
        .from('mascotas')
        .select('*, usuarios(usua_nombre, usua_telefono, usua_foto_url)')
        .eq('masc_estado', 'para adoptar');

    return (response as List<dynamic>)
        .map((e) => MascotaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene las mascotas en estado "perdido".
  /// Incluye datos del propietario para facilitar el contacto.
  Future<List<MascotaModel>> obtenerMascotasPerdidas() async {
    final response = await _client
        .from('mascotas')
        .select('*, usuarios(usua_nombre, usua_telefono, usua_foto_url)')
        .eq('masc_estado', 'perdido');

    return (response as List<dynamic>)
        .map((e) => MascotaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Inserta una nueva mascota en la BD y retorna el modelo con el ID asignado.
  Future<MascotaModel> crearMascota(MascotaModel mascota) async {
    final response = await _client
        .from('mascotas')
        .insert(mascota.toInsertJson())
        .select() // retorna la fila insertada
        .single();
    return MascotaModel.fromJson(response);
  }

  /// Actualiza los datos de una mascota existente.
  /// Retorna el modelo actualizado con join de usuarios incluido.
  Future<MascotaModel> actualizarMascota(MascotaModel mascota) async {
    final response = await _client
        .from('mascotas')
        .update(mascota.toUpdateJson())
        .eq('masc_id', mascota.id)
        .select('*, usuarios(usua_nombre, usua_telefono, usua_foto_url)')
        .single();
    return MascotaModel.fromJson(response);
  }

  /// Elimina una mascota por su ID.
  Future<void> eliminarMascota(String mascotaId) async {
    await _client.from('mascotas').delete().eq('masc_id', mascotaId);
  }

  // ── Storage de imágenes ───────────────────────────────────────────────────

  /// Sube una imagen al bucket 'mascotas_imagenes' de Supabase Storage
  /// y retorna la URL pública para guardarla en la BD.
  Future<String?> subirImagenMascota(File imagen, String extension) async {
    // Nombre de archivo único usando el timestamp para evitar colisiones.
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ruta = 'mascotas/$fileName';

    try {
      await _client.storage
          .from('mascotas_imagenes')
          .upload(
            ruta,
            imagen,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
    } catch (e) {
      debugPrint('Error al subir imagen a Supabase Storage: $e');
      // Re-lanzamos para que el controller lo capture y muestre el error en la UI.
      rethrow;
    }

    // getPublicUrl construye la URL pública sin hacer otra request.
    return _client.storage.from('mascotas_imagenes').getPublicUrl(ruta);
  }
}
