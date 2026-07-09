class NoticiaModel {
  final String id;
  final String? usuaId;
  final String titulo;
  final String contenido;
  final String? imagenUrl;
  final String categoria;
  final String estado; // pendiente | publicada | rechazada
  final DateTime fecha;

  // Datos del autor (join con usuarios)
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

  factory NoticiaModel.fromJson(Map<String, dynamic> json) {
    final usuariosJoin = json['usuarios'] as Map<String, dynamic>?;

    return NoticiaModel(
      id: json['noti_id']?.toString() ?? '',
      usuaId: json['usua_id']?.toString(),
      titulo: json['noti_titulo'] as String? ?? '',
      contenido: json['noti_contenido'] as String? ?? '',
      imagenUrl: json['noti_imagen'] as String?,
      categoria: json['noti_categoria'] as String? ?? 'general',
      estado: json['noti_estado'] as String? ?? 'pendiente',
      fecha: json['noti_fecha'] != null
          ? DateTime.tryParse(json['noti_fecha'].toString()) ?? DateTime.now()
          : DateTime.now(),
      autorNombre: usuariosJoin?['usua_nombre'] as String?,
      autorFotoUrl: usuariosJoin?['usua_foto_url'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      if (usuaId != null && usuaId!.isNotEmpty) 'usua_id': usuaId,
      'noti_titulo': titulo,
      'noti_contenido': contenido,
      if (imagenUrl != null && imagenUrl!.isNotEmpty) 'noti_imagen': imagenUrl,
      'noti_categoria': categoria,
      'noti_estado': 'pendiente',
    };
  }

  /// Tiempo relativo legible
  String get tiempoRelativo {
    final diff = DateTime.now().difference(fecha);
    if (diff.inSeconds < 60) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
}
