// auth_controller.dart — Controlador de autenticación.
//
// Actúa como puente entre la UI y el AuthService.
// Extiende ChangeNotifier para que la UI escuche cambios de estado con Provider.
//
// Estado que maneja:
//   - isLoading: hay una operación en curso (login, registro, etc.)
//   - isInitializing: restaurando la sesión al arrancar la app
//   - errorMessage: último error a mostrar en la UI
//   - currentUser: perfil del usuario autenticado

import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth_error_mapper.dart';
import '../../core/token_push_port.dart';
import '../../data/models/usuario_model.dart';
import '../../data/services/auth_service.dart';

class AuthController extends ChangeNotifier {
  // Seam de inyección (TDD-02): en producción se usa AuthService() con el
  // singleton de Supabase; los tests inyectan un doble sin tocar la red.
  final AuthService _authService;

  // Seam del puerto FCM (TDD-06 / DES-DP-1(a)): en producción delega en
  // FcmService.instance vía FcmTokenPushAdapter; los tests inyectan un
  // FakeTokenPushPort y el controlador NO toca Firebase.
  final TokenPushPort _tokenPush;

  AuthController({AuthService? authService, TokenPushPort? tokenPush})
    : _authService = authService ?? AuthService(),
      _tokenPush = tokenPush ?? const FcmTokenPushAdapter();

  // ── Listener global de sesión (S2 / SES-01) ────────────────────────────────
  // Suscripción única a AuthService.authStates (onAuthStateChange de Supabase);
  // se registra una sola vez y se cancela en dispose() (sin fugas).
  StreamSubscription<AuthState>? _authSub;

  // true mientras `logout()` está pidiendo el cierre: el signedOut resultante
  // se trata en silencio (sin mensaje de expiración). One-shot: se consume al
  // procesar el evento (diseño, matriz de eventos).
  bool _cerrandoSesion = false;

  // Aviso one-shot para el Consumer raíz: queda en true tras cada `signedOut`
  // (silencioso o remoto) hasta que `consumirAvisoDeCierre()` lo lee y resetea.
  // Lector único por diseño (DP-P2-1, opción a).
  bool _avisoDeCierrePendiente = false;

  /// Suscribe el listener de eventos de autenticación de forma idempotente:
  /// las llamadas repetidas NO registran suscripciones adicionales (SES-01).
  void initAuthListener() {
    if (_authSub != null) return;
    _authSub = _authService.authStates.listen(
      (state) => unawaited(_procesarEvento(state)),
      // Errores del stream (p. ej. refresh con red caída): sólo traza —
      // NUNCA mutan estado: una transitoria no debe simular un logout;
      // el fallo definitivo de sesión llega como `signedOut` (diseño,
      // matriz de eventos; un error de stream sin onError crashea la app).
      onError: (Object error) =>
          debugPrint('Stream de sesión (onAuthStateChange): $error'),
    );
  }

  /// Devuelve true UNA sola vez tras cada `signedOut` (consume-once): el
  /// Consumer raíz de `lib/main.dart` lo lee como primera línea para programar
  /// el reset de pila a `/login` (post-frame y sólo si `canPop()`).
  bool consumirAvisoDeCierre() {
    final pendiente = _avisoDeCierrePendiente;
    _avisoDeCierrePendiente = false;
    return pendiente;
  }

