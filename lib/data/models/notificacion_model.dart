/// Tipos de notificación in-app
enum TipoNotificacion {
  nuevaCita,           // Vet recibe nueva solicitud de cita
  citaConfirmada,      // Usuario: su cita fue confirmada
  citaRechazada,       // Usuario: su cita fue rechazada
  citaPendiente,       // Usuario: cita enviada esperando respuesta
  recordatorio30min,   // 30 minutos antes de la cita
  recordatorioAhora,   // A la hora exacta de la cita
  solicitudAdopcion,   // Dueño: alguien quiere adoptar su mascota
  urgencia,            // Veterinario: urgencia crítica entrante
}

/// Prioridad visual de la notificación
enum PrioridadNotificacion { alta, media, baja }

class NotificacionModel {
  final String id;
  final TipoNotificacion tipo;
  final String titulo;
  final String cuerpo;
  final String? citaId;
  final String? mascotaNombre;
  final String? fecha;
  final String? hora;
  final DateTime creadaEn;
  bool leida;

  // ── Datos del solicitante (para solicitudAdopcion y nuevaCita) ─────────────
  final String? solicitanteId;
  final String? solicitanteNombre;
  final String? solicitanteCorreo;
  final String? solicitanteTelefono;
  final String? solicitanteFotoUrl;

  NotificacionModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    this.citaId,
    this.mascotaNombre,
    this.fecha,
    this.hora,
    DateTime? creadaEn,
    this.leida = false,
    this.solicitanteId,
    this.solicitanteNombre,
    this.solicitanteCorreo,
    this.solicitanteTelefono,
    this.solicitanteFotoUrl,
  }) : creadaEn = creadaEn ?? DateTime.now();

  // ── Color por tipo ─────────────────────────────────────────────────────────
  static const Map<TipoNotificacion, int> _colorMap = {
    TipoNotificacion.nuevaCita:          0xFFE58D57,
    TipoNotificacion.citaConfirmada:     0xFF43B89C,
    TipoNotificacion.citaRechazada:      0xFFE53935,
    TipoNotificacion.citaPendiente:      0xFF1CB5C9,
    TipoNotificacion.recordatorio30min:  0xFF1CB5C9,
    TipoNotificacion.recordatorioAhora:  0xFF7C6FCD,
    TipoNotificacion.solicitudAdopcion:  0xFFE58D57,
    TipoNotificacion.urgencia:           0xFFB71C1C,
  };

  // ── Prioridad por tipo ─────────────────────────────────────────────────────
  static const Map<TipoNotificacion, PrioridadNotificacion> _prioridadMap = {
    TipoNotificacion.recordatorioAhora:  PrioridadNotificacion.alta,
    TipoNotificacion.citaRechazada:      PrioridadNotificacion.alta,
    TipoNotificacion.urgencia:           PrioridadNotificacion.alta,
    TipoNotificacion.recordatorio30min:  PrioridadNotificacion.media,
    TipoNotificacion.citaConfirmada:     PrioridadNotificacion.media,
    TipoNotificacion.citaPendiente:      PrioridadNotificacion.baja,
    TipoNotificacion.nuevaCita:          PrioridadNotificacion.baja,
    TipoNotificacion.solicitudAdopcion:  PrioridadNotificacion.media,
  };

  int get colorValue => _colorMap[tipo] ?? 0xFF1CB5C9;
  PrioridadNotificacion get prioridad =>
      _prioridadMap[tipo] ?? PrioridadNotificacion.baja;

  /// ¿Tiene datos de solicitante para mostrar perfil?
  bool get tieneSolicitante =>
      solicitanteId != null && solicitanteId!.isNotEmpty;

  // ── Factory constructors por tipo de evento ────────────────────────────────

  factory NotificacionModel.urgencia({
    required String citaId,
    required String propietarioNombre,
    required String mascotaNombre,
    required String sintomas,
    String? fecha,
    String? hora,
  }) =>
      NotificacionModel(
        id: 'urgencia_$citaId',
        tipo: TipoNotificacion.urgencia,
        titulo: '🚨 Urgencia crítica',
        cuerpo: '$propietarioNombre reporta urgencia de $mascotaNombre: $sintomas',
        citaId: citaId,
        mascotaNombre: mascotaNombre,
        fecha: fecha,
        hora: hora,
      );

  factory NotificacionModel.nuevaCita({
    required String citaId,
    required String propietarioNombre,
    required String mascotaNombre,
    String? fecha,
    String? hora,
  }) =>
      NotificacionModel(
        id: 'nueva_$citaId',
        tipo: TipoNotificacion.nuevaCita,
        titulo: 'Nueva solicitud de cita',
        cuerpo: '$propietarioNombre solicita cita para $mascotaNombre',
        citaId: citaId,
        mascotaNombre: mascotaNombre,
        fecha: fecha,
        hora: hora,
      );

  factory NotificacionModel.citaConfirmada({
    required String citaId,
    required String mascotaNombre,
    String? fecha,
    String? hora,
    bool esUrgencia = false,
    String idPrefix = 'confirmada',
  }) =>
      NotificacionModel(
        id: '${idPrefix}_$citaId',
        tipo: TipoNotificacion.citaConfirmada,
        titulo: esUrgencia ? '🚨 ¡Urgencia aceptada!' : '¡Cita confirmada! 🎉',
        cuerpo: esUrgencia
            ? 'El veterinario aceptó tu emergencia de $mascotaNombre. Está en camino.'
            : 'Tu cita para $mascotaNombre el ${_formatFecha(fecha)} a las $hora fue confirmada.',
        citaId: citaId,
        mascotaNombre: mascotaNombre,
        fecha: fecha,
        hora: hora,
      );

  factory NotificacionModel.citaRechazada({
    required String citaId,
    required String mascotaNombre,
    String? fecha,
    String? hora,
    bool esUrgencia = false,
    String idPrefix = 'rechazada',
  }) =>
      NotificacionModel(
        id: '${idPrefix}_$citaId',
        tipo: TipoNotificacion.citaRechazada,
        titulo: esUrgencia ? '❌ Urgencia rechazada' : 'Cita rechazada',
        cuerpo: esUrgencia
            ? 'El veterinario no puede atender la emergencia de $mascotaNombre. Intenta con otro veterinario.'
            : 'Tu cita para $mascotaNombre el ${_formatFecha(fecha)} no pudo ser agendada.',
        citaId: citaId,
        mascotaNombre: mascotaNombre,
        fecha: fecha,
        hora: hora,
      );

  factory NotificacionModel.citaPendiente({
    required String citaId,
    required String mascotaNombre,
    String? fecha,
    String? hora,
  }) =>
      NotificacionModel(
        id: 'pendiente_$citaId',
        tipo: TipoNotificacion.citaPendiente,
        titulo: 'Cita en espera ⏳',
        cuerpo: 'Tu cita para $mascotaNombre el ${_formatFecha(fecha)} a las $hora está pendiente de confirmación.',
        citaId: citaId,
        mascotaNombre: mascotaNombre,
        fecha: fecha,
        hora: hora,
      );

  factory NotificacionModel.recordatorio30min({
    required String citaId,
    required String mascotaNombre,
    required String prefixRol,
    String? fecha,
    String? hora,
  }) =>
      NotificacionModel(
        id: 'recuerdo30_$citaId',
        tipo: TipoNotificacion.recordatorio30min,
        titulo: '⏰ Cita en 30 minutos',
        cuerpo: '$prefixRol $mascotaNombre tiene cita a las $hora.',
        citaId: citaId,
        mascotaNombre: mascotaNombre,
        fecha: fecha,
        hora: hora,
      );

  factory NotificacionModel.recordatorioAhora({
    required String citaId,
    required String mascotaNombre,
    required String prefixRol,
    String? fecha,
    String? hora,
  }) =>
      NotificacionModel(
        id: 'recuerdoAhora_$citaId',
        tipo: TipoNotificacion.recordatorioAhora,
        titulo: '🔔 ¡Es la hora de la cita!',
        cuerpo: '$prefixRol $mascotaNombre — cita comenzando ahora ($hora).',
        citaId: citaId,
        mascotaNombre: mascotaNombre,
        fecha: fecha,
        hora: hora,
      );

  /// Formatea 'yyyy-MM-dd' → 'dd/MM/yyyy'. Retorna la cadena original si falla.
  static String _formatFecha(String? fecha) {
    if (fecha == null) return '';
    return fecha.split('-').reversed.join('/');
  }

  /// Tiempo relativo legible
  String get tiempoRelativo {
    final diff = DateTime.now().difference(creadaEn);
    if (diff.inSeconds < 60) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    return '${creadaEn.day}/${creadaEn.month}/${creadaEn.year}';
  }

  /// Etiqueta de categoría para agrupar en tabs
  String get categoria {
    switch (tipo) {
      case TipoNotificacion.nuevaCita:
        return 'Solicitudes';
      case TipoNotificacion.solicitudAdopcion:
        return 'Solicitudes';
      case TipoNotificacion.citaPendiente:
        return 'Solicitudes';
      case TipoNotificacion.citaConfirmada:
      case TipoNotificacion.citaRechazada:
        return 'Confirmaciones';
      case TipoNotificacion.recordatorio30min:
      case TipoNotificacion.recordatorioAhora:
        return 'Recordatorios';
      case TipoNotificacion.urgencia:
        return 'Urgencias';
    }
  }
}
