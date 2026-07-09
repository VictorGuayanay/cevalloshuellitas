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
import 'domain/controllers/cita_controller.dart';
import 'domain/controllers/veterinario_controller.dart';
import 'domain/controllers/servicio_controller.dart';
import 'domain/controllers/solicitud_adopcion_controller.dart';
import 'domain/controllers/noticia_controller.dart';
import 'presentation/screens/login/login_screen.dart';
import 'presentation/screens/login/register_screen.dart';
import 'presentation/screens/usuario/home_screen.dart';
import 'presentation/screens/veterinario/vet_home_screen.dart';
import 'presentation/screens/veterinario/vet_citas_screen.dart';
import 'presentation/screens/veterinario/vet_mascotas_screen.dart';
import 'presentation/screens/veterinario/vet_perfil_screen.dart';
import 'presentation/screens/usuario/mis_mascotas_screen.dart';
import 'presentation/screens/usuario/adopciones_screen.dart';
import 'presentation/screens/usuario/servicios_screen.dart';
import 'presentation/screens/usuario/solicitudes_adopcion_screen.dart';
import 'presentation/screens/veterinario/urgencias_screen.dart';
import 'presentation/screens/usuario/urgencias_usuario_screen.dart';
import 'presentation/screens/usuario/perfil_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/usuario/mapa_veterinarios_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase (necesario para FCM)
  // Se captura PlatformException y FirebaseException por si los archivos de
  // configuración nativos no están presentes o el canal de plataforma falla,
  // evitando que la app crashee; FCM quedará deshabilitado en ese caso.
  bool firebaseDisponible = false;
  try {
    await Firebase.initializeApp();
    firebaseDisponible = true;
  } on PlatformException catch (e) {
    debugPrint('Firebase no pudo inicializarse (PlatformException): $e');
  } on FirebaseException catch (e) {
    debugPrint('Firebase no pudo inicializarse (FirebaseException): $e');
  } catch (e) {
    debugPrint('Firebase error inesperado: $e');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Inicializar notificaciones locales (vibración, recordatorios)
  await NotificacionLocalService.instance.init();

  // Inicializar FCM solo si Firebase se inicializó correctamente
  if (firebaseDisponible) {
    await FcmService.instance.init();
  } else {
    debugPrint('FCM deshabilitado: Firebase no disponible.');
  }

  // Registrar handler: al tocar una push navega a la pantalla correcta
  NotificacionLocalService.instance.setOnTap((payload) {
    debugPrint('Push tocada con payload: $payload');

    // Esperar un frame para asegurar que la app esté montada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = MyApp.navigatorKey.currentState;
      if (nav == null) return;

      if (payload == null) {
        nav.pushNamedAndRemoveUntil('/home', (r) => false);
        return;
      }

      switch (payload) {
        case 'vet_citas':
          // Nueva cita → vet ve su gestión de citas
          nav.pushNamedAndRemoveUntil('/vet_home', (r) => false);
          Future.delayed(const Duration(milliseconds: 400), () {
            MyApp.navigatorKey.currentState?.pushNamed('/vet_citas');
          });
          break;

        case 'historial_citas':
          // Cita confirmada/rechazada → usuario va a perfil donde está el historial
          nav.pushNamedAndRemoveUntil('/home', (r) => false);
          Future.delayed(const Duration(milliseconds: 400), () {
            MyApp.navigatorKey.currentState?.pushNamed('/perfil');
          });
          break;

        case 'solicitudes_adopcion':
          // Solicitud de adopción → panel de solicitudes recibidas
          nav.pushNamedAndRemoveUntil('/home', (r) => false);
          Future.delayed(const Duration(milliseconds: 400), () {
            MyApp.navigatorKey.currentState?.pushNamed('/solicitudes_adopcion');
          });
          break;

        case 'vet_home':
          // Urgencia → home del vet
          nav.pushNamedAndRemoveUntil('/vet_home', (r) => false);
          break;

        default:
          // Payloads legacy ('adopcion:xxx', 'cita:xxx', 'urgencia:xxx')
          if (payload.startsWith('vet') || payload.startsWith('urgencia')) {
            nav.pushNamedAndRemoveUntil('/vet_home', (r) => false);
          } else {
            nav.pushNamedAndRemoveUntil('/home', (r) => false);
          }
      }
    });
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()..tryRestoreSession()),
        ChangeNotifierProvider(create: (_) => MascotaController()),
        ChangeNotifierProvider(create: (_) => CitaController()),
        ChangeNotifierProvider(create: (_) => VeterinarioController()),
        ChangeNotifierProvider(create: (_) => ServicioController()),
        ChangeNotifierProvider(create: (_) => SolicitudAdopcionController()),
        ChangeNotifierProvider(create: (_) => NoticiaController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Huellitas',
      debugShowCheckedModeBanner: false,
      navigatorKey: MyApp.navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6B35)),
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        useMaterial3: true,
      ),
      home: Consumer<AuthController>(
        builder: (context, authController, _) {
          if (authController.isInitializing) {
            return const SplashScreen();
          }
          if (authController.isAuthenticated) {
            if (authController.currentUser?.rol == 'veterinario') {
              return const VetHomeScreen();
            }
            // Los administradores no tienen acceso en la app móvil.
            // El AuthController cerrará sesión si el login retornó 'administrador'.
            // Por si acaso queda una sesión previa, redirigir a login.
            if (authController.currentUser?.rol == 'administrador') {
              return const LoginScreen();
            }
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => _RouteGuard(
              rolesPermitidos: const ['usuario'],
              child: const HomeScreen(),
            ),
        '/vet_home': (context) => _RouteGuard(
              rolesPermitidos: const ['veterinario'],
              child: const VetHomeScreen(),
            ),
        '/mis_mascotas': (context) => _RouteGuard(
              rolesPermitidos: const ['usuario'],
              child: const MisMascotasScreen(),
            ),
        '/adopciones': (context) => const AdopcionesScreen(),
        '/solicitudes_adopcion': (context) => _RouteGuard(
              rolesPermitidos: const ['usuario'],
              child: const SolicitudesAdopcionScreen(),
            ),
        '/servicios': (context) => const ServiciosScreen(),
        '/urgencias': (context) => _RouteGuard(
              rolesPermitidos: const ['veterinario'],
              child: const UrgenciasScreen(),
            ),
        '/urgencias_usuario': (context) => _RouteGuard(
              rolesPermitidos: const ['usuario'],
              child: const UrgenciasUsuarioScreen(),
            ),
        '/perfil': (context) => _RouteGuard(
              rolesPermitidos: const ['usuario'],
              child: const PerfilScreen(),
            ),
        '/vet_citas': (context) => _RouteGuard(
              rolesPermitidos: const ['veterinario'],
              child: const VetCitasScreen(),
            ),
        '/vet_mascotas': (context) => _RouteGuard(
              rolesPermitidos: const ['veterinario'],
              child: const VetMascotasScreen(),
            ),
        '/vet_perfil': (context) => _RouteGuard(
              rolesPermitidos: const ['veterinario'],
              child: const VetPerfilScreen(),
            ),
        '/mapa_veterinarios': (context) => const MapaVeterinariosScreen(),
      },
    );
  }
}

/// Guard de rutas en cliente.
/// Verifica que el usuario autenticado tenga uno de los [rolesPermitidos]
/// antes de renderizar el [child]. Si no está autenticado redirige a /login;
/// si tiene un rol diferente redirige a la pantalla correcta para su rol.
class _RouteGuard extends StatelessWidget {
  final List<String> rolesPermitidos;
  final Widget child;

  const _RouteGuard({
    required this.rolesPermitidos,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    // Mientras se restaura la sesión, mostrar splash
    if (auth.isInitializing) return const SplashScreen();

    // Sin sesión → login
    if (!auth.isAuthenticated || auth.currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const SplashScreen();
    }

    final rol = auth.currentUser!.rol;

    // Rol permitido → renderizar pantalla
    if (rolesPermitidos.contains(rol)) return child;

    // Rol incorrecto → redirigir a la pantalla correspondiente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rol == 'veterinario') {
        Navigator.pushReplacementNamed(context, '/vet_home');
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
    return const SplashScreen();
  }
}