  /// Procesa un evento de `onAuthStateChange` según la matriz del diseño.
  ///
  /// `signedOut` (SES-02): si el cierre lo pidió `logout()` se limpia el
  /// estado en silencio; si llega del servidor (expiración/revocación) se
  /// limpia además dejando el mensaje de sesión. En ambos casos se marca
  /// `_avisoDeCierrePendiente` para que la UI resetee la pila de navegación.
  ///
  /// `signedIn` (SES-03): carga el perfil de `session.user.id` para que el
  /// Consumer raíz enrute por rol.
  Future<void> _procesarEvento(AuthState state) async {
    switch (state.event) {
      case AuthChangeEvent.signedOut:
        final silencioso = _cerrandoSesion;
        _cerrandoSesion = false; // one-shot: el próximo signedOut es remoto
        _currentUser = null;
        if (!silencioso) {
          _errorMessage = 'Tu sesión ha expirado. Inicia sesión de nuevo.';
        }
        _avisoDeCierrePendiente = true;
        notifyListeners();
      case AuthChangeEvent.signedIn:
        final uid = state.session?.user.id;
        if (uid != null) await _cargarPerfil(uid);
      case AuthChangeEvent.tokenRefreshed:
        // SES-04: refresh silencioso — sin navegación, splash ni re-fetch
        // de perfil; sólo mantiene viva la sesión. No-op explícito.
        return;
      case AuthChangeEvent.userUpdated:
        // SES-05: el perfil se editó (p. ej. en otro dispositivo) →
        // recargar `currentUser` desde la fuente para que la UI refleje
        // los cambios sin re-login.
        final uid = state.session?.user.id;
        if (uid != null) await _cargarPerfil(uid);
      case AuthChangeEvent.passwordRecovery:
        // SES-06: con sesión activa, reflejarla cargando el perfil.
        // Nunca fuerza navegación — la pantalla de recuperación maneja su
        // propio flujo (evita carrera con el updateUser en vuelo).
        final uidRecuperacion = state.session?.user.id;
        if (uidRecuperacion != null) {
          await _cargarPerfil(uidRecuperacion);
        } else {
          // Sesión nula/expirada: quedarse en login con mensaje recuperable.
          // Copy interim: el mapeo fino de recuperación llega con el
          // AuthErrorMapper en la Fase 3; por ahora, el fallback fijo de
          // ERR-06 (string acotado en el spec).
          _errorMessage = 'Ocurrió un error. Intenta de nuevo.';
          notifyListeners();
        }
      case AuthChangeEvent.initialSession:
        // SES-07: en frío, `tryRestoreSession()` es dueña del arranque —
        // el replay de GoTrue no debe duplicar la carga (exactamente UNA
        // vía: sin doble carga de perfil ni doble save de token FCM).
        if (_isInitializing) return;
        // En caliente: si hay sesión y aún no hay perfil cargado, cargarlo.
        final uidInicial = state.session?.user.id;
        if (_currentUser == null && uidInicial != null) {
          await _cargarPerfil(uidInicial);
        }
      default:
        // Resto de eventos: tareas 2.8 (tokenRefreshed), 2.10 (userUpdated),
        // 2.11 (passwordRecovery / initialSession).
        break;
    }
  }

  /// Carga el perfil de [uid] en `currentUser` y notifica (SES-03).
  /// Si la fila no existe (PGRST116) u otro fallo ocurre, se deja un estado
  /// recuperable: `currentUser` limpio + mensaje genérico — sin crash ni loop
  /// silencioso (orfanato residual detectable, SGN-06). Copy interim: el
  /// `AuthErrorMapper` con el mensaje exacto de perfil inexistente llega en
  /// la Fase 3 (tarea 3.6); por ahora se usa el fallback fijo de ERR-06.
  Future<void> _cargarPerfil(String uid) async {
    try {
      _currentUser = await _authService.getUserProfile(uid);
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando perfil desde evento de sesión: $e');
      _currentUser = null;
      // ERR-06/SES-03: PGRST116 → mensaje exacto de perfil no encontrado
      // (rama 4 del mapa; reemplaza el interim genérico de la Fase 2).
      _errorMessage = AuthErrorMapper.map(e);
      notifyListeners();
    }
  }

  // ── Cooldown de reenvío de código (ERR-07 / SP-DP-1) ───────────────────────

  /// Duración del cooldown de reenvío tras enviar el código de recuperación.
  /// Configurable vía constante estática (SP-DP-1); default 60 s.
  static const Duration cooldownReenvio = Duration(seconds: 60);

  Timer? _timerCooldown;
  Duration _cooldownRestante = Duration.zero;

  /// Restante del cooldown (Duration.zero cuando no hay cooldown).
  Duration get cooldownRestante => _cooldownRestante;

  /// true cuando ya se puede reenviar el código (sin cooldown activo).
  bool get puedeReenviarCodigo => _timerCooldown == null;

  /// Arranca (o reinicia) el cooldown de reenvío: decrece 1 s por tick,
  /// notifica cada segundo y detiene el timer al llegar a cero — así no
  /// queda ningún timer vivo más allá de la ventana de cooldown.
  void iniciarCooldownReenvio() {
    _timerCooldown?.cancel();
    _cooldownRestante = cooldownReenvio;
    _timerCooldown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_cooldownRestante.inSeconds <= 1) {
        _cooldownRestante = Duration.zero;
        _timerCooldown?.cancel();
        _timerCooldown = null;
        notifyListeners();
      } else {
        _cooldownRestante -= const Duration(seconds: 1);
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    // Regla de duración (ERR-07): sin timers activos tras dispose().
    _timerCooldown?.cancel();
    _timerCooldown = null;
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }

  // ── Estado interno ─────────────────────────────────────────────────────────
  bool _isLoading = false; // true mientras hay operación en curso
  bool _isInitializing = true; // true durante el splash inicial
  String? _errorMessage; // null si no hay error
  UsuarioModel? _currentUser; // null si no hay sesión

  // ── Getters públicos ────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  UsuarioModel? get currentUser => _currentUser;
  bool get isAuthenticated => _authService.isAuthenticated;

  // ── Login ──────────────────────────────────────────────────────────────────

  /// Inicia sesión con email y contraseña.
  /// Retorna true si tuvo éxito, false si falló (el error queda en errorMessage).
  Future<bool> login(String correo, String password) async {
    // ERR-01: el error anterior no sobrevive al nuevo intento (silencioso,
    // sin notify: el banner se limpia en el notify que sigue).
    _errorMessage = null;
    _setLoading(true);
    try {
      _currentUser = await _authService.signIn(
        correo: correo.trim(),
        password: password,
      );
      // Guardar token FCM para que el usuario reciba notificaciones push.
      await _tokenPush.guardarToken(_currentUser!.id);
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      // Errores de Supabase Auth (credenciales inválidas, email no confirmado, etc.)
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    } catch (e) {
      // ERR-06: el texto crudo jamás llega a la UI — el mapa fija el copy.
      debugPrint('Error en login: $e');
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    }
  }

  /// Inicia sesión con Google.
  /// Retorna true si tuvo éxito, false si el usuario canceló o hubo error.
  Future<bool> loginWithGoogle() async {
    // ERR-01: limpiar al entrar (la cancelación de Google queda silenciosa).
    _errorMessage = null;
    _setLoading(true);
    try {
      _currentUser = await _authService.signInWithGoogle();
      await _tokenPush.guardarToken(_currentUser!.id);
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    } catch (e) {
      // ERR-05/ERR-01: cancelación de Google → map devuelve null (silencio);
      // cualquier otro fallo → copy permitido, jamás el wrapper crudo.
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    }
  }

  // ── Registro ───────────────────────────────────────────────────────────────

