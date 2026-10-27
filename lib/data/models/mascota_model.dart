// mascota_model.dart — Modelo de datos para las mascotas.
//
// Representa un registro de la tabla `mascotas` en Supabase.
// También incluye campos opcionales que vienen del join con `usuarios`
// cuando se necesita mostrar información del propietario.

import 'package:flutter/material.dart';

class MascotaModel {
  final String id; // masc_id: identificador único de la mascota
  final String usuarioId; // usua_id: ID del dueño de la mascota
  final String nombre; // masc_nombre
  final String especie; // masc_especie (ej: "Perro", "Gato")
  final String raza; // masc_raza
  final String genero; // masc_sexo ("Macho" | "Hembra")
  final String
  edad; // masc_edad — guardamos como texto para mostrar "Menor de 1 año"
  final String estado; // masc_estado ("Disponible", "perdido", "para adoptar")
  final String? descripcion; // masc_descripcion (opcional)
  final String? fotoUrl; // masc_foto_url (opcional)
  final DateTime? createdAt; // created_at — cuándo se registró en Supabase
  final String?
  rasgoDistintivo; // masc_rasgo_distintivo (ej: "mancha en la oreja")
  final String? colorMascota; // masc_color (ej: "café y blanco")
  final String? tamano; // masc_tamano ("Pequeño" | "Mediano" | "Grande")
  final String? peso; // masc_peso en kg (ej: "4.5")
  final bool? esterilizado; // masc_esterilizado

  // Datos del propietario — solo disponibles cuando se hace JOIN con `usuarios`.
  final String? propietarioNombre;
  final String? propietarioTelefono;
  final String? propietarioFotoUrl;

  MascotaModel({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.especie,
    required this.raza,
    required this.genero,
    required this.edad,
    this.estado = 'Disponible',
    this.descripcion,
    this.fotoUrl,
    this.createdAt,
    this.rasgoDistintivo,
    this.colorMascota,
    this.tamano,
    this.peso,
    this.esterilizado,
    this.propietarioNombre,
    this.propietarioTelefono,
    this.propietarioFotoUrl,
  });

  // ── Deserialización ───────────────────────────────────────────────────────

