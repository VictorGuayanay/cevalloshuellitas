// mapa_veterinarios_screen.dart
//
// Mejoras de rendimiento:
//   · FlutterMap vive en su propio StatefulWidget (_MapView) para que los
//     Consumer de datos NO lo reconstruyan ni descarten el caché de tiles.
//   · onPositionChanged ya no llama setState() en cada frame: solo activa
//     _mapReady una vez y controla la brújula con un ValueNotifier.
//   · Las dos cargas de Supabase se lanzan en paralelo (Future.wait).
//   · Los marcadores usan RepaintBoundary para aislar sus repaints.
//
// Mejoras visuales:
//   · Marcadores tipo "pin" con sombra de color en lugar de círculos planos.
//   · Skeleton shimmer mientras cargan los datos.
//   · Card de detalle con gradiente de acento y chips rediseñados.
//   · Barra de búsqueda con glassmorphism suave.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import '../../../data/models/veterinario_model.dart';
import '../../../data/models/productor_model.dart';
import '../../../domain/controllers/veterinario_controller.dart';
import '../../../domain/controllers/productor_controller.dart';
import '../../../core/app_colors.dart';

enum _TipoSeleccionado { veterinario, productor }

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla principal
// ─────────────────────────────────────────────────────────────────────────────
class MapaVeterinariosScreen extends StatefulWidget {
  const MapaVeterinariosScreen({super.key});
  @override
  State<MapaVeterinariosScreen> createState() => _MapaVeterinariosScreenState();
}

