// recovery_cooldown_ui_test.dart — UI del banner de error y del cooldown
// (ERR-01 / ERR-07 · cambio mejoras-login).
//
// Pumps el LoginScreen REAL (no el harness de widget_test.dart):
//   - banner de error anunciado: Semantics(liveRegion: true) + tokens
//     AppColors.red/redDark/redBg (contraste redDark sobre redBg verificado
//     manualmente = 6.14:1 ≥ 4.5, R1 UI/UX);
//   - botón de reenvío deshabilitado con cuenta regresiva 'Reenviar en N s'
//     mientras `!puedeReenviarCodigo` (ERR-07, R3);
//   - enlace "Enviar de nuevo" con target táctil ≥ 44 px (R4).

import 'package:aplicacion/core/app_colors.dart';
import 'package:aplicacion/domain/controllers/auth_controller.dart';
import 'package:aplicacion/presentation/screens/login/login_screen.dart';
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

  testWidgets(
    'banner liveRegion+tokens, reenvío deshabilitado con countdown y link ≥44 px',
    (tester) async {
      // GIVEN un login fallido dejó el banner de error visible
      when(
        () => mockAuthService.signIn(
          correo: any(named: 'correo'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => throw const AuthException('Invalid login credentials'),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>(
          create: (_) => controller,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // GIVEN el formulario de correo está expandido: por defecto está
      // colapsado (SizeTransition) y el link queda recortado/inalcanzable.
      await tester.tap(find.text('Iniciar sesión con correo'));
      await tester.pumpAndSettle();

      await controller.login('ana@test.local', 'mala');
      await tester.pump();

      const mensaje = 'Correo o contraseña incorrectos.';
      expect(find.text(mensaje), findsOneWidget);

      // THEN el banner está anunciado por lectores: envuelto en
      // Semantics(liveRegion: true) (ERR-07 / R1 — aria-live).
      final liveRegions = tester
          .widgetList<Semantics>(
            find.ancestor(
              of: find.text(mensaje),
              matching: find.byType(Semantics),
            ),
          )
          .where((w) => w.properties.liveRegion == true);
      expect(
        liveRegions,
        isNotEmpty,
        reason: 'el banner de error debe ser liveRegion para lectores',
      );

      // THEN tokens rojos migrados: fondo redBg, texto redDark
      // (contraste manual redDark sobre redBg = 6.14:1 ≥ 4.5 — R1).
      final fondo = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == AppColors.redBg,
      );
      expect(fondo, findsOneWidget);
      final textoBanner = tester.widget<Text>(find.text(mensaje));
      expect(textoBanner.style?.color, AppColors.redDark);

      // GIVEN un cooldown activo (envío de código exitoso)
      when(
        () => mockAuthService.enviarRecuperacionContrasena('ana@test.local'),
      ).thenAnswer((_) async {});
      await controller.recuperarContrasena('ana@test.local');

      // El formulario de recuperación parte del correo del login.
      await tester.enterText(
        find.byType(TextFormField).first,
        'ana@test.local',
      );
      await tester.pump();

      // WHEN abre la pantalla de recuperación de contraseña
      final linkOlvide = find.text('¿Olvidaste tu contraseña?');
      await tester.ensureVisible(linkOlvide);
      await tester.pumpAndSettle();
      await tester.tap(linkOlvide);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // THEN la acción de reenvío está deshabilitada mostrando la cuenta
      // regresiva 'Reenviar en N s' (ERR-07, R3).
      await tester.pump();
      final etiqueta = 'Reenviar en ${controller.cooldownRestante.inSeconds} s';
      expect(
        find.widgetWithText(ElevatedButton, etiqueta),
        findsOneWidget,
        reason: 'el botón debe mostrar el countdown del cooldown',
      );
      final botonReenvio = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, etiqueta),
      );
      expect(botonReenvio.onPressed, isNull);
      expect(
        find.widgetWithText(ElevatedButton, 'Enviar código'),
        findsNothing,
      );

      // THEN a los 61 s se habilita de nuevo con su label original.
      await tester.pump(const Duration(seconds: 61));
      expect(
        find.widgetWithText(ElevatedButton, 'Enviar código'),
        findsOneWidget,
      );
      final botonHabilitado = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Enviar código'),
      );
      expect(botonHabilitado.onPressed, isNotNull);

      // WHEN avanza al paso 2 (código OTP + nueva contraseña)
      final botonEnviar = find.widgetWithText(ElevatedButton, 'Enviar código');
      await tester.ensureVisible(botonEnviar);
      await tester.pumpAndSettle();
      await tester.tap(botonEnviar);
      await tester.pump();
      await tester.pumpAndSettle();

      // THEN el enlace de reenvío tiene target táctil ≥ 44 px (R4).
      final enlace = find.byKey(const Key('reenviar-codigo-link'));
      expect(enlace, findsOneWidget);
      expect(tester.getSize(enlace).height, greaterThanOrEqualTo(44));

      // Limpieza: desmontar el árbol — ChangeNotifierProvider es DUEÑO del
      // controlador (create:) y lo dispone al desmontar, cancelando el timer
      // del cooldown (regla de duración ERR-07: cero timers tras dispose).
      await tester.pumpWidget(const SizedBox());
    },
  );
}
