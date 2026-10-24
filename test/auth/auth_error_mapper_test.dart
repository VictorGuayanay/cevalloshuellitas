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

    // AMD-2026-10-23-02, ciclo 1 — scenario "Google platform error maps to
    // actionable Spanish copy": los códigos de plataforma de Google
    // (sign_in_failed / sign_in_required / ApiException: 10 / 12500) mapean a
    // copy accionable en español, distinto del fallback y limpio de tokens
    // crudos (ERR-06: sin ApiException, sin códigos numéricos, sin texto
    // técnico). Incluye la cancelación ampliada (sign_in_canceled / 12501 →
    // null) CON precedencia sobre los códigos de plataforma — baseline-first:
    // el test 'cancelado' de arriba debe seguir en verde.
    // RED: el mapa aún no reconoce ninguna de estas marcas → fallback crudo.
    test(
      'plataforma Google mapea a copy accionable y el cancel ampliado sigue silencioso',
      () {
        const esperado =
            'No se pudo iniciar sesión con Google. '
            'Verifica tu cuenta en el dispositivo o contacta al administrador.';
        final denylistGoogle = RegExp(
          r'ApiException|PlatformException|sign_in|Api|\d',
        );
        final plataforma = <String>[
          'PlatformException(sign_in_failed, ApiException: 10, null)',
          'PlatformException(sign_in_failed, ApiException: 12500, null)',
          'PlatformException(sign_in_required, null, null)',
        ];

        for (final caso in plataforma) {
          final resultado = AuthErrorMapper.map(Exception(caso));
          expect(resultado, esperado, reason: 'para $caso');
          expect(resultado, isNot('Ocurrió un error. Intenta de nuevo.'));
          expect(denylist.hasMatch(resultado!), isFalse);
          expect(denylistGoogle.hasMatch(resultado), isFalse);
        }

        // Cancel ampliado: un marcador por caso; el segundo además pinza la
        // precedencia de la rama de silencio (texto con 'sign_in_failed').
        expect(
          AuthErrorMapper.map(
            Exception('PlatformException(sign_in_canceled, null, null)'),
          ),
          isNull,
        );
        expect(
          AuthErrorMapper.map(
            Exception(
              'PlatformException(sign_in_failed, ApiException: 12501, null)',
            ),
          ),
          isNull,
        );
      },
    );

    // AMD-2026-10-23-02, ciclo 2 — scenario "Wrapper-prefixed stage errors
    // are distinguishable": cada prefijo de etapa del servicio mapea a su
    // copy accionable PROPIO — distinto entre sí, del fallback y del copy de
    // plataforma (los wrappers ganan: son más específicos e interpolan los
    // códigos crudos dentro). Sin tokens crudos hacia la UI (ERR-06).
    // RED: las ramas de prefijo aún no existen → los wrappers con códigos
    // dentro caen a la rama de plataforma del ciclo 1.
    test(
      'los tres prefijos de etapa del wrapper Google mapean a su copy propio',
      () {
        final denylistGoogle = RegExp(r'Exception|sign_in|Api|\d');
        final wrapper = <String, String>{
          'Error al abrir Google: '
                  'PlatformException(sign_in_failed, ApiException: 10, null)':
              'No se pudo abrir el selector de cuentas de Google. '
              'Revisa Google Play Services e inténtalo de nuevo.',
          'Error obteniendo autenticación de Google: '
                  'PlatformException(sign_in_failed, ApiException: 12500, null)':
              'No se pudo verificar tu cuenta de Google. '
              'Cierra la sesión de Google en tu dispositivo y vuelve a '
              'intentarlo.',
          'Error autenticando en Supabase con Google: '
                  'AuthException(message: SQLSTATE 23505, statusCode: 409)':
              'La cuenta de Google fue verificada, pero el servidor no '
              'autorizó el inicio de sesión. Vuelve a intentarlo en unos '
              'minutos.',
        };

        for (final caso in wrapper.entries) {
          final resultado = AuthErrorMapper.map(Exception(caso.key));
          // Cada etapa → su copy distinto (valores únicos por prefijo).
          expect(resultado, caso.value, reason: 'para ${caso.key}');
          expect(resultado, isNot('Ocurrió un error. Intenta de nuevo.'));
          expect(denylist.hasMatch(resultado!), isFalse);
          expect(denylistGoogle.hasMatch(resultado), isFalse);
        }
      },
    );
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

  group('RST-09 / RST-12 — fallos de enlace de recuperación', () {
    // RST-09: esFalloDeEnlaceRecuperacion detecta fallos de canje de código PKCE
    // design §6.1 decisión 3: AuthPKCEGrantCodeExchangeError → true,
    // AuthApiException → true, AuthRetryableFetchException → false (transitorio).
    test(
      'esFalloDeEnlaceRecuperacion: AuthPKCEGrantCodeExchangeError → true',
      () {
        final error = AuthPKCEGrantCodeExchangeError(
          'Code verifier could not be found',
        );
        expect(AuthErrorMapper.esFalloDeEnlaceRecuperacion(error), isTrue);
      },
    );

    test('esFalloDeEnlaceRecuperacion: AuthApiException → true', () {
      final error = AuthApiException('Invalid code');
      expect(AuthErrorMapper.esFalloDeEnlaceRecuperacion(error), isTrue);
    });

    test(
      'esFalloDeEnlaceRecuperacion: AuthRetryableFetchException → false (transitorio)',
      () {
        final error = AuthRetryableFetchException(message: 'Network error');
        expect(AuthErrorMapper.esFalloDeEnlaceRecuperacion(error), isFalse);
      },
    );

    test('esFalloDeEnlaceRecuperacion: otros errores → false', () {
      expect(AuthErrorMapper.esFalloDeEnlaceRecuperacion(Object()), isFalse);
      expect(
        AuthErrorMapper.esFalloDeEnlaceRecuperacion(
          const AuthException('Invalid login credentials'),
        ),
        isFalse,
      );
      expect(
        AuthErrorMapper.esFalloDeEnlaceRecuperacion(
          const SocketException('failed'),
        ),
        isFalse,
      );
    });
  });

  group(
    'RST-09 / RST-12 — literales verbatim y AuthSessionMissingException',
    () {
      // RST-DP-3(a): literales verbatim del spec — igualdad exacta de strings.
      test('mensajeEnlaceInvalido literal verbatim (RST-09)', () {
        expect(
          AuthErrorMapper.mensajeEnlaceInvalido,
          'El enlace expiró o no es válido. Solicita uno nuevo.',
        );
      });

      test(
        'mensajeSesionRecuperacionExpirada literal verbatim (RST-12, E7)',
        () {
          expect(
            AuthErrorMapper.mensajeSesionRecuperacionExpirada,
            'Tu sesión de recuperación expiró. Solicita un enlace nuevo.',
          );
        },
      );

      // RST-12 scenario "Submit without a session": AuthSessionMissingException
      // mapea al literal de sesión de recuperación expirada.
      test(
        'AuthSessionMissingException → mensajeSesionRecuperacionExpirada',
        () {
          final resultado = AuthErrorMapper.map(
            AuthSessionMissingException('Session missing'),
          );

          expect(resultado, AuthErrorMapper.mensajeSesionRecuperacionExpirada);
          expect(denylist.hasMatch(resultado!), isFalse);
        },
      );
    },
  );

  group('ERR-06 — denylist para nuevos literales (RST-09 pre-gate)', () {
    // RST-09 "No token leakage on failure": los nuevos literales deben pasar
    // el denylist ERR-06 (sin Exception, rate limit, attempt, ApiException).
    test('mensajeEnlaceInvalido pasa denylist ERR-06', () {
      expect(denylist.hasMatch(AuthErrorMapper.mensajeEnlaceInvalido), isFalse);
    });

    test('mensajeSesionRecuperacionExpirada pasa denylist ERR-06', () {
      expect(
        denylist.hasMatch(AuthErrorMapper.mensajeSesionRecuperacionExpirada),
        isFalse,
      );
    });
  });
}
