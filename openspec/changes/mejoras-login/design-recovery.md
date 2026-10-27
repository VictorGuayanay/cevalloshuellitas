# Design — Recuperación de contraseña por enlace (deep link)

Documento complementario de `design.md` (fase S7). Mantiene sus costuras: seam de
`AuthService` en `AuthController`, listener único `authStates`, patrón de aviso
one-shot + `MyApp.navigatorKey`, y mapeo de errores centralizado en
`AuthErrorMapper`. Donde no se contradice explícitamente, `design.md` sigue
siendo la referencia.

---

## 1. Hechos verificados de las dependencias

Verificado directamente en el pub cache, no en documentación externa:

**supabase_flutter 2.15.0** (`lib/src/supabase_auth.dart`):

- `Supabase.initialize()` arranca `_startDeeplinkObserver()` internamente:
  suscribe `_handleIncomingLinks()` a `_appLinks.uriLinkStream` y luego llama
  `_handleInitialUri()`. **En móvil `_handleInitialUri()` es no-op**: el propio
  código comenta *"On mobile, the initial uri is included in the uriLinkStream"*
  (líneas 239-240). El link inicial de arranque en frío llega, por lo tanto,
  por el mismo `uriLinkStream` al que se suscribe el SDK.
- `_isAuthCallbackDeeplink(uri)` (líneas 181-190) empareja por **parámetros**,
  no por host: devuelve true si la query o el fragment contienen
  `access_token`, `code` o `error_description`. `huellitas://password-recovery?code=...`
  califica por el parámetro `code`; el host es para nuestro routing, no para
  el SDK.
- `_handleDeeplink(uri)` llama `getSessionFromUrl(uri)` (PKCE →
  `exchangeCodeForSession`) y, si lanza `AuthException`, la re-emite como error
  del stream vía `notifyException` (líneas 265-272). Es decir: **el fallo de
  intercambio llega a `onAuthStateChange` como error del stream**, que es
  exactamente donde hoy está nuestro `onError` en `initAuthListener`.
- El SDK persiste la sesión resultante automáticamente en `_onAuthStateChange`
  (líneas 172-178): una sesión de recuperación **queda persistida** al
  canjearse el código (ver caso E5, §9).

**gotrue 2.22.0** (`lib/src/gotrue_client.dart`):

- `resetPasswordForEmail(email, {redirectTo})` guarda el PKCE verifier
  etiquetado como `passwordRecovery` (línea 1006:
  `'$codeVerifier/${AuthChangeEvent.passwordRecovery.name}'`).
- `exchangeCodeForSession` emite `AuthChangeEvent.passwordRecovery` (líneas
  416-417 y 617) cuando el verifier almacenado era de recuperación; con un
  verifier normal emite `signedIn`. El tipo de evento lo decide el cliente, no
  el servidor.
- Sin verifier local (link abierto en otro dispositivo):
  `AuthPKCEGrantCodeExchangeError('Code verifier could not be found in local
  storage.')`.
- El flujo PKCE está fijado por defecto en `supabase_flutter`; no hay OTP en
  el flujo por enlace.

**app_links 6.4.1** (Android, `AppLinksPlugin.java`):

- Arranque en frío: `onAttachedToActivity()` captura el intent de lanzamiento
  (`handleIntent(binding.getActivity().getIntent())`), guarda `initialLink` y
  **lo re-emite en `onListen`** (líneas 133-137) cuando el Dart se suscribe.
  No hay carrera: el plugin retiene el link hasta que hay listener.
- En caliente: `onNewIntent()` → `handleIntent` → `eventSink.success(...)`
  con `launchMode="singleTop"` ya configurado en la Activity (manifest actual),
  así que el intent se entrega a la instancia viva sin recrearla.
- Intents con `FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY` (recents) se ignoran
  (líneas 166-169): reabrir desde recents no re-dispara el intercambio.

