// restablecer_contrasena_test.dart — Tests de restablecerContrasena (RST-11).
//
// RST-11/RST-DP-2(a): restablecerContrasena invoca updateUser → signOut silencioso.
// RED stub-first: el método no existe hasta la implementación.

import 'dart:async';

import 'package:aplicacion/domain/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mocks.dart';

/// Fuente de eventos de auth simulada (copia de auth_session_events_test.dart).
class _FuenteAuthEvents {
  _FuenteAuthEvents() {
    eventos = StreamController<AuthState>.broadcast(
      onCancel: () => cancelado = true,
    );
    stream = Stream<AuthState>.multi((node) {
      final sub = eventos.stream.listen(
        node.addSync,
        onError: node.addErrorSync,
        onDone: node.closeSync,
      );
      node.onCancel = () => sub.cancel();
    });
  }

  late final StreamController<AuthState> eventos;
  late final Stream<AuthState> stream;
  bool cancelado = false;

  Future<void> emitir(AuthState state) async {
    eventos.add(state);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> cerrar() => eventos.close();
}

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

  group('restablecerContrasena (RST-11)', () {
    // Éxito: updateUser → signOut (orden verificado), flag false, retorna true.
    test(
      'éxito: invoca updateUser, luego signOut silencioso, limpia flag',
      () async {
        when(
          () => mockAuthService.restablecerContrasena('nueva123'),
        ).thenAnswer((_) async {});
        when(() => mockAuthService.signOut()).thenAnswer((_) async {});

        final fakeTokenPush = FakeTokenPushPort();
        controller = AuthController(
          authService: mockAuthService,
          tokenPush: fakeTokenPush,
        );

        // Pre-seteamos el flag enModoRecuperacion=true emitiendo passwordRecovery.
        final fuente = _FuenteAuthEvents();
        when(() => mockAuthService.authStates).thenAnswer((_) => fuente.stream);
        controller!.initAuthListener();
        await fuente.emitir(
          AuthState(
            AuthChangeEvent.passwordRecovery,
            Session(
              accessToken: 'recovery-token',
              tokenType: 'bearer',
              user: buildAuthUser(id: 'uid-test-001'),
            ),
          ),
        );
        expect(controller!.enModoRecuperacion, isTrue);
        await fuente.cerrar();

        // Usamos una secuencia de verificación manual para el orden:
        var orden = <String>[];
        when(
          () => mockAuthService.restablecerContrasena('nueva123'),
        ).thenAnswer((_) async => orden.add('update'));
        when(
          () => mockAuthService.signOut(),
        ).thenAnswer((_) async => orden.add('signOut'));

        final resultado = await controller!.restablecerContrasena('nueva123');

        expect(resultado, isTrue);
        expect(orden, ['update', 'signOut']);
        expect(controller!.enModoRecuperacion, isFalse);
        // signOut silencioso: errorMessage debe ser null (no mensaje de expiración)
        expect(controller!.errorMessage, isNull);
      },
    );

    // Fallo del servicio: errorMessage mapeado (AuthSessionMissingException →
    // mensajeSesionRecuperacionExpirada), signOut NO invocado, retorna false.
    test(
      'fallo del servicio: errorMessage mapeado, sin signOut, retorna false',
      () async {
        when(
          () => mockAuthService.restablecerContrasena('nueva123'),
        ).thenThrow(AuthSessionMissingException());
        when(() => mockAuthService.signOut()).thenAnswer((_) async {});

        final fakeTokenPush = FakeTokenPushPort();
        controller = AuthController(
          authService: mockAuthService,
          tokenPush: fakeTokenPush,
        );

        // Pre-seteamos el flag enModoRecuperacion=true.
        final fuente = _FuenteAuthEvents();
        when(() => mockAuthService.authStates).thenAnswer((_) => fuente.stream);
        controller!.initAuthListener();
        await fuente.emitir(
          AuthState(
            AuthChangeEvent.passwordRecovery,
            Session(
              accessToken: 'recovery-token',
              tokenType: 'bearer',
              user: buildAuthUser(id: 'uid-test-001'),
            ),
          ),
        );
        expect(controller!.enModoRecuperacion, isTrue);
        await fuente.cerrar();

        final resultado = await controller!.restablecerContrasena('nueva123');

        expect(resultado, isFalse);
        expect(
          controller!.errorMessage,
          'Tu sesión de recuperación expiró. Solicita un enlace nuevo.',
        );
        verifyNever(() => mockAuthService.signOut());
        // Flag debe seguir true (no se limpió porque falló)
        expect(controller!.enModoRecuperacion, isTrue);
      },
    );

    // ERR-01: errorMessage limpio al inicio de la operación.
    test(
      'ERR-01: errorMessage se limpia al entrar (incluso si hay error previo)',
      () async {
        // GIVEN: un error previo en errorMessage.
        controller = AuthController(
          authService: mockAuthService,
          tokenPush: FakeTokenPushPort(),
        );
        controller!.limpiarError(); // asegurar estado limpio
        // Simular error previo invocando una operación que falle.
        when(
          () => mockAuthService.enviarRecuperacionContrasena(any()),
        ).thenAnswer(
          (_) async => throw AuthException('Invalid login credentials'),
        );
        await controller!.recuperarContrasena('ana@test.local');
        expect(controller!.errorMessage, isNotNull); // precondición

        // NOW: restablecerContrasena falla también → errorMessage NUEVO, no el viejo.
        when(
          () => mockAuthService.restablecerContrasena('nueva123'),
        ).thenThrow(AuthSessionMissingException());
        when(() => mockAuthService.signOut()).thenAnswer((_) async {});

        final resultado = await controller!.restablecerContrasena('nueva123');

        expect(resultado, isFalse);
        // ERR-01: al ENTRAR a restablecerContrasena, errorMessage se limpia.
        // El mensaje final debe ser el NUEVO mapeado, no el anterior.
        expect(controller!.errorMessage, isNotNull);
        expect(
          controller!.errorMessage,
          isNot('Correo o contraseña incorrectos.'),
        );
        expect(
          controller!.errorMessage,
          'Tu sesión de recuperación expiró. Solicita un enlace nuevo.',
        );
      },
    );
  });
}
