class UsuarioModel {
  final String id;
  final String nombre;
  final String correo;
  final String? telefono;
  final String rol;
  final DateTime? fechaRegistro;
  final String? fotoUrl; // usua_foto_url

  UsuarioModel({
    required this.id,
    required this.nombre,
    required this.correo,
    this.telefono,
    required this.rol,
    this.fechaRegistro,
    this.fotoUrl,
  });

  /// Crea una instancia de [UsuarioModel] a partir de un mapa JSON
  /// que proviene de la tabla `usuarios` en Supabase.
  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['usua_id']?.toString() ?? '',
      nombre: json['usua_nombre']?.toString() ?? '',
      correo: json['usua_correo']?.toString() ?? '',
      telefono: json['usua_telefono'] as String?,
      rol: json['usua_rol']?.toString() ?? 'usuario',
      fechaRegistro: json['usua_fecha_registro'] != null
          ? DateTime.tryParse(json['usua_fecha_registro'].toString())
          : null,
      fotoUrl: json['usua_foto_url'] as String?,
    );
  }
}