**Conclusión de la cadena**: no hace falta `getInitialLink()` manual, ni
parsing de URIs hecho a mano (RST-13 se respeta porque el SDK hace el
parseo/intercambio y nosotros sólo reaccionamos al evento `passwordRecovery`.

---

## 2. Arquitectura de navegación y cadena de eventos

### 2.1 Estado nuevo del controlador

En `AuthController`:

```dart
// true desde que llega `passwordRecovery` hasta que la recuperación se
// completa (signOut) o se consume el fallo. El Consumer raíz usa este flag
// para renderizar NuevaContrasenaScreen con prioridad sobre sesión/home.
bool _enModoRecuperacion = false;
bool get enModoRecuperacion => _enModoRecuperacion;

// Aviso one-shot (mismo patrón que _avisoDeCierrePendiente): el link llegó
// pero la sesión/código es inválido → UI resetea pila y muestra copy.
bool _avisoEnlaceInvalidoPendiente = false;
bool consumirAvisoEnlaceInvalido() { ... consume-once ... }
```

### 2.2 Matriz de eventos (extensión de la de `design.md`)

| Evento | Condición | Acción |
|---|---|---|
| `passwordRecovery` | siempre | `_enModoRecuperacion = true`; **NO** carga perfil (sesión transitoria); `notifyListeners()` |
| error del stream (`onError`) | `esFalloDeEnlaceRecuperacion(error)` (§6) | `_enModoRecuperacion = false`; `_avisoEnlaceInvalidoPendiente = true`; `_errorMessage = 'El enlace expiró o no es válido. Solicita uno nuevo.'`; `notifyListeners()` |
| error del stream | otro (red, refresh) | traza, sin mutar estado (como hoy) |
| `signedOut` | vía `logout()` normal | sin cambios |
| `signedOut` | post-recuperación | ver §4 (`_cerrandoSesionRecuperacion`) |

Cambio respecto de la matriz actual: la rama `passwordRecovery` actual (líneas
107-120 de `auth_controller.dart`) **carga el perfil**; pasa a no cargarlo.

### 2.3 Consumer raíz (`lib/main.dart`)

En el builder del `home:`, después del consume de cierre y antes de evaluar
`isAuthenticated`:

```dart
if (authController.consumirAvisoEnlaceInvalido()) {
  MyApp.programarResetDePila(forzarRuta: '/login');
}
if (authController.enModoRecuperacion) {
  return const NuevaContrasenaScreen(); // RST-DP-1(a): prioridad sobre sesión
}
if (authController.isInitializing) return const SplashScreen();
...
```

Rationale: renderizar en el `home:` (en vez de `pushNamed` desde el handler
del evento) resuelve el arranque en frío sin tocar `navigatorKey` cuando aún
no hay pila montada, y satisface RST-DP-1(a) (con sesión activa, el flag tiene
prioridad y la app muestra la pantalla de nueva contraseña). El reset de pila
sólo se programa para el caso en caliente (§2.4).

### 2.4 Navegación en caliente vs frío

- **Frío (app no corre)**: cadena §1 → evento `passwordRecovery` → flag →
  builder renderiza `NuevaContrasenaScreen` como home. Sin `navigatorKey`,
  sin `pushNamed`: no hay pila que resetear. El splash se salta porque
  `isInitializing` ya pudo resolverse o resolviéndose da igual — el check de
  `enModoRecuperacion` va **antes**.
- **Caliente (app en foreground/background)**: llega `onNewIntent` →
  `passwordRecovery` → flag true **y** hay pila con pantallas encima. El
  Consumer, al reconstruir, programa
  `MyApp.programarResetDePila(forzarRuta: '/nueva_contrasena')` vía
  `addPostFrameCallback` + `pushNamedAndRemoveUntil(..., (r) => false)`.
  La variante "forzada" difiere del `programarResetDePila()` actual: **no**
  exige `canPop()` (la guardia actual existe para SES-02 donde el root ya
  renderiza login; aquí la pila puede estar en raíz y aun así haber pantalla
  que desplazar si el home era home admin/usuario). Se implementa como
  parámetro opcional `{String ruta = '/login', bool forzar = false}` para no
  tocar la firma usada por SES-02.
- Ruta nombrada nueva `/nueva_contrasena` en el mapa de rutas (y
  `/recuperar_contrasena` para la pantalla extraída, ver §3).

### 2.5 Cadena verificada extremo a extremo

```
Tap en link del correo
→ Android resuelve intent-filter huellitas://password-recovery (VIEW/DEFAULT/BROWSABLE)
→ [frío] Activity creada, app_links guarda initialLink, lo emite al onListen
  [caliente] onNewIntent → eventSink.success(uri)
→ supabase_flutter: _handleDeeplink → _isAuthCallbackDeeplink (code presente) ✓
→ getSessionFromUrl → exchangeCodeForSession (verifier local) ✓
→ gotrue emite passwordRecovery (verifier etiquetado) sobre BehaviorSubject
→ AuthController._procesarEvento → enModoRecuperacion = true
→ Consumer raíz renderiza NuevaContrasenaScreen (frío) o resetea pila (caliente)
```

El replay del `BehaviorSubject` garantiza que el evento se entregue aunque el
suscrito se registre tarde respecto del emitido — sin esto el arranque en frío
tendría una carrera real; con esto, no.

---

## 3. Diseño de pantallas

### 3.1 `RecuperarContrasenaScreen` (refactor de `_RecuperarContrasenaScreen`)

- Se extrae de `login_screen.dart` (líneas 732+) a archivo público:
  `lib/presentation/screens/login/recuperar_contrasena_screen.dart`.
- **Un solo paso**: campo correo + botón "Enviar enlace". Sin campo OTP, sin
  paso 2, sin `_paso`, sin `_otpCtrl`.
- Valida formato de correo con la misma regex actual.
- Botón envía `auth.recuperarContrasena(correo)`; en éxito muestra copy de
  confirmación anti-enumeración (spec, mensaje M) y arranca el cooldown
  (ERR-07 se conserva tal cual, incluida la variante server-driven de
  `over_email_send_rate_limit`).
- Botón de reenvío bloqueado durante cooldown; label del contador pendiente de
  RST-DD-2.
- Vuelve con `Navigator.pop` al login (sigue siendo empujada desde
  `LoginScreen`).

### 3.2 `NuevaContrasenaScreen` (nueva)

- Archivo: `lib/presentation/screens/login/nueva_contrasena_screen.dart`.
- Campos: nueva contraseña + confirmar, con obscure toggle (patrón actual).
- Validación local: ≥6 caracteres (regla vigente) y coincidencia.
- Al enviar: `auth.restablecerContrasena(nueva)` (§4). En éxito: SnackBar de
  éxito "¡Contraseña actualizada correctamente!" (copy ya usado hoy, se
  conserva) + navegación a `/login` **ya garantizada por el signOut** del
  controlador (no hace falta pop manual: el Consumer renderiza login por
  `enModoRecuperacion=false` + sesión nula).
- Sin botón de "atras" a recuperación: esta pantalla sólo se llega por link.
  El back del sistema puede cerrar la app; no se navega a login manualmente
  porque la sesión transitoria seguiría viva (comportamiento aceptado, E5).
- Copys de error de enlace inválido/expirado: literals del spec (§6).

### 3.3 Fondo/ondas compartido

El painter de ondas de `LoginScreen` se extrae a
`lib/presentation/widgets/wave_background.dart` para reutilizarlo en las dos
pantallas sin duplicar el painter privado. `LoginScreen` lo usa vía el widget
compartido (refactor mecánico, sin cambio visual).

---

## 4. Controlador y servicio

### 4.1 `AuthService` (`lib/data/services/auth_service.dart`)

- `enviarRecuperacionContrasena(correo)` → pasa a enviar `redirectTo`:

  ```dart
  static const redirectRecuperacion = 'huellitas://password-recovery';
  Future<void> enviarRecuperacionContrasena(String correo) async {
    await _client.auth.resetPasswordForEmail(
      correo.trim(),
      redirectTo: redirectRecuperacion,
    );
  }
  ```

  La constante es la **fuente única** del string; el mismo valor debe
  registrarse en el Dashboard (§8) y vive junto al servicio, no en la UI.
- **Retiro**: `verificarOtpYCambiarContrasena` (líneas 305-323). No queda
  ningún caller en `lib/` tras el refactor de la pantalla (verificado con
  grep: sólo `login_screen.dart` y `auth_controller.dart`).
- **Nuevo**: `actualizarContrasenaSesionRecuperacion(String nueva)` →
  `_client.auth.updateUser(UserAttributes(password: nueva))`. Requiere sesión
  —la de recuperación creada por el intercambio— y no verifica OTP.

### 4.2 `AuthController` (`lib/domain/controllers/auth_controller.dart`)

- `restablecerContrasena(String nuevaContrasena)`:

  ```dart
  Future<bool> restablecerContrasena(String nueva) async {
    _errorMessage = null;                       // ERR-01
    _setLoading(true);
    try {
      await _authService.actualizarContrasenaSesionRecuperacion(nueva);
      _setLoading(false);
      await _cerrarSesionRecuperacion();        // signOut silencioso (RST-DP-2a)
      return true;
    } catch (e) {
      _errorMessage = AuthErrorMapper.map(e);
      _setLoading(false);
      return false;
    }
  }
  ```

- `_cerrarSesionRecuperacion()`:

  ```dart
  Future<void> _cerrarSesionRecuperacion() async {
    _enModoRecuperacion = false;
    _cerrandoSesion = true;   // reuse del one-shot de silencio de SES-02
    await _authService.signOut();
  }
  ```

  El `signedOut` resultante recorre la rama silenciosa existente (líneas
  85-93): sin mensaje de expiración, `_avisoDeCierrePendiente = true` y el
  Consumer ya sabe resetear a `/login`. Un solo mecanismo para dos flujos.
- **Retiro**: `verificarOtpYCambiarContrasena` del controlador (líneas
  489-514).
- `recuperarContrasena` no cambia de firma; sólo se reutiliza tal cual desde
  la pantalla un paso (cooldown intacto).

### 4.3 Recepción del fallo de intercambio (RST-09)

`initAuthListener` hoy traza y descarta errores del stream. Pasa a:

```dart
onError: (Object error) {
  if (AuthErrorMapper.esFalloDeEnlaceRecuperacion(error)) {
    _enModoRecuperacion = false;
    _avisoEnlaceInvalidoPendiente = true;
    _errorMessage = AuthErrorMapper.mensajeEnlaceInvalido; // literal del spec
    notifyListeners();
  } else {
    debugPrint('Stream de sesión (onAuthStateChange): $error');
  }
},
```

El Consumer consume el aviso → reset de pila forzado a `/login`, donde
`LoginScreen` ya sabe mostrar `auth.errorMessage` (mecanismo existente).

**Advertencia de scope**: si el usuario tenía sesión activa y toca un link
muerto, este camino lo manda a `/login` con mensaje y sin sesión (el signOut
no ocurre, pero el reset de pila sí). Es el comportamiento consistente con
"el enlace expiró, solicita uno nuevo"; se documenta en §9 (E4).

---

## 5. AndroidManifest

Nuevo intent-filter dentro de `.MainActivity` (que ya tiene
`launchMode="singleTop"`, necesario para la entrega en caliente):

```xml
<!-- Deep link de recuperación de contraseña: huellitas://password-recovery?code=... -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="huellitas"
        android:host="password-recovery" />
</intent-filter>
```

- `BROWSABLE` es lo que permite que el link desde el correo (app de correo,
  navegador) dispare la app; `DEFAULT` resuelve el intent explícito.
- Especificar `scheme` + `host` acota el filtro: `huellitas://otra-cosa` no
  abre la app.
- **Edge de arranque en frío**: cubierto por el buffer de `initialLink` de
  app_links (§1); no requiere atributos adicionales en el manifest. iOS
  (`Info.plist`, `CFBundleURLSchemes`) queda fuera de alcance por ahora (el
  LIVE gate es Android); se anota como deuda en §8.
- Riesgo de *link hijacking* documentado en §6.

---

## 6. Seguridad

| Amenaza | Tratamiento |
|---|---|
| Token/code en logs | Nuestro código no loguea la URI ni el `code`. Ojo: el propio `supabase_flutter` loguea `'handle deeplink uri: $uri'` a nivel `finest` con el logger `supabase.supabase_flutter` — nivel que **no** se imprime por defecto (el listener de `Supabase.initialize` sólo reenvía `>= INFO`, `supabase.dart:110`). No se configura logging adicional. |
| Enumeración de correos | `resetPasswordForEmail` responde igual para correo existente o no; copy M único y verbatim (spec). El error server-driven `over_email_rate_limit` sólo dispara el cooldown, no un copy distinto. |
| Sesión de recuperación colgando | Tras `updateUser` exitoso se hace `signOut` (RST-DP-2(a)): la sesión transitoria nunca queda viva tras completar el flujo. En caso de link inválido, no hay sesión creada que limpiar. |
| Link abierto en otro dispositivo (PKCE) | Falla con `AuthPKCEGrantCodeExchangeError`; mapeado al copy de enlace inválido. La limitación de mismo-dispositivo está aceptada (RST-DP-3, decisión del usuario). No se intenta workaround manual (RST-13 lo prohibe). |
| Link con sesión activa | RST-DP-1(a): se muestra la pantalla igual. `updateUser` opera sobre la sesión de recuperación vigente; después se cierra. El usuario activo que tocó el link termina en login — efecto documentado, no un leak. |
| *Intent hijacking* | El scheme `huellitas://` es de baja colisión (no es un scheme genérico como `https`), pero **no es exclusivo**: cualquier app que declare el mismo scheme+host podría registrar el intent. Mitigación documentada: host específico (`password-recovery`), copy de error neutral (un atacante que intercepte no aprende nada de otros usuarios), y el código PKCE es de un solo uso y de corta vida. Riesgo residual aceptado; la solución definitiva (App Links https) depende de tener dominio propio — backlog (RST-DD-3). |
| `AuthApiException` genérico | El allowlist del §6.1 no puede distinguir con certeza todos los códigos del servidor sin LIVE; se cubre el tipo (fallo de canje con código presente ⇒ enlace inválido), que es correcto semánticamente: si el canje falló, el enlace ya no sirve. |

### 6.1 `AuthErrorMapper`: funciones nuevas

- `static bool esFalloDeEnlaceRecuperacion(Object error)` → true para
  `AuthPKCEGrantCodeExchangeError` (siempre) y para `AuthApiException`
  durante el canje (el stream no da contexto de operación; se acepta el tipo
  como señal — el escenario en el que un `AuthApiException` viaja por el
  stream de auth y no es un fallo de enlace es marginal y el peor caso es un
  copy de "solicita uno nuevo" injusto, sin pérdida de datos).
  `AuthRetryableFetchException` (red/5xx) **no** califica: es transitorio y
  su copy debe ser el de conexión existente, no "el enlace expiró".
- `static const mensajeEnlaceInvalido = 'El enlace expiró o no es válido. Solicita uno nuevo.';`
- `static const mensajeSesionRecuperacionExpirada = 'Tu sesión de recuperación expiró. Solicita un enlace nuevo.';`

Ambos literales son del spec, verbatim (decisión de usuario). Para la sesión
expirada sin link inválido (E3): cuando `updateUser` falle por
`AuthSessionMissingException`/token expirado, el mapper rama a
`mensajeSesionRecuperacionExpirada`.

---

## 7. Estrategia de pruebas

### 7.1 Mapa por tier (RST-01…RST-13)

| Requisito | Tier | Archivo | Notas |
|---|---|---|---|
| RST-01 (evento navega a pantalla) | unit | `test/auth/auth_session_events_test.dart` | adaptar: `passwordRecovery` ahora setea `enModoRecuperacion` y NO carga perfil |
| RST-02 (link sin sesión) | unit | idem | sesión null + evento → flag true, sin crash |
| RST-03 (restablecer) | unit | nuevo `test/auth/restablecer_contrasena_test.dart` | éxito → `updateUser` llamado → `signOut` llamado (orden verificado con mock) |
| RST-04 (copy de error) | unit | `test/core/auth_error_mapper_test.dart` (extender) | `esFalloDeEnlaceRecuperacion` con cada tipo; literales exactos |
| RST-05 (una sola pantalla) | unit + grep gate | `auth_session_events_test.dart` | sin referencia a OTP/verifyOTP en `lib/` (ver §7.3) |
| RST-06 (E2E manual Android) | **LIVE** | manual | §7.2 |
| RST-07 (recuperación con sesión activa) | **LIVE** | manual | RST-DP-1(a) |
| RST-08 (link en otro dispositivo) | **LIVE** | manual | PKCE: mensaje de enlace inválido |
| RST-09 (link inválido/expirado) | unit (stream error) + **LIVE** | `auth_session_events_test.dart`: simular `addError` en `authStates` → consume-once + copy | |
| RST-10 (cooldown) | unit + UI | conservar `test/auth/recovery_cooldown_test.dart` y adaptar `recovery_cooldown_ui_test.dart` (quitar el paso OTP; el flujo es un paso) | ERR-07 intacto |
| RST-11 (mismo flujo con sesión) | widget | nuevo `test/presentation/nueva_contrasena_screen_test.dart` | `enModoRecuperacion` + sesión presente → Consumer muestra pantalla (widget test del builder con dobles) |
| RST-12 (sin efectos secundarios) | unit | `auth_session_events_test.dart` | no se suscriben mascotas/notifs, no se navega a home |
| RST-13 (sin parsing manual) | estático | grep: `code=` / `Uri.parse` de deep links sólo en SDK | regla de revisión |

### 7.2 Gates LIVE (requieren Dashboard + teléfono conectado)

Precondición: Redirect URL registrado, template con `{{ .ConfirmationURL }}`,
entrega de correo funcionando (ver bloqueo activo: los correos no llegan).

1. Solicitar enlace desde la app en el teléfono → abrir desde la app de
   correo → llega a `NuevaContrasenaScreen` (arranque en frío: app cerrada).
2. Repetir con la app en foreground (arranque en caliente).
3. Restablecer contraseña → login con la contraseña nueva.
4. RST-07: con sesión iniciada, tocar link → pantalla de nueva contraseña.
5. RST-08: tocar el mismo link en otro dispositivo → mensaje de enlace
   inválido (copia literal).
6. Link caducado (>1h) → mensaje de enlace inválido.
7. Reenviar dentro del cooldown → bloqueado; fuera → funciona.

### 7.3 Retiros/adaptaciones sancionados de tests

| Test | Acción |
|---|---|
| `test/auth/mocks.dart` (comentario línea 79) | actualizar comentario: sin verifyOTP |
| `test/presentation/recovery_cooldown_ui_test.dart` (paso 2 OTP, línea ~151) | retirar escenario de paso 2; el cooldown se prueba en el paso único |
| `test/auth/auth_session_events_test.dart` (SES-06 "Recovery OTP succeeds", línea ~346) | reemplazar por escenario de enlace: evento `passwordRecovery` → `enModoRecuperacion`, sin perfil |
| `test/auth/auth_service_test.dart` | retirar tests de `verificarOtpYCambiarContrasena`; adaptar `enviarRecuperacionContrasena` (verifica `redirectTo`) |
| Escenarios OTP en `test/auth/recovery_flow_scenarios_test.dart` (si existe equivalente) | retiro por decisión de usuario (spec, lista sancionada) |

### 7.4 Checklist del Dashboard (para el usuario)

- [ ] Auth → URL Configuration → agregar `huellitas://password-recovery` a
      Redirect URLs (exacto, sin slash final).
- [ ] Authentication → Email Templates → "Reset Password" → usar
      `{{ .ConfirmationURL }}` en el link (ver RST-DD-1 para la ventana
      dual).
- [ ] Confirmar que la entrega de correo funciona (hoy reportada como rota:
      bloquea todos los gates LIVE).

---

## 8. Rollout en dos pasos (app ↔ Dashboard)

La operación se parte en dos pasos independientes con degradación controlada:

**Paso A — Dashboard (previo, inerte para la app vieja)**
Registrar el Redirect URL. Sin template nuevo, el link del correo apunta al
site URL normal: nada cambia para los usuarios actuales. Riesgo: cero.

**Paso B — App (release Play Store)**
Con el intent-filter y el handler de `passwordRecovery`. Mientras el template
viejo siga activo, la app nueva no recibirá links (el flujo viejo por OTP
murió): recuperación **no disponible** en la ventana. Degradación: el usuario
que solicite enlace recibe el correo viejo (token suelto) y la pantalla de un
paso no ofrece dónde ponerlo — dead end. Mitigación: ventana corta, release
inmediato del Paso C.

**Paso C — Template (corte duro)**
Cambiar el template a `{{ .ConfirmationURL }}`. Degradación residual: los
usuarios con app **vieja** reciben un link que no pueden abrir (sin
intent-filter). Recuperación rota para desactualizados hasta actualizar.
Ventana aceptable: el usuario afectado ya está en la pantalla de login con
la alternativa "¿no puedes recuperar? contacta soporte" inexistente — se
acepta como deuda documentada (el flujo viejo muere por decisión de spec).

Orden recomendado: **A → B → C** en días consecuentes (A el mismo día del
registro del template previsto). C nunca antes de B.

---

## 9. Casos límite y edge cases

| # | Caso | Tratamiento |
|---|---|---|
| E1 | Link con app cerrada | §2.4 frío; buffer de app_links |
| E2 | Link con app en background | onNewIntent + reset de pila forzado |
| E3 | Link expirado/caducado | error del stream → allowlist §6.1 → copy literal + aviso one-shot |
| E4 | Link muerto con sesión activa | idem E3; el reset de pila manda a `/login` (scope aceptado y documentado, §4.3) |
| E5 | Usuario cierra la app a mitad del restablecimiento | La sesión de recuperación quedó persistida (§1): al reabrir, `tryRestoreSession` la restaura y el usuario entra a la app como autenticado. Es el comportamiento nativo de Supabase (una sesión de recuperación *es* una sesión). Mitigación futura (backlog): flag local "recuperación en curso" persistido en el evento y verificado en `tryRestoreSession`. Se documenta, no se implementa en S7 |
| E6 | Doble tap en el link | Dos eventos `passwordRecovery`; el flag es idempotente, la pantalla se renderiza una vez por reconstrucción; sin doble navegación (el reset usa `(r) => false` sobre la pila completa) |
| E7 | `updateUser` con sesión ya expirada | `AuthSessionMissingException` → copy de sesión de recuperación expirada (§6) |
| E8 | Reenviar enlace y usar el segundo | El verifier local se reemplaza en cada `resetPasswordForEmail`; el último enlace es el válido — comportamiento del SDK, sin acción |

---

## 10. Decisiones de diseño (con alternativas)

1. **Render en `home:` + flag de estado, no `pushNamed` desde el handler.**
   Alternativa: navegar vía `navigatorKey` desde `_procesarEvento`. Descartada:
   en frío no hay pila montada cuando el evento puede llegar (patrón
   DP-P2-1: navegar desde contexto no garantizado). El flag+builder replica
   el mecanismo de sesión existente y es testeable con widget tests.
2. **`signOut` post-`updateUser` reutilizando `_cerrandoSesion` (RST-DP-2a).**
   Alternativa: dejar la sesión temporal viva. Descartada por spec + riesgo
   de sesión con privilegios de recuperación persistida.
3. **`esFalloDeEnlaceRecuperacion` por tipo de excepción, con
   `AuthRetryableFetchException` excluda.** Alternativa: parsear códigos de
   error del cuerpo. Descartada: el stream no expone contexto y los códigos
   exactos del servidor requieren LIVE; el tipo es una señal correcta y
   conservadora (falso positivo = copy de "solicita uno nuevo", sin daño).
4. **Constante del redirect en `AuthService`.** Alternativa: en la UI o en
   config. Descartada: el valor debe calzar con el Dashboard y vive donde se
   hace la llamada que lo usa.
5. **Extraer pantalla y painter a archivos públicos** con rutas nombradas,
   en vez de dejarlas privadas en `login_screen.dart`: consistente con el
   patrón de pantallas del proyecto y habilita tests de widget directos.
6. **Cooldown conservado sin cambios** (ERR-07): el envío exitoso lo arranca,
   el rate-limit del servidor también; el enlace inválido no toca el cooldown
   (no hay intento autenticado).

---

## 11. Puntos de decisión abiertos (requieren validación)

- **RST-DD-1 — Orden del rollout (§8).** Recomendado: A → B → C (template
  dual opcional durante B: mantener el bloque OTP viejo junto al link para no
  dejar desamparados a los desactualizados; elimina la ventana de dead end a
  costa de un template más largo por días).
- **RST-DD-2 — Label del cooldown.** Recomendado: `Reintentar en N s` junto
  al botón; alternativa: sólo botón deshabilitado sin contador.
- **RST-DD-3 — App Links https (backlog).** Recomendado: dejar anotado como
  mejora futura cuando exista dominio; fuera de S7.

---

## 12. Trazabilidad

| Artefacto | Cubre |
|---|---|
| §2 | RST-01, RST-02, RST-12, RST-13 |
| §3 | RST-01 (UI), RST-05 |
| §4 | RST-03, RST-09 |
| §5 | RST-01 (Android), RST-13 |
| §6 | RST-04, RST-08, RST-11 |
| §7 | RST-06, RST-07, RST-08, RST-09, RST-10 |
| §8 | RST-11 (rollout) |

Afecta a `design.md`: extiende la matriz de eventos y el patrón de aviso
one-shot; no contradice decisiones vigentes. Afecta a `tasks.md`: nueva fase
S7 con las tareas derivadas de §3-§7 (SDD-T-04: el plan queda desglosado allí).
