// token_push_port.dart — Puerto estrecho para el efecto push de FCM.
//
// DES-DP-1(a): aísla las llamadas estáticas a FcmService.instance dentro de
// AuthController para que los tests sean deterministas y offline (TDD-06):
// los tests inyectan un doble y jamás tocan Firebase; en producción el
// adaptador delega en FcmService.instance (comportamiento idéntico al de las
// llamadas estáticas anteriores). FcmService no se modifica.

import '../data/services/fcm_service.dart';

/// Contrato mínimo que AuthController necesita del lado de FCM:
/// persistir el token al autenticarse y limpiarlo al cerrar sesión.
abstract class TokenPushPort {
  /// Persiste el token FCM asociado a [userId] (mejor esfuerzo).
  Future<void> guardarToken(String userId);

  /// Elimina el token FCM asociado a [userId] (mejor esfuerzo).
  Future<void> limpiarToken(String userId);
}

/// Adaptador por defecto: delega en el singleton FcmService.instance.
/// AuthController lo usa cuando no se inyecta ningún puerto (producción).
class FcmTokenPushAdapter implements TokenPushPort {
  const FcmTokenPushAdapter();

  @override
  Future<void> guardarToken(String userId) =>
      FcmService.instance.guardarToken(userId);

  @override
  Future<void> limpiarToken(String userId) =>
      FcmService.instance.limpiarToken(userId);
}
