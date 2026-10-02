import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../domain/controllers/admin_controller.dart';
import '../../../../data/models/usuario_model.dart';
import '../../../widgets/safe_network_image.dart';
import '../../../widgets/header_wave_clipper.dart';

class AdminUsuariosTab extends StatefulWidget {
  const AdminUsuariosTab({super.key});

  @override
  State<AdminUsuariosTab> createState() => _AdminUsuariosTabState();
}

class _AdminUsuariosTabState extends State<AdminUsuariosTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filtroRol = 'todos';

  static const _roles = ['todos', 'usuario', 'veterinario', 'administrador'];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminController>().cargarUsuarios();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<UsuarioModel> _filtrar(List<UsuarioModel> lista) {
    return lista.where((u) {
      final matchRol = _filtroRol == 'todos' || u.rol == _filtroRol;
      final matchQuery = _query.isEmpty ||
          u.nombre.toLowerCase().contains(_query) ||
          u.correo.toLowerCase().contains(_query);
      return matchRol && matchQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AdminController>();
    final filtrados = _filtrar(ctrl.usuarios);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Column(
        children: [
          // ── Cabecera ──────────────────────────────────────────────────
          ClipPath(
            clipper: HeaderWaveClipper(),
            child: Container(
              height: 160,
              color: AppColors.tealBg,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usuarios',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkAlt,
                        ),
                      ),
                      Text(
                        '${ctrl.usuarios.length} registrados',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.darkAlt.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Barra de búsqueda ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                  )
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                style: GoogleFonts.poppins(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o correo...',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 13, color: AppColors.grey),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.tealLight, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.grey),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ),

          // ── Filtro de roles ───────────────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              itemCount: _roles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final rol = _roles[i];
                final selected = _filtroRol == rol;
                return GestureDetector(
                  onTap: () => setState(() => _filtroRol = rol),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.tealLight
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.tealLight
                            : AppColors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      rol[0].toUpperCase() + rol.substring(1),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.grey,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Lista de usuarios ─────────────────────────────────────────
          Expanded(
            child: ctrl.cargandoUsuarios
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.tealLight),
                  )
                : filtrados.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados',
                          style: GoogleFonts.poppins(
                              color: AppColors.grey, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtrados.length,
                        itemBuilder: (context, i) =>
                            _UsuarioTile(usuario: filtrados[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Tile de usuario ───────────────────────────────────────────────────────────
class _UsuarioTile extends StatelessWidget {
  final UsuarioModel usuario;
  const _UsuarioTile({required this.usuario});

  Color get _rolColor {
    switch (usuario.rol) {
      case 'administrador': return AppColors.red;
      case 'veterinario': return AppColors.vetGreen;
      default: return AppColors.tealLight;
    }
  }

  IconData get _rolIcon {
    switch (usuario.rol) {
      case 'administrador': return Icons.shield_rounded;
      case 'veterinario': return Icons.medical_services_rounded;
      default: return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _rolColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: usuario.fotoUrl != null && usuario.fotoUrl!.isNotEmpty
                ? Image.network(usuario.fotoUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(_rolIcon, color: _rolColor, size: 22))
                : Icon(_rolIcon, color: _rolColor, size: 22),
          ),
        ),
        title: Text(
          usuario.nombre,
          style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkAlt),
        ),
        subtitle: Text(
          usuario.correo,
          style: GoogleFonts.poppins(fontSize: 11, color: AppColors.grey),
        ),
        trailing: _RolBadge(rol: usuario.rol, color: _rolColor),
        onTap: () => _mostrarOpciones(context),
      ),
    );
  }

  void _mostrarOpciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CambiarRolSheet(usuario: usuario),
    );
  }
}

class _RolBadge extends StatelessWidget {
  final String rol;
  final Color color;
  const _RolBadge({required this.rol, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        rol,
        style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color),
      ),
    );
  }
}

// ── Sheet para cambiar rol ────────────────────────────────────────────────────
class _CambiarRolSheet extends StatelessWidget {
  final UsuarioModel usuario;
  const _CambiarRolSheet({required this.usuario});

  static const _opcionesRol = ['usuario', 'veterinario', 'administrador'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            usuario.nombre,
            style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.darkAlt),
          ),
          Text(
            usuario.correo,
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            'Cambiar rol',
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.grey),
          ),
          const SizedBox(height: 10),
          ..._opcionesRol.map((rol) {
            final current = usuario.rol == rol;
            return ListTile(
              dense: true,
              leading: Icon(
                rol == 'administrador'
                    ? Icons.shield_rounded
                    : rol == 'veterinario'
                        ? Icons.medical_services_rounded
                        : Icons.person_rounded,
                color: current ? AppColors.tealLight : AppColors.grey,
                size: 20,
              ),
              title: Text(
                rol[0].toUpperCase() + rol.substring(1),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight:
                      current ? FontWeight.w700 : FontWeight.w500,
                  color: current
                      ? AppColors.tealLight
                      : AppColors.darkAlt,
                ),
              ),
              trailing: current
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.tealLight, size: 20)
                  : null,
              onTap: current
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final ok = await context
                          .read<AdminController>()
                          .cambiarRolUsuario(usuario.id, rol);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                            ok
                                ? 'Rol actualizado a $rol'
                                : 'Error al cambiar rol',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                          backgroundColor:
                              ok ? AppColors.tealLight : AppColors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ));
                      }
                    },
            );
          }),
        ],
      ),
    );
  }
}
