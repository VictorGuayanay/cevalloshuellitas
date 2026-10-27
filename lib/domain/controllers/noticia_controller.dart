// noticia_controller.dart — Controlador de noticias de la comunidad.
//
// Gestiona la lista de noticias publicadas y el envío de nuevas noticias.
// El canal Realtime de Supabase recarga la lista automáticamente cuando
// el administrador aprueba o rechaza una noticia desde el panel.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/noticia_model.dart';
import '../../data/services/noticia_service.dart';

class NoticiaController extends ChangeNotifier {
  final NoticiaService _service = NoticiaService();

  // ── Estado interno ─────────────────────────────────────────────────────────
  List<NoticiaModel> _noticias = [];
  bool _isLoading = false; // carga inicial de la lista
  bool _isSubmitting = false; // envío de nueva noticia en curso
  String? _errorMessage;

  RealtimeChannel? _canal; // canal Realtime de Supabase

  // ── Getters ────────────────────────────────────────────────────────────────
  List<NoticiaModel> get noticias => _noticias;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  // ── Cargar + Realtime ──────────────────────────────────────────────────────

  /// Carga las noticias publicadas y activa el canal Realtime para
  /// refrescar automáticamente cuando el admin modere alguna.
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

  /// Escucha cualquier cambio en la tabla `noticias` y recarga la lista.
  /// Así, cuando el admin aprueba una noticia desde el panel web,
  /// los usuarios la ven al instante sin recargar la app.
  void _suscribirRealtime() {
    _canal?.unsubscribe(); // cancelar suscripción anterior

    _canal = Supabase.instance.client
        .channel('noticias_aprobadas')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // INSERT, UPDATE y DELETE
          schema: 'public',
          table: 'noticias',
          callback: (payload) async {
            debugPrint('Realtime noticias: ${payload.eventType}');
            try {
              // Recargamos solo las publicadas para mostrar el estado actualizado.
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

  /// Cancela el canal Realtime. Se llama desde dispose() o al salir de la pantalla.
  void detenerRealtime() {
    _canal?.unsubscribe();
    _canal = null;
  }

  // ── Enviar noticia ─────────────────────────────────────────────────────────

  /// Crea una nueva noticia con estado 'pendiente'.
  /// Si se adjunta imagen, la sube primero a Storage y luego guarda la URL.
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
      // Subir imagen si se seleccionó una.
      String? imagenUrl;
      if (imagen != null && extension != null) {
        imagenUrl = await _service.subirImagenNoticia(imagen, extension);
      }

      // Construir el modelo y enviarlo a la BD.
      final noticia = NoticiaModel(
        id: '', // Supabase asigna el ID automáticamente
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

  /// Limpia recursos al desmontar el provider.
  @override
  void dispose() {
    detenerRealtime();
    super.dispose();
  }
}
