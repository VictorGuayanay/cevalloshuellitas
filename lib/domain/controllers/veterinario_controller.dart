// veterinario_controller.dart — Controlador del perfil y lista de veterinarios.
//
// Gestiona dos contextos:
//   1. Perfil del veterinario autenticado (edición de datos, disponibilidad, ubicación)
//   2. Lista de todos los veterinarios (para la pantalla de servicios del usuario)

import 'package:flutter/material.dart';
import '../../data/models/veterinario_model.dart';
import '../../data/services/veterinario_service.dart';

class VeterinarioController extends ChangeNotifier {
  final VeterinarioService _service = VeterinarioService();

  // ── Estado interno ─────────────────────────────────────────────────────────
  VeterinarioModel? _perfil;       // perfil del veterinario autenticado
  List<VeterinarioModel> _todos = []; // todos los veterinarios de la plataforma
  bool _isLoading   = false;
  String? _errorMessage;

  // ── Getters ────────────────────────────────────────────────────────────────
  VeterinarioModel? get perfil    => _perfil;
  List<VeterinarioModel> get todos => _todos;
  bool get isLoading               => _isLoading;
  String? get errorMessage         => _errorMessage;

  // ── Perfil del veterinario ─────────────────────────────────────────────────

  /// Carga el perfil del veterinario desde la BD usando su usua_id.
  /// Si no tiene registro en la tabla veterinarios, _perfil queda null.
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
  ///
  /// Si no existe registro (perfil == null o sin ID), hace INSERT.
  /// Si ya existe, hace UPDATE usando el vete_id del perfil cargado.
  Future<bool> guardarPerfil(VeterinarioModel vet) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_perfil == null || _perfil!.id.isEmpty) {
        // Primera vez → crear registro en la tabla veterinarios.
        _perfil = await _service.crearVeterinario(vet);
      } else {
        // Ya existe → actualizar conservando el ID y los datos de ubicación.
        final vetConId = VeterinarioModel(
          id:           _perfil!.id,
          usuarioId:    _perfil!.usuarioId,
          nombre:       _perfil!.nombre,
          especialidad: vet.especialidad,
          experiencia:  vet.experiencia,
          tarifa:       vet.tarifa,
          fotoUrl:      vet.fotoUrl,
          disponible:   vet.disponible,
          // Conservamos la ubicación anterior (no se edita desde este formulario).
          latitud:   _perfil!.latitud,
          longitud:  _perfil!.longitud,
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

  /// Alterna la disponibilidad del veterinario (disponible ↔ no disponible).
  ///
  /// Usa actualización optimista: cambia el estado en la UI primero y
  /// luego confirma con la BD. Si falla, revierte el cambio.
  Future<bool> toggleDisponible() async {
    if (_perfil == null || _perfil!.id.isEmpty) return false;

    final valorAnterior = _perfil!.disponible;
    final nuevoValor    = !valorAnterior;

    // Actualizar en la UI de inmediato para que la respuesta sea fluida.
    _perfil = _perfil!.copyWith(disponible: nuevoValor);
    notifyListeners();

    try {
      await _service.actualizarDisponibilidad(
        veteId: _perfil!.id,
        disponible: nuevoValor,
      );
      return true;
    } catch (e) {
      // Si falló, revertir al valor anterior.
      _perfil = _perfil!.copyWith(disponible: valorAnterior);
      _errorMessage = 'No se pudo actualizar la disponibilidad';
      notifyListeners();
      return false;
    }
  }

  /// Guarda la ubicación GPS del veterinario en la BD y actualiza el estado local.
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
        veteId:   _perfil!.id,
        latitud:  latitud,
        longitud: longitud,
        direccion: direccion,
      );
      // Actualizar el modelo local con la nueva ubicación.
      _perfil = _perfil!.copyWith(
        latitud:   latitud,
        longitud:  longitud,
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

  // ── Lista de veterinarios ──────────────────────────────────────────────────

  /// Carga todos los veterinarios para la pantalla de servicios del usuario.
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

  /// Limpia el estado del controlador. Se llama al cerrar sesión.
  void limpiar() {
    _perfil = null;
    _todos  = [];
    _errorMessage = null;
    notifyListeners();
  }
}
