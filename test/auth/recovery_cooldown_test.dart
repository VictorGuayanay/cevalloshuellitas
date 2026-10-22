// recovery_cooldown_test.dart — Cooldown de reenvío de código (ERR-07 / SP-DP-1).
//
// El cooldown es configurable vía `static const` (SP-DP-1, default 60 s),
// arranca en el ÉXITO de `recuperarContrasena`, decrece 1 s por tick y no
// deja ningún timer vivo tras `dispose()` (regla de duración del diseño).

import 'package:aplicacion/domain/controllers/auth_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  AuthController? controller;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  tearDown(() {
    controller?.dispose();
    controller = null;
  });

  group('ERR-07 — cooldown de reenvío', () {
    // ERR-07 escenarios 1 y 3: éxito de `recuperarContrasena` → acción
    // deshabilitada con cuenta regresiva visible (t=0 y t=30 s) y
    // habilitada de nuevo a los 61 s; SIN timer periódico tras dispose().
    // RED: la API de cooldown aún no existe en AuthController (se crea en 3.9).
    test('tras enviar el código el cooldown decrece y termina sin timers', () {
      fakeAsync((async) {
        when(
          () => mockAuthService.enviarRecuperacionContrasena('ana@test.local'),
        ).thenAnswer((_) async {});
        controller = AuthController(
          authService: mockAuthService,
          tokenPush: FakeTokenPushPort(),
        );

        controller!.recuperarContrasena('ana@test.local');
        async.flushMicrotasks();

        // t = 0 s: deshabilitado con el máximo restante.
        expect(controller!.puedeReenviarCodigo, isFalse);
        expect(controller!.cooldownRestante, AuthController.cooldownReenvio);

        // t = 30 s: sigue deshabilitado y muestra 30 s restantes.
        async.elapse(const Duration(seconds: 30));
        expect(controller!.puedeReenviarCodigo, isFalse);
        expect(controller!.cooldownRestante, const Duration(seconds: 30));

        // t = 61 s: habilitado de nuevo.
        async.elapse(const Duration(seconds: 31));
        expect(controller!.puedeReenviarCodigo, isTrue);
        expect(controller!.cooldownRestante, Duration.zero);

        // Regla de duración: ningún timer periódico vivo tras dispose().
        controller!.dispose();
        controller = null;
        expect(async.periodicTimerCount, 0);
      });
    });

    // ERR-07 escenario 2 + ERR-02: el rechazo `over_email_send_rate_limit`
    // del servidor debe arrancar el cooldown además de mostrar el banner
    // mapeado en español (server-driven).
    // RED: hoy el path de error de `recuperarContrasena` no inicia cooldown.
    test(
      'rate-limit del servidor muestra copy de espera y arranca el cooldown',
      () {
        fakeAsync((async) {
          when(
            () =>
                mockAuthService.enviarRecuperacionContrasena('ana@test.local'),
          ).thenAnswer(
            (_) async => throw const AuthException(
              'Email rate limit exceeded (over_email_send_rate_limit)',
            ),
          );
          controller = AuthController(
            authService: mockAuthService,
            tokenPush: FakeTokenPushPort(),
          );

          controller!.recuperarContrasena('ana@test.local');
          async.flushMicrotasks();

          // Banner mapeado (ERR-02): copy de espera en español, sin token crudo.
          expect(
            controller!.errorMessage,
            'Espera un momento antes de solicitar otro correo.',
          );
          // Y el cooldown queda corriendo (ERR-07 escenario 2).
          expect(controller!.puedeReenviarCodigo, isFalse);
          expect(controller!.cooldownRestante, AuthController.cooldownReenvio);

          controller!.dispose();
          controller = null;
          expect(async.periodicTimerCount, 0);
        });
      },
    );
  });
}
