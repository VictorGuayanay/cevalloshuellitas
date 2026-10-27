// main.dart — Punto de entrada de la aplicación Huellitas.
// Aquí inicializamos los servicios externos (Firebase y Supabase),
// configuramos los providers globales y definimos las rutas de navegación.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'supabase_config.dart';
import 'data/services/notificacion_local_service.dart';
import 'data/services/fcm_service.dart';
import 'domain/controllers/auth_controller.dart';
import 'domain/controllers/mascota_controller.dart';
import 'domain/controllers/notificacion_controller.dart';
import 'domain/controllers/veterinario_controller.dart';
import 'domain/controllers/noticia_controller.dart';
import 'domain/controllers/admin_controller.dart';
import 'domain/controllers/productor_controller.dart';
import 'presentation/screens/login/login_screen.dart';
import 'presentation/screens/login/register_screen.dart';
import 'presentation/screens/login/recuperar_contrasena_screen.dart';
import 'presentation/screens/login/nueva_contrasena_screen.dart';
import 'presentation/screens/usuario/home_screen.dart';
import 'presentation/screens/usuario/mis_mascotas_screen.dart';
import 'presentation/screens/usuario/servicios_screen.dart';
import 'presentation/screens/usuario/perfil_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/usuario/mapa_veterinarios_screen.dart';
import 'presentation/screens/admin/admin_screen.dart';

