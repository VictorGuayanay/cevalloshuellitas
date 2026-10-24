// auth_session_events_test.dart — Tests del listener global de sesión (S2).
//
// SES-01…SES-07 del cambio mejoras-login: la fuente de eventos se simula con
// `StreamController<AuthState>` inyectado vía `AuthService.authStates`
// (seam de diseño) — sin Supabase real (TDD-06 offline).

import 'dart:async';

import 'package:aplicacion/domain/controllers/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mocks.dart';

/// Fuente de eventos de auth simulada e instrumentada:
/// cuenta escuchas y cancelaciones, y permite emitir eventos.
class _FuenteAuthEvents {
  _FuenteAuthEvents() {
    eventos = StreamController<AuthState>.broadcast(
      onCancel: () => cancelado = true,
    );
    // Cada `listen()` sobre el stream expuesto dispara [escuchas]++ — permite
    // assertar "exactamente UNA suscripción" aunque se llame 2 veces al seam.
    stream = Stream<AuthState>.multi((node) {
      escuchas++;
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
  int escuchas = 0;
  bool cancelado = false;

  /// Emite [state] y drena la cola de micro-tasks hasta entregarlo.
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

  group('SES-01 — suscripción reactiva', () {
    // SES-01 escenario "Single subscription lifecycle".
    // RED sancionado DP-T1 (seam): no compila hasta que existan
    // `AuthService.authStates` y `AuthController.initAuthListener()`.
    test(
      'initAuthListener registra UNA suscripción y la cancela en dispose',
      () async {
        final fuente = _FuenteAuthEvents();
        when(() => mockAuthService.authStates).thenAnswer(
          (_) => fuente.stream,
        ); // mocktail exige thenAnswer p/ Stream
        controller = AuthController(
          authService: mockAuthService,
          tokenPush: FakeTokenPushPort(),
        );

        controller!.initAuthListener();
        controller!.initAuthListener(); // idempotencia requerida (SES-01)

        expect(fuente.escuchas, 1);

        controller!.dispose();
        controller = null; // ya disposed: el tearDown no debe repetirlo
        await Future<void>.delayed(Duration.zero);

        expect(fuente.cancelado, isTrue); // sin fugas (SES-01)
        await fuente.cerrar();
      },
    );
  });

  group('SES-02 — pérdida remota de sesión', () {
    // SES-02 escenario "Session revoked while using the app" (la mitad RED de
    // SES-01 "Red first"): tras un login exitoso, un `signedOut` remoto DEBE
    // limpiar el estado, dejar el mensaje de sesión y notificar a los listeners.
    // RED: el handler actual es no-op → el estado no cambia.
    test('signedOut remoto limpia estado y notifica', () async {
      final perfil = buildUsuarioModel();
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => perfil);
      final fuente = _FuenteAuthEvents();
      when(() => mockAuthService.authStates).thenAnswer((_) => fuente.stream);
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: FakeTokenPushPort(),
      );
      await controller!.login('ana@test.local', 'secreto123');
      expect(controller!.currentUser, same(perfil)); // precondición SES-02

      controller!.initAuthListener();
      var notificaciones = 0;
      controller!.addListener(() => notificaciones++);

      await fuente.emitir(const AuthState(AuthChangeEvent.signedOut, null));

      expect(controller!.currentUser, isNull);
      expect(
        controller!.errorMessage,
        'Tu sesión ha expirado. Inicia sesión de nuevo.',
      );
      expect(notificaciones, greaterThan(0));
      await fuente.cerrar();
    });

    // DP-P2-1 (opción a): el aviso de cierre es consume-once y de lector
    // único — el Consumer raíz lo lee como PRIMERA línea y programa el
    // reset de pila (post-frame, sólo si canPop()). Baseline: el
    // comportamiento se implementó en 2.4; se registra aquí la guarda de
    // la semántica consume-once (protocolo baseline de sdd-testing).
    test('consumirAvisoDeCierre entrega el aviso una sola vez', () async {
      final fuente = _FuenteAuthEvents();
      when(() => mockAuthService.authStates).thenAnswer((_) => fuente.stream);
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: FakeTokenPushPort(),
      );
      controller!.initAuthListener();

      expect(controller!.consumirAvisoDeCierre(), isFalse); // sin eventos

      await fuente.emitir(const AuthState(AuthChangeEvent.signedOut, null));

      expect(controller!.consumirAvisoDeCierre(), isTrue); // primera lectura
      expect(controller!.consumirAvisoDeCierre(), isFalse); // consume-once
      await fuente.cerrar();
    });
  });

