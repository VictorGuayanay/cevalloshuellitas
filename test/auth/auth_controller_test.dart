// auth_controller_test.dart — Tests unitarios de AuthController (mocktail).
//
// Fase 1 del cambio mejoras-login: seam de inyección TDD-02.
// El controlador se construye con un AuthService doble; ninguna llamada
// real a Supabase/Firebase debe ocurrir (TDD-06 se completa en 1.7/1.8).

import 'dart:io';

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
      // Higiene (sancionada): fake inyectado — el default FcmTokenPushAdapter
      // tocaba FcmService.instance offline y dejaba ruido [core/no-app].
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: FakeTokenPushPort(),
      );

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

      // …y luego iniciar sesión con éxito: currentUser activo y, desde la
      // Fase 3 (ERR-01, tarea 3.7), el banner anterior queda limpio al
      // entrar — el error no sobrevive al nuevo intento.
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => perfil);
      await controller!.login('ana@test.local', 'secreto123');
      expect(controller!.currentUser, same(perfil));
      expect(controller!.errorMessage, isNull);

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

  group('ERR-01 — el error obsoleto se limpia al iniciar la operación', () {
    // ERR-01 escenario "Error does not survive a new attempt" +
    // escenario "Google cancel leaves no residue": el banner anterior debe
    // estar en null de FORMA SÍNCRONA al entrar a cualquier operación.
    // RED: hoy nada limpia al inicio → el error viejo persiste en la entrada.
    test(
      'el error previo no sobrevive a un intento nuevo ni a Google',
      () async {
        controller = AuthController(
          authService: mockAuthService,
          tokenPush: FakeTokenPushPort(),
        );

        // GIVEN un login fallido dejó errorMessage visible.
        when(
          () => mockAuthService.signIn(
            correo: any(named: 'correo'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => throw AuthException('Invalid login credentials'),
        );
        expect(await controller!.login('ana@test.local', 'mala'), isFalse);
        expect(controller!.errorMessage, isNotNull); // precondición ERR-01

        // WHEN se invoca de nuevo (cualquier outcome) —
        // THEN en el MOMENTO de la entrada el banner ya está limpio.
        when(
          () => mockAuthService.signIn(
            correo: any(named: 'correo'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => throw AuthException('Email not confirmed'));
        final reintento = controller!.login('ana@test.local', 'secreto123');
        expect(controller!.errorMessage, isNull); // ← assert de entrada (RED)
        expect(await reintento, isFalse);
        // THEN después: el MENSAJE NUEVO mapeado (o null si hubo éxito).
        expect(
          controller!.errorMessage,
          'Debes confirmar tu correo electrónico.',
        );

        // GIVEN el banner muestra el error del reintento…
        expect(controller!.errorMessage, isNotNull);
        // WHEN el usuario prueba Google y cancela el selector.
        when(() => mockAuthService.signInWithGoogle()).thenAnswer(
          (_) async => throw Exception(
            'Inicio de sesión con Google cancelado por el usuario',
          ),
        );
        final google = controller!.loginWithGoogle();
        expect(controller!.errorMessage, isNull); // ← entrada limpia (RED)
        expect(await google, isFalse);
        // THEN sin residuo: la cancelación sigue siendo silenciosa.
        expect(controller!.errorMessage, isNull);
      },
    );
  });

  // ── AMD-2026-10-23-02 — BUG 1: fallo de Google punta a punta ──────────────
  group('ERR-05 / AMD-2026-10-23-02 — fallo Google mapeado', () {
    // AMD-2026-10-23-02 scenario "Google platform error maps to actionable
    // Spanish copy" + scenario "Wrapper-prefixed stage errors are
    // distinguishable" en su forma REAL: el servicio siempre prefija la etapa
    // ('Error al abrir Google: $e') e interpola el PlatformException crudo.
    // Pin del contrato end-to-end: loginWithGoogle() devuelve false y el
    // banner recibe el copy accionable de la etapa — NUNCA el fallback ni
    // el texto crudo (ERR-06).
    // RED (verify-only GREEN): el mapper aún no conoce el prefijo de etapa
    // → cae al genérico; el GREEN llega con las ramas de la 11.2.
    test(
      'wrapper de etapa con ApiException: 10 produce copy accionable, no fallback',
      () async {
        when(() => mockAuthService.signInWithGoogle()).thenAnswer(
          (_) async => throw Exception(
            'Error al abrir Google: '
            'PlatformException(sign_in_failed, ApiException: 10, null)',
          ),
        );
        controller = AuthController(
          authService: mockAuthService,
          tokenPush: FakeTokenPushPort(),
        );

        final resultado = await controller!.loginWithGoogle();

        expect(resultado, isFalse);
        expect(
          controller!.errorMessage,
          'No se pudo abrir el selector de cuentas de Google. '
          'Revisa Google Play Services e inténtalo de nuevo.',
        );
        expect(
          controller!.errorMessage,
          isNot('Ocurrió un error. Intenta de nuevo.'),
        );
        expect(controller!.isLoading, isFalse);
      },
    );
  });

  group('ERR-06 — lint de seguridad sobre el pipeline del controlador', () {
    // ERR-06 escenario "Security lint on the mapping": fallos crudos
    // representativos (red, SQL, wrappers que interpolan $e) pasados por las
    // operaciones DEL CONTROLADOR deben producir mensajes de la allowlist
    // en español — jamás texto crudo.
    // RED: hoy los catch() del controlador interpolan $e (denylist hit).
    test('ningún fallo crudo produce texto prohibido en errorMessage', () async {
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: FakeTokenPushPort(),
      );

      // Allowlist: el conjunto FINJO de mensajes que la UI puede mostrar
      // (espejo de las ramas de AuthErrorMapper — AMD-2026-10-23-02 añade
      // las 4 copias accionables de Google).
      final permitido = RegExp(
        r'^(Ocurrió un error\. Intenta de nuevo\.|'
        r'Correo o contraseña incorrectos\.|'
        r'Este correo ya está registrado\.|'
        r'La contraseña debe tener al menos 6 caracteres\.|'
        r'Debes confirmar tu correo electrónico\.|'
        r'Espera un momento antes de solicitar otro correo\.|'
        r'Quedan \d+ intentos antes de bloquear la cuenta\.|'
        r'Sin conexión a internet\. Revisa tu conexión y vuelve a intentarlo\.|'
        r'No se pudo iniciar sesión con Google\. '
        r'Verifica el Web Client ID \(tipo Aplicación web\)\.|'
        r'No se pudo iniciar sesión con Google\. '
        r'Verifica tu cuenta en el dispositivo o contacta al '
        r'administrador\.|'
        r'No se pudo abrir el selector de cuentas de Google\. '
        r'Revisa Google Play Services e inténtalo de nuevo\.|'
        r'No se pudo verificar tu cuenta de Google\. '
        r'Cierra la sesión de Google en tu dispositivo y vuelve a '
        r'intentarlo\.|'
        r'La cuenta de Google fue verificada, pero el servidor no '
        r'autorizó el inicio de sesión\. Vuelve a intentarlo en unos '
        r'minutos\.|'
        r'No encontramos tu perfil\. Contacta al administrador\.)$',
      );
      final denylist = RegExp(
        r'Exception|SocketException|Postgrest|Error inesperado|attempt\(|'
        r'rate limit|over_email_send',
      );

      final tabla = <String, Future<bool> Function()>{
        'login con fallo de red crudo': () {
          when(
            () => mockAuthService.signIn(
              correo: any(named: 'correo'),
              password: any(named: 'password'),
            ),
          ).thenAnswer(
            (_) async => throw const SocketException(
              "Failed host lookup: 'xxxx.supabase.co' (errno = -2)",
            ),
          );
          return controller!.login('ana@test.local', 'secreto123');
        },
        'register con error SQL crudo': () {
          when(
            () => mockAuthService.signUp(
              nombre: 'Ana Torres',
              correo: 'ana@test.local',
              password: 'secreto123',
              telefono: null,
              rol: 'usuario',
            ),
          ).thenAnswer(
            (_) async => throw const PostgrestException(
              message: 'relation "usuarios" does not exist',
              code: '42P01',
            ),
          );
          return controller!.register(
            nombre: 'Ana Torres',
            correo: 'ana@test.local',
            password: 'secreto123',
          );
        },
        r'loginWithGoogle con wrapper que interpola \$e': () {
          when(() => mockAuthService.signInWithGoogle()).thenAnswer(
            (_) async => throw Exception(
              'Error autenticando en Supabase con Google: '
              'AuthException(message: SQLSTATE 23505, statusCode: 409)',
            ),
          );
          return controller!.loginWithGoogle();
        },
      };

      for (final caso in tabla.entries) {
        expect(await caso.value(), isFalse, reason: 'caso: ${caso.key}');
        final mensaje = controller!.errorMessage;
        expect(mensaje, isNotNull, reason: 'caso: ${caso.key}');
        expect(
          permitido.hasMatch(mensaje!),
          isTrue,
          reason: 'allowlist violada en "${caso.key}": $mensaje',
        );
        expect(
          denylist.hasMatch(mensaje),
          isFalse,
          reason: 'denylist violada en "${caso.key}": $mensaje',
        );
      }
    });
  });

  // ── 11.5 — AMD-2026-10-23-01 (ERR-01): limpiarError() ──────────────────────
  // Escenario "Error cleared when entering register screen" (mitad controlador):
  //   GIVEN un login fallido dejó errorMessage poblado,
  //   WHEN la pantalla de registro invoca limpiarError() (choke point),
  //   THEN errorMessage queda null Y los listeners son notificados.
  group('limpiarError (11.5 / AMD-2026-10-23-01)', () {
    test('un error dejado por un login fallido se limpia y notifica', () async {
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => throw const AuthException('Invalid login credentials'),
      );
      final fakeTokenPush = FakeTokenPushPort();
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: fakeTokenPush,
      );

      // GIVEN el login falló y dejó el mensaje de error poblado
      final resultado = await controller!.login('ana@test.local', 'mala');
      expect(resultado, isFalse);
      expect(controller!.errorMessage, isNotNull);

      // WHEN invocan limpiarError() (lo hará initState de RegisterScreen)
      var notifico = false;
      controller!.addListener(() => notifico = true);
      controller!.limpiarError();

      // THEN el error queda limpio y los listeners fueron notificados
      expect(
        controller!.errorMessage,
        isNull,
        reason: 'limpiarError() debe descartar el banner heredado (ERR-01)',
      );
      expect(notifico, isTrue, reason: 'limpiarError() debe notificar');
    });
  });
}
