// admin_service.dart — Servicio exclusivo del panel de administrador.
//
// Consulta estadísticas generales del sistema y gestiona:
//   - Usuarios y cambios de rol
//   - Solicitudes de cambio de rol a veterinario
//   - Moderación de noticias (aprobar / rechazar)
// Todos los datos se leen y escriben en Supabase.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';
import '../models/mascota_model.dart';
import '../models/noticia_model.dart';
import '../models/solicitud_rol_model.dart';

class AdminService {
  // Cliente de Supabase singleton; lo usamos en todos los métodos.
  final SupabaseClient _client = Supabase.instance.client;

  // ── Estadísticas generales ──────────────────────────────────────────────────

  /// Obtiene conteos de las tablas principales para el dashboard del admin.
  /// En supabase_flutter v2, .count() retorna un objeto con .count directamente.
  /// No hay que hacer ningún cast — el tipo ya viene resuelto.
  Future<Map<String, int>> obtenerEstadisticas() async {
    try {
      // Ejecutamos cada conteo por separado para evitar problemas de tipo.
      // .count() al final de la query le dice a Supabase que devuelva solo el total.
      final usuarios        = await _client.from('usuarios').select('usua_id').count();
      final mascotas        = await _client.from('mascotas').select('masc_id').count();
      final mascPerdidas    = await _client.from('mascotas').select('masc_id').eq('masc_estado', 'perdido').count();
      final productores     = await _client.from('usuarios').select('usua_id').eq('usua_es_productor', true).count();
      final veterinarios    = await _client.from('veterinarios').select('vete_id').count();
      final noticiasPend    = await _client.from('noticias').select('noti_id').eq('noti_estado', 'pendiente').count();
      final solicitudesPend = await _client.from('solicitudes_rol').select('srol_id').eq('srol_estado', 'pendiente').count();

      return {
        'usuarios':              usuarios.count        ?? 0,
        'mascotas':              mascotas.count        ?? 0,
        'mascotasPerdidas':      mascPerdidas.count    ?? 0,
        'productoresPecuarios':  productores.count     ?? 0,
        'veterinarios':          veterinarios.count    ?? 0,
        'noticiasPendientes':    noticiasPend.count    ?? 0,
        'solicitudesPendientes': solicitudesPend.count ?? 0,
      };
    } catch (e) {
      // Si algo falla, devolvemos ceros para no romper el dashboard.
      debugPrint('AdminService.obtenerEstadisticas error: $e');
      return {
        'usuarios': 0,
        'mascotas': 0,
        'mascotasPerdidas': 0,
        'productoresPecuarios': 0,
        'veterinarios': 0,
        'noticiasPendientes': 0,
        'solicitudesPendientes': 0,
      };
    }
  }

  // ── Usuarios ────────────────────────────────────────────────────────────────

  /// Obtiene todos los usuarios ordenados alfabéticamente por nombre.
  Future<List<UsuarioModel>> obtenerUsuarios() async {
    final response = await _client
        .from('usuarios')
        .select()
        .order('usua_nombre');
    // El response es un List<dynamic>; lo convertimos a List<UsuarioModel>.
    return (response as List)
        .map((e) => UsuarioModel.fromJson(e))
        .toList();
  }

  /// Cambia el rol de un usuario. Si el nuevo rol es 'veterinario',
  /// también crea su registro en la tabla veterinarios si no existe.
  Future<void> cambiarRolUsuario(String userId, String nuevoRol) async {
    // 1. Actualizar el rol en la tabla usuarios.
    await _client
        .from('usuarios')
        .update({'usua_rol': nuevoRol})
        .eq('usua_id', userId);

    // 2. Si pasa a veterinario, asegurarnos de que tenga registro en la tabla.
    if (nuevoRol == 'veterinario') {
      final existing = await _client
          .from('veterinarios')
          .select('vete_id')
          .eq('usua_id', userId)
          .maybeSingle(); // maybeSingle devuelve null si no encuentra fila

      if (existing == null) {
        // No existe → creamos el registro básico.
        await _client.from('veterinarios').insert({
          'usua_id': userId,
          'vete_disponible': true,
        });
      }
    }
  }

  // ── Solicitudes de rol ──────────────────────────────────────────────────────

