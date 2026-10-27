// session_reset_widget_test.dart — Verificación del reset de pila tras un
// cierre de sesión (SES-02, DP-P2-1 opción a) y tras enlace inválido (RST-09):
// `MyApp.programarResetDePila()` debe correr POST-FRAME y SÓLO cuando la
// pila puede poppear (`canPop()`), salvo que `forzar==true` (RST-09).
//
// Se importa lib/main.dart para usar `MyApp.navigatorKey` y el helper —
// el import NO ejecuta `main()` ni inicializa Firebase/Supabase (los
// inicializadores de primer nivel de Dart son perezosos y `main()` jamás
// se invoca desde un test). Se bombea un `MaterialApp` propio, no `MyApp`,
// para no depender de GoogleFonts/tema en la prueba.

import 'package:aplicacion/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reset de pila por cierre de sesión (SES-02)', () {
    testWidgets('reset de pila: post-frame y sólo si canPop()', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: MyApp.navigatorKey,
          home: const Scaffold(body: Text('raíz')),
          routes: {
            '/login': (context) => const Scaffold(body: Text('ruta login')),
            '/perfil': (context) => const Scaffold(body: Text('ruta perfil')),
          },
        ),
      );
      final nav = MyApp.navigatorKey.currentState!;

      // GIVEN una pila con profundidad (usuario dentro de /perfil).
      nav.pushNamed('/perfil');
      await tester.pumpAndSettle();
      expect(nav.canPop(), isTrue);

      // WHEN se programa el reset (como haría el Consumer tras un signedOut).
      MyApp.programarResetDePila();
      // THEN es post-frame: en el mismo frame NO navega todavía.
      expect(nav.canPop(), isTrue);
      expect(find.text('ruta perfil'), findsOneWidget);

      // El binding de test sólo dibuja frames cuando hay uno agendado (en
      // producción el rebuild del Consumer que leyó el aviso ES ese frame):
      // se agenda uno para disparar el callback post-frame, y se asienta la
      // transición de rutas que el reset dispara.
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(nav.canPop(), isFalse);
      expect(find.text('ruta login'), findsOneWidget);
      expect(find.text('ruta perfil'), findsNothing);
    });

    testWidgets('reset de pila: en la raíz (sin canPop) no navega', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: MyApp.navigatorKey,
          home: const Scaffold(body: Text('raíz')),
          routes: {
            '/login': (context) => const Scaffold(body: Text('ruta login')),
          },
        ),
      );
      final nav = MyApp.navigatorKey.currentState!;
      expect(nav.canPop(), isFalse); // GIVEN: sólo la raíz en la pila

      // WHEN se programa el reset sin profundidad que desapilar.
      MyApp.programarResetDePila();
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pumpAndSettle();

      // THEN no navega: la raíz sigue montada (el Consumer ya muestra
      // LoginScreen desde el estado; resetear aquí borraría la pila raíz).
      expect(nav.canPop(), isFalse);
      expect(find.text('raíz'), findsOneWidget);
      expect(find.text('ruta login'), findsNothing);
    });
  });

  group('reset de pila forzado por enlace inválido (RST-09)', () {
    testWidgets('reset forzado: navega a /login aunque canPop()==false', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: MyApp.navigatorKey,
          home: const Scaffold(body: Text('raíz')),
          routes: {
            '/login': (context) => const Scaffold(body: Text('ruta login')),
          },
        ),
      );
      final nav = MyApp.navigatorKey.currentState!;
      expect(nav.canPop(), isFalse); // GIVEN: sólo la raíz en la pila

      // WHEN se programa el reset FORZADO (forzar=true).
      MyApp.programarResetDePila(ruta: '/login', forzar: true);
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pumpAndSettle();

      // THEN navega a /login aunque no haya profundidad que desapilar.
      expect(nav.canPop(), isFalse);
      expect(find.text('raíz'), findsNothing);
      expect(find.text('ruta login'), findsOneWidget);
    });

    testWidgets('reset forzado: ruta personalizada funciona', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: MyApp.navigatorKey,
          home: const Scaffold(body: Text('raíz')),
          routes: {
            '/otra_ruta': (context) => const Scaffold(body: Text('ruta otra')),
          },
        ),
      );
      final nav = MyApp.navigatorKey.currentState!;
      expect(nav.canPop(), isFalse);

      // WHEN se programa el reset forzado a una ruta distinta.
      MyApp.programarResetDePila(ruta: '/otra_ruta', forzar: true);
      tester.binding.scheduleFrame();
      await tester.pump();
      await tester.pumpAndSettle();

      // THEN navega a la ruta especificada.
      expect(find.text('ruta otra'), findsOneWidget);
    });
  });
}
