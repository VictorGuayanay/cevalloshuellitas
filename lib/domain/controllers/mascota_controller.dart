// mascota_controller.dart — Controlador de mascotas.
//
// Gestiona tres listas de mascotas:
//   - mascotas: las del usuario autenticado (con Realtime)
//   - mascotasPerdidas: las reportadas como perdidas (con Realtime)
//   - todasLasMascotas: todas las de la plataforma (para el veterinario)
//
// El Realtime de Supabase actualiza las listas automáticamente cuando
// hay INSERT, UPDATE o DELETE en la tabla `mascotas`, sin necesidad de
// recargar manualmente la pantalla.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/mascota_model.dart';
import '../../data/services/mascota_service.dart';
import '../../data/services/fcm_service.dart';

class MascotaController extends ChangeNotifier {
  final MascotaService _mascotaService = MascotaService();

  // ── Estado interno ─────────────────────────────────────────────────────────
  List<MascotaModel> _mascotas = []; // mascotas del usuario actual
  List<MascotaModel> _mascotasPerdidas = []; // mascotas con estado 'perdido'
  List<MascotaModel> _todasLasMascotas = []; // todas (para el veterinario)

  bool _isLoading = false; // operación principal en curso
  bool _isLoadingPerdidas = false; // carga de mascotas perdidas en curso
  String? _errorMessage;

  // Canales Realtime de Supabase.
  RealtimeChannel? _canalPerdidas; // escucha mascotas perdidas
  RealtimeChannel? _canalMisMascotas; // escucha mascotas del usuario
  String? _usuarioIdSuscrito; // evita suscribir el mismo usuario dos veces

  // ── Getters ────────────────────────────────────────────────────────────────
  List<MascotaModel> get mascotas => _mascotas;
  List<MascotaModel> get mascotasPerdidas => _mascotasPerdidas;
  List<MascotaModel> get todasLasMascotas => _todasLasMascotas;
  bool get isLoading => _isLoading;
  bool get isLoadingPerdidas => _isLoadingPerdidas;
  String? get errorMessage => _errorMessage;

  // ── Mis Mascotas (usuario autenticado) ────────────────────────────────────

  /// Carga las mascotas del usuario y activa el canal Realtime.
  /// Si el usuario ya estaba suscrito, no vuelve a suscribirse.
  Future<void> cargarMascotas(String usuarioId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _mascotas = await _mascotaService.obtenerMascotasPorUsuario(usuarioId);
    } catch (e) {
      _errorMessage = 'Error al cargar las mascotas: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Solo suscribir si es un usuario distinto al que ya está suscrito.
    if (_usuarioIdSuscrito != usuarioId) {
      _usuarioIdSuscrito = usuarioId;
      _suscribirMisMascotas(usuarioId);
    }
  }

