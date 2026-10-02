import 'package:flutter/material.dart';
import '../../../presentation/widgets/header_wave_clipper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/veterinario_model.dart';
import '../../../data/models/productor_model.dart';
import '../../../data/services/productor_service.dart';
import '../../../domain/controllers/veterinario_controller.dart';
import '../../../core/app_colors.dart';

class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key});

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Productores reales desde Supabase ─────────────────────────────────────
  List<ProductorModel> _productores = [];
  bool _loadingProductores = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VeterinarioController>().cargarTodosLosVeterinarios();
      _cargarProductores();
    });
  }

  Future<void> _cargarProductores() async {
    setState(() => _loadingProductores = true);
    _productores = await ProductorService().obtenerProductoresEnVenta();
    if (mounted) setState(() => _loadingProductores = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Column(
        children: [
          _buildHeader(context),
          _buildTabSelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVeterinariosTab(),
                _buildProductoresPecuariosTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Cabecera ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return ClipPath(
      clipper: HeaderWaveClipper(),
      child: Container(
        height: 180,
        color: AppColors.tealBg,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.darkAlt, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Text(
                      'Servicios',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkAlt,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Explora veterinarios y productores pecuarios',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.darkAlt.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Selector de tabs ────────────────────────────────────────────────────────
  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (ctx, child) => Row(
          children: [
            _tabPill(index: 0, icon: Icons.person_outline_rounded, label: 'Veterinarios'),
            const SizedBox(width: 12),
            _tabPill(index: 1, icon: Icons.agriculture_rounded, label: 'Pecuarios'),
          ],
        ),
      ),
    );
  }

  Widget _tabPill({required int index, required IconData icon, required String label}) {
    final isActive = _tabController.index == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.tealLight : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? AppColors.tealLight.withValues(alpha: 0.30)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : AppColors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Veterinarios ────────────────────────────────────────────────────────
  Widget _buildVeterinariosTab() {
    return Consumer<VeterinarioController>(
      builder: (context, ctrl, _) {
        if (ctrl.isLoading) {
          return Center(child: CircularProgressIndicator(color: AppColors.tealLight));
        }
        if (ctrl.todos.isEmpty) {
          return _emptyState(
            icon: Icons.person_off_outlined,
            message: 'Sin veterinarios registrados',
          );
        }

        final filtrados = _searchQuery.isEmpty
            ? ctrl.todos
            : ctrl.todos
                .where((v) =>
                    (v.nombre ?? '').toLowerCase().contains(_searchQuery) ||
                    (v.especialidad ?? '').toLowerCase().contains(_searchQuery))
                .toList();

        return Column(children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.darkAlt),
                decoration: InputDecoration(
                  hintText: 'Buscar veterinario por nombre...',
                  hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.grey),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: AppColors.tealLight, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, color: AppColors.grey, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtrados.length} resultado${filtrados.length != 1 ? "s" : ""} para "$_searchQuery"',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.grey,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          Expanded(
            child: filtrados.isEmpty
                ? _emptyState(
                    icon: Icons.search_off_rounded,
                    message: 'Sin resultados para "$_searchQuery"',
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    itemCount: filtrados.length,
                    itemBuilder: (context, i) => _buildVeterinarioCard(filtrados[i]),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _buildVeterinarioCard(VeterinarioModel v) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _PerfilVeterinarioDirectoPage(vet: v)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.tealLight.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.tealLight.withValues(alpha: 0.35), width: 2),
                ),
                child: ClipOval(
                  child: (v.fotoUrl != null && v.fotoUrl!.isNotEmpty)
                      ? Image.network(v.fotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.person_outline_rounded,
                              size: 30,
                              color: AppColors.tealLight))
                      : Icon(Icons.person_outline_rounded,
                          size: 30, color: AppColors.tealLight),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          v.nombre != null && v.nombre!.isNotEmpty
                              ? 'Dr/a. ${v.nombre}'
                              : 'Dr/a. Veterinario',
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkAlt),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    if (v.especialidad != null && v.especialidad!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(v.especialidad!,
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.tealLight,
                              fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 6),
                    Row(children: [
                      if (v.experiencia != null) ...[
                        Icon(Icons.workspace_premium_rounded,
                            size: 13, color: AppColors.grey),
                        const SizedBox(width: 4),
                        Text('${v.experiencia} años',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.grey,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(width: 12),
                      ],
                      if (v.telefono != null && v.telefono!.isNotEmpty) ...[
                        Icon(Icons.phone_outlined,
                            size: 13, color: AppColors.tealLight),
                        const SizedBox(width: 4),
                        Text(v.telefono!,
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.tealLight,
                                fontWeight: FontWeight.w600)),
                      ],
                    ]),
                    if (v.direccion != null && v.direccion!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.grey),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(v.direccion!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.grey,
                                  fontWeight: FontWeight.w400)),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.grey, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab Productores Pecuarios desde Supabase ─────────────────────────────
  Widget _buildProductoresPecuariosTab() {
    if (_loadingProductores) {
      return Center(child: CircularProgressIndicator(color: AppColors.tealLight));
    }

    if (_productores.isEmpty) {
      return _emptyState(
        icon: Icons.agriculture_rounded,
        message: 'Sin productores con animales en venta',
      );
    }

    // Separar por tipo de producción
    final menores = _productores
        .where((p) => p.especiesEnVenta.any((e) => e.produccion == 'menores'))
        .toList();
    final mayores = _productores
        .where((p) => p.especiesEnVenta.any((e) => e.produccion == 'mayores'))
        .toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBBEBF0), width: 1.2),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.grey,
                labelStyle: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w500),
                padding: const EdgeInsets.all(4),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cruelty_free_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Menores'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.set_meal_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Mayores'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Sub-tab: Animales Menores
                menores.isEmpty
                    ? _emptyState(
                        icon: Icons.cruelty_free_rounded,
                        message: 'Sin productores de animales menores en venta',
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        itemCount: menores.length,
                        itemBuilder: (context, i) => _buildProductorCard(
                          menores[i],
                          isMenores: true,
                        ),
                      ),
                // Sub-tab: Animales Mayores
                mayores.isEmpty
                    ? _emptyState(
                        icon: Icons.set_meal_rounded,
                        message: 'Sin productores de animales mayores en venta',
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        itemCount: mayores.length,
                        itemBuilder: (context, i) => _buildProductorCard(
                          mayores[i],
                          isMenores: false,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductorCard(ProductorModel p, {bool isMenores = false}) {
    final accentColor =
        isMenores ? const Color(0xFF43B89C) : const Color(0xFF5BBFBF);
    final cardIcon =
        isMenores ? Icons.cruelty_free_rounded : Icons.set_meal_rounded;

    // Filtrar solo las especies del tipo correcto
    final especies = p.especiesEnVenta
        .where((e) => e.produccion == (isMenores ? 'menores' : 'mayores'))
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar del productor
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: accentColor.withValues(alpha: 0.35), width: 2),
              ),
              child: ClipOval(
                child: (p.fotoUrl != null && p.fotoUrl!.isNotEmpty)
                    ? Image.network(p.fotoUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                            cardIcon, size: 28, color: accentColor))
                    : Icon(cardIcon, size: 28, color: accentColor),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del productor
                  Text(
                    p.nombre,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkAlt,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Chips de especies en venta
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: especies.map((e) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.pets_rounded,
                            size: 11, color: accentColor),
                        const SizedBox(width: 4),
                        Text(
                          '${e.especie} · ${e.numeroAnimales} aprox.',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ]),
                    )).toList(),
                  ),
                  const SizedBox(height: 8),

                  // Teléfono
                  if (p.telefono != null && p.telefono!.isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        final uri = Uri(scheme: 'tel', path: p.telefono);
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                      child: Row(children: [
                        Icon(Icons.phone_outlined,
                            size: 13, color: accentColor),
                        const SizedBox(width: 4),
                        Text(
                          p.telefono!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Estado vacío ────────────────────────────────────────────────────────────
  Widget _emptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.tealLight.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 44, color: AppColors.tealLight.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: AppColors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Página: Perfil del veterinario ───────────────────────────────────────────
class _PerfilVeterinarioDirectoPage extends StatelessWidget {
  final VeterinarioModel vet;
  const _PerfilVeterinarioDirectoPage({required this.vet});

  @override
  Widget build(BuildContext context) {
    final nombre = (vet.nombre != null && vet.nombre!.isNotEmpty)
        ? vet.nombre!
        : 'Veterinario';
    final tieneUbicacion = vet.latitud != null && vet.longitud != null;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Stack(
        children: [
          Column(children: [
            ClipPath(
              clipper: HeaderWaveClipper(),
              child: Container(
                width: double.infinity,
                color: AppColors.tealBg,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 52),
                    child: Column(children: [
                      Row(children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded,
                              color: AppColors.darkAlt, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Text('Perfil Veterinario',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkAlt)),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ]),
                      const SizedBox(height: 14),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.tealLight.withValues(alpha: 0.15),
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.tealLight.withValues(alpha: 0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: (vet.fotoUrl != null && vet.fotoUrl!.isNotEmpty)
                            ? ClipOval(
                                child: Image.network(vet.fotoUrl!, fit: BoxFit.cover))
                            : Icon(Icons.person_rounded,
                                size: 48, color: AppColors.tealLight),
                      ),
                      const SizedBox(height: 10),
                      Text('Dr/a. $nombre',
                          style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkAlt)),
                      if (vet.especialidad != null &&
                          vet.especialidad!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                              color: AppColors.tealLight,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(vet.especialidad!,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),
              ),
            ),
          ]),

          // Contenido scrollable
          SafeArea(
            child: Column(children: [
              const SizedBox(height: 255),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(children: [
                    // Stats
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statCol(
                              Icons.workspace_premium_rounded,
                              AppColors.tealLight,
                              vet.experiencia != null
                                  ? '${vet.experiencia} años'
                                  : 'N/D',
                              'Experiencia'),
                          Container(
                              width: 1,
                              height: 50,
                              color: Colors.grey.shade100),
                          _statCol(
                              Icons.phone_rounded,
                              AppColors.tealLight,
                              (vet.telefono != null && vet.telefono!.isNotEmpty)
                                  ? vet.telefono!
                                  : 'N/D',
                              'Teléfono'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info profesional
                    _infoCard(
                      title: 'Acerca del profesional',
                      icon: Icons.info_outline_rounded,
                      color: AppColors.tealLight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _profileRow(
                              Icons.school_outlined,
                              'Especialidad',
                              vet.especialidad?.isNotEmpty == true
                                  ? vet.especialidad!
                                  : 'Medicina general veterinaria',
                              AppColors.tealLight),
                          if (vet.experiencia != null) ...[
                            const SizedBox(height: 10),
                            _profileRow(
                                Icons.workspace_premium_rounded,
                                'Experiencia',
                                '${vet.experiencia} años de práctica clínica',
                                AppColors.tealLight),
                          ],
                          if (vet.telefono != null &&
                              vet.telefono!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _profileRow(
                                Icons.phone_rounded,
                                'Teléfono',
                                vet.telefono!,
                                AppColors.tealLight),
                          ],
                          const SizedBox(height: 10),
                          _profileRow(
                              Icons.verified_outlined,
                              'Registro',
                              'Veterinario certificado y habilitado',
                              AppColors.tealLight),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ubicación
                    _infoCard(
                      title: 'Ubicación',
                      icon: Icons.location_on_rounded,
                      color: AppColors.orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (vet.direccion != null &&
                              vet.direccion!.isNotEmpty) ...[
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.place_rounded,
                                    color: AppColors.orange, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(vet.direccion!,
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.darkAlt)),
                              ),
                            ]),
                            const SizedBox(height: 14),
                          ],
                          if (tieneUbicacion) ...[
                            GestureDetector(
                              onTap: () async {
                                final url = Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=${vet.latitud},${vet.longitud}',
                                );
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url,
                                      mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 18),
                                decoration: BoxDecoration(
                                  color: AppColors.orange
                                      .withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.orange
                                        .withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.orange
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.map_rounded,
                                        color: AppColors.orange, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Ver en Google Maps',
                                            style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.darkAlt)),
                                        Text('Toca para abrir la ubicación',
                                            style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: AppColors.grey)),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.open_in_new_rounded,
                                      color: AppColors.orange, size: 20),
                                ]),
                              ),
                            ),
                          ] else if (vet.direccion == null ||
                              vet.direccion!.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                child: Text('Ubicación no registrada',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: AppColors.grey)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _statCol(IconData icon, Color color, String value, String label) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(height: 6),
      Text(value,
          style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.darkAlt)),
      Text(label,
          style: GoogleFonts.poppins(
              fontSize: 10,
              color: AppColors.grey,
              fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(title.toUpperCase(),
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey,
                  letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }

  Widget _profileRow(
      IconData icon, String label, String value, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.grey,
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkAlt)),
          ])),
    ]);
  }
}
