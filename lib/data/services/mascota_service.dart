import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mascota_model.dart';

class MascotaService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Obtiene todas las mascotas registradas para un usuario específico.
  Future<List<MascotaModel>> obtenerMascotasPorUsuario(String usuarioId) async {
    final response = await _client
        .from('mascotas')
        .select()
        .eq('usua_id', usuarioId);

    return (response as List<dynamic>)
        .map((e) => MascotaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene todas las mascotas (para el veterinario).
  Future<List<MascotaModel>> obtenerTodasLasMascotas() async {
    final response = await _client.from('mascotas').select().order('masc_nombre');
    return (response as List<dynamic>)
        .map((e) => MascotaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene todas las mascotas que están en estado "para adoptar" en la plataforma.
  /// Incluye join con usuarios para mostrar nombre, teléfono y foto del propietario.
  Future<List<MascotaModel>> obtenerMascotasParaAdopcion() async {
    final response = await _client
        .from('mascotas')
        .select('*, usuarios(usua_nombre, usua_telefono, usua_foto_url)')
        .eq('masc_estado', 'para adoptar');

    return (response as List<dynamic>)
        .map((e) => MascotaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Obtiene todas las mascotas con estado "perdido".
  /// Incluye join con usuarios para mostrar nombre, teléfono y foto del propietario.
  Future<List<MascotaModel>> obtenerMascotasPerdidas() async {
    final response = await _client
        .from('mascotas')
        .select('*, usuarios(usua_nombre, usua_telefono, usua_foto_url)')
        .eq('masc_estado', 'perdido');

    return (response as List<dynamic>)
        .map((e) => MascotaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Crea una nueva mascota en la base de datos y retorna el modelo con su ID asignado.
  Future<MascotaModel> crearMascota(MascotaModel mascota) async {
    final response = await _client
        .from('mascotas')
        .insert(mascota.toInsertJson())
        .select()
        .single();
    return MascotaModel.fromJson(response);
  }

  /// Actualiza los datos de una mascota existente.
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

  /// Sube una imagen a Supabase Storage y retorna la URL pública.
  Future<String?> subirImagenMascota(File imagen, String extension) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ruta = 'mascotas/$fileName';

    try {
      await _client.storage.from('mascotas_imagenes').upload(
            ruta,
            imagen,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
    } catch (e) {
      debugPrint('Error al subir imagen a Supabase Storage: $e');
      // Re-lanzamos para que el controller lo capture y notifique a la UI
      rethrow;
    }

    final String publicUrl =
        _client.storage.from('mascotas_imagenes').getPublicUrl(ruta);

    return publicUrl;
  }
}
