// mocks.dart — Dobles de prueba para el módulo de autenticación.
//
// Fase 1 del cambio mejoras-login. Usa mocktail (DP-3), sin codegen.
// Los tests de test/auth/ importan este archivo como 'mocks.dart'.
//
// Nota: FakeTokenPushPort se agregará aquí en la tarea 1.7 (seam TokenPushPort),
// cuando la interfaz lib/core/token_push_port.dart exista.

import 'dart:async';

import 'package:aplicacion/core/token_push_port.dart';
import 'package:aplicacion/data/models/usuario_model.dart';
import 'package:aplicacion/data/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Doble de AuthService para inyectar en AuthController (TDD-02/TDD-04).
class MockAuthService extends Mock implements AuthService {}

/// Puerto falso para el efecto push de FCM (DES-DP-1(a), TDD-06):
/// registra las llamadas para poder verificarlas y JAMÁS toca
/// FcmService.instance ni Firebase (determinismo offline).
class FakeTokenPushPort implements TokenPushPort {
  final llamadasGuardar = <String>[];
  final llamadasLimpiar = <String>[];

  @override
  Future<void> guardarToken(String userId) async {
    llamadasGuardar.add(userId);
  }

  @override
  Future<void> limpiarToken(String userId) async {
    llamadasLimpiar.add(userId);
  }
}

// ── Dobles para el seam de cliente Supabase de AuthService (TDD-03) ─────────

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<PostgrestList> {}

class MockPostgrestTransformBuilder extends Mock
    implements PostgrestTransformBuilder<PostgrestMap> {}

/// Stubea `then()` sobre un builder Postgrest simulado de `.single()`.
///
/// Verificado en postgrest 2.7.2: `PostgrestBuilder` (con sus tres
/// parámetros de tipo) `implementa Future`, por lo que `await builder`
/// invoca `then(onValue, onError:)`. Este helper hace que ese await
/// resuelva con [respuesta] sin red.
/// El caller debe registrar en `setUpAll` un fallback para el tipo
/// funcional de `onValue`:
/// `registerFallbackValue((Map<String, dynamic> value) => value);`
void stubPostgrestSingle(
  MockPostgrestTransformBuilder builder, {
  required Map<String, dynamic> respuesta,
}) {
  // Calibrado con sonda aislada: `await builder` invoca
  // then<dynamic>(onValue, onError:) y la reanudación SOLO ocurre cuando
  // onValue se invoca — el await no consume el Future que then devuelve.
  when(
    () => builder.then<dynamic>(any(), onError: any(named: 'onError')),
  ).thenAnswer((invocation) {
    final onValue =
        invocation.positionalArguments.first
            as FutureOr<dynamic> Function(Map<String, dynamic>);
    return Future<dynamic>(() => onValue(respuesta));
  });
}

/// Builder de [User] de Supabase Auth (gotrue) para armar [AuthResponse]
/// en los stubs de signInWithPassword / signUp.
User buildAuthUser({
  String id = 'uid-test-001',
  String email = 'ana@test.local',
}) {
  return User(
    id: id,
    appMetadata: const <String, dynamic>{},
    userMetadata: const <String, dynamic>{},
    aud: 'authenticated',
    email: email,
    createdAt: '2026-01-01T00:00:00.000Z',
  );
}

/// Builder de UsuarioModel con valores por defecto, para stubs de
/// signIn / getUserProfile / signUp en los tests.
UsuarioModel buildUsuarioModel({
  String id = 'uid-test-001',
  String nombre = 'Ana Torres',
  String correo = 'ana@test.local',
  String? telefono = '0991000000',
  String rol = 'usuario',
}) {
  return UsuarioModel(
    id: id,
    nombre: nombre,
    correo: correo,
    telefono: telefono,
    rol: rol,
  );
}