  /// Registra un nuevo usuario con los datos del formulario.
  /// Retorna true si se creó la cuenta, false en caso contrario.
  Future<bool> register({
    required String nombre,
    required String correo,
    required String password,
    String? telefono,
    String rol = 'usuario',
  }) async {
    // ERR-01: el error anterior no sobrevive al nuevo intento.
    _errorMessage = null;
    _setLoading(true);
    try {
      _currentUser = await _authService.signUp(
        nombre: nombre.trim(),
        correo: correo.trim(),
        password: password,
        telefono: telefono?.trim(),
        rol: rol,
      );
      await _tokenPush.guardarToken(_currentUser!.id);
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint('Error en registro: $e');
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  /// Cierra la sesión: limpia el token FCM, cierra sesión en Supabase
  /// y resetea el estado local.
  Future<void> logout() async {
    // ERR-01: cualquier banner previo se limpia al entrar.
    _errorMessage = null;
    // El `signedOut` que dispare Supabase es propio → tratarlo en silencio
    // (sin mensaje de "sesión expirada") — diseño, matriz de eventos.
    _cerrandoSesion = true;
    if (_currentUser != null) {
      // Quitar el token FCM para que el usuario no reciba más notificaciones.
      await _tokenPush.limpiarToken(_currentUser!.id);
    }
    await _authService.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Restaurar sesión ───────────────────────────────────────────────────────

  /// Se llama al arrancar la app para recuperar la sesión anterior.
  /// Mientras corre, isInitializing = true → el splash se mantiene visible.
  Future<void> tryRestoreSession() async {
    _isInitializing = true;
    notifyListeners();

    final userId = _authService.getCurrentUserId();
    if (userId != null) {
      try {
        _currentUser = await _authService.getUserProfile(userId);
        // Actualizar token FCM (puede haber cambiado desde la última vez).
        await _tokenPush.guardarToken(userId);
      } catch (e) {
        debugPrint('Error al restaurar sesión: $e');
        // No abortamos: si falla, el usuario verá el login.
      }
    }

    // Tiempo mínimo para reproducir la animación del splash.
    await Future.delayed(const Duration(milliseconds: 1200));

    _isInitializing = false;
    notifyListeners();
  }

  // ── Foto de perfil ─────────────────────────────────────────────────────────

  /// Sube una foto de perfil y actualiza el estado local con la nueva URL.
  Future<bool> subirFotoUsuario(File imagen, String extension) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    try {
      final url = await _authService.subirFotoUsuario(
        _currentUser!.id,
        imagen,
        extension,
      );
      // Actualizar el modelo local con la nueva URL sin recargar desde BD.
      _currentUser = _currentUser!.copyWith(fotoUrl: url);
      _setLoading(false);
      return true;
    } catch (e) {
      // ERR-06: sin `$e` crudo en la UI — copy fijo vía el mapa.
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    }
  }

  // ── Actualizar perfil ──────────────────────────────────────────────────────

  /// Guarda los cambios del perfil en Supabase y actualiza el estado local.
  Future<bool> updateProfile(
    String nombre,
    String telefono, {
    String? cedula,
    String? direccionGps,
    bool? esProductor,
    String? tipoAnimales,
  }) async {
    // ERR-01: el error anterior no sobrevive a la nueva operación.
    _errorMessage = null;
    if (_currentUser == null) return false;
    _setLoading(true);

    // Si no se pasa esProductor, conservamos el valor actual.
    final productorFinal = esProductor ?? _currentUser!.esProductor;

    try {
      await _authService.updateUserProfile(
        _currentUser!.id,
        nombre,
        telefono,
        cedula: cedula,
        direccionGps: direccionGps,
        esProductor: productorFinal,
        tipoAnimales: productorFinal ? tipoAnimales : null,
      );
      // Actualizar el modelo local (sin ir a la BD de nuevo).
      _currentUser = _currentUser!.copyWith(
        nombre: nombre,
        telefono: telefono,
        cedula: cedula,
        direccionGps: direccionGps,
        esProductor: productorFinal,
        tipoAnimales: productorFinal ? tipoAnimales : null,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    }
  }

  /// Cambia el rol del usuario y actualiza el estado local.
  Future<bool> updateRol(String nuevoRol) async {
    // ERR-01: el error anterior no sobrevive a la nueva operación.
    // (updateRol sigue presente hasta la Fase 8 / DES-DP-3.)
    _errorMessage = null;
    if (_currentUser == null) return false;
    _setLoading(true);
    try {
      await _authService.updateUserRol(_currentUser!.id, nuevoRol);
      _currentUser = _currentUser!.copyWith(rol: nuevoRol);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    }
  }

  // ── Recuperación de contraseña ─────────────────────────────────────────────

  /// Envía el OTP de recuperación al correo indicado.
  Future<bool> recuperarContrasena(String correo) async {
    // ERR-01: el error anterior no sobrevive a la nueva operación.
    _errorMessage = null;
    _setLoading(true);
    try {
      await _authService.enviarRecuperacionContrasena(correo.trim());
      // ERR-07: el envío exitoso arranca el cooldown de reenvío
      // (la UI se re-dibuja en el notify de _setLoading(false)).
      iniciarCooldownReenvio();
      _setLoading(false);
      return true;
    } catch (e) {
      // ERR-02 + ERR-07 esc. 2: el rate-limit del servidor muestra el copy
      // de espera Y arranca el cooldown (server-driven). Sólo en este caso:
      // un fallo de conexión (ERR-04) invita a "vuelve a intentarlo" y no
      // debe bloquear el reenvío 60 s.
      _errorMessage = AuthErrorMapper.map(e);
      if (e.toString().contains('over_email_send_rate_limit')) {
        iniciarCooldownReenvio();
      }
      _setLoading(false);
      return false;
    }
  }

  /// Verifica el OTP y cambia la contraseña al nuevo valor.
  Future<bool> verificarOtpYCambiarContrasena({
    required String correo,
    required String otp,
    required String nuevaContrasena,
  }) async {
    // ERR-01: el error anterior no sobrevive a la nueva operación.
    _errorMessage = null;
    _setLoading(true);
    try {
      await _authService.verificarOtpYCambiarContrasena(
        correo: correo,
        otp: otp,
        nuevaContrasena: nuevaContrasena,
      );
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    }
  }

  /// Cambia la contraseña del usuario ya autenticado (desde perfil).
  Future<bool> cambiarContrasena(String nuevaContrasena) async {
    // ERR-01: el error anterior no sobrevive a la nueva operación.
    _errorMessage = null;
    _setLoading(true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: nuevaContrasena),
      );
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    }
  }

  // ── Utilidades privadas ────────────────────────────────────────────────────

  /// Centraliza el cambio de isLoading para no repetir notifyListeners().
  void _setLoading(bool value) {
    _isLoading = value;
    if (!value) _errorMessage = _errorMessage; // conserva el error si lo hay
    notifyListeners();
  }
}
