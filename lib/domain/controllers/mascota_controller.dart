import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/mascota_model.dart';
import '../../data/services/mascota_service.dart';

class MascotaController extends ChangeNotifier {
  final MascotaService _mascotaService = MascotaService();

  List<MascotaModel> _mascotas = [];
  List<MascotaModel> _mascotasAdopcion = [];
  List<MascotaModel> _mascotasPerdidas = [];
  List<MascotaModel> _todasLasMascotas = [];
  final Set<String> _favoritos = {};
  bool _isLoading = false;
  bool _isLoadingAdopciones = false;
  bool _isLoadingPerdidas = false;
  String? _errorMessage;

  // Canal Realtime para mascotas perdidas
  RealtimeChannel? _canalPerdidas;

  List<MascotaModel> get mascotas => _mascotas;
  List<MascotaModel> get mascotasAdopcion => _mascotasAdopcion;
  List<MascotaModel> get mascotasPerdidas => _mascotasPerdidas;
  List<MascotaModel> get todasLasMascotas => _todasLasMascotas;
  Set<String> get favoritos => _favoritos;
  List<MascotaModel> get mascotasFavoritas =>
      _mascotasAdopcion.where((m) => _favoritos.contains(m.id)).toList();
  bool get isLoading => _isLoading;
  bool get isLoadingAdopciones => _isLoadingAdopciones;
  bool get isLoadingPerdidas => _isLoadingPerdidas;
  String? get errorMessage => _errorMessage;

  bool esFavorito(String id) => _favoritos.contains(id);

  void toggleFavorito(String id) {
    if (_favoritos.contains(id)) {
      _favoritos.remove(id);
    } else {
      _favoritos.add(id);
    }
    notifyListeners();
  }

