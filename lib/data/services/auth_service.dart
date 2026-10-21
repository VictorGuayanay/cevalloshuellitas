// auth_service.dart — Servicio de autenticación con Supabase.
//
// Gestiona:
//   - Registro con email/password
//   - Login con email/password
//   - Login con Google (OAuth)
//   - Recuperación y cambio de contraseña
//   - Subida de foto de perfil a Supabase Storage
//   - Lectura y actualización del perfil en la tabla `usuarios`

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';
import '../../supabase_config.dart';

class AuthService {
  // Cliente de Supabase: seam de inyección (TDD-03). El default evalúa el
  // singleton solo cuando NO se inyecta cliente — los tests que inyectan
  // uno jamás tocan Supabase.instance (escenario "Singleton default").
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // ── Registro ──────────────────────────────────────────────────────────────

  /// Registra un nuevo usuario en Supabase Auth y crea su perfil en `usuarios`.
  /// Retorna el UsuarioModel creado o lanza excepción si algo falla.
  Future<UsuarioModel> signUp({
    required String nombre,
    required String correo,
    required String password,
    String? telefono,
    String rol = 'usuario',
  }) async {
    // 1. Crear cuenta en Supabase Auth (tabla auth.users, gestionada por Supabase).
    final authResponse = await _client.auth.signUp(
      email: correo,
      password: password,
    );

    if (authResponse.user == null) {
      throw Exception('No se pudo crear la cuenta. Intenta de nuevo.');
    }

    final userId = authResponse.user!.id;

    // 2. Crear el perfil en nuestra tabla pública `usuarios`.
    await _client.from('usuarios').insert({
      'usua_id': userId,
      'usua_nombre': nombre,
      'usua_correo': correo,
      'usua_telefono': telefono,
      'usua_rol': rol,
    });

    // 3. Si se registra como veterinario, crear registro en tabla veterinarios.
    if (rol == 'veterinario') {
      await _crearPerfilVeterinarioSiNoExiste(userId);
    }

    return UsuarioModel(
      id: userId,
      nombre: nombre,
      correo: correo,
      telefono: telefono,
      rol: rol,
    );
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  /// Inicia sesión con email y contraseña.
  /// Retorna el UsuarioModel con los datos del perfil.
  Future<UsuarioModel> signIn({
    required String correo,
    required String password,
  }) async {
    final authResponse = await _client.auth.signInWithPassword(
      email: correo,
      password: password,
    );

    if (authResponse.user == null) {
      throw Exception('Credenciales inválidas.');
    }

    // Obtener el perfil completo desde la tabla `usuarios`.
    return getUserProfile(authResponse.user!.id);
  }

  /// Inicia sesión con Google usando el ID Token.
  ///
  /// Flujo:
  ///   1. Obtener cuenta Google del dispositivo
  ///   2. Obtener el ID Token de Google
  ///   3. Autenticar en Supabase con ese token
  ///   4. Si es la primera vez, crear el perfil en `usuarios`
  Future<UsuarioModel> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      serverClientId: googleWebClientId, // Web Client ID de Google Console
      scopes: ['email', 'profile'],
    );

    // Forzar selección de cuenta para evitar tokens cacheados corruptos.
    await googleSignIn.signOut();

    // Abrir el selector de cuenta de Google.
    GoogleSignInAccount? googleUser;
    try {
      googleUser = await googleSignIn.signIn();
    } catch (e) {
      throw Exception('Error al abrir Google: $e');
    }

    if (googleUser == null) {
      throw Exception('Inicio de sesión con Google cancelado.');
    }

