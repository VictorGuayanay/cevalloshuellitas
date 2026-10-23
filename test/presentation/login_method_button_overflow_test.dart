// login_method_button_overflow_test.dart — Defecto de overflow observado en
// dispositivo vivo (evidencia de log capturada durante la tarea 11.4,
// 2026-10-23): "A RenderFlex overflowed by 20 pixels on the right" en
// login_screen.dart:325 (el Row dentro de _MethodButton), en una pantalla
// angosta (Samsung SM-A022M, 720 px físicos de ancho → menos de 360 px
// lógicos).
//
// Pumps el LoginScreen REAL en un viewport angosto. El RenderFlex overflow es
// una excepción capturable en tests: si la etiqueta del _MethodButton no puede
// encoger, el binding la registra y `takeException()` la devuelve → la
// aserción falla (RED). Tras envolver la etiqueta en Expanded + ellipsis, la
// fila ya no desborda y takeException() es null (GREEN).

import 'package:aplicacion/domain/controllers/auth_controller.dart';
import 'package:aplicacion/presentation/screens/login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

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

  testWidgets('el _MethodButton no desborda su Row en una pantalla angosta', (
    tester,
  ) async {
    // GIVEN un viewport angosto. Se usa 460 px (no 320) para aislar el
    // widget bajo prueba: en el entorno de test GoogleFonts no puede hacer
    // fetch (allowRuntimeFetching=false) y la fuente de respaldo pinta cada
    // glifo a ~fontSize de ancho, ~2x más ancha que Poppins real. A 320 px
    // esa inflación haría desbordar también al _GoogleButton
    // (login_screen.dart:389, fuera de este alcance — P11-c/11.7), que en
    // el dispositivo real sí cabe. Con 460 px sólo desborda el _MethodButton
    // (el defecto observado en vivo en :325), de modo que la aserción
    // aísla el comportamiento objetivo sin colateral de un widget ajeno.
    tester.view.physicalSize = const Size(460, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => controller,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // GIVEN el botón de método (etiqueta larga) está en pantalla.
    expect(
      find.text('Iniciar sesión con correo'),
      findsOneWidget,
      reason: 'el _MethodButton debe renderizarse para ejercitar el defecto',
    );

    // THEN no hubo RenderFlex overflow al pintar la fila.
    final excepcion = tester.takeException();
    expect(
      excepcion,
      isNull,
      reason:
          'la fila del _MethodButton no debe desbordar en un viewport '
          'angosto: $excepcion',
    );

    // Limpieza: desmontar el árbol — el provider (create:) es dueño del
    // controlador y lo dispone al desmontar.
    await tester.pumpWidget(const SizedBox());
  });
}
