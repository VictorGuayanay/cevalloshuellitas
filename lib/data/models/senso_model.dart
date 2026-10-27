// senso_model.dart — Modelo del Censo Pecuario (SENSO).
//
// MIGRADO: los datos del SENSO ahora se almacenan en Supabase,
// en la tabla `sensos`. Anteriormente usaban Firebase Firestore.
//
// Tabla en Supabase:
//   sensos (
//     senso_id     uuid pk default gen_random_uuid(),
//     usua_id      uuid references usuarios(usua_id),
//     produccion   text,   -- 'menores' | 'mayores'
//     especie      text,
//     numero_animales int,
//     alimentacion text,   -- 'balanceado' | 'mixto' | 'natural'
//     destinacion  text,   -- 'consumo' | 'venta' | 'ambos'
//     created_at   timestamptz default now()
//   )

/// Representa un registro del Censo Pecuario de un productor.
class SensoModel {
  final String? id; // senso_id: UUID generado por Supabase
  final String usuarioId; // usua_id: FK hacia la tabla usuarios
  final String produccion; // Tipo de producción: "menores" | "mayores"
  final String especie; // Especie animal: "Bovinos", "Cerdos", "Aves", etc.
  final int numeroAnimales; // Cantidad promedio de animales
  final String
  alimentacion; // Tipo de alimentación: "balanceado" | "mixto" | "natural"
  final String
  destinacion; // Destino de la producción: "consumo" | "venta" | "ambos"
  final DateTime? creadoEn; // created_at: timestamp del servidor Supabase

  SensoModel({
    this.id,
    required this.usuarioId,
    required this.produccion,
    required this.especie,
    required this.numeroAnimales,
    required this.alimentacion,
    required this.destinacion,
    this.creadoEn,
  });

  // ── Deserialización desde Supabase ────────────────────────────────────────

  /// Construye un SensoModel desde el JSON que devuelve Supabase.
  factory SensoModel.fromJson(Map<String, dynamic> json) {
    return SensoModel(
      id: json['senso_id']?.toString(),
      usuarioId: json['usua_id']?.toString() ?? '',
      produccion: json['produccion'] as String? ?? '',
      especie: json['especie'] as String? ?? '',
      numeroAnimales: (json['numero_animales'] as num?)?.toInt() ?? 0,
      alimentacion: json['alimentacion'] as String? ?? '',
      destinacion: json['destinacion'] as String? ?? '',
      creadoEn: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  // ── Serialización para Supabase ───────────────────────────────────────────

  /// JSON para INSERT — sin senso_id ni created_at (los genera Supabase).
  Map<String, dynamic> toInsertJson() {
    return {
      'usua_id': usuarioId,
      'produccion': produccion,
      'especie': especie,
      'numero_animales': numeroAnimales,
      'alimentacion': alimentacion,
      'destinacion': destinacion,
    };
  }

  // ── Etiquetas legibles para la UI ─────────────────────────────────────────

  /// Texto legible del tipo de producción.
  String get produccionLabel =>
      produccion == 'menores' ? 'Animales Menores' : 'Animales Mayores';

  /// Texto legible del tipo de alimentación.
  String get alimentacionLabel {
    switch (alimentacion) {
      case 'balanceado':
        return 'Balanceado';
      case 'mixto':
        return 'Mixto';
      case 'natural':
        return 'Natural';
      default:
        return alimentacion;
    }
  }

  /// Texto legible del destino de la producción.
  String get destinacionLabel {
    switch (destinacion) {
      case 'consumo':
        return 'Consumo propio';
      case 'venta':
        return 'Venta';
      case 'ambos':
        return 'Consumo y venta';
      default:
        return destinacion;
    }
  }
}