  /// Activa el canal Realtime para las mascotas del usuario.
  /// Escucha INSERT, UPDATE y DELETE para mantener la lista sincronizada.
  void _suscribirMisMascotas(String usuarioId) {
    _canalMisMascotas?.unsubscribe(); // cancelar suscripción anterior si existe

    _canalMisMascotas = Supabase.instance.client
        .channel('mis_mascotas_$usuarioId')
        // ── INSERT: nueva mascota creada ──────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mascotas',
          callback: (payload) async {
            final rec = payload.newRecord;
            // Ignorar mascotas de otros usuarios.
            if (rec['usua_id']?.toString() != usuarioId) return;
            final mascId = rec['masc_id']?.toString() ?? '';
            if (mascId.isEmpty) return;
            try {
              // Leer la fila completa para tener todos los campos.
              final row = await Supabase.instance.client
                  .from('mascotas')
                  .select()
                  .eq('masc_id', mascId)
                  .maybeSingle();
              if (row != null) {
                final model = MascotaModel.fromJson(row);
                // Evitar duplicados si el INSERT ya se reflejó localmente.
                if (!_mascotas.any((m) => m.id == model.id)) {
                  _mascotas.insert(0, model);
                  notifyListeners();
                }
              }
            } catch (e) {
              debugPrint('Realtime INSERT mis mascotas: $e');
            }
          },
        )
        // ── UPDATE: mascota modificada ────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'mascotas',
          callback: (payload) async {
            final rec = payload.newRecord;
            if (rec['usua_id']?.toString() != usuarioId) return;
            final mascId = rec['masc_id']?.toString() ?? '';
            if (mascId.isEmpty) return;
            try {
              final row = await Supabase.instance.client
                  .from('mascotas')
                  .select()
                  .eq('masc_id', mascId)
                  .maybeSingle();
              if (row != null) {
                final model = MascotaModel.fromJson(row);
                final idx = _mascotas.indexWhere((m) => m.id == mascId);
                if (idx != -1) {
                  _mascotas[idx] = model; // reemplazar el existente
                } else {
                  _mascotas.insert(0, model); // agregar si no estaba
                }
                notifyListeners();
              }
            } catch (e) {
              debugPrint('Realtime UPDATE mis mascotas: $e');
            }
          },
        )
        // ── DELETE: mascota eliminada ─────────────────────────────────────
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'mascotas',
          callback: (payload) {
            final mascId = payload.oldRecord['masc_id']?.toString() ?? '';
            if (mascId.isEmpty) return;
            final antes = _mascotas.length;
            _mascotas.removeWhere((m) => m.id == mascId);
            // Solo notificar si algo cambió realmente.
            if (_mascotas.length != antes) notifyListeners();
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Canal mis_mascotas_$usuarioId: $status ${error ?? ""}');
          if (status == 'SUBSCRIBED') {
            // Al reconectar, recargamos para no perder cambios offline.
            _mascotaService
                .obtenerMascotasPorUsuario(usuarioId)
                .then((lista) {
                  _mascotas = lista;
                  notifyListeners();
                })
                .catchError((e) {
                  debugPrint('Error recargar mis mascotas reconexión: $e');
                });
          }
        });
  }

  /// Cancela la suscripción Realtime de las mascotas del usuario.
  void desuscribirMisMascotas() {
    _canalMisMascotas?.unsubscribe();
    _canalMisMascotas = null;
    _usuarioIdSuscrito = null;
  }

  // ── Mascotas Perdidas ─────────────────────────────────────────────────────

  /// Carga las mascotas perdidas y activa el canal Realtime correspondiente.
  Future<void> cargarMascotasPerdidas() async {
    _isLoadingPerdidas = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _mascotasPerdidas = await _mascotaService.obtenerMascotasPerdidas();
    } catch (e) {
      _errorMessage = 'Error al cargar mascotas perdidas: $e';
    } finally {
      _isLoadingPerdidas = false;
      notifyListeners();
    }
    _suscribirRealtimePerdidas();
  }

  /// Activa el canal Realtime para mascotas perdidas.
  void _suscribirRealtimePerdidas() {
    _canalPerdidas?.unsubscribe();

    _canalPerdidas = Supabase.instance.client
        .channel('mascotas_perdidas_v2')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mascotas',
          callback: (payload) async {
            final nuevo = payload.newRecord;
            if (nuevo['masc_estado']?.toString().toLowerCase() != 'perdido')
              return;
            try {
              final row = await Supabase.instance.client
                  .from('mascotas')
                  .select(
                    '*, usuarios(usua_nombre, usua_telefono, usua_foto_url)',
                  )
                  .eq('masc_id', nuevo['masc_id'].toString())
                  .maybeSingle();
              if (row != null) {
                final model = MascotaModel.fromJson(row);
                if (!_mascotasPerdidas.any((m) => m.id == model.id)) {
                  _mascotasPerdidas.insert(0, model);
                  notifyListeners();
                }
              }
            } catch (e) {
              debugPrint('Realtime INSERT perdida: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'mascotas',
          callback: (payload) async {
            final nuevo = payload.newRecord;
            final mascId = nuevo['masc_id']?.toString() ?? '';
            if (mascId.isEmpty) return;
            final estado = nuevo['masc_estado']?.toString().toLowerCase() ?? '';

            if (estado == 'perdido') {
              // La mascota sigue perdida: actualizamos o agregamos.
              try {
                final row = await Supabase.instance.client
                    .from('mascotas')
                    .select(
                      '*, usuarios(usua_nombre, usua_telefono, usua_foto_url)',
                    )
                    .eq('masc_id', mascId)
                    .maybeSingle();
                if (row != null) {
                  final model = MascotaModel.fromJson(row);
                  final idx = _mascotasPerdidas.indexWhere(
                    (m) => m.id == mascId,
                  );
                  if (idx != -1) {
                    _mascotasPerdidas[idx] = model;
                  } else {
                    _mascotasPerdidas.insert(0, model);
                  }
                  notifyListeners();
                }
              } catch (e) {
                debugPrint('Realtime UPDATE perdida: $e');
              }
            } else {
              // La mascota ya no está perdida: quitarla de la lista.
              final antes = _mascotasPerdidas.length;
              _mascotasPerdidas.removeWhere((m) => m.id == mascId);
              if (_mascotasPerdidas.length != antes) notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'mascotas',
          callback: (payload) {
            final mascId = payload.oldRecord['masc_id']?.toString() ?? '';
            if (mascId.isEmpty) return;
            final antes = _mascotasPerdidas.length;
            _mascotasPerdidas.removeWhere((m) => m.id == mascId);
            if (_mascotasPerdidas.length != antes) notifyListeners();
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Canal mascotas_perdidas: $status ${error ?? ""}');
          if (status == 'SUBSCRIBED') {
            // Recargar al reconectar.
            _mascotaService
                .obtenerMascotasPerdidas()
                .then((lista) {
                  _mascotasPerdidas = lista;
                  notifyListeners();
                })
                .catchError((e) {
                  debugPrint('Error recargar perdidas reconexión: $e');
                });
          }
        });
  }

  /// Cancela el canal Realtime de mascotas perdidas.
  void detenerRealtimePerdidas() {
    _canalPerdidas?.unsubscribe();
    _canalPerdidas = null;
  }

  /// dispose() limpia todos los recursos al desmontar el provider.
  @override
  void dispose() {
    detenerRealtimePerdidas();
    desuscribirMisMascotas();
    super.dispose();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Agrega una nueva mascota. El Realtime la agregará a la lista automáticamente,
  /// pero también la agregamos localmente para respuesta inmediata.
  ///
  /// Si la mascota se crea directamente en estado 'perdido', dispara el
  /// broadcast FCM a todos los usuarios registrados (best-effort).
  Future<bool> agregarMascota(MascotaModel mascota) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final nueva = await _mascotaService.crearMascota(mascota);
      _mascotas.add(nueva);
      _isLoading = false;
      notifyListeners();

      // Si se creó directamente como perdida, notificar a todos.
      if (nueva.estado.toLowerCase() == 'perdido') {
        FcmService.instance.notificarMascotaPerdidaBroadcast(
          mascotaId: nueva.id,
          mascotaNombre: nueva.nombre,
          duenioId: nueva.usuarioId,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error agregarMascota: $e');
      final msg = e.toString();
      // Mensajes de error más descriptivos según el tipo de fallo.
      if (msg.contains('violates')) {
        _errorMessage = 'Error de validación en la base de datos: $msg';
      } else if (msg.contains('null value')) {
        _errorMessage =
            'Falta un campo requerido. Revisa los datos ingresados.';
      } else {
        _errorMessage = 'Error al guardar la mascota: $msg';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Actualiza una mascota existente.
  ///
  /// Si el estado cambia a 'perdido' (y antes no lo era), dispara el
  /// broadcast FCM a todos los usuarios registrados (best-effort).
  Future<bool> actualizarMascota(MascotaModel mascota) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Capturamos el estado anterior antes de hacer el update.
    final estadoAnterior = _mascotas
        .firstWhere((m) => m.id == mascota.id, orElse: () => mascota)
        .estado
        .toLowerCase();

    try {
      final actualizada = await _mascotaService.actualizarMascota(mascota);
      // Reemplazar en la lista local.
      final idx = _mascotas.indexWhere((m) => m.id == mascota.id);
      if (idx != -1) _mascotas[idx] = actualizada;
      _isLoading = false;
      notifyListeners();

      // Notificar solo cuando el estado CAMBIA a 'perdido' por primera vez.
      // Si ya estaba perdida no volvemos a spamear a todos los usuarios.
      if (actualizada.estado.toLowerCase() == 'perdido' &&
          estadoAnterior != 'perdido') {
        FcmService.instance.notificarMascotaPerdidaBroadcast(
          mascotaId: actualizada.id,
          mascotaNombre: actualizada.nombre,
          duenioId: actualizada.usuarioId,
        );
      }

      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar la mascota: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sube una imagen de mascota y retorna la URL, o null si falló.
  Future<String?> subirImagenMascota(File imagen, String extension) async {
    _isLoading = true;
    notifyListeners();
    try {
      return await _mascotaService.subirImagenMascota(imagen, extension);
    } catch (e) {
      _errorMessage = 'Error al subir imagen: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina una mascota de la BD y de todas las listas locales.
  Future<bool> eliminarMascota(String mascotaId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _mascotaService.eliminarMascota(mascotaId);
      // Eliminar de todas las listas para mantener la UI consistente.
      _mascotas.removeWhere((m) => m.id == mascotaId);
      _mascotasPerdidas.removeWhere((m) => m.id == mascotaId);
      _todasLasMascotas.removeWhere((m) => m.id == mascotaId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al eliminar la mascota: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Limpia la lista de mascotas del usuario y cancela la suscripción Realtime.
  /// Se llama al cerrar sesión.
  void limpiarMascotas() {
    desuscribirMisMascotas();
    _mascotas = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Carga todas las mascotas de la plataforma (para la vista del veterinario).
  Future<void> cargarTodasLasMascotas() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _todasLasMascotas = await _mascotaService.obtenerTodasLasMascotas();
    } catch (e) {
      _errorMessage = 'Error al cargar pacientes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
