// noticia_service.dart — Servicio de acceso a datos para noticias.
//
// Gestiona la lectura y escritura de noticias en Supabase.
// Las imágenes se suben al bucket 'noticias_imagenes' de Supabase Storage.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/noticia_model.dart';

class NoticiaService {
  final SupabaseClient _client = Supabase.instance.client;

  // Select con JOIN reutilizado en varias queries para no repetirlo.
  static const _selectJoin = '*, usuarios(usua_nombre, usua_foto_url)';

  // ── Consultas ─────────────────────────────────────────────────────────────

  /// Obtiene todas las noticias en estado 'publicada', ordenadas de más
  /// reciente a más antigua.
  Future<List<NoticiaModel>> obtenerNoticiasAprobadas() async {
    final response = await _client
        .from('noticias')
        .select(_selectJoin)
        .eq('noti_estado', 'publicada')
        .order('noti_fecha', ascending: false);

    return (response as List<dynamic>)
        .map((e) => NoticiaModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Crear ─────────────────────────────────────────────────────────────────

  /// Crea una nueva noticia con estado 'pendiente' (esperando moderación).
  /// Retorna el modelo con el ID asignado por Supabase.
  Future<NoticiaModel> crearNoticia(NoticiaModel noticia) async {
    final response = await _client
        .from('noticias')
        .insert(noticia.toInsertJson())
        .select(_selectJoin) // retorna la fila insertada con el join
        .single();
    return NoticiaModel.fromJson(response);
  }

  // ── Storage de imágenes ───────────────────────────────────────────────────

  /// Sube una imagen al bucket 'noticias_imagenes' y retorna la URL pública.
  Future<String?> subirImagenNoticia(File imagen, String extension) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ruta = 'noticias/$fileName';

    try {
      await _client.storage.from('noticias_imagenes').upload(
            ruta,
            imagen,
            fileOptions:
                const FileOptions(cacheControl: '3600', upsert: false),
          );
    } catch (e) {
      debugPrint('Error al subir imagen de noticia: $e');
      rethrow; // el controller decide cómo manejar el error
    }

    return _client.storage.from('noticias_imagenes').getPublicUrl(ruta);
  }
}
