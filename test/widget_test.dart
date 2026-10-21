// widget_test.dart — Smoke test real de la app (TDD-01).
//
// Reemplaza el contador por defecto generado por `flutter create`:
//   - Escenario "Red → green": el árbol bombeado DEBE renderizar sin lanzar.
//   - Escenario "Replacement smoke test is meaningful": aserciones sobre el
//     enrutamiento raíz real (Consumer de AuthController en lib/main.dart),
//     sin aserciones de contador.
// Sin Firebase/Supabase/GoogleFonts: solo el harness de providers con un
// AuthController mockeado y placeholders locales (sin pantallas reales).

import 'package:aplicacion/domain/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'auth/mocks.dart';

/// Doble de AuthController para el harness (los getters se stubbean por test).
class MockAuthController extends Mock implements AuthController {}

/// Espejo del `Consumer<AuthController>` raíz de lib/main.dart
/// (splash → admin/home → login) con placeholders locales: mismas decisiones
/// de enrutamiento, sin GoogleFonts ni navegación a pantallas reales.
class _RutaRaiz extends StatelessWidget {
  const _RutaRaiz({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, _) {
        if (authController.isInitializing) {
          return const Scaffold(
            body: Center(child: Text('Restaurando sesión…')),
          );
        }
        if (authController.isAuthenticated) {
          final rol = authController.currentUser?.rol ?? '';
          if (rol == 'administrador') {
            return const Scaffold(
              body: Center(child: Text('Panel administrador')),
            );
          }
          return const Scaffold(
            body: Center(child: Text('Inicio de la app')),
          );
        }
        return const Scaffold(
          body: Center(child: Text('Inicia sesión para continuar')),
        );
      },
    );
  }
}

void main() {
  testWidgets(
    'el harness renderiza según el estado de AuthController (smoke TDD-01)',
    (tester) async {
      final authController = MockAuthController();

      // Cada estado bombea un árbol con Key distinta: el Mock no puede
      // notifyListeners y un árbol idéntico se saltaría el rebuild en
      // Element.updateChild — la Key fuerza el reemplazo del Element.
      // Estado A: splash mientras se restaura la sesión.
      when(() => authController.isInitializing).thenReturn(true);
      when(() => authController.isAuthenticated).thenReturn(false);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: authController,
          child: const MaterialApp(home: _RutaRaiz(key: ValueKey('splash'))),
        ),
      );
      await tester.pump();
      expect(find.text('Restaurando sesión…'), findsOneWidget);

      // Estado B: sin sesión → login.
      when(() => authController.isInitializing).thenReturn(false);
      when(() => authController.isAuthenticated).thenReturn(false);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: authController,
          child: const MaterialApp(home: _RutaRaiz(key: ValueKey('login'))),
        ),
      );
      await tester.pump();
      expect(find.text('Inicia sesión para continuar'), findsOneWidget);

      // Estado C: sesión administradora → panel de administración.
      when(() => authController.isInitializing).thenReturn(false);
      when(() => authController.isAuthenticated).thenReturn(true);
      when(() => authController.currentUser)
          .thenReturn(buildUsuarioModel(rol: 'administrador'));
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: authController,
          child: const MaterialApp(home: _RutaRaiz(key: ValueKey('admin'))),
        ),
      );
      await tester.pump();
      expect(find.text('Panel administrador'), findsOneWidget);
    },
  );
}