  /// Construye un MascotaModel desde el JSON de Supabase.
  /// Si el query incluye join con usuarios, los datos del propietario
  /// vienen en el objeto anidado bajo la clave 'usuarios'.
  factory MascotaModel.fromJson(Map<String, dynamic> json) {
    // Extraemos el objeto del join; puede ser null si no se hizo join.
    final usuariosJoin = json['usuarios'] as Map<String, dynamic>?;

    return MascotaModel(
      id: json['masc_id']?.toString() ?? '',
      usuarioId: json['usua_id']?.toString() ?? '',
      nombre: json['masc_nombre'] as String? ?? '',
      especie: json['masc_especie'] as String? ?? '',
      raza: json['masc_raza'] as String? ?? '',
      genero: json['masc_sexo'] as String? ?? '',
      // La edad se guarda como entero en la BD; la convertimos a texto legible.
      edad: _parseEdad(json['masc_edad']),
      estado: json['masc_estado'] as String? ?? 'Disponible',
      descripcion: json['masc_descripcion'] as String?,
      fotoUrl: json['masc_foto_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      rasgoDistintivo: json['masc_rasgo_distintivo'] as String?,
      colorMascota: json['masc_color'] as String?,
      tamano: json['masc_tamano'] as String?,
      // El peso puede venir como número o como cadena; lo normalizamos a String.
      peso: json['masc_peso']?.toString(),
      esterilizado: json['masc_esterilizado'] as bool?,
      // Datos del propietario desde el join (pueden ser null si no se hizo join).
      propietarioNombre: usuariosJoin?['usua_nombre'] as String?,
      propietarioTelefono: usuariosJoin?['usua_telefono'] as String?,
      propietarioFotoUrl: usuariosJoin?['usua_foto_url'] as String?,
    );
  }

  // ── Serialización ─────────────────────────────────────────────────────────

  /// JSON para INSERT — nunca incluye masc_id (lo genera Supabase automáticamente).
  /// Solo incluye los campos que tienen valor para no sobreescribir columnas con null.
  Map<String, dynamic> toInsertJson() {
    // La BD guarda la edad como INTEGER; 0 significa "Menor de 1 año".
    final edadInt = edad.toLowerCase() == 'menor de 1 año'
        ? 0
        : (int.tryParse(edad) ?? 0);

    return {
      if (usuarioId.isNotEmpty) 'usua_id': usuarioId,
      'masc_nombre': nombre,
      if (especie.isNotEmpty) 'masc_especie': especie,
      if (raza.isNotEmpty) 'masc_raza': raza,
      'masc_edad': edadInt,
      if (genero.isNotEmpty) 'masc_sexo': genero,
      if (descripcion != null && descripcion!.isNotEmpty)
        'masc_descripcion': descripcion,
      if (fotoUrl != null && fotoUrl!.isNotEmpty) 'masc_foto_url': fotoUrl,
      'masc_estado': estado,
      if (rasgoDistintivo != null && rasgoDistintivo!.isNotEmpty)
        'masc_rasgo_distintivo': rasgoDistintivo,
      if (colorMascota != null && colorMascota!.isNotEmpty)
        'masc_color': colorMascota,
      if (tamano != null && tamano!.isNotEmpty) 'masc_tamano': tamano,
      if (peso != null && peso!.isNotEmpty) 'masc_peso': peso,
      if (esterilizado != null) 'masc_esterilizado': esterilizado,
    };
  }

  /// JSON para UPDATE — incluye todos los campos (permite borrar valores con null).
  Map<String, dynamic> toUpdateJson() {
    final edadInt = edad.toLowerCase() == 'menor de 1 año'
        ? 0
        : (int.tryParse(edad) ?? 0);

    return {
      'masc_nombre': nombre,
      'masc_especie': especie.isNotEmpty ? especie : null,
      'masc_raza': raza.isNotEmpty ? raza : null,
      'masc_edad': edadInt,
      'masc_sexo': genero.isNotEmpty ? genero : null,
      'masc_descripcion': descripcion?.isNotEmpty == true ? descripcion : null,
      'masc_foto_url': fotoUrl?.isNotEmpty == true ? fotoUrl : null,
      'masc_estado': estado,
      'masc_rasgo_distintivo': rasgoDistintivo?.isNotEmpty == true
          ? rasgoDistintivo
          : null,
      'masc_color': colorMascota?.isNotEmpty == true ? colorMascota : null,
      'masc_tamano': tamano?.isNotEmpty == true ? tamano : null,
      'masc_peso': peso?.isNotEmpty == true ? peso : null,
      'masc_esterilizado': esterilizado,
    };
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  /// Convierte el entero de edad de la BD al texto que se muestra en la UI.
  /// La BD guarda 0 para indicar "Menor de 1 año".
  static String _parseEdad(dynamic raw) {
    if (raw == null) return '';
    final val = int.tryParse(raw.toString());
    if (val == null) return raw.toString(); // fallback: devuelve el valor crudo
    if (val == 0) return 'Menor de 1 año';
    return val.toString();
  }

  /// Ícono de Material según la especie de la mascota.
  IconData get icon {
    final e = especie.toLowerCase();
    if (e.contains('perro')) return Icons.pets;
    if (e.contains('gato')) return Icons.catching_pokemon;
    if (e.contains('ave') || e.contains('pájaro')) return Icons.flutter_dash;
    if (e.contains('conejo')) return Icons.cruelty_free;
    return Icons.pets; // ícono por defecto
  }

  /// Color de acento según la especie (para tarjetas y chips en la UI).
  Color get color {
    final e = especie.toLowerCase();
    if (e.contains('perro')) return const Color(0xFF1CB5C9);
    if (e.contains('gato')) return const Color(0xFFE58D57);
    if (e.contains('ave') || e.contains('pájaro'))
      return const Color(0xFF7C6FCD);
    if (e.contains('conejo')) return const Color(0xFF43B89C);
    return const Color(0xFF1CB5C9); // color por defecto
  }
}
