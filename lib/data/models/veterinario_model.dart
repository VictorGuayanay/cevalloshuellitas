// veterinario_model.dart — Modelo de datos para los veterinarios.
//
// Representa un registro de la tabla `veterinarios` en Supabase.
// Los datos de nombre, teléfono y foto vienen del JOIN con `usuarios`,
// porque el veterinario también es un usuario del sistema.

class VeterinarioModel {
  final String id; // vete_id: identificador único del veterinario
  final String usuarioId; // usua_id: FK hacia la tabla usuarios
  final String? nombre; // usua_nombre (del join con usuarios)
  final String? telefono; // usua_telefono (del join con usuarios)
  final String?
  especialidad; // vete_especialidad (ej: "Cirugía", "Dermatología")
  final int? experiencia; // vete_experiencia en años
  final double? tarifa; // vete_tarifa en dólares por consulta
  final String? fotoUrl; // usua_foto_url (del join con usuarios)
  final bool disponible; // vete_disponible: si acepta citas ahora
  final double? latitud; // vete_latitud: coordenada GPS
  final double? longitud; // vete_longitud: coordenada GPS
  final String? direccion; // vete_direccion: dirección textual

  VeterinarioModel({
    required this.id,
    required this.usuarioId,
    this.nombre,
    this.telefono,
    this.especialidad,
    this.experiencia,
    this.tarifa,
    this.fotoUrl,
    this.disponible = true, // por defecto disponible
    this.latitud,
    this.longitud,
    this.direccion,
  });

  // ── Deserialización ───────────────────────────────────────────────────────

  /// Construye un VeterinarioModel desde el JSON de Supabase.
  /// Nombre, teléfono y foto vienen del objeto anidado 'usuarios' (join).
  factory VeterinarioModel.fromJson(Map<String, dynamic> json) {
    // El join con usuarios viene como objeto anidado.
    final usuario = json['usuarios'] as Map<String, dynamic>?;

    // La foto puede venir del join o de una columna directa (retrocompatibilidad).
    final fotoUrl =
        usuario?['usua_foto_url'] as String? ??
        json['vete_foto_url'] as String?;

    return VeterinarioModel(
      id: json['vete_id']?.toString() ?? '',
      usuarioId: json['usua_id']?.toString() ?? '',
      nombre: usuario?['usua_nombre'] as String?,
      telefono: usuario?['usua_telefono'] as String?,
      especialidad: json['vete_especialidad'] as String?,
      experiencia: json['vete_experiencia'] as int?,
      // La tarifa puede venir como número o como String desde Supabase.
      tarifa: json['vete_tarifa'] != null
          ? double.tryParse(json['vete_tarifa'].toString())
          : null,
      fotoUrl: fotoUrl,
      disponible: json['vete_disponible'] as bool? ?? true,
      latitud: json['vete_latitud'] != null
          ? double.tryParse(json['vete_latitud'].toString())
          : null,
      longitud: json['vete_longitud'] != null
          ? double.tryParse(json['vete_longitud'].toString())
          : null,
      direccion: json['vete_direccion'] as String?,
    );
  }

  // ── Serialización ─────────────────────────────────────────────────────────

  /// JSON para INSERT — sin vete_id (lo genera Supabase automáticamente).
  /// La foto viene del join con usuarios, no se guarda en la tabla veterinarios.
  Map<String, dynamic> toInsertJson() {
    return {
      'usua_id': usuarioId,
      if (especialidad != null && especialidad!.isNotEmpty)
        'vete_especialidad': especialidad,
      if (experiencia != null) 'vete_experiencia': experiencia,
      if (tarifa != null) 'vete_tarifa': tarifa,
      'vete_disponible': disponible,
      if (latitud != null) 'vete_latitud': latitud,
      if (longitud != null) 'vete_longitud': longitud,
      if (direccion != null && direccion!.isNotEmpty)
        'vete_direccion': direccion,
    };
  }

  /// JSON para UPDATE — incluye solo los campos editables del perfil.
  /// Campos con null borran el valor anterior en la BD.
  Map<String, dynamic> toUpdateJson() {
    return {
      'vete_especialidad': especialidad?.isNotEmpty == true
          ? especialidad
          : null,
      'vete_experiencia': experiencia,
      'vete_tarifa': tarifa,
      'vete_disponible': disponible,
      'vete_latitud': latitud,
      'vete_longitud': longitud,
      'vete_direccion': direccion?.isNotEmpty == true ? direccion : null,
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  /// Crea una copia con los campos que se quieran cambiar.
  /// Útil para actualizar el estado local sin ir a la BD.
  VeterinarioModel copyWith({
    String? nombre,
    String? telefono,
    String? especialidad,
    int? experiencia,
    double? tarifa,
    String? fotoUrl,
    bool? disponible,
    double? latitud,
    double? longitud,
    String? direccion,
  }) {
    return VeterinarioModel(
      id: id,
      usuarioId: usuarioId,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      especialidad: especialidad ?? this.especialidad,
      experiencia: experiencia ?? this.experiencia,
      tarifa: tarifa ?? this.tarifa,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      disponible: disponible ?? this.disponible,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      direccion: direccion ?? this.direccion,
    );
  }
}
