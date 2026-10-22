// auth_error_mapper.dart — Mapeador central de errores de auth (ERR-06).
//
// Función pura sin estado ni dependencias de UI (patrón AppColors del diseño):
// convierte cualquier excepción de las operaciones de auth a un mensaje en
// español de la lista permitida (allowlist), o `null` cuando NO debe
// mostrarse ningún error (p. ej. cancelación de Google — ERR-01/ERR-05).
//
// Lookup order del diseño (decision "Error mapping extracted to a pure,
// security-testable mapper"):
//   1. AuthException + sub-cadenas allowlisteadas (existentes + rate-limit + lockout)
//   2. Marcador de cancelación de Google → null (silencio)
//   3. Fallos de conectividad (Socket/Timeout/Client) → mensaje de conexión
//   4. PostgrestException PGRST116 → perfil no encontrado (orfanato SGN-06)
//   5. Fallback fijo genérico (ERR-06)

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthErrorMapper {
  AuthErrorMapper._();

  /// Devuelve el mensaje en español para [error], o `null` si el error no
  /// debe mostrarse (silencio intencional, p. ej. cancelación de Google).
  static String? map(Object error) {
    // `toString()` cubre tanto AuthException como wrappers en español de la
    // capa servicio que interpolan `$e` (el texto crudo queda SOLO aquí,
    // jamás se re-emite — ERR-06).
    final texto = error.toString();

    // Rama 2 (ERR-05/ERR-01): cancelación del selector de Google → null.
    // Primera para que NUNCA se muestre banner en el flujo de cancelación.
    if (texto.contains('cancelado')) return null;

    // Rama 1 (ERR-02): rate-limit de correo → espera en español.
    if (texto.contains('over_email_send_rate_limit')) {
      return 'Espera un momento antes de solicitar otro correo.';
    }

    // Rama 1 (ERR-03): lockout de intentos → español conservando el conteo.
    final lockout = RegExp(
      r'For security purposes, you have (\d+) attempt',
    ).firstMatch(texto);
    if (lockout != null) {
      return 'Quedan ${lockout.group(1)} intentos antes de bloquear la '
          'cuenta.';
    }

    // Rama 1 (mensajes existentes, verbatim): credenciales, registro,
    // longitud de contraseña y correo sin confirmar (spec los cita y las
    // traducciones NO cambian — 3.5).
    if (texto.contains('Invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (texto.contains('User already registered')) {
      return 'Este correo ya está registrado.';
    }
    if (texto.contains('Password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (texto.contains('Email not confirmed')) {
      return 'Debes confirmar tu correo electrónico.';
    }

    // Rama 1 (ERR-05): idToken de Google faltante → configuración del Web
    // Client ID en español, sin exponer rutas internas (ERR-06: cero
    // identificadores internos hacia la UI).
    if (texto.contains('Web Client ID')) {
      return 'No se pudo iniciar sesión con Google. '
          'Verifica el Web Client ID (tipo Aplicación web).';
    }

    // Rama 3 (ERR-04): conectividad → mensaje de revisar conexión y
    // reintentar; jamás hostnames ni texto técnico de la excepción.
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return 'Sin conexión a internet. Revisa tu conexión y vuelve a '
          'intentarlo.';
    }

    // Rama 4 (SES-03/SGN-06): fila `usuarios` inexistente para el uid
    // autenticado → orfanato detectable con mensaje accionable, nunca loop.
    if (error is PostgrestException && error.code == 'PGRST116') {
      return 'No encontramos tu perfil. Contacta al administrador.';
    }

    // Rama 5 (ERR-06): fallback fijo — sin ramas pendientes.
    return 'Ocurrió un error. Intenta de nuevo.';
  }
}
