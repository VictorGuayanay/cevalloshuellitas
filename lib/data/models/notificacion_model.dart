// notificacion_model.dart — Modelo para las notificaciones in-app.
//
// Las notificaciones NO se guardan en Supabase ni Firebase; viven solo
// en memoria mientras la app está abierta. Se generan desde el canal
// Realtime de Supabase cuando una mascota cambia su estado a 'perdido'.

/// Tipos de notificación que puede mostrar la app.
/// Si en el futuro se agregan más tipos (citas, adopciones, etc.),
/// solo hay que agregar el valor aquí y actualizar los mapas de color/prioridad.
enum TipoNotificacion {
  mascotaPerdida, // Alerta pública: nueva mascota reportada como perdida
}

/// Prioridad visual de la notificación.
/// Determina si se muestra en la sección "Requieren atención" o "Anteriores".
enum PrioridadNotificacion { alta, media, baja }

/// Representa una notificación in-app con toda la información visual.
class NotificacionModel {
  final String id; // Identificador único (ej: 'perdida_abc123')
  final TipoNotificacion tipo; // Tipo para decidir ícono, color y prioridad
  final String titulo; // Texto principal de la notificación
  final String cuerpo; // Descripción detallada
  final String? mascotaNombre; // Nombre de la mascota (opcional, para el chip)
  final DateTime creadaEn; // Cuándo se creó (para mostrar tiempo relativo)
  bool leida; // Si el usuario ya la vio (mutable a propósito)

  NotificacionModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    this.mascotaNombre,
    DateTime? creadaEn,
    this.leida = false,
  }) : creadaEn = creadaEn ?? DateTime.now(); // Si no se pasa, usamos "ahora"

  // ── Mapas estáticos de configuración visual ─────────────────────────────────
  // Al ser const y static, se crean una sola vez en memoria para toda la app.

  /// Color asociado a cada tipo de notificación (formato ARGB).
  static const Map<TipoNotificacion, int> _colorMap = {
    TipoNotificacion.mascotaPerdida: 0xFFE53935, // rojo
  };

  /// Prioridad visual asociada a cada tipo de notificación.
  static const Map<TipoNotificacion, PrioridadNotificacion> _prioridadMap = {
    TipoNotificacion.mascotaPerdida: PrioridadNotificacion.alta,
  };

  /// Retorna el color del tipo, o el color teal por defecto si no está mapeado.
  int get colorValue => _colorMap[tipo] ?? 0xFF1CB5C9;

  /// Retorna la prioridad del tipo, o baja por defecto.
  PrioridadNotificacion get prioridad =>
      _prioridadMap[tipo] ?? PrioridadNotificacion.baja;

  // ── Factory constructors ────────────────────────────────────────────────────

  /// Crea una notificación de mascota perdida con el mensaje correcto.
  /// Si se conoce el nombre del dueño, lo incluye en el cuerpo.
  factory NotificacionModel.mascotaPerdida({
    required String mascotaId,
    required String mascotaNombre,
    String? duenioNombre,
  }) => NotificacionModel(
    id: 'perdida_$mascotaId',
    tipo: TipoNotificacion.mascotaPerdida,
    titulo: '🚨 Mascota perdida reportada',
    cuerpo: duenioNombre != null
        ? '$duenioNombre reportó a $mascotaNombre como perdido/a. ¡Ayúdanos a encontrarla!'
        : '$mascotaNombre fue reportado/a como perdido/a. ¡Ayúdanos a encontrarla!',
    mascotaNombre: mascotaNombre,
  );

  // ── Serialización ─────────────────────────────────────────────────────────

  /// Construye un NotificacionModel desde un mapa JSON.
  /// Útil si en el futuro se persisten notificaciones en caché local.
  factory NotificacionModel.fromJson(Map<String, dynamic> json) {
    return NotificacionModel(
      id: json['id'] as String,
      // Buscamos el enum por nombre; si no existe usamos mascotaPerdida como fallback.
      tipo: TipoNotificacion.values.firstWhere(
        (e) => e.name == json['tipo'],
        orElse: () => TipoNotificacion.mascotaPerdida,
      ),
      titulo: json['titulo'] as String,
      cuerpo: json['cuerpo'] as String,
      mascotaNombre: json['mascotaNombre'] as String?,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      leida: json['leida'] as bool? ?? false,
    );
  }

  /// Convierte el modelo a un mapa JSON serializable.
  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name, // guardamos el nombre del enum como String
    'titulo': titulo,
    'cuerpo': cuerpo,
    if (mascotaNombre != null) 'mascotaNombre': mascotaNombre,
    'creadaEn': creadaEn.toIso8601String(),
    'leida': leida,
  };

  // ── Utilidades ─────────────────────────────────────────────────────────────

  /// Retorna una cadena legible del tiempo transcurrido desde que se creó.
  /// Ejemplo: "Hace 5 min", "Ayer", "3/6/2025".
  String get tiempoRelativo {
    final diff = DateTime.now().difference(creadaEn);
    if (diff.inSeconds < 60) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    return '${creadaEn.day}/${creadaEn.month}/${creadaEn.year}';
  }

  /// Dos notificaciones son iguales si tienen el mismo id.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificacionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