class _MapaVeterinariosScreenState extends State<MapaVeterinariosScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Brújula: ValueNotifier evita rebuilds del árbol completo
  final ValueNotifier<double> _rotationNotifier = ValueNotifier(0);
  bool _mapReady = false;

  VeterinarioModel? _vetSeleccionado;
  ProductorModel? _productorSeleccionado;
  _TipoSeleccionado? _tipoSeleccionado;

  bool _locating = false;
  LatLng? _currentLocation;

  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  LatLng? _searchMarker;
  String? _searchLabel;

  late AnimationController _cardAnim;
  late Animation<Offset> _cardSlide;

  bool _mostrarVets = true;
  bool _mostrarProductores = true;

  // Datos pre-procesados — se actualizan desde los controllers
  List<VeterinarioModel> _vets = [];
  List<ProductorModel> _prods = [];

  static const LatLng _centroEcuador = LatLng(-1.8312, -78.1834);

  @override
  void initState() {
    super.initState();

    _cardAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardAnim, curve: Curves.easeOutCubic));

    _searchCtrl.addListener(() => setState(() {}));

    // Cargar datos en paralelo para reducir tiempo de espera total
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.wait([
        context.read<VeterinarioController>().cargarTodosLosVeterinarios(),
        context.read<ProductorController>().cargarProductores(),
      ]);
    });
  }

  @override
  void dispose() {
    _cardAnim.dispose();
    _searchCtrl.dispose();
    _rotationNotifier.dispose();
    super.dispose();
  }

  // ── Selección ─────────────────────────────────────────────────────────────

  void _seleccionarVet(VeterinarioModel vet) {
    setState(() {
      _vetSeleccionado = vet;
      _productorSeleccionado = null;
      _tipoSeleccionado = _TipoSeleccionado.veterinario;
    });
    _cardAnim.forward(from: 0);
    _mapController.move(LatLng(vet.latitud!, vet.longitud!), 15);
  }

  void _seleccionarProductor(ProductorModel p) {
    setState(() {
      _productorSeleccionado = p;
      _vetSeleccionado = null;
      _tipoSeleccionado = _TipoSeleccionado.productor;
    });
    _cardAnim.forward(from: 0);
    _mapController.move(LatLng(p.latitud!, p.longitud!), 15);
  }

  void _cerrarCard() {
    _cardAnim.reverse().then((_) {
      if (mounted) {
        setState(() {
          _vetSeleccionado = null;
          _productorSeleccionado = null;
          _tipoSeleccionado = null;
        });
      }
    });
  }

  bool get _hayCard => _tipoSeleccionado != null;

  // ── Búsqueda ──────────────────────────────────────────────────────────────

  Future<void> _buscarDireccion(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q)}&format=json&limit=5&addressdetails=1',
      );
      final res = await http.get(
        url,
        headers: {'User-Agent': 'com.cevallos.huellitas/1.0.0'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) setState(() => _searchResults = data);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── GPS ───────────────────────────────────────────────────────────────────

  Future<void> _irAMiUbicacion() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Activa los servicios de ubicación.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _snack('Permiso de ubicación denegado.');
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _snack('Activa los permisos en ajustes del sistema.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentLocation = ll);
      _mapController.move(ll, 16);
    } catch (_) {
      _snack('No se pudo obtener la ubicación.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.darkAlt,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Leer controllers solo para saber si están cargando y actualizar listas
    // locales. El mapa NO escucha estos consumers directamente.
    final vetCtrl = context.watch<VeterinarioController>();
    final prodCtrl = context.watch<ProductorController>();

    // Filtrar y cachear listas (solo cuando cambian los controllers)
    _vets = vetCtrl.todos
        .where((v) => v.latitud != null && v.longitud != null)
        .toList();
    _prods = prodCtrl.productoresConUbicacion;

    final isLoading = vetCtrl.isLoading || prodCtrl.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Stack(
        children: [
          // ── 1. Mapa aislado: no se reconstruye con los consumers ───────
          _MapView(
            mapController: _mapController,
            rotationNotifier: _rotationNotifier,
            currentLocation: _currentLocation,
            searchMarker: _searchMarker,
            searchLabel: _searchLabel,
            vets: _mostrarVets ? _vets : [],
            prods: _mostrarProductores ? _prods : [],
            vetSeleccionadoId: _vetSeleccionado?.id,
            prodSeleccionadoId: _productorSeleccionado?.usuarioId,
            onTapVet: _seleccionarVet,
            onTapProductor: _seleccionarProductor,
            onTapFondo: _cerrarCard,
            onMapReady: () {
              if (!_mapReady) setState(() => _mapReady = true);
            },
            onRotationChanged: (r) => _rotationNotifier.value = r,
          ),

          // ── 2. Skeleton shimmer mientras cargan los datos ──────────────
          if (isLoading) const _MapSkeleton(),

          // ── 3. Barra superior ──────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SearchBar(
                    controller: _searchCtrl,
                    isSearching: _isSearching,
                    onBack: () => Navigator.pop(context),
                    onSearch: _buscarDireccion,
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() {
                        _searchResults = [];
                        _searchMarker = null;
                        _searchLabel = null;
                      });
                      FocusScope.of(context).unfocus();
                    },
                  ),
                  if (_searchResults.isNotEmpty)
                    _SearchResultsList(
                      results: _searchResults,
                      onSelect: (lat, lon, label) {
                        setState(() {
                          _searchMarker = LatLng(lat, lon);
                          _searchLabel = label;
                          _searchResults = [];
                        });
                        _mapController.move(LatLng(lat, lon), 15);
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  const SizedBox(height: 8),
                  // Toggles de capa
                  Row(
                    children: [
                      const SizedBox(width: 52),
                      _LayerToggle(
                        color: AppColors.tealLight,
                        icon: Icons.medical_services_rounded,
                        label: 'Veterinarios',
                        count: _vets.length,
                        active: _mostrarVets,
                        onTap: () =>
                            setState(() => _mostrarVets = !_mostrarVets),
                      ),
                      const SizedBox(width: 8),
                      _LayerToggle(
                        color: AppColors.vetGreen,
                        icon: Icons.agriculture_rounded,
                        label: 'Productores',
                        count: _prods.length,
                        active: _mostrarProductores,
                        onTap: () => setState(
                          () => _mostrarProductores = !_mostrarProductores,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── 4. Controles laterales ─────────────────────────────────────
          Positioned(
            right: 14,
            bottom: _hayCard ? 300 : 30,
            child: Column(
              children: [
                // Brújula — solo aparece cuando el mapa está rotado
                ValueListenableBuilder<double>(
                  valueListenable: _rotationNotifier,
                  builder: (_, rot, __) {
                    if (rot.abs() < 1.0) return const SizedBox.shrink();
                    return Column(
                      children: [
                        _FloatingBtn(
                          icon: Icons.explore_rounded,
                          color: AppColors.orange,
                          rotate: -rot * (3.14159265 / 180),
                          onTap: () => _mapController.rotate(0.0),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
                // GPS
                _FloatingBtn(
                  icon: _locating
                      ? Icons.sync_rounded
                      : Icons.my_location_rounded,
                  color: _currentLocation != null
                      ? AppColors.tealLight
                      : AppColors.grey,
                  loading: _locating,
                  onTap: _irAMiUbicacion,
                ),
                const SizedBox(height: 8),
                // Zoom +
                _FloatingBtn(
                  icon: Icons.add_rounded,
                  onTap: () => _mapReady
                      ? _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        )
                      : null,
                ),
                const SizedBox(height: 4),
                // Zoom -
                _FloatingBtn(
                  icon: Icons.remove_rounded,
                  onTap: () => _mapReady
                      ? _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        )
                      : null,
                ),
              ],
            ),
          ),

          // ── 5. Card de detalle ─────────────────────────────────────────
          if (_hayCard)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _cardSlide,
                child: _tipoSeleccionado == _TipoSeleccionado.veterinario
                    ? _VetCard(vet: _vetSeleccionado!, onClose: _cerrarCard)
                    : _ProductorCard(
                        p: _productorSeleccionado!,
                        onClose: _cerrarCard,
                      ),
              ),
            ),

          // ── 6. Estado vacío ────────────────────────────────────────────
          if (!isLoading && _vets.isEmpty && _prods.isEmpty)
            const _EmptyState(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget del mapa aislado — se reconstruye SOLO cuando cambian sus propios
// parámetros, no cuando los controllers notifican cambios.
// ─────────────────────────────────────────────────────────────────────────────
class _MapView extends StatefulWidget {
  final MapController mapController;
  final ValueNotifier<double> rotationNotifier;
  final LatLng? currentLocation;
  final LatLng? searchMarker;
  final String? searchLabel;
  final List<VeterinarioModel> vets;
  final List<ProductorModel> prods;
  final String? vetSeleccionadoId;
  final String? prodSeleccionadoId;
  final void Function(VeterinarioModel) onTapVet;
  final void Function(ProductorModel) onTapProductor;
  final VoidCallback onTapFondo;
  final VoidCallback onMapReady;
  final void Function(double) onRotationChanged;

  const _MapView({
    required this.mapController,
    required this.rotationNotifier,
    required this.currentLocation,
    required this.searchMarker,
    required this.searchLabel,
    required this.vets,
    required this.prods,
    required this.vetSeleccionadoId,
    required this.prodSeleccionadoId,
    required this.onTapVet,
    required this.onTapProductor,
    required this.onTapFondo,
    required this.onMapReady,
    required this.onRotationChanged,
  });

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  static const LatLng _centroEcuador = LatLng(-1.8312, -78.1834);
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.vets.isNotEmpty
        ? LatLng(widget.vets.first.latitud!, widget.vets.first.longitud!)
        : _centroEcuador;

    return FlutterMap(
      mapController: widget.mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 13,
        maxZoom: 19,
        minZoom: 5,
        onTap: (_, __) => widget.onTapFondo(),
        onPositionChanged: (pos, _) {
          // Solo llama setState una vez (cuando el mapa ya cargó)
          if (!_ready) {
            setState(() => _ready = true);
            widget.onMapReady();
          }
          // Notificamos la rotación sin reconstruir el árbol
          widget.onRotationChanged(pos.rotation ?? 0);
        },
      ),
      children: [
        // ── Tiles OSM ──────────────────────────────────────────────────
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.cevallos.huellitas',
        ),

        // ── Ubicación del usuario ──────────────────────────────────────
        if (widget.currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.currentLocation!,
                width: 48,
                height: 48,
                child: const RepaintBoundary(child: _UserDot()),
              ),
            ],
          ),

        // ── Marcador de búsqueda ───────────────────────────────────────
        if (widget.searchMarker != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.searchMarker!,
                width: 130,
                height: 76,
                child: _PinLabel(
                  label: widget.searchLabel ?? 'Dirección',
                  color: AppColors.orange,
                ),
              ),
            ],
          ),

        // ── Marcadores productores ─────────────────────────────────────
        MarkerLayer(
          markers: widget.prods.map((p) {
            final sel = widget.prodSeleccionadoId == p.usuarioId;
            return Marker(
              point: LatLng(p.latitud!, p.longitud!),
              width: sel ? 68 : 54,
              height: sel ? 80 : 64,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: () => widget.onTapProductor(p),
                  child: _PinMarker(
                    foto: p.fotoUrl,
                    color: AppColors.vetGreen,
                    icon: Icons.agriculture_rounded,
                    selected: sel,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // ── Marcadores veterinarios ────────────────────────────────────
        MarkerLayer(
          markers: widget.vets.map((v) {
            final sel = widget.vetSeleccionadoId == v.id;
            return Marker(
              point: LatLng(v.latitud!, v.longitud!),
              width: sel ? 68 : 54,
              height: sel ? 80 : 64,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: () => widget.onTapVet(v),
                  child: _PinMarker(
                    foto: v.fotoUrl,
                    color: AppColors.tealLight,
                    icon: Icons.medical_services_rounded,
                    selected: sel,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Marcador tipo pin con foto circular + punta inferior
// ─────────────────────────────────────────────────────────────────────────────
class _PinMarker extends StatelessWidget {
  final String? foto;
  final Color color;
  final IconData icon;
  final bool selected;

  const _PinMarker({
    required this.foto,
    required this.color,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final size = selected ? 52.0 : 42.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: selected ? 3.0 : 2.0),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: selected ? 0.55 : 0.25),
                blurRadius: selected ? 18 : 8,
                spreadRadius: selected ? 3 : 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: foto != null && foto!.isNotEmpty
                ? Image.network(
                    foto!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallback(selected),
                  )
                : _fallback(selected),
          ),
        ),
        // Punta del pin
        CustomPaint(
          painter: _PinTipPainter(color: color),
          size: const Size(10, 6),
        ),
      ],
    );
  }

  Widget _fallback(bool sel) =>
      Icon(icon, size: sel ? 24 : 18, color: sel ? Colors.white : color);
}

class _PinTipPainter extends CustomPainter {
  final Color color;
  const _PinTipPainter({required this.color});
  @override
  void paint(Canvas c, Size s) {
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(s.width, 0)
        ..lineTo(s.width / 2, s.height)
        ..close(),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton shimmer durante la carga
// ─────────────────────────────────────────────────────────────────────────────
class _MapSkeleton extends StatefulWidget {
  const _MapSkeleton();
  @override
  State<_MapSkeleton> createState() => _MapSkeletonState();
}

class _MapSkeletonState extends State<_MapSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => Container(
        color: Color.lerp(
          const Color(0xFFDCEAEC),
          const Color(0xFFB8D8DC),
          _shimmer.value,
        )!.withValues(alpha: 0.65),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.tealLight,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Cargando mapa…',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkAlt,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de búsqueda
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final VoidCallback onBack;
  final void Function(String) onSearch;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.isSearching,
    required this.onBack,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FloatingBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_rounded,
                  color: AppColors.tealLight,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.darkAlt,
                    ),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Buscar dirección…',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.grey,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: onSearch,
                  ),
                ),
                if (controller.text.isNotEmpty) ...[
                  isSearching
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.tealLight,
                          ),
                        )
                      : GestureDetector(
                          onTap: () => onSearch(controller.text),
                          child: Icon(
                            Icons.search_rounded,
                            color: AppColors.tealLight,
                            size: 18,
                          ),
                        ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.grey,
                    ),
                  ),
                ],
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lista de resultados de búsqueda
// ─────────────────────────────────────────────────────────────────────────────
class _SearchResultsList extends StatelessWidget {
  final List<dynamic> results;
  final void Function(double lat, double lon, String label) onSelect;

  const _SearchResultsList({required this.results, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6, left: 52),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: results.length,
        separatorBuilder: (_, __) =>
            Divider(color: Colors.grey.shade100, height: 1),
        itemBuilder: (_, i) {
          final item = results[i];
          return ListTile(
            dense: true,
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.tealLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: AppColors.tealLight,
                size: 14,
              ),
            ),
            title: Text(
              item['display_name'] ?? '',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.darkAlt,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              final lat = double.tryParse(item['lat']?.toString() ?? '');
              final lon = double.tryParse(item['lon']?.toString() ?? '');
              if (lat == null || lon == null) return;
              final addr = item['address'];
              final label = addr != null
                  ? (addr['road'] ??
                        addr['suburb'] ??
                        addr['city'] ??
                        'Dirección')
                  : 'Dirección';
              onSelect(lat, lon, label as String);
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggle de capa con contador de marcadores
// ─────────────────────────────────────────────────────────────────────────────
class _LayerToggle extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _LayerToggle({
    required this.color,
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color : Colors.grey.shade300,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? color : Colors.grey.shade400),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? color : Colors.grey.shade400,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? color : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Punto pulsante de ubicación del usuario
// ─────────────────────────────────────────────────────────────────────────────
class _UserDot extends StatefulWidget {
  const _UserDot();
  @override
  State<_UserDot> createState() => _UserDotState();
}

class _UserDotState extends State<_UserDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scale = Tween(
      begin: 0.7,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _scale,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.tealLight.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.tealLight.withValues(alpha: 0.6),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pin label (resultado de búsqueda)
// ─────────────────────────────────────────────────────────────────────────────
class _PinLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _PinLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        CustomPaint(
          painter: _PinTipPainter(color: color),
          size: const Size(10, 6),
        ),
        Icon(Icons.location_on_rounded, color: color, size: 26),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Botón flotante del mapa
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingBtn extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final double? rotate;
  final bool loading;

  const _FloatingBtn({
    required this.icon,
    this.color,
    this.onTap,
    this.rotate,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: loading
            ? Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.tealLight,
                  ),
                ),
              )
            : rotate != null
            ? Transform.rotate(
                angle: rotate!,
                child: Icon(
                  icon,
                  color: color ?? AppColors.tealLight,
                  size: 22,
                ),
              )
            : Icon(icon, color: color ?? AppColors.tealLight, size: 22),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card detalle — Veterinario
// ─────────────────────────────────────────────────────────────────────────────
class _VetCard extends StatelessWidget {
  final VeterinarioModel vet;
  final VoidCallback onClose;
  const _VetCard({required this.vet, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return _DetailCardShell(
      accentColor: AppColors.tealLight,
      onClose: onClose,
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            url: vet.fotoUrl,
            color: AppColors.tealLight,
            fallback: Icons.medical_services_rounded,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vet.nombre ?? 'Veterinario',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkAlt,
                  ),
                ),
                const SizedBox(height: 4),
                if (vet.especialidad != null && vet.especialidad!.isNotEmpty)
                  Text(
                    vet.especialidad!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.tealLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          _StatusBadge(
            label: vet.disponible ? 'Disponible' : 'Ocupado',
            color: vet.disponible
                ? Colors.green.shade600
                : Colors.grey.shade500,
            bg: vet.disponible ? Colors.green.shade50 : Colors.grey.shade100,
          ),
        ],
      ),
      chips: [
        if (vet.experiencia != null)
          _Chip(
            icon: Icons.workspace_premium_rounded,
            label: '${vet.experiencia} años',
            color: AppColors.tealLight,
          ),
        if (vet.tarifa != null)
          _Chip(
            icon: Icons.attach_money_rounded,
            label: '\$${vet.tarifa!.toStringAsFixed(2)}/consulta',
            color: AppColors.green,
          ),
        if (vet.telefono != null)
          _Chip(
            icon: Icons.phone_rounded,
            label: vet.telefono!,
            color: AppColors.orange,
          ),
      ],
      extra: vet.direccion != null && vet.direccion!.isNotEmpty
          ? _AddressRow(text: vet.direccion!)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card detalle — Productor
// ─────────────────────────────────────────────────────────────────────────────
class _ProductorCard extends StatelessWidget {
  final ProductorModel p;
  final VoidCallback onClose;
  const _ProductorCard({required this.p, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return _DetailCardShell(
      accentColor: AppColors.vetGreen,
      onClose: onClose,
      header: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            url: p.fotoUrl,
            color: AppColors.vetGreen,
            fallback: Icons.agriculture_rounded,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkAlt,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Productor pecuario',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.vetGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _StatusBadge(
            label: 'En venta',
            color: AppColors.vetGreen,
            bg: AppColors.vetGreen.withValues(alpha: 0.1),
          ),
        ],
      ),
      chips: [
        _Chip(
          icon: Icons.pets_rounded,
          label: '${p.totalAnimales} animales',
          color: AppColors.vetGreen,
        ),
        if (p.tipoAnimales != null)
          _Chip(
            icon: Icons.category_rounded,
            label: _tipoLabel(p.tipoAnimales!),
            color: AppColors.orange,
          ),
        if (p.telefono != null)
          _Chip(
            icon: Icons.phone_rounded,
            label: p.telefono!,
            color: AppColors.teal,
          ),
      ],
      extra: p.especiesEnVenta.isNotEmpty
          ? _EspeciesWrap(especies: p.especiesEnVenta)
          : null,
    );
  }

  String _tipoLabel(String t) {
    switch (t) {
      case 'menores':
        return 'Animales menores';
      case 'mayores':
        return 'Animales mayores';
      case 'ambos':
        return 'Menores y mayores';
      default:
        return t;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell compartido de la card de detalle
// ─────────────────────────────────────────────────────────────────────────────
class _DetailCardShell extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onClose;
  final Widget header;
  final List<Widget> chips;
  final Widget? extra;

  const _DetailCardShell({
    required this.accentColor,
    required this.onClose,
    required this.header,
    required this.chips,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Franja de acento en la parte superior
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle + close
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                header,
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
                ],
                if (extra != null) ...[const SizedBox(height: 10), extra!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets de apoyo para las cards
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? url;
  final Color color;
  final IconData fallback;
  const _Avatar({
    required this.url,
    required this.color,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(fallback, color: color, size: 28),
              )
            : Icon(fallback, color: color, size: 28),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final String text;
  const _AddressRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on_rounded, size: 14, color: AppColors.orange),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EspeciesWrap extends StatelessWidget {
  final List<EspecieEnVenta> especies;
  const _EspeciesWrap({required this.especies});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Disponibles para venta:',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: especies
              .map(
                (e) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.vetGreen.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.vetGreen.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.especie,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.vetGreen,
                        ),
                      ),
                      Text(
                        ' · ${e.numeroAnimales}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado vacío
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.tealLight.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_off_rounded,
                size: 38,
                color: AppColors.tealLight,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Sin ubicaciones aún',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.darkAlt,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Veterinarios y productores\naún no han registrado su ubicación.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
