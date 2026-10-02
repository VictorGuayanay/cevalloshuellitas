// productor_controller.dart — Controlador de productores pecuarios en venta.
//
// Carga la lista de productores con animales disponibles para venta
// y la expone para que el mapa muestre sus marcadores.

import 'package:flutter/foundation.dart';
import '../../data/models/productor_model.dart';
import '../../data/services/productor_service.dart';

class ProductorController extends ChangeNotifier {
  final ProductorService _service = ProductorService();

  // ── Estado interno ─────────────────────────────────────────────────────────
  List<ProductorModel> _productores = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<ProductorModel> get productores => _productores;

  /// Solo los productores que tienen coordenadas GPS válidas.
  List<ProductorModel> get productoresConUbicacion =>
      _productores.where((p) => p.tieneUbicacion).toList();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ── Carga ──────────────────────────────────────────────────────────────────

  /// Carga todos los productores con animales en venta desde Supabase.
  /// Solo filtra productores con usua_direccion_gps para reducir datos transferidos.
  Future<void> cargarProductores() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _productores = await _service.obtenerProductoresEnVenta();
      debugPrint(
          'ProductorController: ${_productores.length} productores cargados, '
          '${productoresConUbicacion.length} con ubicación GPS.');
    } catch (e) {
      _errorMessage = 'Error al cargar productores: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Limpia el estado. Se llama al cerrar sesión.
  void limpiar() {
    _productores = [];
    _errorMessage = null;
    notifyListeners();
  }
}