  group('SES-03 — signedIn carga el perfil y expone el rol', () {
    // SES-03 escenario "Role-based routing after event": el Consumer raíz
    // decide AdminScreen/HomeScreen a partir de `currentUser.rol`.
    // RED: el handler no carga el perfil en el evento → currentUser null.
    test('signedIn expone el rol administrador y luego usuario', () async {
      final admin = buildUsuarioModel(
        id: 'uid-admin-001',
        rol: 'administrador',
      );
      final usuario = buildUsuarioModel(id: 'uid-user-002', rol: 'usuario');
      when(
        () => mockAuthService.getUserProfile(admin.id),
      ).thenAnswer((_) async => admin);
      when(
        () => mockAuthService.getUserProfile(usuario.id),
      ).thenAnswer((_) async => usuario);
      final fuente = _FuenteAuthEvents();
      when(() => mockAuthService.authStates).thenAnswer((_) => fuente.stream);
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: FakeTokenPushPort(),
      );
      controller!.initAuthListener();

      await fuente.emitir(
        AuthState(
          AuthChangeEvent.signedIn,
          Session(
            accessToken: 'token-test',
            tokenType: 'bearer',
            user: buildAuthUser(id: admin.id),
          ),
        ),
      );
      expect(controller!.currentUser, same(admin));
      expect(controller!.currentUser!.rol, 'administrador');

      await fuente.emitir(
        AuthState(
          AuthChangeEvent.signedIn,
          Session(
            accessToken: 'token-test',
            tokenType: 'bearer',
            user: buildAuthUser(id: usuario.id),
          ),
        ),
      );
      expect(controller!.currentUser, same(usuario));
      expect(controller!.currentUser!.rol, 'usuario');

      await fuente.cerrar();
    });

    // SES-03 escenario "Signed-in event for a user whose profile row is
    // missing" (PGRST116): no crash, no loop silencioso — estado recuperable.
    // RED: el handler sólo hace debugPrint → errorMessage sigue en null.
    test('signedIn sin fila de perfil deja estado recuperable', () async {
      const uidOrfan = 'uid-orfan-003';
      when(() => mockAuthService.getUserProfile(uidOrfan)).thenThrow(
        const PostgrestException(
          message: 'JSON object requested, multiple (or no) rows returned',
          code: 'PGRST116',
        ),
      );
      final fuente = _FuenteAuthEvents();
      when(() => mockAuthService.authStates).thenAnswer((_) => fuente.stream);
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: FakeTokenPushPort(),
      );
      controller!.initAuthListener();

      await fuente.emitir(
        AuthState(
          AuthChangeEvent.signedIn,
          Session(
            accessToken: 'token-test',
            tokenType: 'bearer',
            user: buildAuthUser(id: uidOrfan),
          ),
        ),
      );

      expect(controller!.currentUser, isNull);
      expect(
        controller!.errorMessage,
        isNotNull,
      ); // estado recuperable (SES-03)
      await fuente.cerrar();
    });
  });

  group('SES-04 — token refresh silencioso', () {
    // SES-04 escenario "No navigation churn on refresh".
    // NOTA (protocolo baseline sdd-testing): la premisa RED "el handler naive
    // re-fetcha" no aplica a este codebase — nunca existió un handler que
    // re-cargara el perfil en `tokenRefreshed` (cae en `default`). La prueba
    // pasa a la primera: se registra como guarda de regresión; forzar un RED
    // requeriría empeorar el código a propósito (anti-patrón L6).
    test('tokenRefreshed no muta estado ni re-carga perfil', () async {
      final perfil = buildUsuarioModel();
      var cargas = 0;
      when(() => mockAuthService.getUserProfile(perfil.id)).thenAnswer((
        _,
      ) async {
        cargas++;
        return perfil;
      });
      when(() => mockAuthService.getCurrentUserId()).thenAnswer((_) => null);
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => perfil);
      final fuente = _FuenteAuthEvents();
      when(() => mockAuthService.authStates).thenAnswer((_) => fuente.stream);
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: FakeTokenPushPort(),
      );
      // GIVEN un usuario autenticado en HomeScreen (splash ya terminó).
      await controller!.login('ana@test.local', 'secreto123');
      await controller!.tryRestoreSession();
      expect(controller!.isInitializing, isFalse);
      controller!.initAuthListener();
      final cargasTrasLogin = cargas;

      // WHEN se emiten varios tokenRefreshed.
      final sesion = Session(
        accessToken: 'token-test',
        tokenType: 'bearer',
        user: buildAuthUser(id: perfil.id),
      );
      await fuente.emitir(AuthState(AuthChangeEvent.tokenRefreshed, sesion));
      await fuente.emitir(AuthState(AuthChangeEvent.tokenRefreshed, sesion));

      // THEN sin churn: estado intacto, sin splash, perfil a lo sumo 1 fetch.
      expect(controller!.currentUser, same(perfil));
      expect(controller!.isInitializing, isFalse);
      expect(cargas - cargasTrasLogin, lessThanOrEqualTo(1));
      await fuente.cerrar();
    });
  });

  group('SES-05 — userUpdated refresca el perfil', () {
    // SES-05 escenario "Profile changed elsewhere": el perfil se edita en
    // otro dispositivo → el evento debe recargar `currentUser` desde la
    // fuente. RED: el handler lo ignora → queda el perfil viejo.
    test('userUpdated recarga el perfil desde la fuente', () async {
      final perfilViejo = buildUsuarioModel(nombre: 'Ana Torres');
      final perfilNuevo = buildUsuarioModel(nombre: 'Ana Torres Actualizada');
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => perfilViejo);
      when(
        () => mockAuthService.getUserProfile(perfilViejo.id),
      ).thenAnswer((_) async => perfilNuevo);
      final fuente = _FuenteAuthEvents();
      when(() => mockAuthService.authStates).thenAnswer((_) => fuente.stream);
      controller = AuthController(
        authService: mockAuthService,
        tokenPush: FakeTokenPushPort(),
      );
      // GIVEN una sesión autenticada con el perfil v1.
      await controller!.login('ana@test.local', 'secreto123');
      expect(controller!.currentUser!.nombre, 'Ana Torres');
      controller!.initAuthListener();

      // WHEN Supabase emite userUpdated (cambio hecho en otro dispositivo).
      await fuente.emitir(
        AuthState(
          AuthChangeEvent.userUpdated,
          Session(
            accessToken: 'token-test',
            tokenType: 'bearer',
            user: buildAuthUser(id: perfilViejo.id),
          ),
        ),
      );

      // THEN currentUser refleja el perfil actualizado.
      expect(controller!.currentUser!.nombre, 'Ana Torres Actualizada');
      await fuente.cerrar();
    });
  });

  group('SES-07 — initialSession no pelea con la restauración', () {
    // SES-07 escenario "Warm start with stored session": en frío,
    // `tryRestoreSession()` es la ÚNICA vía de carga (el replay de GoTrue a
    // nuevos suscriptores no debe duplicarla — sin doble save FCM); en
    // caliente, el replay con sesión y sin perfil sí debe cargarlo.
    // RED: la parte caliente falla — el handler ignora initialSession.
    test(
      'initialSession: ignorado en frío, carga perfil en caliente',
      () async {
        final perfil = buildUsuarioModel();
        var cargas = 0;
        when(() => mockAuthService.getUserProfile(perfil.id)).thenAnswer((
          _,
        ) async {
          cargas++;
          return perfil;
        });
        when(() => mockAuthService.getCurrentUserId()).thenAnswer((_) => null);
        final fuente = _FuenteAuthEvents();
        when(() => mockAuthService.authStates).thenAnswer((_) => fuente.stream);
        controller = AuthController(
          authService: mockAuthService,
          tokenPush: FakeTokenPushPort(),
        );
        controller!.initAuthListener();
        final sesion = Session(
          accessToken: 'token-test',
          tokenType: 'bearer',
          user: buildAuthUser(id: perfil.id),
        );

        // GIVEN arranque en frío: el splash todavía corre (isInitializing).
        expect(controller!.isInitializing, isTrue);
        // WHEN llega el initialSession del replay de GoTrue.
        await fuente.emitir(AuthState(AuthChangeEvent.initialSession, sesion));
        // THEN se ignora: tryRestoreSession es la única vía en frío.
        expect(cargas, 0);
        expect(controller!.currentUser, isNull);

        // WHEN termina la restauración (splash descartado) y llega otro
        // initialSession en caliente (replay a un suscriptor nuevo).
        await controller!.tryRestoreSession();
        expect(controller!.isInitializing, isFalse);
        await fuente.emitir(AuthState(AuthChangeEvent.initialSession, sesion));
        // THEN el perfil se carga EXACTAMENTE una vez (sin doble carga).
        expect(cargas, 1);
        expect(controller!.currentUser, same(perfil));
        await fuente.cerrar();
      },
    );
  });
}