    // Obtener las credenciales (idToken + accessToken).
    GoogleSignInAuthentication googleAuth;
    try {
      googleAuth = await googleUser.authentication;
    } catch (e) {
      throw Exception('Error obteniendo autenticación de Google: $e');
    }

    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw Exception(
        'No se pudo obtener el token de Google. '
        'Verifica que el Web Client ID en supabase_config.dart '
        'sea el OAuth de tipo "Aplicación web".',
      );
    }

    // Autenticar en Supabase usando el ID Token de Google.
    AuthResponse authResponse;
    try {
      authResponse = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );
    } catch (e) {
      throw Exception('Error autenticando en Supabase con Google: $e');
    }

    if (authResponse.user == null) {
      throw Exception(
        'Supabase no devolvió un usuario tras el login con Google.',
      );
    }

    final userId = authResponse.user!.id;
    final nombre = googleUser.displayName ?? googleUser.email.split('@').first;
    final correo = googleUser.email;

    // Verificar si ya existe el perfil en nuestra tabla `usuarios`.
    Map<String, dynamic>? existing;
    try {
      existing = await _client
          .from('usuarios')
          .select()
          .eq('usua_id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Error verificando perfil Google: $e');
      existing = null;
    }

    if (existing == null) {
      // Primera vez con Google → creamos el perfil.
      try {
        await _client.from('usuarios').insert({
          'usua_id': userId,
          'usua_nombre': nombre,
          'usua_correo': correo,
          'usua_telefono': null,
          'usua_rol': 'usuario',
        });
      } catch (e) {
        throw Exception(
          'No se pudo crear el perfil en la base de datos: $e. '
          'Verifica las políticas RLS de la tabla "usuarios" en Supabase.',
        );
      }

      return UsuarioModel(
        id: userId,
        nombre: nombre,
        correo: correo,
        rol: 'usuario',
      );
    }

    // Perfil ya existe → construirlo desde la BD.
    return UsuarioModel.fromJson(existing);
  }

  // ── Cierre de sesión ──────────────────────────────────────────────────────

  /// Cierra la sesión activa en Supabase Auth.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Perfil ────────────────────────────────────────────────────────────────

  /// Lee el perfil completo del usuario desde la tabla `usuarios`.
  Future<UsuarioModel> getUserProfile(String userId) async {
    final response = await _client
        .from('usuarios')
        .select()
        .eq('usua_id', userId)
        .single(); // lanza excepción si no existe
    return UsuarioModel.fromJson(response);
  }

  /// Actualiza los campos editables del perfil en la tabla `usuarios`.
  Future<void> updateUserProfile(
    String userId,
    String nombre,
    String telefono, {
    String? cedula,
    String? direccionGps,
    bool esProductor = false,
    String? tipoAnimales,
  }) async {
    await _client
        .from('usuarios')
        .update({
          'usua_nombre': nombre,
          'usua_telefono': telefono,
          'usua_cedula': cedula,
          'usua_direccion_gps': direccionGps,
          'usua_es_productor': esProductor,
          // Si no es productor, guardamos null para limpiar el tipo de animales.
          'usua_tipo_animales': esProductor ? tipoAnimales : null,
        })
        .eq('usua_id', userId);
  }

  /// Cambia el rol del usuario. Si es 'veterinario', crea su registro
  /// en la tabla veterinarios si aún no existe.
  Future<void> updateUserRol(String userId, String nuevoRol) async {
    await _client
        .from('usuarios')
        .update({'usua_rol': nuevoRol})
        .eq('usua_id', userId);

    if (nuevoRol == 'veterinario') {
      await _crearPerfilVeterinarioSiNoExiste(userId);
    }
  }

  /// Crea un registro básico en `veterinarios` si todavía no existe.
  /// Es privado porque solo lo llaman signUp y updateUserRol.
  Future<void> _crearPerfilVeterinarioSiNoExiste(String userId) async {
    try {
      final existing = await _client
          .from('veterinarios')
          .select('vete_id')
          .eq('usua_id', userId)
          .maybeSingle();
      if (existing == null) {
        await _client.from('veterinarios').insert({
          'usua_id': userId,
          'vete_disponible': true,
        });
      }
    } catch (e) {
      // No abortamos el flujo si esto falla; el admin puede crearlo manualmente.
      debugPrint('Error al crear perfil veterinario: $e');
    }
  }

  // ── Recuperación de contraseña ────────────────────────────────────────────

  /// Envía un código OTP al correo para recuperar la contraseña.
  Future<void> enviarRecuperacionContrasena(String correo) async {
    await _client.auth.resetPasswordForEmail(correo.trim());
  }

  /// Verifica el OTP recibido por email y luego actualiza la contraseña.
  /// Lanza excepción si el código es inválido o expiró.
  Future<void> verificarOtpYCambiarContrasena({
    required String correo,
    required String otp,
    required String nuevaContrasena,
  }) async {
    // 1. Verificar el OTP — esto crea una sesión temporal.
    final response = await _client.auth.verifyOTP(
      email: correo.trim(),
      token: otp.trim(),
      type: OtpType.recovery,
    );

    if (response.user == null) {
      throw Exception('Código inválido o expirado. Solicita uno nuevo.');
    }

    // 2. Con la sesión activa, actualizar la contraseña.
    await _client.auth.updateUser(UserAttributes(password: nuevaContrasena));
  }

  // ── Foto de perfil ────────────────────────────────────────────────────────

  /// Sube la foto de perfil al bucket 'usuarios_imagenes' de Supabase Storage.
  /// Actualiza el campo usua_foto_url en la tabla usuarios.
  /// Retorna la URL pública de la imagen.
  Future<String> subirFotoUsuario(
    String userId,
    File imagen,
    String extension,
  ) async {
    // Nombre de archivo único usando el ID del usuario y el timestamp actual.
    final fileName =
        '${userId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ruta = 'perfiles/$fileName';

    // Subir el archivo al bucket.
    await _client.storage
        .from('usuarios_imagenes')
        .upload(
          ruta,
          imagen,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    // Obtener la URL pública para mostrar la imagen en la UI.
    final String publicUrl = _client.storage
        .from('usuarios_imagenes')
        .getPublicUrl(ruta);

    // Guardar la URL en la tabla usuarios para que persista entre sesiones.
    await _client
        .from('usuarios')
        .update({'usua_foto_url': publicUrl})
        .eq('usua_id', userId);

    return publicUrl;
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  /// Retorna el ID del usuario autenticado actualmente, o null si no hay sesión.
  String? getCurrentUserId() => _client.auth.currentUser?.id;

  /// True si hay una sesión activa en Supabase Auth.
  bool get isAuthenticated => _client.auth.currentSession != null;
}
