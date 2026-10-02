// usuario_model.dart — Modelo de datos para los usuarios de la app.
//
// Representa un registro de la tabla `usuarios` en Supabase.
// Se usa para gestionar el perfil, el rol y los datos personales del usuario.

class UsuarioModel {
  final String id;            // usua_id: UUID de Supabase Auth
  final String nombre;        // usua_nombre
  final String correo;        // usua_correo
  final String? telefono;     // usua_telefono (opcional)
  final String rol;           // usua_rol: 'usuario' | 'veterinario' | 'administrador'
  final DateTime? fechaRegistro; // usua_fecha_registro: cuándo se creó la cuenta
  final String? fotoUrl;      // usua_foto_url: imagen de perfil en Supabase Storage
  final String? cedula;       // usua_cedula: número de cédula (opcional)
  final String? direccionGps; // usua_direccion_gps: "latitud,longitud" (opcional)
  final bool esProductor;     // usua_es_productor: true si tiene registro de SENSO
  final String? tipoAnimales; // usua_tipo_animales: "mayores" | "menores" | "ambos"

  UsuarioModel({
    required this.id,
    required this.nombre,
    required this.correo,
    this.telefono,
    required this.rol,
    this.fechaRegistro,
    this.fotoUrl,
    this.cedula,
    this.direccionGps,
    this.esProductor = false,
    this.tipoAnimales,
  });

  // ── Deserialización ───────────────────────────────────────────────────────

  /// Construye un UsuarioModel desde el JSON que devuelve Supabase.
  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id:      json['usua_id']?.toString()     ?? '',
      nombre:  json['usua_nombre']?.toString() ?? '',
      correo:  json['usua_correo']?.toString() ?? '',
      // Para campos opcionales usamos cast directo; si el tipo no coincide, null.
      telefono:     json['usua_telefono']   as String?,
      rol:          json['usua_rol']?.toString() ?? 'usuario',
      fechaRegistro: json['usua_fecha_registro'] != null
          ? DateTime.tryParse(json['usua_fecha_registro'].toString())
          : null,
      fotoUrl:      json['usua_foto_url']        as String?,
      cedula:       json['usua_cedula']           as String?,
      direccionGps: json['usua_direccion_gps']    as String?,
      esProductor:  json['usua_es_productor']     as bool? ?? false,
      tipoAnimales: json['usua_tipo_animales']    as String?,
    );
  }

  // ── Serialización ─────────────────────────────────────────────────────────

  /// JSON con solo los campos editables desde el formulario de perfil.
  /// Se usa para el UPDATE en Supabase (no incluye id, correo ni fecha).
  Map<String, dynamic> toUpdateJson() {
    return {
      'usua_nombre':       nombre,
      'usua_telefono':     telefono,
      'usua_cedula':       cedula,
      'usua_direccion_gps': direccionGps,
      'usua_es_productor': esProductor,
      // Si no es productor, guardamos null para limpiar el tipo de animales.
      'usua_tipo_animales': esProductor ? tipoAnimales : null,
    };
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  /// Crea una copia del modelo con los campos que se quieran modificar.
  ///
  /// El campo [esProductor] usa un valor centinela porque distinguir
  /// "no se pasó" de "se pasó false" es importante para no perder el estado.
  UsuarioModel copyWith({
    String? nombre,
    String? correo,
    String? telefono,
    String? rol,
    DateTime? fechaRegistro,
    String? fotoUrl,
    String? cedula,
    String? direccionGps,
    Object? esProductor = _sentinel, // usa _sentinel para detectar "no pasado"
    String? tipoAnimales,
  }) {
    return UsuarioModel(
      id:           id,
      nombre:       nombre       ?? this.nombre,
      correo:       correo       ?? this.correo,
      telefono:     telefono     ?? this.telefono,
      rol:          rol          ?? this.rol,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      fotoUrl:      fotoUrl      ?? this.fotoUrl,
      cedula:       cedula       ?? this.cedula,
      direccionGps: direccionGps ?? this.direccionGps,
      // Si se pasó el valor, usarlo; si no, conservar el actual.
      esProductor: identical(esProductor, _sentinel)
          ? this.esProductor
          : (esProductor as bool),
      tipoAnimales: tipoAnimales ?? this.tipoAnimales,
    );
  }
}

// Objeto centinela para distinguir "no se pasó esProductor" de "se pasó false".
// Se declara fuera de la clase para que sea una constante global inmutable.
const Object _sentinel = Object();
