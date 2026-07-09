import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/noticia_model.dart';
import '../../data/services/noticia_service.dart';

class NoticiaController extends ChangeNotifier {
  final NoticiaService _service = NoticiaService();

  List<NoticiaModel> _noticias = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Canal Realtime
  RealtimeChannel? _canal;

  List<NoticiaModel> get noticias => _noticias;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  // ── Cargar noticias aprobadas + Realtime ────────────────────────────────────
  Future<void> cargarNoticias() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _noticias = await _service.obtenerNoticiasAprobadas();
    } catch (e) {
      _errorMessage = 'Error al cargar noticias: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    _suscribirRealtime();
  }

  /// Escucha cambios en la tabla noticias para refrescar automáticamente
  /// cuando el admin aprueba una noticia desde el panel web.
  void _suscribirRealtime() {
    _canal?.unsubscribe();

    _canal = Supabase.instance.client
        .channel('noticias_aprobadas')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'noticias',
          callback: (payload) async {
            debugPrint('Realtime noticias: ${payload.eventType}');
            try {
              _noticias = await _service.obtenerNoticiasAprobadas();
              notifyListeners();
            } catch (e) {
              debugPrint('Error Realtime noticias: $e');
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Canal noticias_aprobadas: $status ${error ?? ""}');
        });
  }

  void detenerRealtime() {
    _canal?.unsubscribe();
    _canal = null;
  }

  // ── Enviar nueva noticia ────────────────────────────────────────────────────
  Future<bool> enviarNoticia({
    required String usuaId,
    required String titulo,
    required String contenido,
    required String categoria,
    File? imagen,
    String? extension,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? imagenUrl;
      if (imagen != null && extension != null) {
        imagenUrl = await _service.subirImagenNoticia(imagen, extension);
      }

      final noticia = NoticiaModel(
        id: '',
        usuaId: usuaId,
        titulo: titulo,
        contenido: contenido,
        imagenUrl: imagenUrl,
        categoria: categoria,
        estado: 'pendiente',
        fecha: DateTime.now(),
      );

      await _service.crearNoticia(noticia);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al enviar la noticia: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    detenerRealtime();
    super.dispose();
  }
}
