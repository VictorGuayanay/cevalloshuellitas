import 'package:flutter/material.dart';
import '../../data/models/veterinario_model.dart';
import '../../data/services/veterinario_service.dart';

class VeterinarioController extends ChangeNotifier {
  final VeterinarioService _service = VeterinarioService();

  VeterinarioModel? _perfil;
  List<VeterinarioModel> _todos = [];
  bool _isLoading = false;
  String? _errorMessage;

  VeterinarioModel? get perfil => _perfil;
  List<VeterinarioModel> get todos => _todos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Carga el perfil del veterinario desde la tabla `veterinarios`.
  Future<void> cargarPerfil(String usuarioId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _perfil = await _service.obtenerPorUsuarioId(usuarioId);
    } catch (e) {
      _errorMessage = 'Error al cargar perfil: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda o actualiza el perfil del veterinario.
  /// Si no existe registro en veterinarios, lo crea.
  /// Si ya existe, lo actualiza usando el vete_id real.
  Future<bool> guardarPerfil(VeterinarioModel vet) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_perfil == null || _perfil!.id.isEmpty) {
        // No existe → INSERT
        _perfil = await _service.crearVeterinario(vet);
      } else {
        // Existe → UPDATE con el vete_id real del perfil cargado
        final vetConId = VeterinarioModel(
          id: _perfil!.id,
          usuarioId: _perfil!.usuarioId,
          nombre: _perfil!.nombre,
          especialidad: vet.especialidad,
          experiencia: vet.experiencia,
          tarifa: vet.tarifa,
          fotoUrl: vet.fotoUrl,
          disponible: vet.disponible,
          latitud: _perfil!.latitud,
          longitud: _perfil!.longitud,
          direccion: _perfil!.direccion,
        );
        _perfil = await _service.actualizarVeterinario(vetConId);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al guardar: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Alterna la disponibilidad del veterinario y actualiza en BD.
  /// Retorna true si tuvo éxito, false si falló (el estado se revierte).
  Future<bool> toggleDisponible() async {
    if (_perfil == null || _perfil!.id.isEmpty) return false;
    final valorAnterior = _perfil!.disponible;
    final nuevo = !valorAnterior;

    // Actualizar optimistamente en UI primero
    _perfil = _perfil!.copyWith(disponible: nuevo);
    notifyListeners();

    try {
      await _service.actualizarDisponibilidad(
        veteId: _perfil!.id,
        disponible: nuevo,
      );
      return true;
    } catch (e) {
      // Revertir si falló
      _perfil = _perfil!.copyWith(disponible: valorAnterior);
      _errorMessage = 'No se pudo actualizar la disponibilidad';
      notifyListeners();
      return false;
    }
  }

  /// Guarda la ubicación del veterinario en el mapa.
  Future<bool> guardarUbicacion({
    required double latitud,
    required double longitud,
    String? direccion,
  }) async {
    if (_perfil == null || _perfil!.id.isEmpty) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _service.guardarUbicacion(
        veteId: _perfil!.id,
        latitud: latitud,
        longitud: longitud,
        direccion: direccion,
      );
      _perfil = VeterinarioModel(
        id: _perfil!.id,
        usuarioId: _perfil!.usuarioId,
        nombre: _perfil!.nombre,
        especialidad: _perfil!.especialidad,
        experiencia: _perfil!.experiencia,
        tarifa: _perfil!.tarifa,
        fotoUrl: _perfil!.fotoUrl,
        disponible: _perfil!.disponible,
        latitud: latitud,
        longitud: longitud,
        direccion: direccion,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al guardar ubicación: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void limpiar() {
    _perfil = null;
    _todos = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Carga todos los veterinarios (para la pantalla de servicios del usuario).
  Future<void> cargarTodosLosVeterinarios() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _todos = await _service.obtenerTodos();
    } catch (e) {
      _errorMessage = 'Error al cargar veterinarios: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
