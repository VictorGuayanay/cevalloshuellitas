import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cita_model.dart';
import '../services/fcm_service.dart';

class CitaService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _selectConJoin = '''
    *,
    mascotas(masc_nombre),
    usuarios(usua_nombre)
  ''';

  /// Citas del día actual — filtra por fecha dentro del timestamp
  Future<List<CitaModel>> obtenerCitasHoy() async {
    try {
      final hoy = DateTime.now();
      final inicio = DateTime(hoy.year, hoy.month, hoy.day);
      final fin = inicio.add(const Duration(days: 1));
      final response = await _client
          .from('citas')
          .select(_selectConJoin)
          .gte('cita_fecha', inicio.toIso8601String())
          .lt('cita_fecha', fin.toIso8601String())
          .order('cita_fecha');
      return (response as List).map((e) => CitaModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error citasHoy: $e');
      return [];
    }
  }

  /// Todas las citas ordenadas por fecha descendente
  Future<List<CitaModel>> obtenerTodasLasCitas() async {
    try {
      final response = await _client
          .from('citas')
          .select(_selectConJoin)
          .order('cita_fecha', ascending: false);
      return (response as List).map((e) => CitaModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error todasCitas: $e');
      return [];
    }
  }

  /// Citas de un usuario específico (dueño de mascotas)
  Future<List<CitaModel>> obtenerCitasPorUsuario(String usuarioId) async {
    try {
      final response = await _client
          .from('citas')
          .select(_selectConJoin)
          .eq('usua_id', usuarioId)
          .order('cita_fecha', ascending: false);
      return (response as List).map((e) => CitaModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error citasUsuario: $e');
      return [];
    }
  }

  /// Citas de un veterinario específico
  Future<List<CitaModel>> obtenerCitasPorVeterinario(String veteId) async {
    try {
      final response = await _client
          .from('citas')
          .select(_selectConJoin)
          .eq('vete_id', veteId)
          .order('cita_fecha', ascending: false);
      return (response as List).map((e) => CitaModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error citasVet: $e');
      return [];
    }
  }

  /// Retorna los horarios (HH:MM) ya ocupados para un veterinario en una fecha.
  /// Considera citas en estado pendiente, confirmada o "en atención".
  Future<Set<String>> obtenerHorasOcupadas({
    required String veteId,
    required String fecha, // formato YYYY-MM-DD
  }) async {
    try {
      final inicio = '${fecha}T00:00:00';
      final fin    = '${fecha}T23:59:59';
      final response = await _client
          .from('citas')
          .select('cita_fecha')
          .eq('vete_id', veteId)
          .gte('cita_fecha', inicio)
          .lte('cita_fecha', fin)
          .inFilter('cita_estado', ['pendiente', 'confirmada', 'en atención']);
      return (response as List).map((e) {
        final raw = e['cita_fecha']?.toString() ?? '';
        if (raw.isEmpty) return '';
        try {
          final dt = DateTime.parse(raw);
          return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {
          return '';
        }
      }).where((h) => h.isNotEmpty).toSet();
    } catch (e) {
      debugPrint('Error obtenerHorasOcupadas: $e');
      return {};
    }
  }

  /// Crea una nueva cita usando toInsertJson()
  Future<CitaModel> crearCita(CitaModel cita) async {
    // 1. Validaciones
    final now = DateTime.now();
    final citaDateTime = DateTime.parse('${cita.fecha}T${cita.hora}:00');
    if (citaDateTime.isBefore(now)) {
      throw Exception('La fecha y hora seleccionada no puede ser en el pasado.');
    }

    // A. Verificar disponibilidad del veterinario (vete_disponible = true)
    if (cita.veteId != null && cita.veteId!.isNotEmpty) {
      final vet = await _client
          .from('veterinarios')
          .select('vete_disponible')
          .eq('vete_id', cita.veteId!)
          .maybeSingle();
      if (vet != null && vet['vete_disponible'] == false) {
        throw Exception('El veterinario no se encuentra disponible actualmente.');
      }

      // B. Verificar que no exista otra cita confirmada para el mismo veterinario en el mismo horario
      final citaFechaIso = '${cita.fecha}T${cita.hora}:00';
      final conflictVet = await _client
          .from('citas')
          .select('cita_id')
          .eq('vete_id', cita.veteId!)
          .eq('cita_fecha', citaFechaIso)
          .eq('cita_estado', 'confirmada')
          .maybeSingle();
      if (conflictVet != null) {
        throw Exception('El veterinario ya tiene una cita confirmada en este horario.');
      }
    }

    // C. Verificar que la mascota no tenga otra cita programada para la misma fecha y hora (pendiente o confirmada o en atención)
    if (cita.mascotaId != null && cita.mascotaId!.isNotEmpty) {
      final citaFechaIso = '${cita.fecha}T${cita.hora}:00';
      final conflictMascota = await _client
          .from('citas')
          .select('cita_id')
          .eq('masc_id', cita.mascotaId!)
          .eq('cita_fecha', citaFechaIso)
          .inFilter('cita_estado', ['pendiente', 'confirmada', 'en atención'])
          .maybeSingle();
      if (conflictMascota != null) {
        throw Exception('La mascota ya tiene una cita programada para esta fecha y hora.');
      }
    }

    // 2. Insertar la cita
    final inserted = await _client
        .from('citas')
        .insert(cita.toInsertJson())
        .select()
        .single();

    // 3. Volver a leer con join para obtener masc_nombre y propietario_nombre
    final citaId = inserted['cita_id']?.toString() ?? '';
    try {
      final full = await _client
          .from('citas')
          .select('''
            *,
            mascotas(masc_nombre),
            usuarios(usua_nombre)
          ''')
          .eq('cita_id', citaId)
          .single();
      final citaCreada = CitaModel.fromJson(full);

      // ── Push FCM al veterinario: nueva solicitud ──────────────────────────
      if (citaCreada.veteId != null && citaCreada.veteId!.isNotEmpty) {
        // Obtener el usua_id del veterinario para buscar su token
        final vetRow = await _client
            .from('veterinarios')
            .select('usua_id')
            .eq('vete_id', citaCreada.veteId!)
            .maybeSingle();
        final vetUsuaId = vetRow?['usua_id']?.toString();
        if (vetUsuaId != null && vetUsuaId.isNotEmpty) {
          FcmService.instance.enviarNotificacion(
            destinatarioUserId: vetUsuaId,
            titulo: '📋 Nueva solicitud de cita',
            cuerpo: '${citaCreada.propietarioNombre} solicita cita para ${citaCreada.mascotaNombre} el ${citaCreada.fecha.split('-').reversed.join('/')} a las ${citaCreada.hora}.',
            tipo: 'nueva_cita',
            citaId: citaCreada.id,
            mascotaNombre: citaCreada.mascotaNombre,
          );
        }
      }
      return citaCreada;
    } catch (_) {
      // Si el join falla, devolvemos lo que tenemos con los datos locales
      return CitaModel(
        id: citaId,
        usuarioId: cita.usuarioId,
        veteId: cita.veteId,
        mascotaId: cita.mascotaId,
        mascotaNombre: cita.mascotaNombre,
        propietarioNombre: cita.propietarioNombre,
        motivo: cita.motivo,
        fecha: cita.fecha,
        hora: cita.hora,
        estado: inserted['cita_estado'] as String? ?? cita.estado,
        direccion: cita.direccion,
      );
    }
  }

  /// Guarda descripción, receta y estado de una cita (uso del veterinario)
  /// y registra en historial_medico con diagnóstico y tratamiento.
  Future<CitaModel> guardarConsulta({
    required String citaId,
    required String estado,
    String? descripcion,
    String? receta,
    String? mascotaId,
    String? veteId,
  }) async {
    final response = await _client
        .from('citas')
        .update({
          'cita_estado': estado,
          if (descripcion != null) 'cita_descripcion': descripcion,
          if (receta != null) 'cita_receta': receta,
        })
        .eq('cita_id', citaId)
        .select(_selectConJoin)
        .single();

    // Guardar en historial_medico si hay contenido clínico
    if ((descripcion != null && descripcion.isNotEmpty) ||
        (receta != null && receta.isNotEmpty)) {
      try {
        await _client.from('historial_medico').insert({
          if (mascotaId?.isNotEmpty == true) 'masc_id': mascotaId,
          if (veteId?.isNotEmpty == true) 'vete_id': veteId,
          if (descripcion?.isNotEmpty == true) 'hist_diagnostico': descripcion,
          if (receta?.isNotEmpty == true) 'hist_tratamiento': receta,
          'hist_fecha_consulta': DateTime.now()
              .toIso8601String()
              .split('T')
              .first,
        });
      } catch (e) {
        debugPrint('Error guardando historial: $e');
      }
    }

    return CitaModel.fromJson(response);
  }

  /// Actualiza el estado de una cita
  Future<CitaModel> actualizarEstadoCita(
      String citaId, String nuevoEstado) async {
    final response = await _client
        .from('citas')
        .update({'cita_estado': nuevoEstado})
        .eq('cita_id', citaId)
        .select(_selectConJoin)
        .single();
    final cita = CitaModel.fromJson(response);

    // ── Push FCM al usuario: confirmación o rechazo ───────────────────────
    if (cita.usuarioId.isNotEmpty &&
        (nuevoEstado == 'confirmada' || nuevoEstado == 'rechazada')) {
      final esConfirmada = nuevoEstado == 'confirmada';
      FcmService.instance.enviarNotificacion(
        destinatarioUserId: cita.usuarioId,
        titulo: esConfirmada
            ? '✅ ¡Cita confirmada!'
            : '❌ Cita no disponible',
        cuerpo: esConfirmada
            ? 'Tu cita para ${cita.mascotaNombre} el ${cita.fecha.split('-').reversed.join('/')} a las ${cita.hora} fue confirmada.'
            : 'Tu cita para ${cita.mascotaNombre} el ${cita.fecha.split('-').reversed.join('/')} no pudo ser agendada.',
        tipo: esConfirmada ? 'cita_confirmada' : 'cita_rechazada',
        citaId: cita.id,
        mascotaNombre: cita.mascotaNombre,
        urgente: !esConfirmada,
      );
    }
    return cita;
  }
}
