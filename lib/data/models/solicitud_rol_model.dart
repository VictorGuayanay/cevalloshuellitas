// solicitud_rol_model.dart — Modelo de datos para las solicitudes de cambio de rol.
//
// Cuando un usuario quiere convertirse en veterinario, envía una solicitud
// que queda en estado 'pendiente' hasta que el administrador la aprueba o rechaza.
// Los datos se almacenan en la tabla `solicitudes_rol` de Supabase.

/// Representa una solicitud de cambio de rol en la base de datos.
class SolicitudRolModel {
  final String id; // srol_id: identificador único de la solicitud
  final String usuaId; // usua_id: ID del usuario que hizo la solicitud
  final String estado; // srol_estado: 'pendiente' | 'aprobada' | 'rechazada'
  final DateTime? fecha; // srol_fecha: cuándo se envió la solicitud

  const SolicitudRolModel({
    required this.id,
    required this.usuaId,
    required this.estado,
    this.fecha,
  });

  /// Crea un SolicitudRolModel a partir del JSON que devuelve Supabase.
  /// Maneja el campo fecha tanto como String ISO-8601 como int (timestamp Unix ms).
  factory SolicitudRolModel.fromJson(Map<String, dynamic> json) {
    // Función auxiliar local para parsear la fecha con seguridad.
    DateTime? parseFecha(dynamic value) {
      if (value == null) return null;
      // Supabase puede devolver la fecha como número (milisegundos Unix)
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      // O como String en formato ISO-8601 (lo más común)
      return DateTime.tryParse(value.toString());
    }

    return SolicitudRolModel(
      id: json['srol_id']?.toString() ?? '',
      usuaId: json['usua_id']?.toString() ?? '',
      estado: json['srol_estado']?.toString() ?? 'pendiente',
      fecha: parseFecha(json['srol_fecha']),
    );
  }

  /// Convierte el modelo a JSON para enviar a Supabase en INSERT o UPDATE.
  Map<String, dynamic> toJson() {
    return {
      'srol_id': id,
      'usua_id': usuaId,
      'srol_estado': estado,
      // Solo incluimos la fecha si tiene valor (evita enviar null innecesariamente)
      if (fecha != null) 'srol_fecha': fecha!.toIso8601String(),
    };
  }

  /// Crea una copia del modelo con los campos que quieras cambiar.
  /// Útil para actualizar el estado localmente sin volver a consultar Supabase.
  SolicitudRolModel copyWith({
    String? id,
    String? usuaId,
    String? estado,
    DateTime? fecha,
  }) {
    return SolicitudRolModel(
      id: id ?? this.id,
      usuaId: usuaId ?? this.usuaId,
      estado: estado ?? this.estado,
      fecha: fecha ?? this.fecha,
    );
  }

  /// Dos solicitudes son iguales si tienen el mismo srol_id.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SolicitudRolModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  /// El hashCode también se basa solo en el id.
  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SolicitudRolModel(id: $id, usuaId: $usuaId, estado: $estado, fecha: $fecha)';
}
