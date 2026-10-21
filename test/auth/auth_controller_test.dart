// auth_controller_test.dart — Tests unitarios de AuthController (mocktail).
//
// Fase 1 del cambio mejoras-login: seam de inyección TDD-02.
// El controlador se construye con un AuthService doble; ninguna llamada
// real a Supabase/Firebase debe ocurrir (TDD-06 se completa en 1.7/1.8).

import 'package:aplicacion/domain/controllers/auth_controller.dart';
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

  group('login', () {
    // TDD-02, escenario "Red first": el controlador DEBE poder construirse con
    // un AuthService inyectado y login() delega en él (verify en el doble),
    // sin tocar Supabase real.
    test('delega en el AuthService inyectado (seam TDD-02)', () async {
      final perfil = buildUsuarioModel();
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => perfil);
      controller = AuthController(authService: mockAuthService);

      await controller!.login('ana@test.local', 'secreto123');

      verify(
        () => mockAuthService.signIn(
          correo: 'ana@test.local',
          password: 'secreto123',
        ),
      ).called(1);
      expect(controller!.currentUser, same(perfil));
    });

    // TDD-06, escenario "Suite runs offline" + DES-DP-1(a): el login exitoso
    // NO debe depender de FcmService.instance (Firebase no está inicializado
    // offline y su singleton lanza [core/no-app]).
    // RED: hoy login() llama a FcmService.instance.guardarToken(...) directo →
    // el throw cae en el catch genérico → login devuelve false, deja
    // errorMessage y jamás invoca el puerto (verify: 0 llamadas).
    test('login exitoso delega el token FCM en el puerto (TDD-06)', () async {
      final perfil = buildUsuarioModel();
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => perfil);
      final fakeTokenPush = FakeTokenPushPort();
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: fakeTokenPush,
      );

      final resultado = await controller!.login('ana@test.local', 'secreto123');

      expect(resultado, isTrue);
      expect(controller!.errorMessage, isNull);
      // El fake registra las llamadas: verify() de mocktail no aplica a un
      // fake (solo a Mocks), se aserta sobre el estado grabado.
      expect(fakeTokenPush.llamadasGuardar, ['uid-test-001']);
    });
  });

  // ── 1.9 BASELINE (Baseline Protocol) ──────────────────────────────────────
  // Comportamiento actual de AuthController: son guardas de regresión para la
  // Fase 2+ y deben PASAR A LA PRIMERA contra la lógica sin modificar.
  group('baseline de comportamiento (1.9)', () {
    test('login exitoso establece el perfil y termina loading', () async {
      final perfil = buildUsuarioModel();
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => perfil);
      final fakeTokenPush = FakeTokenPushPort();
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: fakeTokenPush,
      );

      final resultado = await controller!.login('ana@test.local', 'secreto123');

      expect(resultado, isTrue);
      expect(controller!.currentUser, same(perfil));
      expect(controller!.isLoading, isFalse);
      expect(controller!.errorMessage, isNull);
    });

    test('login fallido mapea credenciales inválidas al español', () async {
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {
        throw AuthException('Invalid login credentials');
      });
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: FakeTokenPushPort(),
      );

      final resultado = await controller!.login('ana@test.local', 'mala');

      expect(resultado, isFalse);
      expect(controller!.errorMessage, 'Correo o contraseña incorrectos.');
      expect(controller!.isLoading, isFalse);
      expect(controller!.currentUser, isNull);
    });

    test('cancelar Google no deja errorMessage (silencioso)', () async {
      when(() => mockAuthService.signInWithGoogle()).thenAnswer((_) async {
        throw Exception('Inicio de sesión con Google cancelado por el usuario');
      });
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: FakeTokenPushPort(),
      );

      final resultado = await controller!.loginWithGoogle();

      expect(resultado, isFalse);
      expect(controller!.errorMessage, isNull);
      expect(controller!.isLoading, isFalse);
    });

    test('logout resetea estado, limpia el token y notifica', () async {
      final perfil = buildUsuarioModel();
      final fakeTokenPush = FakeTokenPushPort();
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: fakeTokenPush,
      );

      // Sembrar errorMessage con un login fallido…
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {
        throw AuthException('Invalid login credentials');
      });
      await controller!.login('ana@test.local', 'mala');
      expect(controller!.errorMessage, isNotNull);

      // …y luego iniciar sesión con éxito: currentUser activo y, en la Fase 1,
      // el error persiste (el clear-on-start llega en una tarea posterior).
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => perfil);
      await controller!.login('ana@test.local', 'secreto123');
      expect(controller!.currentUser, same(perfil));
      expect(controller!.errorMessage, isNotNull);

      when(() => mockAuthService.signOut()).thenAnswer((_) async {});
      var notificaciones = 0;
      controller!.addListener(() => notificaciones++);

      await controller!.logout();

      expect(controller!.currentUser, isNull);
      expect(controller!.errorMessage, isNull);
      expect(notificaciones, 1);
      expect(fakeTokenPush.llamadasLimpiar, ['uid-test-001']);
      verify(() => mockAuthService.signOut()).called(1);
    });

    test('tryRestoreSession con sesión activa restaura el perfil', () async {
      final perfil = buildUsuarioModel();
      when(() => mockAuthService.getCurrentUserId()).thenReturn('uid-test-001');
      when(
        () => mockAuthService.getUserProfile(any()),
      ).thenAnswer((_) async => perfil);
      final fakeTokenPush = FakeTokenPushPort();
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: fakeTokenPush,
      );
      expect(controller!.isInitializing, isTrue); // arranque en splash

      await controller!.tryRestoreSession();

      expect(controller!.currentUser, same(perfil));
      expect(controller!.isInitializing, isFalse);
      expect(fakeTokenPush.llamadasGuardar, ['uid-test-001']);
    });

    test(
      'tryRestoreSession sin sesión termina el splash sin usuario',
      () async {
        when(() => mockAuthService.getCurrentUserId()).thenReturn(null);
        controller = AuthController(
          authService: mockAuthService,
          tokenPush: FakeTokenPushPort(),
        );

        await controller!.tryRestoreSession();

        expect(controller!.currentUser, isNull);
        expect(controller!.isInitializing, isFalse);
      },
    );
  });
}
