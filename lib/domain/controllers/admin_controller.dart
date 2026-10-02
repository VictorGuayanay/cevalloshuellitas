import 'package:flutter/material.dart';
import '../../data/models/usuario_model.dart';
import '../../data/models/mascota_model.dart';
import '../../data/models/noticia_model.dart';
import '../../data/services/admin_service.dart';

class AdminController extends ChangeNotifier {
  final AdminService _service = AdminService();

  // ── Estado ─────────────────────────────────────────────────────────────────
  bool _cargandoStats       = false;
  bool _cargandoUsuarios    = false;
  bool _cargandoSolicitudes = false;
  bool _cargandoNoticias    = false;
  String? _error;

  Map<String, int> _stats                          = {};
  List<UsuarioModel> _usuarios                     = [];
  List<Map<String, dynamic>> _solicitudesPendientes = [];
  List<Map<String, dynamic>> _todasLasSolicitudes  = [];
  List<NoticiaModel> _noticiasPendientes           = [];
  List<NoticiaModel> _todasLasNoticias             = [];
  List<MascotaModel> _ultimasMascotas              = [];

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get cargandoStats       => _cargandoStats;
  bool get cargandoUsuarios    => _cargandoUsuarios;
  bool get cargandoSolicitudes => _cargandoSolicitudes;
  bool get cargandoNoticias    => _cargandoNoticias;
  String? get error            => _error;

  Map<String, int> get stats                         => _stats;
  List<UsuarioModel> get usuarios                    => _usuarios;
  List<Map<String, dynamic>> get solicitudesPendientes => _solicitudesPendientes;
  List<Map<String, dynamic>> get todasLasSolicitudes => _todasLasSolicitudes;
  List<NoticiaModel> get noticiasPendientes          => _noticiasPendientes;
  List<NoticiaModel> get todasLasNoticias            => _todasLasNoticias;
  List<MascotaModel> get ultimasMascotas             => _ultimasMascotas;

  int get totalPendientes =>
      (_stats['noticiasPendientes'] ?? 0) +
      (_stats['solicitudesPendientes'] ?? 0);

  // ── Dashboard ──────────────────────────────────────────────────────────────

