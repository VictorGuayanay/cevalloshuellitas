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

import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/usuario_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/fcm_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  // ── Estado interno ─────────────────────────────────────────────────────────
  bool _isLoading      = false; // true mientras hay operación en curso
  bool _isInitializing = true;  // true durante el splash inicial
  String? _errorMessage;        // null si no hay error
  UsuarioModel? _currentUser;   // null si no hay sesión

  // ── Getters públicos ────────────────────────────────────────────────────────
  bool get isLoading      => _isLoading;
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
      await FcmService.instance.guardarToken(_currentUser!.id);
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
      await FcmService.instance.guardarToken(_currentUser!.id);
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
      await FcmService.instance.guardarToken(_currentUser!.id);
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
    if (_currentUser != null) {
      // Quitar el token FCM para que el usuario no reciba más notificaciones.
      await FcmService.instance.limpiarToken(_currentUser!.id);
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
        await FcmService.instance.guardarToken(userId);
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
        _currentUser!.id, imagen, extension,
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
        _currentUser!.id, nombre, telefono,
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
        correo: correo, otp: otp, nuevaContrasena: nuevaContrasena,
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
