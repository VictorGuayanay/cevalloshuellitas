import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/noticia_model.dart';

class NoticiaService {
  final SupabaseClient _client = Supabase.instance.client;

  static const _selectJoin =
      '*, usuarios(usua_nombre, usua_foto_url)';

  /// Obtiene todas las noticias publicadas ordenadas por fecha descendente.
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

  /// Crea una nueva noticia con estado 'pendiente'.
  Future<NoticiaModel> crearNoticia(NoticiaModel noticia) async {
    final response = await _client
        .from('noticias')
        .insert(noticia.toInsertJson())
        .select(_selectJoin)
        .single();
    return NoticiaModel.fromJson(response);
  }

  /// Sube una imagen al bucket 'noticias_imagenes' y retorna la URL pública.
  Future<String?> subirImagenNoticia(File imagen, String extension) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ruta = 'noticias/$fileName';

    try {
      await _client.storage.from('noticias_imagenes').upload(
            ruta,
            imagen,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
    } catch (e) {
      debugPrint('Error al subir imagen de noticia: $e');
      rethrow;
    }

    return _client.storage.from('noticias_imagenes').getPublicUrl(ruta);
  }
}
