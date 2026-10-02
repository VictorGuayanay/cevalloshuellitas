// productor_service.dart — Servicio para obtener productores pecuarios en venta.
//
// Consulta Supabase para obtener usuarios que:
//   1. Son productores (usua_es_productor = true)
//   2. Tienen registros de censo con destinacion 'venta' o 'ambos'
// y agrupa sus especies disponibles para venta.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/productor_model.dart';

class ProductorService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Obtiene todos los productores con especies disponibles para venta.
  /// Filtra sensos con destinacion 'venta' o 'ambos', agrupa por usuario.
  Future<List<ProductorModel>> obtenerProductoresEnVenta() async {
    try {
      // 1. Obtener todos los sensos con destinacion venta o ambos,
      //    incluyendo los datos del usuario mediante join.
      final response = await _client
          .from('sensos')
          .select('''
            especie,
            produccion,
            numero_animales,
            alimentacion,
            destinacion,
            usua_id,
            usuarios!inner(
              usua_id,
              usua_nombre,
              usua_telefono,
              usua_foto_url,
              usua_direccion_gps,
              usua_tipo_animales,
              usua_es_productor
            )
          ''')
          .or('destinacion.eq.venta,destinacion.eq.ambos')
          .eq('usuarios.usua_es_productor', true);

      // 2. Agrupar por usuarioId
      final Map<String, ProductorModel> mapa = {};

      for (final row in (response as List)) {
        final usuarioData = row['usuarios'] as Map<String, dynamic>?;
        if (usuarioData == null) continue;
        if (usuarioData['usua_es_productor'] != true) continue;

        final usuarioId = usuarioData['usua_id']?.toString() ?? '';
        if (usuarioId.isEmpty) continue;

        final especie = EspecieEnVenta.fromJson(row as Map<String, dynamic>);

        if (mapa.containsKey(usuarioId)) {
          // Agregar especie al productor ya existente
          mapa[usuarioId] = ProductorModel(
            usuarioId:      mapa[usuarioId]!.usuarioId,
            nombre:         mapa[usuarioId]!.nombre,
            telefono:       mapa[usuarioId]!.telefono,
            fotoUrl:        mapa[usuarioId]!.fotoUrl,
            direccionGps:   mapa[usuarioId]!.direccionGps,
            tipoAnimales:   mapa[usuarioId]!.tipoAnimales,
            especiesEnVenta: [...mapa[usuarioId]!.especiesEnVenta, especie],
          );
        } else {
          mapa[usuarioId] = ProductorModel(
            usuarioId:    usuarioId,
            nombre:       usuarioData['usua_nombre']      as String? ?? 'Productor',
            telefono:     usuarioData['usua_telefono']    as String?,
            fotoUrl:      usuarioData['usua_foto_url']    as String?,
            direccionGps: usuarioData['usua_direccion_gps'] as String?,
            tipoAnimales: usuarioData['usua_tipo_animales'] as String?,
            especiesEnVenta: [especie],
          );
        }
      }

      return mapa.values.toList();
    } catch (e) {
      debugPrint('ProductorService.obtenerProductoresEnVenta error: $e');
      return [];
    }
  }
}
