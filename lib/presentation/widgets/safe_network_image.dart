import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// Widget de imagen de red con manejo de errores y loading integrados.
///
/// Reemplaza cualquier [Image.network] que no tenga [errorBuilder] ni
/// [loadingBuilder]. Si la URL es nula/vacía o falla la carga (corte de
/// conexión, 404, timeout), muestra automáticamente el [fallbackIcon].
///
/// Uso básico:
/// ```dart
/// SafeNetworkImage(
///   url: mascota.fotoUrl,
///   fit: BoxFit.cover,
///   borderRadius: BorderRadius.circular(12),
///   fallbackIcon: Icons.pets_rounded,
///   fallbackColor: Colors.teal,
/// )
/// ```
class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final double fallbackIconSize;
  final Color? fallbackBg;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.width,
    this.height,
    this.fallbackIcon = Icons.image_not_supported_outlined,
    this.fallbackColor = const Color(0xFF2FA3A3),
    this.fallbackIconSize = 28,
    this.fallbackBg,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;

    Widget child;

    if (!hasUrl) {
      child = _fallback();
    } else {
      child = Image.network(
        url!,
        fit: fit,
        width: width,
        height: height,
        // Muestra un shimmer/placeholder mientras carga
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return _shimmer();
        },
        // Muestra ícono fallback en cualquier error de red o 4xx/5xx
        errorBuilder: (ctx, error, stack) {
          debugPrint('SafeNetworkImage error: $error — url: $url');
          return _fallback();
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: SizedBox(width: width, height: height, child: child),
      );
    }

    return SizedBox(width: width, height: height, child: child);
  }

  Widget _fallback() => Container(
    width: width,
    height: height,
    color: fallbackBg ?? fallbackColor.withValues(alpha: 0.10),
    child: Center(
      child: Icon(fallbackIcon, color: fallbackColor, size: fallbackIconSize),
    ),
  );

  Widget _shimmer() => Container(
    width: width,
    height: height,
    color: Colors.grey.shade200,
    child: const _ShimmerBox(),
  );
}

/// Versión circular (para avatars de veterinarios/usuarios).
class SafeNetworkAvatar extends StatelessWidget {
  final String? url;
  final double size;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final Color? fallbackBg;

  const SafeNetworkAvatar({
    super.key,
    required this.url,
    this.size = 48,
    this.fallbackIcon = Icons.person_rounded,
    this.fallbackColor = const Color(0xFF2FA3A3),
    this.fallbackBg,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SafeNetworkImage(
        url: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fallbackIcon: fallbackIcon,
        fallbackColor: fallbackColor,
        fallbackBg: fallbackBg,
        fallbackIconSize: size * 0.5,
      ),
    );
  }
}

/// Animación shimmer simple sin dependencias externas.
class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox();

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) =>
          Container(color: Colors.grey.shade300.withValues(alpha: _anim.value)),
    );
  }
}
