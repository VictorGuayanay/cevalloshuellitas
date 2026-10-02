// noticia_model.dart — Modelo de datos para las noticias de la comunidad.
//
// Las noticias las envían los usuarios y el administrador las modera.
// Los datos se almacenan en la tabla `noticias` de Supabase.
// Estado del ciclo de vida: 'pendiente' → 'publicada' | 'rechazada'

class NoticiaModel {
  final String id;           // noti_id: identificador único
  final String? usuaId;      // usua_id: quién envió la noticia (puede ser null si se borró el usuario)
  final String titulo;       // noti_titulo
  final String contenido;    // noti_contenido
  final String? imagenUrl;   // noti_imagen: URL de la imagen adjunta (opcional)
  final String categoria;    // noti_categoria (ej: "general", "salud", "adopción")
  final String estado;       // 'pendiente' | 'publicada' | 'rechazada'
  final DateTime fecha;      // noti_fecha: cuándo se envió

  // Datos del autor — disponibles solo cuando se hace JOIN con `usuarios`.
  final String? autorNombre;
  final String? autorFotoUrl;

  NoticiaModel({
    required this.id,
    this.usuaId,
    required this.titulo,
    required this.contenido,
    this.imagenUrl,
    this.categoria = 'general',
    this.estado = 'pendiente',
    required this.fecha,
    this.autorNombre,
    this.autorFotoUrl,
  });

  // ── Deserialización ───────────────────────────────────────────────────────

  /// Construye un NoticiaModel desde el JSON de Supabase.
  /// Si el query incluye JOIN con usuarios, los datos del autor vienen
  /// en el objeto anidado bajo la clave 'usuarios'.
  factory NoticiaModel.fromJson(Map<String, dynamic> json) {
    final usuariosJoin = json['usuarios'] as Map<String, dynamic>?;

    return NoticiaModel(
      id:        json['noti_id']?.toString() ?? '',
      usuaId:    json['usua_id']?.toString(),
      titulo:    json['noti_titulo']   as String? ?? '',
      contenido: json['noti_contenido'] as String? ?? '',
      imagenUrl: json['noti_imagen']   as String?,
      categoria: json['noti_categoria'] as String? ?? 'general',
      estado:    json['noti_estado']   as String? ?? 'pendiente',
      // Si la fecha no se puede parsear, usamos DateTime.now() como fallback.
      fecha: json['noti_fecha'] != null
          ? DateTime.tryParse(json['noti_fecha'].toString()) ?? DateTime.now()
          : DateTime.now(),
      autorNombre:   usuariosJoin?['usua_nombre']   as String?,
      autorFotoUrl:  usuariosJoin?['usua_foto_url'] as String?,
    );
  }

  // ── Serialización ─────────────────────────────────────────────────────────

  /// JSON para INSERT — el estado siempre es 'pendiente' al crearse.
  /// No incluimos noti_id (lo genera Supabase) ni noti_fecha (la pone el servidor).
  Map<String, dynamic> toInsertJson() {
    return {
      if (usuaId != null && usuaId!.isNotEmpty) 'usua_id': usuaId,
      'noti_titulo':    titulo,
      'noti_contenido': contenido,
      if (imagenUrl != null && imagenUrl!.isNotEmpty) 'noti_imagen': imagenUrl,
      'noti_categoria': categoria,
      'noti_estado':    'pendiente', // siempre empieza en pendiente
    };
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  /// Tiempo relativo legible desde la fecha de publicación.
  /// Ejemplos: "Ahora mismo", "Hace 5 min", "Ayer", "3/6/2025".
  String get tiempoRelativo {
    final diff = DateTime.now().difference(fecha);
    if (diff.inSeconds < 60)  return 'Ahora mismo';
    if (diff.inMinutes < 60)  return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24)    return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1)     return 'Ayer';
    if (diff.inDays < 7)      return 'Hace ${diff.inDays} días';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
}
