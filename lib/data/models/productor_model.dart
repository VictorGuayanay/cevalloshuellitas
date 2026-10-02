// productor_model.dart — Modelo de datos para productores pecuarios en venta.
//
// Agrega datos del usuario (nombre, teléfono, foto, dirección)
// con sus registros de censo cuya destinación es 'venta' o 'ambos'.
// Se construye desde un JOIN entre `usuarios` y `sensos`.

class ProductorModel {
  final String usuarioId;       // usua_id
  final String nombre;          // usua_nombre
  final String? telefono;       // usua_telefono
  final String? fotoUrl;        // usua_foto_url
  final String? direccionGps;   // usua_direccion_gps: "lat,lng" o texto libre
  final String? tipoAnimales;   // usua_tipo_animales: 'menores' | 'mayores' | 'ambos'

  /// Lista de especies que este productor tiene disponibles para venta.
  /// Cada entrada viene de un registro de senso con destinacion 'venta' o 'ambos'.
  final List<EspecieEnVenta> especiesEnVenta;

  ProductorModel({
    required this.usuarioId,
    required this.nombre,
    this.telefono,
    this.fotoUrl,
    this.direccionGps,
    this.tipoAnimales,
    required this.especiesEnVenta,
  });

  // ── Coordenadas GPS parseadas ─────────────────────────────────────────────

  /// Parsea el campo `usua_direccion_gps` con formato "lat,lng".
  /// Retorna null si el campo está vacío o no tiene el formato correcto.
  double? get latitud {
    if (direccionGps == null || !direccionGps!.contains(',')) return null;
    final parts = direccionGps!.split(',');
    return double.tryParse(parts[0].trim());
  }

  double? get longitud {
    if (direccionGps == null || !direccionGps!.contains(',')) return null;
    final parts = direccionGps!.split(',');
    if (parts.length < 2) return null;
    return double.tryParse(parts[1].trim());
  }

  /// True si el productor tiene coordenadas GPS válidas.
  bool get tieneUbicacion => latitud != null && longitud != null;

  /// Resumen legible de los animales en venta.
  String get resumenAnimales {
    if (especiesEnVenta.isEmpty) return 'Sin especies registradas';
    return especiesEnVenta.map((e) => e.especie).toSet().join(', ');
  }

  /// Total de animales disponibles para venta.
  int get totalAnimales =>
      especiesEnVenta.fold(0, (sum, e) => sum + e.numeroAnimales);
}

/// Representa una especie/animal que un productor tiene disponible para venta.
class EspecieEnVenta {
  final String especie;         // ej: "Bovinos (vacas)", "Cerdos"
  final String produccion;      // 'menores' | 'mayores'
  final int numeroAnimales;     // cantidad promedio disponible
  final String alimentacion;    // 'balanceado' | 'mixto' | 'natural'

  const EspecieEnVenta({
    required this.especie,
    required this.produccion,
    required this.numeroAnimales,
    required this.alimentacion,
  });

  factory EspecieEnVenta.fromJson(Map<String, dynamic> json) {
    return EspecieEnVenta(
      especie:        json['especie']          as String? ?? '',
      produccion:     json['produccion']       as String? ?? '',
      numeroAnimales: (json['numero_animales'] as num?)?.toInt() ?? 0,
      alimentacion:   json['alimentacion']     as String? ?? '',
    );
  }

  String get alimentacionLabel {
    switch (alimentacion) {
      case 'balanceado': return 'Balanceado';
      case 'mixto':      return 'Mixto';
      case 'natural':    return 'Natural';
      default:           return alimentacion;
    }
  }
}
