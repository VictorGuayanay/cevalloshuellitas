// auth_service_test.dart — Tests unitarios de AuthService (mocktail).
//
// Fase 1 del cambio mejoras-login: seam de cliente Supabase TDD-03.
// El servicio se construye con un SupabaseClient doble; si llegara a
// tocar Supabase.instance el test fallaría (singleton sin inicializar).

import 'package:aplicacion/data/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mocks.dart';

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late MockSupabaseQueryBuilder mockQueryBuilder;
  late MockPostgrestFilterBuilder mockFilterBuilder;
  late MockPostgrestTransformBuilder mockTransformBuilder;

  setUpAll(() {
    // PostgrestBuilder implementa Future: 'await' llama a then(onValue).
    // any() sobre ese callback exige un fallback con el mismo tipo funcional.
    registerFallbackValue((Map<String, dynamic> value) => value);
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockQueryBuilder = MockSupabaseQueryBuilder();
    mockFilterBuilder = MockPostgrestFilterBuilder();
    mockTransformBuilder = MockPostgrestTransformBuilder();
    when(() => mockClient.auth).thenReturn(mockAuth);
  });

  group('signIn', () {
    // TDD-03, escenario "Red first": el servicio DEBE poder construirse con
    // un SupabaseClient inyectado y la consulta de perfil debe recorrer el
    // doble inyectado (cero acceso a Supabase.instance).
    test('lee el perfil a través del cliente inyectado (seam TDD-03)', () async {
      when(
        () => mockAuth.signInWithPassword(
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          password: any(named: 'password'),
          captchaToken: any(named: 'captchaToken'),
        ),
      ).thenAnswer((_) async => AuthResponse(user: buildAuthUser()));

      // Los builders Postgrest implementan Future → mocktail exige thenAnswer.
      when(
        () => mockClient.from('usuarios'),
      ).thenAnswer((_) => mockQueryBuilder);
      when(
        () => mockQueryBuilder.select(any()),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.eq('usua_id', any()),
      ).thenAnswer((_) => mockFilterBuilder);
      when(
        () => mockFilterBuilder.single(),
      ).thenAnswer((_) => mockTransformBuilder);
      stubPostgrestSingle(
        mockTransformBuilder,
        respuesta: const <String, dynamic>{
          'usua_id': 'uid-test-001',
          'usua_nombre': 'Ana Torres',
          'usua_correo': 'ana@test.local',
          'usua_telefono': '0991000000',
          'usua_rol': 'usuario',
        },
      );

      final servicio = AuthService(client: mockClient);

      final perfil = await servicio.signIn(
        correo: 'ana@test.local',
        password: 'secreto123',
      );

      // La consulta de perfil recorrió el doble inyectado, sin singleton.
      verify(
        () => mockAuth.signInWithPassword(
          email: 'ana@test.local',
          phone: null,
          password: 'secreto123',
          captchaToken: null,
        ),
      ).called(1);
      verify(() => mockClient.from('usuarios')).called(1);
      expect(perfil.id, 'uid-test-001');
      expect(perfil.nombre, 'Ana Torres');
      expect(perfil.rol, 'usuario');
    });
  });
}
