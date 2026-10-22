// auth_error_mapper_test.dart — Tests del mapeador central de errores de auth.
//
// ERR-01…ERR-07 (cambio mejoras-login): toda la UI de auth recibe strings en
// español de una lista permitida (allowlist) — nunca texto crudo de excepciones
// (ERR-06 / T7 del diseño "Info leak via errors": denylist unit-test).

import 'package:aplicacion/core/auth_error_mapper.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Denylist: patrones prohibidos en CUALQUIER mensaje que llegue a la UI
  // (ERR-06: sin clases de excepción, SQL, texto inglés del servidor ni $e).
  final denylist = RegExp(
    r'Exception|SocketException|Postgrest|Error inesperado|attempt\(|'
    r'rate limit|over_email_send',
  );

  group('ERR-06 — fallback genérico', () {
    // ERR-06 escenario "Unknown failure fallback": un error sin mapear cae
    // SIEMPRE al string fijo genérico, sin merma de información.
    test('un error sin mapear cae al mensaje genérico permitido', () {
      final resultado = AuthErrorMapper.map(Object());

      expect(resultado, 'Ocurrió un error. Intenta de nuevo.');
      expect(denylist.hasMatch(resultado!), isFalse);
    });
  });

  group('ERR-02 — rate-limit de correo', () {
    // ERR-02 escenario "Rate-limited recovery email": el token inglés del
    // servidor jamás llega a la UI; el mensaje debe invitar a esperar.
    // Copy (R-Copy design:515): sin cita literal en el spec → español
    // coherente con el tono existente.
    test('over_email_send_rate_limit se mapea a espera en español', () {
      final resultado = AuthErrorMapper.map(
        const AuthException(
          'Email rate limit exceeded. Please wait a few minutes '
          'before trying again. (over_email_send_rate_limit)',
        ),
      );

      expect(resultado, 'Espera un momento antes de solicitar otro correo.');
      expect(resultado, isNot(contains('over_email_send_rate_limit')));
      expect(resultado, isNot(contains('rate limit')));
      expect(denylist.hasMatch(resultado!), isFalse);
    });
  });

  group('ERR-03 — lockout de intentos', () {
    // ERR-03 escenario "Lockout warning with count": la frase inglesa del
    // servidor se sustituye por español que CONSERVA el número restante.
    test('mensaje de intentos se traduce conservando el conteo', () {
      final resultado = AuthErrorMapper.map(
        const AuthException(
          'For security purposes, you have 3 attempts left before being '
          'locked',
        ),
      );

      expect(resultado, 'Quedan 3 intentos antes de bloquear la cuenta.');
      expect(resultado, isNot(contains('For security purposes')));
      expect(denylist.hasMatch(resultado!), isFalse);
    });
  });

  group('ERR-04 — fallos de conectividad', () {
    // ERR-04 escenario "Login with no connectivity": cualquier excepción de
    // socket/HTTP/timeouts se traduce al mensaje de conexión, sin strings
    // técnicos (hostnames, detalles de excepción).
    test('socket, timeout y client se mapean a mensaje de conexión', () {
      final esperado =
          'Sin conexión a internet. Revisa tu conexión y vuelve a '
          'intentarlo.';

      final casos = <Object>[
        const SocketException(
          "Failed host lookup: 'xxxx.supabase.co' (errno = -2)",
        ),
        TimeoutException('Connection timed out'),
        http.ClientException(
          'Connection closed before full header was received',
          Uri.parse('https://xxxx.supabase.co/auth/v1/token'),
        ),
      ];

      for (final caso in casos) {
        final resultado = AuthErrorMapper.map(caso);
        expect(resultado, esperado, reason: 'para ${caso.runtimeType}');
        expect(resultado, isNot(contains('supabase')));
        expect(resultado, isNot(contains('Failed host')));
        expect(denylist.hasMatch(resultado!), isFalse);
      }
    });
  });

  group('ERR-05 / ERR-01 — flujo Google', () {
    // ERR-05 + ERR-01 escenario "Google cancel leaves no residue": la
    // cancelación del selector de cuentas es SILENCIOSA (null, sin banner).
    test('cancelación de Google devuelve null (silencioso)', () {
      final resultado = AuthErrorMapper.map(
        Exception('Inicio de sesión con Google cancelado por el usuario'),
      );

      expect(resultado, isNull);
    });

    // ERR-05 escenario "Missing ID token": la configuración del Web Client
    // ID se explica en español SIN exponer rutas internas de configuración.
    // ERR-05 escenario "Supabase rejects the Google token" + verificación de
    // que las 4 traducciones existentes se conservan VERBATIM (3.5 GREEN).
    test('idToken faltante y mensajes de auth existentes se mapean', () {
      final idTokenFaltante = AuthErrorMapper.map(
        Exception(
          'No se pudo obtener el token de Google. '
          'Verifica que el Web Client ID en supabase_config.dart '
          'sea el OAuth de tipo "Aplicación web".',
        ),
      );
      expect(
        idTokenFaltante,
        'No se pudo iniciar sesión con Google. '
        'Verifica el Web Client ID (tipo Aplicación web).',
      );
      expect(idTokenFaltante, isNot(contains('supabase_config.dart')));

      // Mensajes existentes: verbatim (sin regresión copy).
      expect(
        AuthErrorMapper.map(const AuthException('Invalid login credentials')),
        'Correo o contraseña incorrectos.',
      );
      expect(
        AuthErrorMapper.map(const AuthException('User already registered')),
        'Este correo ya está registrado.',
      );
      expect(
        AuthErrorMapper.map(
          const AuthException('Password should be at least 6 characters'),
        ),
        'La contraseña debe tener al menos 6 caracteres.',
      );
      expect(
        AuthErrorMapper.map(const AuthException('Email not confirmed')),
        'Debes confirmar tu correo electrónico.',
      );

      // Rechazo de token de Google desconocido → genérico, jamás passthrough.
      final rechazo = AuthErrorMapper.map(
        const AuthException('Invalid Refresh Token: Refresh Token Not Found'),
      );
      expect(rechazo, 'Ocurrió un error. Intenta de nuevo.');
      expect(rechazo, isNot(contains('Error inesperado')));
    });
  });

  group('SES-03 / SGN-06 — perfil inexistente', () {
    // SES-03 / SGN-06 escenario "Residual orphan is detected, not looped":
    // la fila `usuarios` no existe para el uid autenticado (PGRST116) →
    // mensaje accionable en español que hace detectable el orfanato.
    // Copy (R-Copy design:515): sin cita literal en el spec → español
    // coherente con el tono existente; reemplaza el interim de la 2.6.
    test('PGRST116 se mapea a mensaje de perfil no encontrado', () {
      final resultado = AuthErrorMapper.map(
        const PostgrestException(
          message: 'JSON object requested, multiple (or no) rows returned',
          code: 'PGRST116',
        ),
      );

      expect(resultado, 'No encontramos tu perfil. Contacta al administrador.');
      expect(denylist.hasMatch(resultado!), isFalse);
    });
  });
}
