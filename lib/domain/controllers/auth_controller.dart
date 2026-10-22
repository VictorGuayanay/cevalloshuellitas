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
      _errorMessage = 'Ocurrió un error. Intenta de nuevo.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
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
      _errorMessage = _mapAuthError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint('Error en login: $e');
      _errorMessage = 'Error inesperado: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Inicia sesión con Google.
  /// Retorna true si tuvo éxito, false si el usuario canceló o hubo error.
  Future<bool> loginWithGoogle() async {
    _setLoading(true);
    try {
      _currentUser = await _authService.signInWithGoogle();
      await _tokenPush.guardarToken(_currentUser!.id);
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      final msg = e.toString();
      // Si el usuario canceló el selector, no mostramos error.
      _errorMessage = msg.contains('cancelado')
          ? null
          : msg.replaceAll('Exception: ', '').replaceAll('exception: ', '');
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
      _errorMessage = _mapAuthError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint('Error en registro: $e');
      _errorMessage = 'Error al crear la cuenta: $e';
      _setLoading(false);
      return false;
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  /// Cierra la sesión: limpia el token FCM, cierra sesión en Supabase
  /// y resetea el estado local.
  Future<void> logout() async {
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
      _errorMessage = 'Error al subir la foto: $e';
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
      _errorMessage = 'Error al actualizar el perfil: $e';
      _setLoading(false);
      return false;
    }
  }

  /// Cambia el rol del usuario y actualiza el estado local.
  Future<bool> updateRol(String nuevoRol) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    try {
      await _authService.updateUserRol(_currentUser!.id, nuevoRol);
      _currentUser = _currentUser!.copyWith(rol: nuevoRol);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Error al cambiar el rol: $e';
      _setLoading(false);
      return false;
    }
  }

  // ── Recuperación de contraseña ─────────────────────────────────────────────

  /// Envía el OTP de recuperación al correo indicado.
  Future<bool> recuperarContrasena(String correo) async {
    _setLoading(true);
    try {
      await _authService.enviarRecuperacionContrasena(correo.trim());
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo enviar el correo. Verifica la dirección.';
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
      _errorMessage = _mapAuthError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Cambia la contraseña del usuario ya autenticado (desde perfil).
  Future<bool> cambiarContrasena(String nuevaContrasena) async {
    _setLoading(true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: nuevaContrasena),
      );
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _errorMessage = _mapAuthError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Error al cambiar la contraseña.';
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

  /// Traduce los mensajes de error de Supabase Auth al español.
  String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (message.contains('User already registered')) {
      return 'Este correo ya está registrado.';
    }
    if (message.contains('Password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Debes confirmar tu correo electrónico.';
    }
    return 'Error de autenticación: $message';
  }
}
