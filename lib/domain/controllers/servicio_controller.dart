import 'package:flutter/material.dart';
import '../../data/models/servicio_model.dart';
import '../../data/services/servicio_service.dart';

class ServicioController extends ChangeNotifier {
  final ServicioService _service = ServicioService();

  List<ServicioModel> _servicios = [];
  // Mapa: servId → lista de veterinarios que lo atienden
  final Map<String, List<VeterinarioServicioModel>> _vetsPorServicio = {};
  // Servicios del vet logueado
  List<VeterinarioServicioModel> _misServicios = [];
  bool _isLoading = false;
  bool _isLoadingVets = false;
  bool _isLoadingMisServicios = false;
  String? _errorMessage;

  List<ServicioModel> get servicios => _servicios;
  List<VeterinarioServicioModel> get misServicios => _misServicios;
  bool get isLoading => _isLoading;
  bool get isLoadingVets => _isLoadingVets;
  bool get isLoadingMisServicios => _isLoadingMisServicios;
  String? get errorMessage => _errorMessage;

  bool tieneServicio(String servId) => _misServicios.any((s) => s.servId == servId);

  List<VeterinarioServicioModel> veterinariosPorServicio(String servId) =>
      _vetsPorServicio[servId] ?? [];

  /// Carga el catálogo de servicios.
  Future<void> cargarServicios() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _servicios = await _service.obtenerServicios();
    } catch (e) {
      _errorMessage = 'Error al cargar servicios: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga los veterinarios que atienden un servicio específico.
  Future<void> cargarVeterinariosPorServicio(String servId) async {
    _isLoadingVets = true;
    notifyListeners();
    try {
      _vetsPorServicio[servId] =
          await _service.obtenerVeterinariosPorServicio(servId);
    } catch (e) {
      _errorMessage = 'Error: $e';
    } finally {
      _isLoadingVets = false;
      notifyListeners();
    }
  }

  /// Carga los servicios asignados al veterinario logueado.
  Future<void> cargarMisServicios(String veteId) async {
    _isLoadingMisServicios = true;
    notifyListeners();
    try {
      _misServicios = await _service.obtenerServiciosPorVeterinario(veteId);
    } catch (e) {
      _errorMessage = 'Error: $e';
    } finally {
      _isLoadingMisServicios = false;
      notifyListeners();
    }
  }

  /// Asigna un nuevo servicio al veterinario.
  Future<bool> asignarServicio({
    required String veteId,
    required String servId,
    double? precio,
    String? duracion,
  }) async {
    try {
      await _service.asignarServicio(
          veteId: veteId, servId: servId, precio: precio, duracion: duracion);
      await cargarMisServicios(veteId);
      return true;
    } catch (e) {
      _errorMessage = 'Error al asignar: $e';
      notifyListeners();
      return false;
    }
  }

  /// Quita un servicio del veterinario.
  Future<bool> quitarServicio(String veseId, String veteId) async {
    try {
      await _service.quitarServicio(veseId);
      await cargarMisServicios(veteId);
      return true;
    } catch (e) {
      _errorMessage = 'Error al quitar: $e';
      notifyListeners();
      return false;
    }
  }
}