  /// Obtiene TODAS las solicitudes (pendiente, aprobada, rechazada).
  /// Incluye datos del usuario solicitante mediante un join con la tabla usuarios.
  Future<List<Map<String, dynamic>>> obtenerTodasLasSolicitudes() async {
    final response = await _client
        .from('solicitudes_rol')
        .select('*, usuarios(usua_nombre, usua_correo, usua_foto_url)')
        .order('srol_fecha', ascending: false); // más recientes primero
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Obtiene todas las solicitudes pendientes de cambio de rol.
  /// Incluye datos del usuario solicitante mediante un join con la tabla usuarios.
  Future<List<Map<String, dynamic>>> obtenerSolicitudesPendientes() async {
    final response = await _client
        .from('solicitudes_rol')
        .select('*, usuarios(usua_nombre, usua_correo, usua_foto_url)')
        .eq('srol_estado', 'pendiente')
        .order('srol_fecha', ascending: true); // más antiguas primero
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Cambia el estado de una solicitud a 'aprobada' o 'rechazada'.
  Future<void> responderSolicitud(String solicitudId, String estado) async {
    await _client
        .from('solicitudes_rol')
        .update({'srol_estado': estado})
        .eq('srol_id', solicitudId);
  }

  /// Aprueba una solicitud Y cambia el rol del usuario en paralelo.
  /// Usar Future.wait aquí es seguro porque ambas operaciones son independientes.
  Future<void> aprobarSolicitudYCambiarRol({
    required String solicitudId,
    required String usuarioId,
  }) async {
    await Future.wait([
      responderSolicitud(solicitudId, 'aprobada'),
      cambiarRolUsuario(usuarioId, 'veterinario'),
    ]);
  }

  // ── Noticias ────────────────────────────────────────────────────────────────

  /// Obtiene TODAS las noticias (publicadas, pendientes, rechazadas).
  Future<List<NoticiaModel>> obtenerTodasLasNoticias() async {
    final response = await _client
        .from('noticias')
        .select('*, usuarios(usua_nombre, usua_foto_url)')
        .order('noti_fecha', ascending: false); // más recientes primero
    return (response as List)
        .map((e) => NoticiaModel.fromJson(e))
        .toList();
  }

  /// Obtiene las noticias que están esperando moderación.
  /// Incluye nombre y foto del autor mediante join con usuarios.
  Future<List<NoticiaModel>> obtenerNoticiasPendientes() async {
    final response = await _client
        .from('noticias')
        .select('*, usuarios(usua_nombre, usua_foto_url)')
        .eq('noti_estado', 'pendiente')
        .order('noti_fecha', ascending: true); // más antiguas primero
    return (response as List)
        .map((e) => NoticiaModel.fromJson(e))
        .toList();
  }

  /// Cambia el estado de una noticia a 'publicada' o 'rechazada'.
  Future<void> cambiarEstadoNoticia(String noticiaId, String estado) async {
    await _client
        .from('noticias')
        .update({'noti_estado': estado})
        .eq('noti_id', noticiaId);
  }

  /// Crea una noticia nueva desde el panel admin (publicada directamente).
  Future<void> crearNoticia({
    required String titulo,
    required String contenido,
    required String categoria,
    String? imagenUrl,
    required String autorId,
  }) async {
    await _client.from('noticias').insert({
      'usua_id':        autorId,
      'noti_titulo':    titulo,
      'noti_contenido': contenido,
      'noti_categoria': categoria,
      if (imagenUrl != null && imagenUrl.isNotEmpty) 'noti_imagen': imagenUrl,
      'noti_estado':    'publicada', // admin publica directamente
    });
  }

  /// Actualiza los campos de una noticia existente.
  Future<void> editarNoticia({
    required String noticiaId,
    required String titulo,
    required String contenido,
    required String categoria,
    String? imagenUrl,
  }) async {
    await _client.from('noticias').update({
      'noti_titulo':    titulo,
      'noti_contenido': contenido,
      'noti_categoria': categoria,
      'noti_imagen':    imagenUrl,
    }).eq('noti_id', noticiaId);
  }

  /// Elimina una noticia permanentemente.
  Future<void> eliminarNoticia(String noticiaId) async {
    await _client.from('noticias').delete().eq('noti_id', noticiaId);
  }

  // ── Mascotas ────────────────────────────────────────────────────────────────

  /// Obtiene las [limit] mascotas más recientes para el widget del dashboard.
  /// Incluye nombre, teléfono y foto del propietario mediante join.
  Future<List<MascotaModel>> obtenerUltimasMascotas({int limit = 10}) async {
    final response = await _client
        .from('mascotas')
        .select('*, usuarios(usua_nombre, usua_telefono, usua_foto_url)')
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List)
        .map((e) => MascotaModel.fromJson(e))
        .toList();
  }
}