/// main() es la función que Flutter llama cuando arranca la app.
/// Usamos async porque necesitamos esperar varias inicializaciones.
void main() async {
  // Asegura que los bindings de Flutter estén listos antes de usar plugins.
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Firebase (usado solo para notificaciones push FCM) ───────────────────
  // El módulo SENSO fue migrado a Supabase, por lo que Firebase solo se usa
  // para FCM. Si falla, la app funciona pero sin notificaciones push remotas.
  bool firebaseDisponible = false;
  try {
    await Firebase.initializeApp();
    firebaseDisponible = true;
    debugPrint('Firebase inicializado correctamente.');
  } on PlatformException catch (e) {
    debugPrint('Firebase no pudo inicializarse (PlatformException): $e');
    debugPrint('→ Verifica que google-services.json esté en android/app/');
  } on FirebaseException catch (e) {
    debugPrint(
      'Firebase no pudo inicializarse (FirebaseException): ${e.code} — ${e.message}',
    );
  } catch (e) {
    debugPrint('Firebase error inesperado: $e');
  }

  // ── 2. Supabase (base de datos principal: usuarios, mascotas, etc.) ──────────
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // ── 3. Notificaciones locales (banners, sonidos, vibración) ──────────────────
  await NotificacionLocalService.instance.init();

  // ── 4. FCM (solo si Firebase arrancó correctamente) ──────────────────────────
  if (firebaseDisponible) {
    await FcmService.instance.init();
  } else {
    debugPrint('FCM deshabilitado: Firebase no disponible.');
  }

  // ── 5. Callback al tocar una notificación push ────────────────────────────────
  // Cuando el usuario toca la notificación, lo llevamos a la pantalla /home.
  NotificacionLocalService.instance.setOnTap((payload) {
    debugPrint('Push tocada con payload: $payload');
    // addPostFrameCallback garantiza que el Navigator ya esté montado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = MyApp.navigatorKey.currentState;
      if (nav == null) return;
      nav.pushNamedAndRemoveUntil('/home', (r) => false);
    });
  });

  // ── 6. Levantar la app con todos los providers ────────────────────────────────
  runApp(
    MultiProvider(
      providers: [
        // AuthController gestiona login, registro y sesión activa.
        // initAuthListener(): el listener global (SES-01…SES-07) se registra
        // ANTES de restaurar para no perderte eventos durante el splash.
        ChangeNotifierProvider(
          create: (_) => AuthController()
            ..initAuthListener()
            ..tryRestoreSession(),
        ),
        // MascotaController gestiona la lista de mascotas del usuario.
        ChangeNotifierProvider(create: (_) => MascotaController()),
        // NotificacionController maneja las alertas in-app (mascotas perdidas).
        ChangeNotifierProvider(create: (_) => NotificacionController()),
        // VeterinarioController gestiona el perfil y lista de veterinarios.
        ChangeNotifierProvider(create: (_) => VeterinarioController()),
        // NoticiaController gestiona las noticias de la comunidad.
        ChangeNotifierProvider(create: (_) => NoticiaController()),
        // AdminController gestiona el panel de administración.
        ChangeNotifierProvider(create: (_) => AdminController()),
        // ProductorController gestiona los productores pecuarios con animales en venta.
        ChangeNotifierProvider(create: (_) => ProductorController()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Widget raíz de la aplicación.
/// Define el tema, las rutas y la pantalla inicial según el estado de sesión.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Key global del Navigator para navegar sin BuildContext
  /// (necesario para el tap en notificaciones push en background).
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Programa (post-frame) el reset de la pila de navegación a [ruta]
  /// tras un cierre de sesión (SES-02) o enlace inválido (RST-09).
  /// Si [forzar] es false (default), sólo navega si la pila puede
  /// poppear (`canPop()`): en la raíz no hay nada que desapilar y el
  /// `Consumer` raíz ya renderiza `LoginScreen` desde el estado.
  /// Si [forzar] es true, navega incluso sin profundidad (caso en caliente
  /// RST-09: reset forzado a `/login` aunque la pila esté en raíz).
  static void programarResetDePila({
    String ruta = '/login',
    bool forzar = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigatorKey.currentState;
      if (nav != null && (forzar || nav.canPop())) {
        nav.pushNamedAndRemoveUntil(ruta, (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Huellitas',
      debugShowCheckedModeBanner: false,
      navigatorKey: MyApp.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6B35)),
        // Poppins como tipografía global de la app.
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      // Pantalla inicial: decidida dinámicamente según el estado de auth.
      home: Consumer<AuthController>(
        builder: (context, authController, _) {
          // RST-09: consume-once — tras un enlace de recuperación inválido,
          // programar reset de pila forzado a `/login`.
          if (authController.consumirAvisoEnlaceInvalido()) {
            MyApp.programarResetDePila(ruta: '/login', forzar: true);
          }

          // SES-02 (DP-P2-1): consume-once — tras un `signedOut`, programar
          // el reset de pila (post-frame, sólo si hay profundidad que poppear).
          if (authController.consumirAvisoDeCierre()) {
            MyApp.programarResetDePila();
          }

          // RST-DP-1(a): modo recuperación tiene prioridad sobre sesión/home.
          if (authController.enModoRecuperacion)
            return const NuevaContrasenaScreen();

          // Mientras restauramos la sesión, mostramos el splash.
          if (authController.isInitializing) return const SplashScreen();

          if (authController.isAuthenticated) {
            final user = authController.currentUser;
            final rol = user?.rol ?? '';
            final uid = user?.id ?? '';

            // Suscripciones en tiempo real: se activan una vez montada la UI.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final notifCtrl = context.read<NotificacionController>();
              final mascotaCtrl = context.read<MascotaController>();

              // Todos los roles reciben alertas de mascotas perdidas.
              notifCtrl.suscribirMascotasPerdidas();

              // Cargar las mascotas del usuario autenticado.
              if (uid.isNotEmpty) {
                mascotaCtrl.cargarMascotas(uid);
              }
            });

            // Redirigir según rol.
            if (rol == 'administrador') return const AdminScreen();
            return const HomeScreen(); // usuario y veterinario
          }

          // Sin sesión → pantalla de login.
          return const LoginScreen();
        },
      ),
      // Rutas nombradas para navegación con pushNamed.
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/admin': (context) => const AdminScreen(),
        '/mis_mascotas': (context) => const MisMascotasScreen(),
        '/servicios': (context) => const ServiciosScreen(),
        '/perfil': (context) => const PerfilScreen(),
        '/mapa_veterinarios': (context) => const MapaVeterinariosScreen(),
        '/nueva_contrasena': (context) => const NuevaContrasenaScreen(),
        '/recuperar_contrasena': (context) =>
            const RecuperarContrasenaScreen(correoInicial: ''),
      },
    );
  }
}