  Future<void> cargarDashboard() async {
    _cargandoStats = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.obtenerEstadisticas(),
        _service.obtenerUltimasMascotas(limit: 6),
      ]);
      _stats          = results[0] as Map<String, int>;
      _ultimasMascotas = results[1] as List<MascotaModel>;
    } catch (e) {
      _error = 'Error al cargar el dashboard: $e';
    } finally {
      _cargandoStats = false;
      notifyListeners();
    }
  }

  // ── Usuarios ───────────────────────────────────────────────────────────────

  Future<void> cargarUsuarios() async {
    _cargandoUsuarios = true;
    _error = null;
    notifyListeners();
    try {
      _usuarios = await _service.obtenerUsuarios();
    } catch (e) {
      _error = 'Error al cargar usuarios: $e';
    } finally {
      _cargandoUsuarios = false;
      notifyListeners();
    }
  }

  Future<bool> cambiarRolUsuario(String userId, String nuevoRol) async {
    try {
      await _service.cambiarRolUsuario(userId, nuevoRol);
      final idx = _usuarios.indexWhere((u) => u.id == userId);
      if (idx != -1) {
        _usuarios[idx] = _usuarios[idx].copyWith(rol: nuevoRol);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Error al cambiar rol: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Solicitudes de rol ─────────────────────────────────────────────────────

  Future<void> cargarSolicitudesPendientes() async {
    _cargandoSolicitudes = true;
    _error = null;
    notifyListeners();
    try {
      _todasLasSolicitudes = await _service.obtenerTodasLasSolicitudes();
      _solicitudesPendientes = _todasLasSolicitudes
          .where((s) => s['srol_estado'] == 'pendiente')
          .toList();
    } catch (e) {
      _error = 'Error al cargar solicitudes: $e';
    } finally {
      _cargandoSolicitudes = false;
      notifyListeners();
    }
  }

  Future<bool> aprobarSolicitud({
    required String solicitudId,
    required String usuarioId,
  }) async {
    try {
      await _service.aprobarSolicitudYCambiarRol(
        solicitudId: solicitudId,
        usuarioId: usuarioId,
      );
      final idx = _todasLasSolicitudes
          .indexWhere((s) => s['srol_id'] == solicitudId);
      if (idx != -1) {
        _todasLasSolicitudes[idx] = {
          ..._todasLasSolicitudes[idx],
          'srol_estado': 'aprobada',
        };
      }
      _solicitudesPendientes.removeWhere((s) => s['srol_id'] == solicitudId);
      _stats['solicitudesPendientes'] =
          (_stats['solicitudesPendientes'] ?? 1) - 1;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al aprobar solicitud: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> rechazarSolicitud(String solicitudId) async {
    try {
      await _service.responderSolicitud(solicitudId, 'rechazada');
      final idx = _todasLasSolicitudes
          .indexWhere((s) => s['srol_id'] == solicitudId);
      if (idx != -1) {
        _todasLasSolicitudes[idx] = {
          ..._todasLasSolicitudes[idx],
          'srol_estado': 'rechazada',
        };
      }
      _solicitudesPendientes.removeWhere((s) => s['srol_id'] == solicitudId);
      _stats['solicitudesPendientes'] =
          (_stats['solicitudesPendientes'] ?? 1) - 1;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al rechazar solicitud: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Noticias ───────────────────────────────────────────────────────────────

  Future<void> cargarNoticiasPendientes() async {
    _cargandoNoticias = true;
    _error = null;
    notifyListeners();
    try {
      _todasLasNoticias = await _service.obtenerTodasLasNoticias();
      _noticiasPendientes =
          _todasLasNoticias.where((n) => n.estado == 'pendiente').toList();
    } catch (e) {
      _error = 'Error al cargar noticias: $e';
    } finally {
      _cargandoNoticias = false;
      notifyListeners();
    }
  }

  Future<bool> publicarNoticia(String noticiaId) async {
    try {
      await _service.cambiarEstadoNoticia(noticiaId, 'publicada');
      _actualizarEstadoNoticia(noticiaId, 'publicada');
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al publicar noticia: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> rechazarNoticia(String noticiaId) async {
    try {
      await _service.cambiarEstadoNoticia(noticiaId, 'rechazada');
      _actualizarEstadoNoticia(noticiaId, 'rechazada');
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al rechazar noticia: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> crearNoticia({
    required String titulo,
    required String contenido,
    required String categoria,
    String? imagenUrl,
    required String autorId,
  }) async {
    try {
      await _service.crearNoticia(
        titulo: titulo,
        contenido: contenido,
        categoria: categoria,
        imagenUrl: imagenUrl,
        autorId: autorId,
      );
      await cargarNoticiasPendientes();
      return true;
    } catch (e) {
      _error = 'Error al crear noticia: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarNoticia({
    required String noticiaId,
    required String titulo,
    required String contenido,
    required String categoria,
    String? imagenUrl,
  }) async {
    try {
      await _service.editarNoticia(
        noticiaId: noticiaId,
        titulo: titulo,
        contenido: contenido,
        categoria: categoria,
        imagenUrl: imagenUrl,
      );
      await cargarNoticiasPendientes();
      return true;
    } catch (e) {
      _error = 'Error al editar noticia: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarNoticia(String noticiaId) async {
    try {
      await _service.eliminarNoticia(noticiaId);
      _todasLasNoticias.removeWhere((n) => n.id == noticiaId);
      _noticiasPendientes.removeWhere((n) => n.id == noticiaId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al eliminar noticia: $e';
      notifyListeners();
      return false;
    }
  }

  void _actualizarEstadoNoticia(String noticiaId, String nuevoEstado) {
    _noticiasPendientes.removeWhere((n) => n.id == noticiaId);
    if (nuevoEstado == 'publicada') {
      _stats['noticiasPendientes'] =
          (_stats['noticiasPendientes'] ?? 1) - 1;
    }
    final idx = _todasLasNoticias.indexWhere((n) => n.id == noticiaId);
    if (idx != -1) {
      final n = _todasLasNoticias[idx];
      _todasLasNoticias[idx] = NoticiaModel(
        id: n.id,
        usuaId: n.usuaId,
        titulo: n.titulo,
        contenido: n.contenido,
        imagenUrl: n.imagenUrl,
        categoria: n.categoria,
        estado: nuevoEstado,
        fecha: n.fecha,
        autorNombre: n.autorNombre,
        autorFotoUrl: n.autorFotoUrl,
      );
    }
  }
}
