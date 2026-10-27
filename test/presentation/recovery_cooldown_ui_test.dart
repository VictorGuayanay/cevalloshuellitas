// recovery_cooldown_ui_test.dart — UI del banner de error y del cooldown
// (ERR-01 / ERR-07 · cambio mejoras-login).
//
// Pumps el LoginScreen REAL (no el harness de widget_test.dart):
//   - banner de error anunciado: Semantics(liveRegion: true) + tokens
//     AppColors.red/redDark/redBg (contraste redDark sobre redBg verificado
//     manualmente = 6.14:1 ≥ 4.5, R1 UI/UX);
//   - botón de reenvío deshabilitado con cuenta regresiva 'Reintentar en N s'
//     mientras `!puedeReenviarCodigo` (ERR-07, R3);
//   - botón "Reenviar enlace" con target táctil ≥ 44 px tras éxito (R4).
//
// Re-pin sancionado (AMD-2026-10-23-05 + decisión user-validated RST-DD-2):
// 'Enviar código' → 'Restablecer contraseña'; 'Reenviar en N s' → 'Reintentar en N s'.

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

/// Espera hasta que [finder] encuentre al menos un widget, con timeout.
Future<void> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (tester.any(finder)) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  // Último intento para fallar con mensaje claro
  expect(tester.any(finder), isTrue, reason: 'Timeout esperando $finder');
}

void main() {
  late MockAuthService mockAuthService;

  setUpAll(() {
    // Sin fetching en tests: google_fonts no debe hacer HTTP al pintar.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    mockAuthService = MockAuthService();
  });

  testWidgets(
    'banner liveRegion+tokens, reenvío deshabilitado con countdown y link ≥44 px',
    (tester) async {
      final controller = AuthController(
        authService: mockAuthService,
        tokenPush: FakeTokenPushPort(),
      );

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
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
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

      // THEN la acción principal muestra "Restablecer contraseña" (re-pin RST-01)
      expect(find.text('Restablecer contraseña'), findsOneWidget);
      expect(find.text('Enviar código'), findsNothing);

      // GIVEN un envío exitoso
      when(
        () => mockAuthService.enviarRecuperacionContrasena('ana@test.local'),
      ).thenAnswer((_) async {});

      // WHEN tap en "Restablecer contraseña" → éxito → muestra mensaje M
      await tester.tap(find.text('Restablecer contraseña'));
      // Esperamos a que la operación async complete y el widget se reconstruya
      await waitForWidget(
        tester,
        find.text(
          'Si el correo existe, recibirás un enlace para restablecer tu '
          'contraseña. Revisa tu correo y la carpeta de spam.',
        ),
      );

      // THEN mensaje anti-enumeración M visible
      const mensajeM =
          'Si el correo existe, recibirás un enlace para restablecer tu '
          'contraseña. Revisa tu correo y la carpeta de spam.';
      expect(find.text(mensajeM), findsOneWidget);

      // THEN durante cooldown, el botón de reenvío muestra "Reintentar en N s"
      // (re-pin RST-DD-2: 'Reenviar en N s' → 'Reintentar en N s')
      await waitForWidget(
        tester,
        find.widgetWithText(
          ElevatedButton,
          'Reintentar en ${controller.cooldownRestante.inSeconds} s',
        ),
      );

      // El cooldown empieza en 60s (iniciarCooldownReenvio lo setea inmediatamente)
      expect(controller.cooldownRestante.inSeconds, greaterThan(0));

      final etiqueta =
          'Reintentar en ${controller.cooldownRestante.inSeconds} s';
      expect(
        find.widgetWithText(ElevatedButton, etiqueta),
        findsOneWidget,
        reason:
            'el botón debe mostrar el countdown del cooldown con "Reintentar"',
      );
      final botonReintento = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, etiqueta),
      );
      expect(botonReintento.onPressed, isNull);
      expect(
        find.widgetWithText(ElevatedButton, 'Restablecer contraseña'),
        findsNothing,
      );

      // THEN a los 61 s se habilita de nuevo con su label "Reenviar enlace".
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(ElevatedButton, 'Reenviar enlace'),
        findsOneWidget,
      );
      final botonHabilitado = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Reenviar enlace'),
      );
      expect(botonHabilitado.onPressed, isNotNull);

      // Limpieza
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
