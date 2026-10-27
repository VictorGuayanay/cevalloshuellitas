// recuperar_contrasena_screen_test.dart — Tests de la pantalla de recuperación (1 paso).
//
// RST-01/RST-02/RST-DD-2: la acción primaria lee "Restablecer contraseña", NO
// existe widget de ingreso de código, y el cooldown muestra "Reintentar en N s".

import 'package:aplicacion/core/app_colors.dart';
import 'package:aplicacion/domain/controllers/auth_controller.dart';
import 'package:aplicacion/presentation/screens/login/recuperar_contrasena_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

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

  group('RecuperarContrasenaScreen — flujo de 1 paso (RST-01/RST-02)', () {
    testWidgets(
      'la acción primaria lee "Restablecer contraseña" y NO existe campo de código',
      (tester) async {
        when(
          () => mockAuthService.enviarRecuperacionContrasena('ana@test.local'),
        ).thenAnswer((_) async {});

        final controller = AuthController(
          authService: mockAuthService,
          tokenPush: FakeTokenPushPort(),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthController>.value(
            value: controller,
            child: MaterialApp(
              home: RecuperarContrasenaScreen(correoInicial: 'ana@test.local'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // THEN: el botón principal muestra "Restablecer contraseña"
        expect(find.text('Restablecer contraseña'), findsOneWidget);

        // THEN: NO existe widget de ingreso de código (OTP)
        expect(find.text('Código de 6 dígitos'), findsNothing);
        expect(find.text('Ingresa el código'), findsNothing);

        // THEN: NO existe botón "Cambiar contraseña" (paso 2)
        expect(find.text('Cambiar contraseña'), findsNothing);

        // THEN: NO existe link "¿No recibiste el código? Enviar de nuevo"
        expect(
          find.text('¿No recibiste el código? Enviar de nuevo'),
          findsNothing,
        );

        controller.dispose();
      },
    );

    testWidgets(
      'tap con controller exitoso → mensaje anti-enumeración M byte-idéntico, '
      'la pantalla queda (sin transición a paso 2)',
      (tester) async {
        when(
          () => mockAuthService.enviarRecuperacionContrasena('ana@test.local'),
        ).thenAnswer((_) async {});

        final controller = AuthController(
          authService: mockAuthService,
          tokenPush: FakeTokenPushPort(),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthController>.value(
            value: controller,
            child: MaterialApp(
              home: RecuperarContrasenaScreen(correoInicial: 'ana@test.local'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // WHEN: tap en el botón "Restablecer contraseña"
        await tester.tap(find.text('Restablecer contraseña'));
        // Esperamos a que la operación async complete y el widget se reconstruya
        await waitForWidget(
          tester,
          find.text(
            'Si el correo existe, recibirás un enlace para restablecer tu '
            'contraseña. Revisa tu correo y la carpeta de spam.',
          ),
        );

        // THEN: mensaje M anti-enumeración byte-idéntico
        const mensajeM =
            'Si el correo existe, recibirás un enlace para restablecer tu '
            'contraseña. Revisa tu correo y la carpeta de spam.';
        expect(find.text(mensajeM), findsOneWidget);

        // THEN: la pantalla NO transiciona a paso 2 (no hay campos de contraseña)
        expect(find.text('Nueva contraseña'), findsNothing);
        expect(find.text('Confirmar contraseña'), findsNothing);

        controller.dispose();
      },
    );

    testWidgets(
      'cooldown: label "Reintentar en N s" (RST-DD-2) mientras !puedeReenviarCodigo',
      (tester) async {
        when(
          () => mockAuthService.enviarRecuperacionContrasena('ana@test.local'),
        ).thenAnswer((_) async {});

        final controller = AuthController(
          authService: mockAuthService,
          tokenPush: FakeTokenPushPort(),
        );

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthController>.value(
            value: controller,
            child: MaterialApp(
              home: RecuperarContrasenaScreen(correoInicial: 'ana@test.local'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // GIVEN: envío exitoso arranca cooldown
        await tester.tap(find.text('Restablecer contraseña'));
        // Esperamos a que aparezca el botón con cooldown
        await waitForWidget(
          tester,
          find.widgetWithText(
            ElevatedButton,
            'Reintentar en ${controller.cooldownRestante.inSeconds} s',
          ),
        );

        // THEN: durante cooldown, el botón muestra "Reintentar en N s"
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

        // THEN: a los 61 s se habilita de nuevo con su label original
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

        controller.dispose();
      },
    );
  });
}
