// register_screen_test.dart — Pantalla de registro (ERR-01 /
// AMD-2026-10-23-01 · cambio mejoras-login).
//
// Pumps el RegisterScreen REAL con un AuthController cuyo errorMessage
// quedó poblado por un login fallido: al entrar, el initState (choke
// point único) debe limpiarlo, de modo que el banner obsoleto heredado
// del login NUNCA se renderice en la pantalla de registro.

import 'package:aplicacion/domain/controllers/auth_controller.dart';
import 'package:aplicacion/presentation/screens/login/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late AuthController controller;

  setUpAll(() {
    // Sin fetching en tests: google_fonts no debe hacer HTTP al pintar.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    mockAuthService = MockAuthService();
    controller = AuthController(
      authService: mockAuthService,
      tokenPush: FakeTokenPushPort(),
    );
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets(
    'el banner de un login fallido NO se renderiza al entrar en registro (ERR-01)',
    (tester) async {
      // GIVEN un login fallido dejó errorMessage poblado en el controlador
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => throw const AuthException('Invalid login credentials'),
      );
      await controller.login('ana@test.local', 'mala');
      const mensaje = 'Correo o contraseña incorrectos.';
      expect(controller.errorMessage, isNotNull);

      // GIVEN el árbol raíz ya está construido (provider ARRIBA de
      // MaterialApp, como en lib/main.dart): la pantalla de registro se
      // alcanza por Navigator.push desde el login — initState corre durante
      // el push, nunca durante la inflación inicial del árbol.
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: const MaterialApp(home: Scaffold(body: SizedBox())),
        ),
      );
      await tester.pumpAndSettle();

      // WHEN el usuario navega a la pantalla de registro (initState)
      final loginContext = tester.element(find.byType(Scaffold));
      Navigator.of(
        loginContext,
      ).push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
      await tester.pumpAndSettle();

      // THEN el banner heredado no se renderiza (el choke point lo limpió)
      expect(
        find.text(mensaje),
        findsNothing,
        reason:
            'el banner de un error previo no debe sobrevivir al '
            'initState de RegisterScreen (AMD-2026-10-23-01)',
      );
      expect(
        controller.errorMessage,
        isNull,
        reason: 'initState debe invocar limpiarError() (choke point único)',
      );

      // Limpieza: desmontar el árbol — el provider .value no dispone el
      // controlador (lo dispone el tearDown del grupo).
      await tester.pumpWidget(const SizedBox());
    },
  );
}