  /// Carga las mascotas de un usuario específico.
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
  }

  /// Carga todas las mascotas en estado de adopción.
  Future<void> cargarMascotasAdopcion() async {
    _isLoadingAdopciones = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _mascotasAdopcion = await _mascotaService.obtenerMascotasParaAdopcion();
    } catch (e) {
      _errorMessage = 'Error al cargar adopciones: $e';
    } finally {
      _isLoadingAdopciones = false;
      notifyListeners();
    }
  }

  /// Carga todas las mascotas con estado "perdido" y suscribe a cambios en tiempo real.
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

    // Iniciar escucha Realtime sobre la tabla mascotas
    _suscribirRealtimePerdidas();
  }

  /// Suscribe un canal Realtime que reacciona a INSERT, UPDATE y DELETE
  /// en la tabla mascotas para mantener la lista de perdidas actualizada.
  /// Maneja cada evento en memoria para evitar una query extra por cambio.
  void _suscribirRealtimePerdidas() {
    _canalPerdidas?.unsubscribe();

    _canalPerdidas = Supabase.instance.client
        .channel('mascotas_perdidas_v2')
        // INSERT: puede ser una mascota nueva que ya viene como "perdido"
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mascotas',
          callback: (payload) async {
            debugPrint('Realtime INSERT mascota');
            final nuevo = payload.newRecord;
            if (nuevo['masc_estado']?.toString().toLowerCase() == 'perdido') {
              // Necesitamos el join con usuarios — hacemos una sola query puntual
              try {
                final row = await Supabase.instance.client
                    .from('mascotas')
                    .select('*, usuarios(usua_nombre, usua_telefono, usua_foto_url)')
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
                debugPrint('Error Realtime INSERT perdida: $e');
              }
            }
          },
        )
        // UPDATE: puede pasar de otro estado a "perdido" o dejar de estar perdida
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'mascotas',
          callback: (payload) async {
            debugPrint('Realtime UPDATE mascota');
            final nuevo = payload.newRecord;
            final mascId = nuevo['masc_id']?.toString() ?? '';
            if (mascId.isEmpty) return;

            final nuevoEstado = nuevo['masc_estado']?.toString().toLowerCase() ?? '';

            if (nuevoEstado == 'perdido') {
              // Se volvió perdida: actualizar o agregar con join
              try {
                final row = await Supabase.instance.client
                    .from('mascotas')
                    .select('*, usuarios(usua_nombre, usua_telefono, usua_foto_url)')
                    .eq('masc_id', mascId)
                    .maybeSingle();
                if (row != null) {
                  final model = MascotaModel.fromJson(row);
                  final idx = _mascotasPerdidas.indexWhere((m) => m.id == mascId);
                  if (idx != -1) {
                    _mascotasPerdidas[idx] = model;
                  } else {
                    _mascotasPerdidas.insert(0, model);
                  }
                  notifyListeners();
                }
              } catch (e) {
                debugPrint('Error Realtime UPDATE perdida (agregar): $e');
              }
            } else {
              // Ya no está perdida: quitar de la lista
              final antes = _mascotasPerdidas.length;
              _mascotasPerdidas.removeWhere((m) => m.id == mascId);
              if (_mascotasPerdidas.length != antes) notifyListeners();
            }
          },
        )
        // DELETE: quitar de la lista directamente
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'mascotas',
          callback: (payload) {
            debugPrint('Realtime DELETE mascota');
            // old_record contiene el id en DELETE si REPLICA IDENTITY está configurado
            final mascId = payload.oldRecord['masc_id']?.toString() ?? '';
            if (mascId.isEmpty) return;
            final antes = _mascotasPerdidas.length;
            _mascotasPerdidas.removeWhere((m) => m.id == mascId);
            if (_mascotasPerdidas.length != antes) notifyListeners();
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Canal mascotas_perdidas: $status ${error ?? ""}');
          // Si el canal se reconecta, recargar para no perder cambios durante la desconexión
          if (status == 'SUBSCRIBED') {
            _mascotaService.obtenerMascotasPerdidas().then((lista) {
              _mascotasPerdidas = lista;
              notifyListeners();
            }).catchError((e) {
              debugPrint('Error al recargar perdidas en reconexión: $e');
            });
          }
        });
  }

  /// Cancela la suscripción Realtime de mascotas perdidas.
  void detenerRealtimePerdidas() {
    _canalPerdidas?.unsubscribe();
    _canalPerdidas = null;
  }

  @override
  void dispose() {
    detenerRealtimePerdidas();
    super.dispose();
  }

  /// Agrega una nueva mascota y la añade a la lista actual si es exitoso.
  Future<bool> agregarMascota(MascotaModel mascota) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nuevaMascota = await _mascotaService.crearMascota(mascota);
      _mascotas.add(nuevaMascota);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error agregarMascota: $e');
      final msg = e.toString();
      if (msg.contains('violates')) {
        _errorMessage = 'Error de validación en la base de datos: $msg';
      } else if (msg.contains('null value')) {
        _errorMessage = 'Falta un campo requerido. Revisa los datos ingresados.';
      } else {
        _errorMessage = 'Error al guardar la mascota: $msg';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Actualiza una mascota existente
  Future<bool> actualizarMascota(MascotaModel mascota) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final mascotaActualizada = await _mascotaService.actualizarMascota(mascota);

      // Actualizar en la lista local de mis mascotas
      final index = _mascotas.indexWhere((m) => m.id == mascota.id);
      if (index != -1) {
        _mascotas[index] = mascotaActualizada;
      }

      // Actualizar en la lista local de adopciones si corresponde
      final indexAdopcion = _mascotasAdopcion.indexWhere((m) => m.id == mascota.id);
      if (mascotaActualizada.estado.toLowerCase() == 'para adoptar') {
        if (indexAdopcion != -1) {
          _mascotasAdopcion[indexAdopcion] = mascotaActualizada;
        } else {
          _mascotasAdopcion.add(mascotaActualizada);
        }
      } else {
        if (indexAdopcion != -1) {
          _mascotasAdopcion.removeAt(indexAdopcion);
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar la mascota: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sube una imagen de mascota delegando al servicio
  Future<String?> subirImagenMascota(File imagen, String extension) async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = await _mascotaService.subirImagenMascota(imagen, extension);
      return url;
    } catch (e) {
      _errorMessage = 'Error al subir imagen: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina una mascota por ID y la remueve de todas las listas locales.
  Future<bool> eliminarMascota(String mascotaId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _mascotaService.eliminarMascota(mascotaId);
      _mascotas.removeWhere((m) => m.id == mascotaId);
      _mascotasAdopcion.removeWhere((m) => m.id == mascotaId);
      _mascotasPerdidas.removeWhere((m) => m.id == mascotaId);
      _todasLasMascotas.removeWhere((m) => m.id == mascotaId);
      _favoritos.remove(mascotaId);
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

  /// Limpia la lista de mascotas (útil al cerrar sesión)
  void limpiarMascotas() {
    _mascotas = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Carga TODAS las mascotas (para uso del veterinario).
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
