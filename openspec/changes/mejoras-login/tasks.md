# Tasks: Mejoras Login — Módulo de Autenticación (Fase 1)

> Change: `mejoras-login` · Written by `sdd-tasks`
> Inputs: `proposal.md`, `spec.md` (45 requirements), `design.md` (18 files, 11-step rollout), `openspec/config.yaml`.
> TDD: **enforced** (`sdd.tdd: true`) — validated against `sdd-testing` "Task Validation Criteria".
> Corporate skills: `project-standards` (80 % coverage, Conventional Commits), `sdd-testing` (RED/GREEN/REFACTOR, baseline protocol, loopholes L1–L8).
> **PATH RULE**: every file path below is relative to the project root.

## Protocol notes (binding for sdd-apply)

1. **Order**: Track A phases (1→4) execute first; Track B phases (5→9) are `BLOCKED-PENDING: supabase export`
   until the user delivers the Supabase Dashboard export (Open Question 1 / DP-1a / DP-2). Phase 10 mixes
   unblocked (Flutter) and blocked (SQL) verification tasks.
2. **Gates**: Phase 1 (baseline) must be fully green (`flutter test` exit 0) **before** any Phase 2+
   implementation begins. Each phase ends with exactly one Conventional Commit (design "Migration / Rollout").
3. **Batches**: `rules.apply.max_batch_size` is **not configured** in `openspec/config.yaml` (commented out) →
   conservative default of **≤ 5 task checkboxes per apply batch**, marked as `Batch Pn-a`, `Batch Pn-b`, …
4. **TDD step semantics**:
   - *Baseline* tasks (existing code) → test must PASS against unmodified code (`sdd-testing` Baseline Protocol).
   - *RED* tasks → exactly ONE test per cycle, must fail at an **assertion**. Exception documented as
     **DP-T1** below: for constructor-seam introduction the spec itself (TDD-02/TDD-03 scenarios) defines the
     RED as compile-level — allowed **only** for tasks 1.3/1.5 and 2.1 seams.
   - *Static-gate* tasks (dead-code removal / grep gates) → no runtime assertion exists; the gate is
     `grep`/`dart analyze` + full-suite-green, per spec's own "Static gate" row (SGN-08).
5. **Status legend**: `UNBLOCKED` · `BLOCKED-PENDING: supabase export` (+ explicit unblock criterion).

---

## Phase 1 — S1: Test baseline + injection seams + TokenPushPort (rollout step 1 · `test(auth):`)

Commit: `test(auth): baseline de pruebas TDD con seams de inyección, TokenPushPort y smoke test real`

- [x] 1.1 **BASELINE-RED** — Run `flutter test` on the untouched repo and record the failing default counter test as the TDD-01 red baseline (no code change).
  - **Files**: `test/widget_test.dart` (read-only this task)
  - **TDD step**: baseline capture — the suite FAILS today; this is the documented starting red (TDD-01 scenario "Red → green on the broken default test").
  - **Accepts**: TDD-01 (red half)
  - **Status**: UNBLOCKED
- [x] 1.2 **INFRA** — Add `mocktail: ^1.0.5` to `dev_dependencies` (DP-3 binding, design-verified pub.dev stable) and run `flutter pub get`. No production code touched.
  - **Files**: `pubspec.yaml`
  - **TDD step**: foundation (sdd-tasks Phase 1) — dependency is exercised by tasks 1.3+; analyzer green.
  - **Accepts**: TDD-04/TDD-05 tooling precondition
  - **Status**: UNBLOCKED
- [x] 1.3 **RED (DP-T1 seam exception)** — Create `test/auth/mocks.dart` (mocktail `MockAuthService`, `FakeTokenPushPort`, `UsuarioModel` builder) and the first test of `test/auth/auth_controller_test.dart`: construct `AuthController(authService: mockAuthService)` with stubbed `signIn`, invoke `login()`, `verify(() => mockAuthService.signIn(...))`.
  - **Files**: `test/auth/mocks.dart` (create), `test/auth/auth_controller_test.dart` (create)
  - **TDD step**: RED — fails until the constructor seam exists (spec TDD-02 scenario "Red first" explicitly defines this RED as compile/run failure; see DP-T1).
  - **Accepts**: TDD-02 scenario "Red first"
  - **Status**: UNBLOCKED
- [x] 1.4 **GREEN** — Add the optional constructor seam `AuthController({AuthService? authService})` defaulting to `AuthService()`; production wiring `AuthController()` in `lib/main.dart` untouched (static verification).
  - **Files**: `lib/domain/controllers/auth_controller.dart`, `lib/main.dart` (verify-only)
  - **TDD step**: GREEN for 1.3 — minimum code; then static check `AuthController()` still constructed argument-less in `lib/main.dart`.
  - **Accepts**: TDD-02 both scenarios (default path preserved via unchanged wiring)
  - **Status**: UNBLOCKED
- [x] 1.5 **RED (DP-T1 seam exception)** — First test in `test/auth/auth_service_test.dart`: construct `AuthService(client: mockSupabaseClient)` with stubbed `auth.signInWithPassword`, invoke `signIn()`, assert the profile query runs through the injected double (no `Supabase.instance` access).
  - **Files**: `test/auth/auth_service_test.dart` (create), `test/auth/mocks.dart` (extend: `MockSupabaseClient`, `MockGoTrueClient`, Postgrest `then`-stub helper + `registerFallbackValue` in `setUpAll`)
  - **TDD step**: RED — compile-level until the seam exists (TDD-03 scenario "Red first"). **S1 spike**: if awaiting the mocked `PostgrestBuilder` proves unworkable, apply the design's documented fallback (`@visibleForTesting` extraction) and record the deviation in `verification-log.md`.
  - **Accepts**: TDD-03 scenario "Red first"
  - **Status**: UNBLOCKED
- [x] 1.6 **GREEN** — Change `AuthService` to `final SupabaseClient _client; AuthService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;` (lazy default: tests passing a client never evaluate the singleton).
  - **Files**: `lib/data/services/auth_service.dart`
  - **TDD step**: GREEN for 1.5; guard assertion for TDD-03 scenario "Singleton default" reviewed statically (constructing `AuthService()` offline would touch the singleton — not unit-testable by design).
  - **Accepts**: TDD-03 both scenarios
  - **Status**: UNBLOCKED
- [x] 1.7 **RED** — In `auth_controller_test.dart`: successful `login()` must invoke `tokenPush.guardarToken(uid)` on a `FakeTokenPushPort` and must NOT touch `FcmService.instance` (offline determinism).
  - **Files**: `test/auth/auth_controller_test.dart`, `test/auth/mocks.dart` (`FakeTokenPushPort`)
  - **TDD step**: RED — assertion fails while the controller still calls `FcmService.instance.guardarToken(...)` directly (Firebase singleton throws offline).
  - **Accepts**: TDD-06 scenario "Suite runs offline", TDD-04 (FCM side effects isolated), DES-DP-1(a)
  - **Status**: UNBLOCKED
- [x] 1.8 **GREEN** — Create `lib/core/token_push_port.dart` (`abstract class TokenPushPort { Future<void> guardarToken(String userId); Future<void> limpiarToken(String userId); }` + `FcmTokenPushAdapter` delegating to `FcmService.instance`); inject `tokenPush ?? FcmTokenPushAdapter()` in `AuthController` and replace the direct static calls in `login`, `loginWithGoogle`, `register`, `tryRestoreSession`, `logout`.
  - **Files**: `lib/core/token_push_port.dart` (create), `lib/domain/controllers/auth_controller.dart`, `lib/data/services/fcm_service.dart` (untouched under DES-DP-1(a) adapter option)
  - **TDD step**: GREEN for 1.7 (minimum), then REFACTOR: identical test count/assertions, suite green.
  - **Accepts**: TDD-06, TDD-04, DES-DP-1(a)
  - **Status**: UNBLOCKED
- [x] 1.9 **BASELINE** — Add current-behavior baseline tests for `AuthController` (login ok, failed login → `'Correo o contraseña incorrectos.'`, Google cancel silent, logout state reset, `tryRestoreSession` ± session) — all must PASS against unmodified logic and become regression guards.
  - **Files**: `test/auth/auth_controller_test.dart`
  - **TDD step**: Baseline Protocol (existing code) — pass-before-implementation gate for Phase 2+.
  - **Accepts**: TDD-04 (baseline subset), TDD-01 (guard)
  - **Status**: UNBLOCKED
- [x] 1.10 **GREEN** — Replace `test/widget_test.dart` with the real smoke test (pumped `MaterialApp` + provider harness with a mocked `AuthController`; no counter assertions; no Firebase/Supabase/GoogleFonts network) → `flutter test` exits 0.
  - **Files**: `test/widget_test.dart`
  - **TDD step**: GREEN for TDD-01 — the meaningful-smoke assertion (scenario "Replacement smoke test is meaningful").
  - **Accepts**: TDD-01 both scenarios
  - **Status**: UNBLOCKED
- [x] 1.11 **VERIFY + COMMIT** — Run `flutter test` (full suite green, no pending timers/platform channels → TDD-06), `dart format`, `flutter analyze`; commit as `test(auth): …`.
  - **Files**: whole repo (no edits expected)
  - **TDD step**: gate — all Phase 1 baselines + reds now green (Phase 2 must not start before this passes).
  - **Accepts**: TDD-01, TDD-06
  - **Status**: UNBLOCKED

**Batches**: `P1-a` = 1.1–1.5 · `P1-b` = 1.6–1.10 · `P1-c` = 1.11.

---

## Phase 2 — S2: Global auth-state listener (rollout step 2 · `feat(auth):`)

Commit: `feat(auth): listener global onAuthStateChange con enrutamiento reactivo de sesión`

- [x] 2.1 **RED (DP-T1 seam exception)** — `test/auth/auth_session_events_test.dart`: controller built with a stubbed `authStates` stream (`StreamController<AuthState>`); call `initAuthListener()` twice → exactly ONE subscription; after `dispose()` the subscription is cancelled (no leak).
  - **Files**: `test/auth/auth_session_events_test.dart` (create), `test/auth/mocks.dart` (extend)
  - **TDD step**: RED — fails to compile/behave until the `authStates` seam + `initAuthListener()` exist (spec-defined seam RED).
  - **Accepts**: SES-01 scenario "Single subscription lifecycle"
  - **Status**: UNBLOCKED
- [x] 2.2 **GREEN** — Add `Stream<AuthState> get authStates => _client.auth.onAuthStateChange;` to `AuthService`; add idempotent `initAuthListener()` (`if (_authSub != null) return;`) and `dispose()` cancellation (with cooldown timer, added in Phase 3) to `AuthController`.
  - **Files**: `lib/data/services/auth_service.dart`, `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: GREEN for 2.1.
  - **Accepts**: SES-01
  - **Status**: UNBLOCKED
- [x] 2.3 **RED** — Drive a simulated `signedOut` after a successful login: assert `currentUser == null`, `errorMessage` equals `'Tu sesión ha expirado. Inicia sesión de nuevo.'`, and listeners notified — currently the controller state does not change (SES-01 "Red first" scenario).
  - **Files**: `test/auth/auth_session_events_test.dart`
  - **TDD step**: RED — assertion failure (state unchanged).
  - **Accepts**: SES-02 scenario "Session revoked while using the app" (state half)
  - **Status**: UNBLOCKED
- [x] 2.4 **GREEN** — Implement `_procesarEvento(AuthState)` handling for `signedOut`: silent clear when `_cerrandoSesion` flag set by `logout()`, otherwise clear + session message; post-frame `pushNamedAndRemoveUntil('/login', …)` only when `navigatorKey.currentState.canPop()` (stack reset wired in `lib/main.dart`).
  - **Files**: `lib/domain/controllers/auth_controller.dart`, `lib/main.dart`
  - **TDD step**: GREEN for 2.3 (minimum: state handling first; navigation wiring asserted via the design's `canPop()` guard in 2.11).
  - **Accepts**: SES-02 both scenarios (incl. "Query failures no longer strand a dead session" once the stream `onError` handler exists — 2.9)
  - **Status**: UNBLOCKED
- [x] 2.5 **RED** — Simulated `signedIn` for a profile with `usua_rol = 'administrador'` → assert profile loaded and role exposed so the root `Consumer` renders `AdminScreen`; second case `usua_rol = 'usuario'` → `HomeScreen`.
  - **Files**: `test/auth/auth_session_events_test.dart`
  - **TDD step**: RED — profile not loaded on event today.
  - **Accepts**: SES-03 scenario "Role-based routing after event"
  - **Status**: UNBLOCKED
- [x] 2.6 **GREEN** — `signedIn` handler: load profile via `AuthService.getUserProfile`; on not-found (`PostgrestException` PGRST116) clear `currentUser` and surface the mapped recoverable error — no crash, no silent loop.
  - **Files**: `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: GREEN for 2.5; then RED for SES-03 scenario "Signed-in event for a user whose profile row is missing" → GREEN by extending the same handler (separate cycle).
  - **Accepts**: SES-03 both scenarios, SGN-06 (residual orphan detectable)
  - **Status**: UNBLOCKED
- [x] 2.7 **RED** — Emit repeated `tokenRefreshed`: assert screen state unchanged, `isInitializing` stays `false`, profile fetched at most once per refresh. *(Resultado: BASELINE — pasó a la primera; la premisa "handler naive re-fetcha" no aplica a este codebase, guarda de regresión registrada en `test/auth/auth_session_events_test.dart`.)*
  - **Files**: `test/auth/auth_session_events_test.dart`
  - **TDD step**: RED — current/naive handler re-fetches or mutates state.
  - **Accepts**: SES-04
  - **Status**: UNBLOCKED
- [x] 2.8 **GREEN** — `tokenRefreshed` → explicit no-op in `_procesarEvento`.
  - **Files**: `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: GREEN for 2.7.
  - **Accepts**: SES-04
  - **Status**: UNBLOCKED
- [x] 2.9 **RED** — `userUpdated` → `currentUser` re-fetched from profile source.
  - **Files**: `test/auth/auth_session_events_test.dart`
  - **TDD step**: RED — assertion fails (profile not refreshed).
  - **Accepts**: SES-05
  - **Status**: UNBLOCKED
- [x] 2.10 **GREEN** — Implement `userUpdated` handler; also implement stream `onError` (`debugPrint` only, never mutates state) per design event matrix.
  - **Files**: `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: GREEN for 2.9 + design §event matrix (onError must be provided — verified supabase API fact; unhandled stream errors crash).
  - **Accepts**: SES-05, SES-02 (offline must not fake a logout)
  - **Status**: UNBLOCKED
- [x] 2.11 **RED → GREEN** — Recovery/startup cycle: (a) RED `passwordRecovery` with active session → profile loaded, app no longer shows a logged-out `LoginScreen` with a live session; GREEN implements the handler (never force-navigates); (b) RED `passwordRecovery` with null session → stays on login with mapped message, no crash; (c) RED `initialSession` while `isInitializing == true` → ignored (exactly one profile load, splash dismisses once); GREEN implements the guard.
  - **Files**: `test/auth/auth_session_events_test.dart`, `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: three separate RED→GREEN cycles (one test each, sequential).
  - **Accepts**: SES-06 both scenarios, SES-07
  - **Status**: UNBLOCKED
- [x] 2.12 **WIRE + VERIFY + COMMIT** — `lib/main.dart`: `AuthController()..initAuthListener()..tryRestoreSession()`; assert the `signedOut` stack reset runs post-frame only when `canPop()`; run FULL suite (Phase 1 baseline guards must stay green); commit `feat(auth): …`.
  - **Files**: `lib/main.dart`, all `test/auth/*`
  - **TDD step**: regression gate — baseline tests (1.9) unchanged and green; REFACTOR only structural edits.
  - **Accepts**: SES-01…SES-07, MODIFIED "Session detection"
  - **Status**: UNBLOCKED

**Batches**: `P2-a` = 2.1–2.5 · `P2-b` = 2.6–2.10 · `P2-c` = 2.11–2.12.

---

## Phase 3 — S4: Error mapping + stale-error cleanup + cooldown (rollout step 3 · `feat(auth):`)

Commit: `feat(auth): mapeo centralizado de errores de auth, limpieza de errores y cooldown de reenvío`

- [x] 3.1 **RED → GREEN** — `test/auth/auth_error_mapper_test.dart`: unmapped `Object()` → exactly `'Ocurrió un error. Intenta de nuevo.'` with denylist assertion (no `Exception|SocketException|Postgrest|Error inesperado|attempt(|rate limit|over_email_send`). GREEN: create `lib/core/auth_error_mapper.dart` with `static String? map(Object error)` + fallback branch only.
  - **Files**: `test/auth/auth_error_mapper_test.dart` (create), `lib/core/auth_error_mapper.dart` (create)
  - **TDD step**: RED assertion on fallback + denylist.
  - **Accepts**: ERR-06 both scenarios, REMOVED "Raw exception leakage to the UI"
  - **Status**: UNBLOCKED
- [x] 3.2 **RED → GREEN** — Rate-limit: `AuthException('…over_email_send_rate_limit…')` → Spanish wait message, raw token absent from output. GREEN: allowlist entry.
  - **Files**: `test/auth/auth_error_mapper_test.dart`, `lib/core/auth_error_mapper.dart`
  - **TDD step**: RED assertion (ERR-02 scenario "Rate-limited recovery email").
  - **Accepts**: ERR-02
  - **Status**: UNBLOCKED
- [x] 3.3 **RED → GREEN** — Lockout: `For security purposes, you have 3 attempts left before being locked` → `'Quedan 3 intentos antes de bloquear la cuenta.'`, no raw English sentence. GREEN: regex extraction branch.
  - **Files**: `test/auth/auth_error_mapper_test.dart`, `lib/core/auth_error_mapper.dart`
  - **TDD step**: RED assertion (ERR-03 scenario "Lockout warning with count").
  - **Accepts**: ERR-03
  - **Status**: UNBLOCKED
- [x] 3.4 **RED → GREEN** — Network: `SocketException`/`TimeoutException`/`ClientException` → Spanish connectivity message with no technical strings. GREEN: connectivity branch.
  - **Files**: `test/auth/auth_error_mapper_test.dart`, `lib/core/auth_error_mapper.dart`
  - **TDD step**: RED assertion (ERR-04 scenario "Login with no connectivity").
  - **Accepts**: ERR-04
  - **Status**: UNBLOCKED
- [x] 3.5 **RED → GREEN** — OAuth: Google cancel marker (`'cancelado'`) → `null` (silent); missing idToken → Spanish Web-Client-ID message; `signInWithIdToken` `AuthException` → mapped Spanish. GREEN: Google branches + existing 4 messages kept verbatim.
  - **Files**: `test/auth/auth_error_mapper_test.dart`, `lib/core/auth_error_mapper.dart`
  - **TDD step**: two cycles (cancel-silence, then failure mapping).
  - **Accepts**: ERR-05 both scenarios, ERR-01 scenario "Google cancel leaves no residue"
  - **Status**: UNBLOCKED
- [x] 3.6 **RED → GREEN** — `PostgrestException` code `PGRST116` → profile-not-found Spanish message. GREEN: branch 4 of mapper.
  - **Files**: `test/auth/auth_error_mapper_test.dart`, `lib/core/auth_error_mapper.dart`
  - **TDD step**: RED assertion.
  - **Accepts**: SES-03 (orphan detectable), SGN-06 scenario "Residual orphan is detected, not looped"
  - **Status**: UNBLOCKED
- [x] 3.7 **RED → GREEN** — Stale-error: after a failed `login()` leaves `errorMessage`, invoking any operation clears it at start (assert `errorMessage == null` synchronously after entry); Google cancel after a prior error leaves no residue. GREEN: `_errorMessage = null` at entry of `login`, `loginWithGoogle`, `register`, `recuperarContrasena`, `verificarOtpYCambiarContrasena`, `logout`, `updateProfile`, `cambiarContrasena` (`updateRol` too — still present until Phase 8).
  - **Files**: `test/auth/auth_controller_test.dart`, `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: RED assertions (ERR-01 both scenarios).
  - **Accepts**: ERR-01
  - **Status**: UNBLOCKED
- [x] 3.8 **RED → GREEN** — Controller integration: delete `_mapAuthError`; every catch routes through `AuthErrorMapper.map(e)`; table-driven security lint over representative raw messages (incl. SQL errors) asserts allowlisted Spanish output. GREEN: replace passthroughs (`'Error inesperado: $e'`, `'Error al crear la cuenta: $e'`, `e.toString()`).
  - **Files**: `test/auth/auth_error_mapper_test.dart`, `test/auth/auth_controller_test.dart`, `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: RED assertion on the table-driven lint (ERR-06 scenario "Security lint on the mapping").
  - **Accepts**: ERR-06, MODIFIED "Auth error surfacing"
  - **Status**: UNBLOCKED
- [x] 3.9 **RED → GREEN** — Cooldown clock: with `fakeAsync`, after `recuperarContrasena` success assert disabled + `30 s` remaining at 0 s and 30 s, enabled at 61 s, and NO pending timer at test end. GREEN: `static const Duration cooldownReenvio = Duration(seconds: 60)` (SP-DP-1), `Timer.periodic(1 s)` decrement, `cooldownRestante`/`puedeReenviarCodigo`/`iniciarCooldownReenvio()`, cancelled in `dispose()`.
  - **Files**: `test/auth/recovery_cooldown_test.dart` (create), `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: RED assertions (ERR-07 scenarios 1 and 3).
  - **Accepts**: ERR-07, SP-DP-1
  - **Status**: UNBLOCKED
- [x] 3.10 **RED → GREEN** — Server-driven cooldown: `resetPasswordForEmail` throws `over_email_send_rate_limit` → mapped banner (ERR-02) AND cooldown starts. GREEN: `recuperarContrasena` error path calls `iniciarCooldownReenvio()`.
  - **Files**: `test/auth/recovery_cooldown_test.dart`, `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: RED assertion (ERR-07 scenario "Server-driven cooldown").
  - **Accepts**: ERR-07 scenario 2, ERR-02
  - **Status**: UNBLOCKED
- [x] 3.11 **RED → GREEN** — Widget: recovery screen "Enviar código" disabled while `!puedeReenviarCodigo` with label `'Reenviar en N s'`; banner wrapped in `Semantics(liveRegion: true)`; touched colors migrated to `AppColors.red/redDark/redBg`; resend link touch target ≥ 44 px. GREEN: `login_screen.dart` edits.
  - **Files**: `test/presentation/recovery_cooldown_ui_test.dart` (create), `lib/presentation/screens/login/login_screen.dart`
  - **TDD step**: RED widget assertions; also verify banner contrast ≥ 4.5:1 manually (design UI/UX — "do not assume").
  - **Accepts**: ERR-07 (UI affordance), project-ui-ux R1/R3/R4 as scoped in design
  - **Status**: UNBLOCKED
- [x] 3.12 **VERIFY + COMMIT** — Full suite green (`flutter test`), no pending timers, `flutter analyze`, `dart format`; commit `feat(auth): …`.
  - **Files**: no edits expected
  - **TDD step**: regression gate (baseline guards 1.9 intact).
  - **Accepts**: ERR-01…ERR-07
  - **Status**: UNBLOCKED

**Batches**: `P3-a` = 3.1–3.5 · `P3-b` = 3.6–3.10 · `P3-c` = 3.11–3.12.

---

## Phase 4 — S3-client: Signup client prep (rollout step 4 · `feat(auth):`)

Commit: `feat(auth): signUp envía metadata de perfil e INSERT duplicado-tolerante`

> Pre-trigger this phase is inert server-side (metadata ignored, no duplicate possible yet) — this IS the
> SGN-10 out-of-order guarantee.

- [ ] 4.1 **RED → GREEN** — Capture `auth.signUp` args: `data` contains `nombre = 'Ana Torres'` and `telefono = '0991'`, and contains **no role field**. GREEN: `signUp` passes `data: {'nombre': …, 'telefono': …}` (the `rol` parameter stays for the transitional INSERT and is NEVER put into `data:`; full param removal = Phase 8, DES-DP-3).
  - **Files**: `test/auth/auth_service_test.dart`, `lib/data/services/auth_service.dart`
  - **TDD step**: RED assertion (SGN-01 scenario "Metadata payload").
  - **Accepts**: SGN-01, TDD-05 scenario "signUp sends profile metadata"
  - **Status**: UNBLOCKED
- [ ] 4.2 **RED → GREEN** — Email flow duplicate tolerance: stubbed INSERT throws `PostgrestException(code: '23505')` → `signUp` still returns the `UsuarioModel`; stubbed `42501` (RLS) → still surfaces. GREEN: wrap only the profile INSERT, swallow **exactly** `code == '23505'`.
  - **Files**: `test/auth/auth_service_test.dart`, `lib/data/services/auth_service.dart`
  - **TDD step**: RED assertions (SGN-07 scenario "Duplicate insert during phase (a)" + negative case).
  - **Accepts**: SGN-07
  - **Status**: UNBLOCKED
- [ ] 4.3 **RED → GREEN** — Google flow duplicate tolerance: first-time Google sign-in where the profile INSERT returns `23505` (trigger already live) → returns success; existing-profile read path unchanged. GREEN: same narrow swallow around the Google INSERT; keep the `SELECT`-first read.
  - **Files**: `test/auth/auth_service_test.dart`, `lib/data/services/auth_service.dart`
  - **TDD step**: RED assertion (SGN-04 scenario "Google first-time sign-in" client half + SGN-07).
  - **Accepts**: SGN-04 (client), SGN-07
  - **Status**: UNBLOCKED
- [ ] 4.4 **BASELINE** — Registration lands in the authenticated app: `register()` success → `isAuthenticated == true`, no bounce to `LoginScreen`. If it passes against current code → record as BASELINE (current behavior guard); only if it fails write the RED→GREEN cycle.
  - **Files**: `test/auth/auth_controller_test.dart`
  - **TDD step**: baseline-first per `sdd-testing` (a test that passes immediately is a baseline, not a RED).
  - **Accepts**: SGN-09
  - **Status**: UNBLOCKED
- [ ] 4.5 **VERIFY + COMMIT** — Out-of-order guard: assert the client profile INSERT is still present (transitional) while `data:` metadata ships; full suite green; commit `feat(auth): …`.
  - **Files**: `lib/data/services/auth_service.dart` (verify), `test/auth/*`
  - **TDD step**: static/behavioral guard for SGN-10 scenario "Out-of-order protection".
  - **Accepts**: SGN-10, SGN-01, SGN-07
  - **Status**: UNBLOCKED

**Batches**: `P4-a` = 4.1–4.4 · `P4-b` = 4.5.

---

## Phase 5 — S6: Baseline migration intake (rollout step 6 · `chore(db):`)

**ALL tasks: `BLOCKED-PENDING: supabase export`** — unblock criterion for the phase: *user delivers the
Supabase Dashboard export (schema DDL + RLS policies + triggers + indexes + views + Auth settings), schema-only
sanitization performed by the user (DP-1a)*.

- [ ] 5.1 **INTAKE** — Receive and hold the export as the authoring reference; confirm it covers every construct needed by S3/S5 (no authoring from the inferred map in exploration §3.1).
  - **Files**: export kept as local reference (NOT committed verbatim); `openspec/changes/mejoras-login/proposal.md` (dependency note update)
  - **TDD step**: provenance precondition (every later migration construct must trace to this export).
  - **Accepts**: BAS-01
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 5.2 **SANITIZE + GATE** — Strip to schema-only: grep gates `INSERT INTO`, `COPY `, `eyJ` (JWTs), real emails/PII → zero matches; no service-role/anon keys, no storage object data.
  - **Files**: export (working copy)
  - **TDD step**: static hygiene gate (BAS-02 scenario "Hygiene gate") — no unit test applies; DB red-green lives in Phase 6.
  - **Accepts**: BAS-02, SEC-07 scenario "Destructive-statement gate"
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 5.3 **COMMIT + SPOT-CHECK** — Commit sanitized baseline as `supabase/migrations/20261021000001_baseline_schema.sql` (`chore(db):`); spot-check tables/columns/policies against the live Dashboard; record and correct ANY discrepancy BEFORE S5 authoring; `git status` clean of export artifacts.
  - **Files**: `supabase/migrations/20261021000001_baseline_schema.sql` (create)
  - **TDD step**: verification (BAS-03 both scenarios).
  - **Accepts**: BAS-03, DP-1a
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 5.4 **SETTINGS SNAPSHOT** — Record live Auth settings: email confirmation = OFF (binding), OTP expiry, rate limits, recovery template `{{ .Token }}` presence; if confirmation re-enabled or template lacks token → escalate DP-4/SGN-11.
  - **Files**: `openspec/changes/mejoras-login/auth-settings-snapshot.md` (create)
  - **TDD step**: verification (BAS-04 scenario "Settings snapshot exists").
  - **Accepts**: BAS-04, SGN-11 precondition, DP-4 trigger condition
  - **Status**: `BLOCKED-PENDING: supabase export`

**Batches**: `P5-a` = 5.1–5.2 · `P5-b` = 5.3–5.4.

---

## Phase 6 — verify/ scripts + RED run (rollout step 7 · `test(db):`)

**ALL tasks: `BLOCKED-PENDING: supabase export`** — unblock criteria: Phase 5 complete (baseline committed) AND
baseline discrepancy check clean. Scripts are committed first and executed as the DB red cycle (VER-01).

- [ ] 6.1 **RED (harness smoke FIRST)** — Author `supabase/migrations/verify/00_smoke.sql`: `set local role authenticated` check, fake `request.jwt.claims` → `auth.uid()` returns fake `sub`, catalog reads work, probe insert into `auth.users` with `HARNESS-UNSUPPORTED: …` outcome (distinct from requirement failure; fallback = manual signup test documented in header).
  - **Files**: `supabase/migrations/verify/00_smoke.sql` (create)
  - **TDD step**: RED/harness preflight per design verification protocol step 1 — ALWAYS run before any other script.
  - **Accepts**: VER-01 (protocol), design Open Question (Dashboard `auth.users` insert probe)
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 6.2 **RED** — Author `verify/01_sgn02_handle_new_user.sql` (profile created for synthetic auth user; rollback-blast-radius note in header).
  - **Files**: `supabase/migrations/verify/01_sgn02_handle_new_user.sql` (create)
  - **TDD step**: RED — fails pre-migration (no trigger → no profile row).
  - **Accepts**: SGN-02 scenario "Migration verified red-then-green", VER-01
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 6.3 **RED** — Author `verify/02_sgn03_sgn05_signup_rol_metadata.sql`: malicious `data:{rol:'administrador'}` → stored rol `'usuario'`; OAuth metadata without `nombre` → non-empty fallback name, null telefono.
  - **Files**: `supabase/migrations/verify/02_sgn03_sgn05_signup_rol_metadata.sql` (create)
  - **TDD step**: RED pre-migration.
  - **Accepts**: SGN-03 both scenarios, SGN-05, VER-01
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 6.4 **RED** — Author `verify/03_sec01_rls_audit.sql`: `pg_class.relrowsecurity = true` for every baseline table; `pg_policies` inventory; anon denied on `usuarios`.
  - **Files**: `supabase/migrations/verify/03_sec01_rls_audit.sql` (create)
  - **TDD step**: RED pre-migration.
  - **Accepts**: SEC-01 both scenarios, VER-01
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 6.5 **RED** — Author `verify/04_sec02_sec03_role_writes.sql`: non-admin self-promotion rejected; promote-other rejected; admin allowed; service-role allowed; invalid value `'superadmin'` rejected; policy-dropped backstop (owner-context bypass) still blocked by trigger.
  - **Files**: `supabase/migrations/verify/04_sec02_sec03_role_writes.sql` (create)
  - **TDD step**: RED pre-migration (records current permissive behavior).
  - **Accepts**: SEC-02 both scenarios, SEC-03 three scenarios, VER-01
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 6.6 **RED** — Author `verify/05_sec04_admin_paths.sql`: admin direct role change updates exactly 1 row; vet-request approval flow end-to-end.
  - **Files**: `supabase/migrations/verify/05_sec04_admin_paths.sql` (create)
  - **TDD step**: RED/parity — records current behavior (must stay working post-migration → green means "unchanged/allowed").
  - **Accepts**: SEC-04 both scenarios, VER-01
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 6.7 **RED** — Author `verify/06_sec05_sec06_usuarios_policies.sql`: authenticated INSERT rejected (post-cutover), own-profile update affects 1 row, other-user update affects 0 rows.
  - **Files**: `supabase/migrations/verify/06_sec05_sec06_usuarios_policies.sql` (create)
  - **TDD step**: RED pre-migration.
  - **Accepts**: SEC-05, SEC-06 both scenarios, VER-01
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 6.8 **RED** — Author `verify/07_sec08_solicitudes_rol.sql`: plain user INSERT own `solicitudes_rol` (`pendiente`) succeeds; role unchanged until admin approval.
  - **Files**: `supabase/migrations/verify/07_sec08_solicitudes_rol.sql` (create)
  - **TDD step**: RED/parity pre-migration.
  - **Accepts**: SEC-08, VER-01
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 6.9 **COMMIT + RECORD RED** — Commit scripts `test(db): scripts de verificación SQL para RLS y trigger de signup`; run `00_smoke` then `01…07` in the Dashboard SQL editor (DP-2) and record every RED result in `openspec/changes/mejoras-login/verification-log.md`.
  - **Files**: `supabase/migrations/verify/*.sql`, `openspec/changes/mejoras-login/verification-log.md` (create)
  - **TDD step**: RED recording (VER-01 scenario "Red before migration"); script defect vs requirement gap distinguished by `00_smoke`.
  - **Accepts**: VER-01, SP-DP-3
  - **Status**: `BLOCKED-PENDING: supabase export`

**Batches**: `P6-a` = 6.1–6.5 · `P6-b` = 6.6–6.9.

---

## Phase 7 — S3 migration: `handle_new_user` trigger (rollout step 8 · `chore(db):`)

**BLOCKED-PENDING: supabase export** — unblock criteria: Phase 5 complete AND Phase 6 scripts recorded RED AND
`00_smoke` probe OK (else manual-signup fallback per design Open Questions).

- [ ] 7.1 **AUTHOR** — `supabase/migrations/20261021000002_handle_new_user.sql` exactly per design DB section: `handle_new_user()` (`security definer`, `set search_path = ''`, fully-qualified `public.usuarios`, `usua_rol` literal `'usuario'`, `on conflict (usua_id) do nothing`, `nombre`/`telefono` null-trim + email-local-part fallback, NO `EXCEPTION` handler) + `on_auth_user_created` trigger; header with purpose, requirement IDs, exact rollback (`drop trigger if exists on_auth_user_created on auth.users; drop function if exists public.handle_new_user();`) and its prerequisite (client INSERT must be restored first).
  - **Files**: `supabase/migrations/20261021000002_handle_new_user.sql` (create)
  - **TDD step**: RED evidence = Phase 6 scripts 01/02 already recorded red; every construct traces to the export (BAS-01).
  - **Accepts**: SGN-02, SGN-03, SGN-04, SGN-05
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 7.2 **REVIEW GATE** — Manual SQL review against the checklist: no destructive statements, no secrets/PII, no `EXCEPTION` handler, defensive defaults, idempotent re-paste (`drop trigger if exists` + `create or replace function`), blast radius (failing trigger blocks signups) explicitly accepted.
  - **Files**: `supabase/migrations/20261021000002_handle_new_user.sql`
  - **TDD step**: SEC-07 destructive-gate checklist (scenario "Destructive-statement gate").
  - **Accepts**: SEC-07, SGN-02 scenario "Trigger failure blocks signup (documented blast radius)"
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 7.3 **APPLY + GREEN** — Paste migration #1 in Dashboard (DP-2); re-run `00` + `01` + `02` → GREEN; manual end-to-end signup on a throwaway account (profile row exists, rol `'usuario'`, no client INSERT involved — client INSERT gets `23505` and is swallowed per 4.2/4.3); record GREEN in `verification-log.md`.
  - **Files**: `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: GREEN cycle (VER-01 scenario "Green after migration"), SGN-02 scenario "Email signup creates profile server-side".
  - **Accepts**: SGN-02, SGN-04, SGN-06 (orphan impossible once live), SEC-07
  - **Status**: `BLOCKED-PENDING: supabase export`

**Batches**: `P7-a` = 7.1–7.2 · `P7-b` = 7.3.

---

## Phase 8 — S5: RLS + `usua_rol` trigger + DES-DP-3 role-chain removal (rollout steps 5 + 9)

> **Scope note (binding DES-DP-3)**: the full dead client role-change chain is removed here as directed
> (`AuthController.updateRol`, `AuthService.updateUserRol`, `signUp(rol:)` param + vet branch,
> `AuthService._crearPerfilVeterinarioSiNoExiste`, register-screen rol dropdown).
> Sub-tasks 8.1/8.2 are **Flutter-only and export-independent** — see DECISION POINT **DP-T2** for their
> execution timing (recommended: run right after Phase 4 as rollout step 5). Sub-tasks 8.3+ are
> `BLOCKED-PENDING: supabase export`.

- [ ] 8.1 **REMOVAL (static gate)** — Remove `AuthController.updateRol` (SP-DP-2) and `AuthService.updateUserRol`. Legacy baseline test "role-update call-through" (TDD-05) is retired here — requires the spec amendment in **DP-T3** before execution.
  - **Files**: `lib/domain/controllers/auth_controller.dart`, `lib/data/services/auth_service.dart`, `test/auth/auth_service_test.dart`, `test/auth/auth_controller_test.dart`
  - **TDD step**: static gate — `grep -n "updateRol\|updateUserRol" lib/ test/` → 0 matches; `dart analyze` clean; full suite green (no assertion weakening — test RETIREMENT is gated by DP-T3 approval, else L1 violation).
  - **Accepts**: SP-DP-2, DES-DP-3(a), MODIFIED "Role assignment at signup" (client half)
  - **Status**: UNBLOCKED (Flutter-only) — pending DP-T2 timing confirmation
- [ ] 8.2 **RED → GREEN + static gate** — Remove the rest of the chain: `signUp(rol:)` param + `rol == 'veterinario'` branch, `_crearPerfilVeterinarioSiNoExiste`, register-screen single-option rol dropdown and `rol:` pass-through (transitional INSERT writes the literal `'usuario'`). RED widget test: register screen renders NO role dropdown. GREEN: delete dropdown + param.
  - **Files**: `lib/data/services/auth_service.dart`, `lib/domain/controllers/auth_controller.dart`, `lib/presentation/screens/login/register_screen.dart`, `test/auth/auth_service_test.dart`, `test/presentation/register_screen_test.dart` (create)
  - **TDD step**: RED widget assertion (MODIFIED "Role assignment at signup" client half) + static gate `grep "rol:" lib/presentation/screens/login/register_screen.dart` → 0 matches.
  - **Accepts**: DES-DP-3(a), MODIFIED "Role assignment at signup", TDD-05 (superseded payload assertion from 4.1 stays green)
  - **Status**: UNBLOCKED (Flutter-only) — pending DP-T2 timing confirmation
- [ ] 8.3 **AUTHOR (RED evidence exists)** — `supabase/migrations/20261021000003_usuarios_rls_usua_rol.sql` from the baseline: `enable row level security` on ALL baseline tables (DES-DP-2) with behavior-preserving policies ported from the export; `usuarios` policy set (`usuarios_select_authenticated` per DES-DP-4, `usuarios_update_propio_o_admin`, transitional `usuarios_insert_transitorio`); `es_admin()` helper; `restringir_cambio_usua_rol()` + `tr_restringir_usua_rol` (allowlist first, actor second, service-role/claims-absent allowed, `WHEN old.usua_rol is distinct from new.usua_rol`); `solicitudes_rol`/`veterinarios` minimums; rollback statements in header.
  - **Files**: `supabase/migrations/20261021000003_usuarios_rls_usua_rol.sql` (create)
  - **TDD step**: RED evidence = scripts 03–07 recorded red (Phase 6); provenance = export only (BAS-01).
  - **Accepts**: SEC-01, SEC-02, SEC-03, SEC-04, SEC-05 (transitional), SEC-06, SEC-07, SEC-08, DES-DP-2, DES-DP-4
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 8.4 **REVIEW GATE** — Checklist: per-table policy parity vs export; **Realtime `postgres_changes` read-parity check** for any table newly enabled with RLS (e.g. `mascotas`/`noticias` — DES-DP-2 mandatory check); no `TO anon` policies; no destructive statements; no secrets; rollbacks applicable via Dashboard paste (SEC-07).
  - **Files**: `supabase/migrations/20261021000003_usuarios_rls_usua_rol.sql`, `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: static/security review gate (project-security: RBAC + defense in depth).
  - **Accepts**: SEC-01 scenario "RLS audit query", SEC-07, DES-DP-2
  - **Status**: `BLOCKED-PENDING: supabase export`
- [ ] 8.5 **APPLY + GREEN + SMOKE** — Paste migration #2; re-run `00` + `03`…`07` → GREEN; manual least-functionality smoke: admin changes a role, admin approves a vet request, user edits own profile, user files a vet request (SEC-04/SEC-08 gate); record results.
  - **Files**: `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: GREEN cycle (VER-01) + manual smoke per design rollout step 9.
  - **Accepts**: SEC-01…SEC-08
  - **Status**: `BLOCKED-PENDING: supabase export`

**Batches**: `P8-a` = 8.1–8.2 · `P8-b` = 8.3–8.5.

---

## Phase 9 — Client cutover + post-cutover policy (rollout steps 10–11)

**BLOCKED-PENDING: supabase export** — unblock criteria: 7.3 GREEN recorded AND 8.5 GREEN recorded.
Cutover invariants: **7.3 strictly before 9.1; 9.1 strictly before 9.2; Phase 4 strictly before 7.3.**

- [ ] 9.1 **RED → GREEN** — Remove BOTH client profile INSERTs (`AuthService.signUp` + `signInWithGoogle`). RED test: `verifyNever` any `from('usuarios').insert(...)` in the signup/Google flows (fails while INSERTs remain); GREEN: delete them (Google "profile exists?" read stays).
  - **Files**: `test/auth/auth_service_test.dart`, `lib/data/services/auth_service.dart`
  - **TDD step**: RED assertion → GREEN removal → static grep gate as acceptance: `grep "from('usuarios').insert(" lib/data/services/auth_service.dart` → 0 matches. Commit: `refactor(auth): eliminar INSERTs cliente de perfil (cutover trigger)`.
  - **Accepts**: SGN-08 both scenarios, REMOVED "Client-side `usuarios` INSERT in email signup" / "Google sign-in"
  - **Status**: `BLOCKED-PENDING: supabase export` (unblock: 7.3 green)
- [ ] 9.2 **APPLY + GREEN** — Paste migration #3 `supabase/migrations/20261021000004_drop_usuarios_insert_policy.sql` (drops transitional INSERT policy; header rollback = re-create it ONLY if 9.1 is being reverted); re-run `06` → GREEN (SEC-05 final).
  - **Files**: `supabase/migrations/20261021000004_drop_usuarios_insert_policy.sql` (create), `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: GREEN cycle (SEC-05 scenario "Direct profile insert denied" final form).
  - **Accepts**: SEC-05, SEC-07, SGN-10 (step 11 strictly after 10)
  - **Status**: `BLOCKED-PENDING: supabase export` (unblock: 9.1 merged + deployed)

**Batches**: `P9-a` = 9.1 · `P9-b` = 9.2.

---

## Phase 10 — Final verification, rollback drills & cleanup

- [ ] 10.1 **COVERAGE GATE** — `flutter test --coverage`; lcov ≥ 80 % line coverage for `lib/domain/controllers/auth_controller.dart` and `lib/data/services/auth_service.dart`; if below, add assertion-driven tests (RED cycles) — never weaken existing assertions (L2).
  - **Files**: `test/auth/*` (possible additions)
  - **TDD step**: coverage gate (TDD-07 scenario "Coverage gate", project-standards ≥ 80 %).
  - **Accepts**: TDD-07
  - **Status**: UNBLOCKED (Track A) — final numbers may include Phase 8 client tasks
- [ ] 10.2 **FULL SUITE + LINTS** — `flutter test` exit 0 (all baselines + all new tests), `dart format`, `flutter analyze` clean; static security lint over error messages (no raw-pattern leaks).
  - **Files**: no edits expected
  - **TDD step**: final regression run (TDD-01, ERR-06 denylist).
  - **Accepts**: TDD-01, TDD-06, ERR-06
  - **Status**: UNBLOCKED (Track A portion)
- [ ] 10.3 **ROLLBACK DRILLS** — Paste rollback of migration `…0003` → re-run `03`…`07` → RED; re-paste migration → GREEN. Repeat for `…0002` ONLY while the client INSERT is deployed (hard constraint: never drop the trigger after 9.1 without restoring the INSERT). Record all three states.
  - **Files**: `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: VER-01 scenario "Rollback returns to red", SEC-07 scenario "Rollback drill".
  - **Accepts**: SEC-07, VER-01
  - **Status**: `BLOCKED-PENDING: supabase export` (unblock: 8.5 green; 10.3a for `…0002` unblocked after 7.3 green)
- [ ] 10.4 **CUTOVER AUDIT** — Verify invariants: 7.3 < 9.1 < 9.2 in commit/paste history; grep gates (no client profile INSERT, no `updateRol`/`updateUserRol`); orphan repair note for pre-existing production accounts documented in change notes (manual SQL / re-trigger — operational remedy out of app scope).
  - **Files**: `openspec/changes/mejoras-login/verification-log.md`, change notes
  - **TDD step**: static gates (SGN-08, SGN-06 residual-orphan note, SGN-10 ordering).
  - **Accepts**: SGN-06, SGN-08, SGN-10, DES-DP-3
  - **Status**: `BLOCKED-PENDING: supabase export` (final state), partial static checks possible earlier
- [ ] 10.5 **DOC CLEANUP** — Update `verification-log.md` completeness, confirm `auth-settings-snapshot.md` still matches live (SGN-11/DP-4 status), ensure no absolute machine paths in any artifact, ready for `sdd-verify`/`sdd-review`.
  - **Files**: `openspec/changes/mejoras-login/verification-log.md`, `openspec/changes/mejoras-login/auth-settings-snapshot.md`
  - **TDD step**: artifact review (no code).
  - **Accepts**: BAS-04, SGN-11 (conditional status re-checked), PATH RULE
  - **Status**: mixed — Track A portion UNBLOCKED, Track B portion `BLOCKED-PENDING: supabase export`

**Batches**: `P10-a` = 10.1–10.2 · `P10-b` = 10.3–10.5.

---

## Phase 11 — Hotfix de prueba en vivo: errores Google (BUG-1), banner obsoleto (BUG-2) y botón Google en registro (NEW)

> **Scope (binding, user-validated)**: three fixes validated live on a connected Android phone.
> Recovery/OTP redesign is OUT of SCOPE for this batch (next phase). Track B remains
> `BLOCKED-PENDING: supabase export` — status unchanged.
> New spec IDs: **AMD-2026-10-23-01** (ERR-01 + scenario "Error cleared when entering
> register screen"), **AMD-2026-10-23-02** (ERR-05 + Google platform/wrapper/cancel
> scenarios), **SGN-12** (AMD-2026-10-23-03, register-screen Google sign-in).
> **Commit guidance deviation (see DP-T4)**: one commit per fix-batch instead of one per
> phase — each fix is independently revertable on a live-tested build (hotfix semantics);
> orchestrator may squash at 11.10.

- [x] 11.1 **OBSERVABILITY (exención `sdd-testing` — log-only, sin test posible)** — Add stage-tagged diagnostics: `debugPrint` in `AuthController.loginWithGoogle()`'s generic catch (the only auth catch without it — mirror `login()`'s `'Error en login: $e'` pattern), and `debugPrint` of the raw `$e` at each `AuthService.signInWithGoogle()` wrapper throw site (before wrapping), so the live log correlates each Spanish wrapper prefix to its underlying `PlatformException`/`ApiException` code. NO user-visible text changes.
  - **Files**: `lib/domain/controllers/auth_controller.dart`, `lib/data/services/auth_service.dart`
  - **TDD step**: observability/baseline exception per `sdd-testing` — instrumentation with no deterministic assertion (raw platform text varies per device/Play-Services version); acceptance = `dart analyze` clean + full suite green (no behavior change) + live log capture in 11.4. No RED is possible; documented here so it is never mistaken for a skipped test.
  - **Accepts**: AMD-2026-10-23-02 scenario "Wrapper-prefixed stage errors are distinguishable" (log-only half), ERR-06 invariant (raw text stays out of the UI)
  - **Status**: UNBLOCKED
- [x] 11.2 **RED → GREEN (2 ciclos)** — `test/auth/auth_error_mapper_test.dart`: **ciclo 1 (platform codes)** — texts `sign_in_failed … ApiException: 10`, `sign_in_failed … ApiException: 12500`, `sign_in_required` → actionable Spanish copy ≠ `'Ocurrió un error. Intenta de nuevo.'`, each asserted against the ERR-06 denylist (no `ApiException`, no numeric codes, no raw English); extend the cancel-silence branch to also match `sign_in_canceled`/`12501` (baseline-first: the existing `'cancelado'` test must stay green). **ciclo 2 (wrappers)** — the three prefixes `'Error al abrir Google: …'`, `'Error obteniendo autenticación de Google: …'`, `'Error autenticando en Supabase con Google: …'` → stage-appropriate actionable copy, distinct from each other and from the fallback. GREEN: new `texto.contains`-style string branches in the mapper (consistent with its existing allowlist style — matches both raw and wrapper-interpolated forms; no new import needed).
  - **Files**: `test/auth/auth_error_mapper_test.dart`, `lib/core/auth_error_mapper.dart`
  - **TDD step**: RED assertion-level, 2 cycles (one per error family, precedent 3.5); cancel extension is a baseline-first guard.
  - **Accepts**: AMD-2026-10-23-02 (platform + wrapper + cancel scenarios), ERR-05 extended, ERR-06 denylist
  - **Status**: UNBLOCKED
- [x] 11.3 **RED (verify-only GREEN)** — `test/auth/auth_controller_test.dart`: mocked `AuthService.signInWithGoogle` throws `Exception('Error al abrir Google: PlatformException(sign_in_failed, ApiException: 10, null)')` → `loginWithGoogle()` returns `false`, `errorMessage` equals the new actionable copy (≠ generic fallback), `isLoading == false`. NO controller edit expected (all catches already route through `AuthErrorMapper.map`) — GREEN arrives via 11.2; this test pins the end-to-end mapping contract.
  - **Files**: `test/auth/auth_controller_test.dart`
  - **TDD step**: RED assertion on `errorMessage`; GREEN from 11.2 (controller verify-only).
  - **Accepts**: AMD-2026-10-23-02, ERR-05 scenario "Google platform error maps to actionable Spanish copy"
  - **Status**: UNBLOCKED
- [ ] 11.4 **LIVE TEST (manual — puerta de aceptación validada por el usuario)** — On a connected Android phone: (a) force/observe a Google failure → the debug log shows the raw code via 11.1 instrumentation AND the banner shows the new actionable copy; (b) cancel the account picker → no banner; (c) record captured logs + outcomes in `openspec/changes/mejoras-login/verification-log.md`.
  - **Files**: `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: manual live verification — not automatable (device/Google-services dependent); sanctioned by the binding user decision "BUG 1 = code fix tested live on a connected phone".
  - **Accepts**: AMD-2026-10-23-02 (end-to-end), BUG 1 acceptance gate
  - **Status**: UNBLOCKED (requires user's connected phone)
- [x] 11.5 **RED → GREEN** — `test/auth/auth_controller_test.dart`: given a failed `login()` left `errorMessage` populated, invoking the new `limpiarError()` sets `errorMessage == null` and notifies listeners. GREEN: add `void limpiarError()` to `AuthController` (`_errorMessage = null` + `notifyListeners()`).
  - **Files**: `test/auth/auth_controller_test.dart`, `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: RED assertion (AMD-2026-10-23-01 controller half).
  - **Accepts**: AMD-2026-10-23-01
  - **Status**: UNBLOCKED
- [x] 11.6 **RED → GREEN (widget)** — `test/presentation/register_screen_test.dart` (create): pump `RegisterScreen` with a mocked `AuthController` exposing `errorMessage = 'Correo o contraseña incorrectos.'`; after settle the error banner is ABSENT (fails today — the stale banner renders from the existing `Consumer<AuthController>`). GREEN: `context.read<AuthController>().limpiarError()` inside `_RegisterScreenState.initState` (the screen's existing `initState` is the single choke point). *Note: because `initState` runs during the build phase and `limpiarError()` calls `notifyListeners()`, a synchronous call violates the framework (`markNeedsBuild during build`); the choke point is kept in `initState` but the clear is deferred via `WidgetsBinding.instance.addPostFrameCallback`, the idiomatic pattern.*
  - **Files**: `test/presentation/register_screen_test.dart` (create), `lib/presentation/screens/login/register_screen.dart`
  - **TDD step**: RED widget assertion (AMD-2026-10-23-01 scenario "Error cleared when entering register screen").
  - **Accepts**: AMD-2026-10-23-01 (widget half), BUG 2 acceptance gate
  - **Status**: UNBLOCKED
- [ ] 11.7 **BASELINE + EXTRACT (refactor — sin RED nuevo)** — Baseline gate first: run the existing tests touching `login_screen.dart` (incl. `test/presentation/recovery_cooldown_ui_test.dart`) and record GREEN against unmodified code (`sdd-testing` Baseline Protocol). Then extract the private `_GoogleButton` + `_GoogleLogoPainter` from `lib/presentation/screens/login/login_screen.dart` into `lib/presentation/widgets/google_button.dart` (public `GoogleButton`; painter stays private to the shared file) and update `login_screen.dart` to import/use it. Moving private widgets is a REFACTOR: existing behavior is preserved by the existing tests — identical test count and assertions, suite stays green, `dart analyze` clean; a failure here signals accidental breakage, not a missing test.
  - **Files**: `lib/presentation/widgets/google_button.dart` (create), `lib/presentation/screens/login/login_screen.dart`
  - **TDD step**: refactor — behavior preserved by existing tests (extraction is not a behavior change; no new assertions added or removed).
  - **Accepts**: SGN-12 scenario "Shared widget parity" (definition half), `sdd-testing` Baseline Protocol
  - **Status**: UNBLOCKED
- [ ] 11.8 **RED** — `test/presentation/register_screen_test.dart`: `RegisterScreen` renders the Google button (located via the shared widget's key/tooltip) — fails today (button absent). Also assert the cancel contract: mocked `loginWithGoogle()` returning `false` with `errorMessage == null` (cancel) → NO banner on the register screen.
  - **Files**: `test/presentation/register_screen_test.dart`
  - **TDD step**: RED widget assertions (SGN-12 render half + "Cancel from register stays silent").
  - **Accepts**: SGN-12 scenario "Register-screen Google sign-in succeeds" (render half), scenario "Cancel from register stays silent"
  - **Status**: UNBLOCKED
- [ ] 11.9 **GREEN + handler** — Wire `GoogleButton` into `lib/presentation/screens/login/register_screen.dart` with `_handleGoogleLogin()` mirroring `login_screen.dart`'s (`context.read<AuthController>().loginWithGoogle()`; on success rol-aware `pushReplacementNamed('/admin'|'/home')`; on failure the existing `Consumer<AuthController>` renders the shared mapped banner — no banner code added). Then extend the widget test: mocked failure (`loginWithGoogle()` → `false` with mapped `errorMessage`) → banner visible on the register screen. NO `AuthController`/`AuthService` changes (binding diagnosis: none needed).
  - **Files**: `lib/presentation/screens/login/register_screen.dart`, `test/presentation/register_screen_test.dart`
  - **TDD step**: GREEN for 11.8 + one additional RED→GREEN cycle (failure-banner widget assertion).
  - **Accepts**: SGN-12 (success + failure + cancel scenarios), ERR-05/ERR-06 (banner copy via mapper)
  - **Status**: UNBLOCKED
- [ ] 11.10 **VERIFY + COMMIT + LIVE SMOKE** — Full suite green (all Phase 1–3 baselines intact; zero assertion changes in 11.7), `dart format`, `flutter analyze`; grep gate `grep -n "_GoogleButton\|_GoogleLogoPainter" lib/presentation/screens/login/login_screen.dart` → 0 DEFINITION matches; live smoke on the connected phone: register screen → Google button → account picker → successful sign-in lands rol-aware. Commits (DP-T4 option (a)): `fix(auth): mapeo accionable de fallos de Google e instrumentación de diagnóstico` after 11.4, `fix(auth): limpiar banner de error al entrar en la pantalla de registro` after 11.6, `feat(auth): botón de Google compartido en la pantalla de registro` after 11.9 (squash into one phase commit only if DP-T4 option (b) is chosen).
  - **Files**: no further edits expected; `openspec/changes/mejoras-login/verification-log.md` (live-smoke record)
  - **TDD step**: regression gate (TDD-01) + static gate (SGN-12 grep) + manual live smoke.
  - **Accepts**: SGN-12, AMD-2026-10-23-01, AMD-2026-10-23-02 (end-to-end), BUG 1 / BUG 2 / NEW user-validated gates
  - **Status**: UNBLOCKED (live-smoke part requires user's connected phone)
- [x] 11.11 **RED → GREEN (widget · added 2026-10-23 from live-device evidence)** — Overflows observed in a live log capture during 11.4: "A RenderFlex overflowed by 20 pixels on the right" at `lib/presentation/screens/login/login_screen.dart:325` (the `Row` inside `_MethodButton`), on a Samsung SM-A022M (720-logical-px-wide screen). RED: `test/presentation/login_method_button_overflow_test.dart` (create): pump the real `LoginScreen` at a constrained viewport (320 logical px wide) and assert `tester.takeException()` is `isNull` — today the un-shrinkable `Text(label)` in the `Row` overflows, so the RenderFlex overflow exception is captured and the assertion fails. GREEN: wrap the label `Text` in the `_MethodButton` `Row` with `Expanded` + `maxLines: 1, overflow: TextOverflow.ellipsis` (and drop the now-redundant `Spacer`), so the label shrinks/ellipsizes on narrow screens while the chevron stays pinned right — design preserved on wide AND narrow. *Note: viewport set to 460 logical px (not 320) to isolate the target — the offline test fallback font renders glyphs ~2× wider than Poppins, which at 320 would also overflow the out-of-scope `_GoogleButton` (line 389, P11-c); at 460 only `_MethodButton` overflows.*
  - **Files**: `lib/presentation/screens/login/login_screen.dart`, `test/presentation/login_method_button_overflow_test.dart` (create)
  - **TDD step**: RED widget assertion on the captured RenderFlex overflow exception (device defect, non-functional UI bug); GREEN is a minimal layout fix.
  - **Accepts**: device-observed overflow defect (log evidence captured during 11.4); Flutter best-practice Row overflow handling
  - **Status**: UNBLOCKED

**Batches**: `P11-a` = 11.1–11.4 (BUG 1) · `P11-b` = 11.5–11.6 (BUG 2) · `P11-c` = 11.7–11.10 (NEW) · `P11-d` = 11.11 (overflow defect — added 2026-10-23 from live-device evidence, log capture during 11.4).

---

## Phase 12 — S7: Recuperación de contraseña por enlace (deep link `huellitas://`) · `feat(auth):`

> **Scope (binding, user-validated 2026-10-23)**: link-based recovery redesign per spec
> Amendments 2026-10-23-b (RST-01…RST-13, AMD-2026-10-23-04…-10) and `design-recovery.md` §1–§12.
> Inputs: `spec.md` (2026-10-23-b amendments), `design-recovery.md`, current code (verified
> 2026-10-23: `auth_controller.dart:107-121` carga perfil en `passwordRecovery`;
> `auth_service.dart:299-300` sin `redirectTo`; OTP en `login_screen.dart:732+` y
> `auth_controller.dart:489-514`; manifest sin deep link; `programarResetDePila()` sin
> parámetros en `lib/main.dart:126`).
> Binding decisions: custom scheme `huellitas://password-recovery`; NO 6-digit code anywhere;
> single anti-enumeration success message (no existence check); 60 s cooldown retained with
> label **"Reintentar en N s"** (RST-DD-2); `updateUser` → `signOut` → `/login` (RST-DP-2(a));
> the link ALWAYS opens the new-password screen (RST-DP-1(a)); spec copy verbatim
> (RST-DP-3(a)). **OUT**: Google-login fixes (pending), Track B, iOS `Info.plist` (no `ios/`
> directory in repo — documented out-of-scope), template/Redirect-URL/SMTP editing (user
> Dashboard actions → 12.23), App Links https (RST-DD-3 backlog). Track B status UNCHANGED.
> **Commit guidance (DP-T4 option (a) convention)**: one commit per batch (`P12-a`…`P12-f`);
> `P12-g` produces only `verification-log.md` records.
> **TDD sanction note (binding)**: the test retirements in P12-a are spec-sanctioned by
> AMD-2026-10-23-04/-05/-06/-07/-08 (same discipline as AMD-2026-10-21-01/DP-T3) — they are
> NOT an sdd-testing L1/L3 loophole. Every retired test MUST be recorded in
> `openspec/changes/mejoras-login/verification-log.md` with its amendment ID in the same commit.

### P12-a — Baseline + retiros sancionados de OTP (commit: `test(auth): retiros sancionados de tests OTP y baseline del flujo por enlace`)

- [x] 12.1 **BASELINE** — Run and record GREEN against unmodified code (`sdd-testing` Baseline Protocol) the tests that will guard/bracket the recovery refactor: `test/auth/recovery_cooldown_test.dart`, `test/presentation/recovery_cooldown_ui_test.dart`, `test/auth/auth_session_events_test.dart`, `test/auth/auth_controller_test.dart`, `test/auth/auth_service_test.dart`.
  - **Files**: no edits expected (record in `openspec/changes/mejoras-login/verification-log.md`)
  - **TDD step**: baseline gate — these are the regression guards for Phases 2–3 behavior (ERR-07, SES-01…SES-07); Phase 12 implementation must not start before they pass.
  - **Accepts**: `sdd-testing` Baseline Protocol; TDD-06 (suite offline-green precondition)
  - **Status**: UNBLOCKED
- [x] 12.2 **RETIREMENT (sancionado AMD-2026-10-23-04, design §7.3)** — Retire the SES-06 group in `test/auth/auth_session_events_test.dart` (both tests: "passwordRecovery con sesión activa carga el perfil" — la premisa OTP de carga de perfil contradice la nueva rama —, y "passwordRecovery sin sesión deja mensaje recuperable" — escenario retirado; su edge migra a RST-07/RST-12) and update the stale comment in `test/auth/mocks.dart:79` (remove `verifyOTP` mention). **Verified 2026-10-23**: `test/auth/auth_service_test.dart` contains NO `verificarOtpYCambiarContrasena` tests to retire (design §7.3 row is a no-op — see flagged inconsistency #4) and `test/auth/recovery_flow_scenarios_test.dart` does not exist (design §7.3 conditional row no-op).
  - **Files**: `test/auth/auth_session_events_test.dart`, `test/auth/mocks.dart`, `openspec/changes/mejoras-login/verification-log.md` (retirement record with AMD-2026-10-23-04)
  - **TDD step**: sanctioned retirement (L1 exception pre-approved by spec) — suite stays green; replacement RED cycles arrive in 12.10/12.13 (RST-07/RST-09). No assertion weakening: the retired tests are deleted wholesale, never edited to match new behavior.
  - **Accepts**: AMD-2026-10-23-04 (migration to RST-07/RST-08/RST-09), RST-05 "una sola pantalla"
  - **Status**: UNBLOCKED
- [x] 12.3 **RETIREMENT (sancionado AMD-2026-10-23-05/-06, design §7.3)** — Retire the OTP step-2 scenario in `test/presentation/recovery_cooldown_ui_test.dart` (lines ~151-162: tap 'Enviar código' → avance a paso 2); keep the cooldown countdown + banner semantics assertions intact (they re-pin in 12.16). Record the retirement in `verification-log.md` with amendment IDs.
  - **Files**: `test/presentation/recovery_cooldown_ui_test.dart`, `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: sanctioned retirement (AMD-2026-10-23-05 re-pins ERR-07 copy only; the step-2 OTP UI ceases to exist per RST-01/RST-13(d)); suite green after removal.
  - **Accepts**: AMD-2026-10-23-05, AMD-2026-10-23-07 (TDD-04 coverage item swap), RST-01 (no code entry anywhere)
  - **Status**: UNBLOCKED

**Batches**: `P12-a` = 12.1–12.3.

### P12-b — Mapper: fallo de enlace + literales (commit: `feat(auth): mapeo de fallos de enlace y literales de recuperación`)

- [x] 12.4 **RED → GREEN** — `test/auth/auth_error_mapper_test.dart`: (a) `AuthPKCEGrantCodeExchangeError` → `esFalloDeEnlaceRecuperacion(...) == true`; (b) `AuthApiException` → `true`; (c) `AuthRetryableFetchException` → `false` (transitorio — NO es fallo de enlace, design §6.1/decisión 3). RED con stub-first: el `static` se añade devolviendo `false` para que (a) falle en la aserción (no en compilación). GREEN: añadir `static bool esFalloDeEnlaceRecuperacion(Object error)` en `lib/core/auth_error_mapper.dart` (tipos gotrue exportados por `supabase_flutter` — verificar constructor de `AuthPKCEGrantCodeExchangeError` en el pub cache antes de escribir el test; design §1 lo verificó en gotrue 2.22.0).
  - **Files**: `test/auth/auth_error_mapper_test.dart`, `lib/core/auth_error_mapper.dart`
  - **TDD step**: RED assertion-level (stub scaffold para evitar RED de compilación — un ciclo por tipo).
  - **Accepts**: RST-09 (mapeo de tipo), design §6.1 decisión 3
  - **Status**: UNBLOCKED
- [x] 12.5 **RED → GREEN** — Literales verbatim (RST-DP-3(a)): (a) `AuthErrorMapper.mensajeEnlaceInvalido == 'El enlace expiró o no es válido. Solicita uno nuevo.'` (RST-09); (b) `AuthErrorMapper.mensajeSesionRecuperacionExpirada == 'Tu sesión de recuperación expiró. Solicita un enlace nuevo.'` (RST-12, E7); (c) `map()` con `AuthSessionMissingException` → `mensajeSesionRecuperacionExpirada`. GREEN: `static const` + rama del mapper.
  - **Files**: `test/auth/auth_error_mapper_test.dart`, `lib/core/auth_error_mapper.dart`
  - **TDD step**: RED assertions (3 literales exactos — string equality, no `contains`).
  - **Accepts**: RST-09 scenario "Expired link" (copy half), RST-12 scenario "Submit without a session" (copy half), RST-DP-3(a)
  - **Status**: UNBLOCKED
- [x] 12.6 **VERIFY + COMMIT** — Assert the two nuevos literales pasan el denylist ERR-06 (no `Exception|rate limit|attempt(|ApiException`); full mapper suite green; commit `feat(auth): …` (`P12-b`).
  - **Files**: `test/auth/auth_error_mapper_test.dart` (denylist assertions), no production edits expected
  - **TDD step**: regression gate (3.1 baseline denylist intact) + static denylist assertion (RST-09 "No token leakage on failure" pre-gate).
  - **Accepts**: ERR-06 denylist, RST-09 (no raw text), RST-13(a) copy half
  - **Status**: UNBLOCKED

**Batches**: `P12-b` = 12.4–12.6.

### P12-c — Service: `redirectTo` + actualización por sesión de recuperación + retiro OTP servicio (commit: `feat(auth): redirectTo huellitas:// y actualización de contraseña por sesión de recuperación`)

- [x] 12.7 **RED → GREEN** — RST-03: `test/auth/auth_service_test.dart` (mocktail `MockGoTrueClient` capturando args de `resetPasswordForEmail`): `enviarRecuperacionContrasena(' a@b.c ')` → email recortado `a@b.c` **y** `redirectTo == 'huellitas://password-recovery'` (hoy falta el argumento → aserción falla). GREEN: `static const redirectRecuperacion = 'huellitas://password-recovery'` + `redirectTo: redirectRecuperacion` en `lib/data/services/auth_service.dart:299` (constante = fuente única, design §4.1/decisión 4).
  - **Files**: `test/auth/auth_service_test.dart`, `lib/data/services/auth_service.dart`
  - **TDD step**: RED assertion on captured `redirectTo` (nuevo test — no hay test previo del send que adaptar, ver inconsistencia #4; el stub del cliente ya existe en `mocks.dart`).
  - **Accepts**: RST-03 scenario "Captured redirect argument", TDD-05 (AMD-2026-10-23-08: send call-through con `redirectTo`)
  - **Status**: UNBLOCKED
- [x] 12.8 **RED → GREEN** — RST-11 service half: `test/auth/auth_service_test.dart`: nuevo método (nombre pendiente **DP-T5** — spec `AuthService.restablecerContrasena` vs design §4.1 `actualizarContrasenaSesionRecuperacion`; recomendación: nombre del spec) invocado con `'nueva123'` → `auth.updateUser(UserAttributes(password: 'nueva123'))` exactamente UNA vez a través del cliente mockeado (el único write path, RST-13(b)). RED stub-first (método stub que lanza `UnimplementedError` → falla en aserción del verify). GREEN: `Future<void> …(String nueva) => _client.auth.updateUser(UserAttributes(password: nueva))` en `lib/data/services/auth_service.dart` (reutiliza el patrón de la línea 322 actual).
  - **Files**: `test/auth/auth_service_test.dart`, `lib/data/services/auth_service.dart`
  - **TDD step**: RED assertion (mocktail `verify` on captured args).
  - **Accepts**: RST-11 scenario "updateUser call-through" (service half), TDD-05 (AMD-2026-10-23-08), RST-13(b)
  - **Status**: UNBLOCKED — pending **DP-T5** (sólo el nombre del método; el comportamiento está fijado)
- [x] 12.9 **RETIRO + STATIC GATE (sancionado AMD-2026-10-23-06/-08)** — Remove `verificarOtpYCambiarContrasena` de `lib/data/services/auth_service.dart` (líneas 305-323; verificado: su único caller era `login_screen.dart:808`, retirado en 12.16). Static gate: `grep -n "verificarOtpYCambiarContrasena\|verifyOtp\|OtpType" lib/data/services/` → 0 matches; `dart analyze` clean; full suite green (no test existed for this method — verificado 2026-10-23, inconsistencia #4).
  - **Files**: `lib/data/services/auth_service.dart`, `lib/domain/controllers/auth_controller.dart`, `lib/presentation/screens/login/login_screen.dart`, `lib/presentation/screens/login/recuperar_contrasena_screen.dart` (create), `openspec/changes/mejoras-login/verification-log.md` (gate record)
  - **TDD step**: static gate (dead-code removal sin test previo — la ausencia de tests del método es la razón del gate; retiro sancionado por AMD-2026-10-23-06).
  - **Accepts**: AMD-2026-10-23-06, RST-13(d) (service half), design §4.1 retiro
  - **Status**: UNBLOCKED

**Batches**: `P12-c` = 12.7–12.9.

### P12-d — Controller: `enModoRecuperacion`, `restablecerContrasena`, rama `passwordRecovery`, fallo de enlace (commit: `feat(auth): enModoRecuperacion, restablecerContrasena y fallo de enlace en el listener`)

- [x] 12.10 **RED → GREEN** — RST-07 (unit): `test/auth/auth_session_events_test.dart`: emitir `passwordRecovery` con sesión → `controller.enModoRecuperacion == true`, `verifyNever(() => mockAuthService.getUserProfile(any()))` (NO carga perfil — cambio vs rama actual `auth_controller.dart:107-121`), listeners notificados. RED stub-first: getter `enModoRecuperacion` stub devuelve `false` → aserción falla. GREEN: `_enModoRecuperacion` field + getter + rama `passwordRecovery` = flag `true`, sin carga de perfil, `notifyListeners()` (design §2.2 matriz).
  - **Files**: `test/auth/auth_session_events_test.dart`, `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: RED assertion-level (stub scaffold); sustituye al test retirado en 12.2 (AMD-2026-10-23-04).
  - **Accepts**: RST-07 scenario "Anti-desync preserved (SES-06 migration)", RST-01/RST-02 (evento no dispara UI de código), AMD-2026-10-23-10
  - **Status**: UNBLOCKED
- [x] 12.11 **BASELINE-FIRST (pasa a la primera ⇒ registro como guard)** — RST-05/RST-07-parity: `test/auth/auth_controller_test.dart`: (a) `recuperarContrasena` offline (`SocketException`) → `errorMessage` = copy de conectividad, cooldown NO arranca (ERR-07 "Network failure does not lock the user out" — nuevo escenario re-pin); (b) `recuperarContrasena` rate-limit → copy ERR-02 + cooldown arranca (guard de 3.10); (c) RST-02: en `recuperarContrasena` la ÚNICA interacción con la capa de auth es el send (`verifyNever` sobre lookups de perfil/usuario — noEnumeration channel). Si (a)/(c) pasan contra el código actual → BASELINE guards; sólo si fallan → ciclo RED→GREEN mínimo.
  - **Files**: `test/auth/auth_controller_test.dart`
  - **TDD step**: baseline-first (`sdd-testing`: un test que pasa de inmediato es un baseline, no un RED).
  - **Accepts**: RST-02 scenario "No enumeration channel in the client", RST-05 scenario "Offline send", ERR-07 re-pinned scenario "Network failure does not lock the user out"
  - **Status**: UNBLOCKED
- [x] 12.12 **RED → GREEN** — RST-11/RST-DP-2(a): `test/auth/restablecer_contrasena_test.dart` (create): `restablecerContrasena('nueva123')` → (a) éxito: servicio de update invocado exactamente 1 vez, orden `update → signOut` verificado con mock, `enModoRecuperacion == false`, `signOut` invocado con `_cerrandoSesion` silencioso (sin mensaje de expiración — rama existente `auth_controller.dart:85-93`), devuelve `true`; (b) error del servicio → `errorMessage` mapeado (ERR-06), `signOut` NO invocado, devuelve `false`; (c) ERR-01: `errorMessage` limpio al inicio de la operación. RED stub-first. GREEN: `restablecerContrasena` + `_cerrarSesionRecuperacion()` reutilizando `_cerrandoSesion` (design §4.2, decisión 2).
  - **Files**: `test/auth/restablecer_contrasena_test.dart` (create), `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: RED assertions (3 ciclos: éxito+orden, fallo, ERR-01 start-clear — uno por ciclo).
  - **Accepts**: RST-11 scenario "updateUser call-through" + "Failure keeps the user on the screen" (controller half), RST-DP-2(a), AMD-2026-10-23-06 (`restablecerContrasena` joins ERR-01 enumeration), design §4.2
  - **Status**: UNBLOCKED
- [x] 12.13 **RED → GREEN** — RST-09 (stream error): `test/auth/auth_session_events_test.dart`: (a) `addError(AuthPKCEGrantCodeExchangeError…)` sobre `authStates` → `enModoRecuperacion == false`, `consumirAvisoEnlaceInvalido()` devuelve `true` UNA vez y `false` después (consume-once), `errorMessage == 'El enlace expiró o no es válido. Solicita uno nuevo.'`; (b) `addError(AuthRetryableFetchException…)` → estado intacto (sin mutación, `debugPrint` only). RED stub-first (`consumirAvisoEnlaceInvalido` stub). GREEN: `onError` en `initAuthListener` con `AuthErrorMapper.esFalloDeEnlaceRecuperacion` (design §4.3) + método consume-once (patrón `_avisoDeCierrePendiente`, `auth_controller.dart:69-70`).
  - **Files**: `test/auth/auth_session_events_test.dart`, `lib/domain/controllers/auth_controller.dart`
  - **TDD step**: RED assertions (2 ciclos: fallo de enlace, error transitorio no-muta).
  - **Accepts**: RST-09 scenario "Expired link" (unit half), SES-02 ("offline must not fake a logout" preservado), design §4.3 + E3/E4
  - **Status**: UNBLOCKED
- [x] 12.14 **RETIRO + STATIC GATE (sancionado AMD-2026-10-23-06)** — Remove `AuthController.verificarOtpYCambiarContrasena` (`lib/domain/controllers/auth_controller.dart:489-514`); re-pin ERR-01 enumeration: `login`, `loginWithGoogle`, `register`, `recuperarContrasena`, `restablecerContrasena`, `logout`, `updateProfile`, `cambiarContrasena` — si `test/auth/auth_controller_test.dart` (ciclo 3.7) tiene asserts que referencian la operación retirada, re-pin CON la sanción AMD-2026-10-23-06 anotado (nunca debounceilado). Static gate: `grep -n "verificarOtpYCambiarContrasena\|verifyOtp" lib/domain/ test/` → 0 matches; suite green.
  - **Files**: `lib/domain/controllers/auth_controller.dart`, `test/auth/auth_controller_test.dart` (sólo re-pins sancionados), `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: static gate + sanctioned retirement (AMD-2026-10-23-06); cualquier ajuste de test existente debe citar la enmienda en el commit.
  - **Accepts**: AMD-2026-10-23-06, ERR-01 (enumeración enmendada), RST-13(d) (controller half)
  - **Status**: UNBLOCKED

**Batches**: `P12-d` = 12.10–12.14.

### P12-e — Pantallas: extracción paso-1 + `NuevaContrasenaScreen` + Consumer raíz (commit: `feat(auth): pantallas de recuperación por enlace y render raíz enModoRecuperacion`)

- [x] 12.15 **BASELINE + REFACTOR (sin RED — comportamiento preservado)** — Baseline gate: run `test/presentation/recovery_cooldown_ui_test.dart` + `test/presentation/login_method_button_overflow_test.dart` + `test/widget_test.dart` against unmodified code (record GREEN). Then mechanical extraction: (a) painter de ondas de `login_screen.dart` → `lib/presentation/widgets/wave_background.dart` (widget público, sin cambio visual); (b) `_RecuperarContrasenaScreen` (`login_screen.dart:732+`) → `lib/presentation/screens/login/recuperar_contrasena_screen.dart` (público `RecuperarContrasenaScreen`, aún con comportamiento actual — la conversión a un paso es 12.16); `login_screen.dart` lo importa en vez del widget privado (push de la línea 452 intacto).
  - **Files**: `lib/presentation/widgets/wave_background.dart` (create), `lib/presentation/screens/login/recuperar_contrasena_screen.dart` (create), `lib/presentation/screens/login/login_screen.dart`
  - **TDD step**: refactor — conteo de tests/assertions idéntico, suite verde; una falla aquí = rotura accidental, no test faltante (design §3.3, decisión 5).
  - **Accepts**: design §3.1/§3.3, `sdd-testing` REFACTOR validation, RST-11 refactor-parity (precondition)
  - **Status**: UNBLOCKED
- [x] 12.16 **RED → GREEN + RE-PIN sancionado** — RST-01/RST-02/RST-DD-2: `test/presentation/recuperar_contrasena_screen_test.dart` (create): (a) acción primaria lee **"Restablecer contraseña"** y NO existe widget de ingreso de código (RED: hoy el paso 2 existe); (b) tap con controller mockeado exitoso → mensaje M `'Si el correo existe, recibirás un enlace para restablecer tu contraseña. Revisa tu correo y la carpeta de spam.'` byte-idéntico, la pantalla queda (sin transición a paso 2); (c) cooldown: label **"Reintentar en N s"** (RST-DD-2) mientras `!puedeReenviarCodigo`. GREEN: convertir la pantalla extraída a un paso (borrar `_paso`, `_otpCtrl`, paso 2; button copy nueva; arranque de cooldown intacto — ERR-07). **Re-pin sancionado**: actualizar en `test/presentation/recovery_cooldown_ui_test.dart` los literals `'Enviar código'` → `'Restablecer contraseña'` y `'Reenviar en N s'` → `'Reintentar en N s'` (sanción: AMD-2026-10-23-05 + decisión user-validated RST-DD-2; anotar en `verification-log.md` — es un re-pin de copy, NO un debilitamiento de aserción).
  - **Files**: `test/presentation/recuperar_contrasena_screen_test.dart` (create), `test/presentation/recovery_cooldown_ui_test.dart` (re-pin copy), `lib/presentation/screens/login/recuperar_contrasena_screen.dart`
  - **TDD step**: RED widget assertions (3 ciclos); re-pin de copy con sanción documentada (AMD-2026-10-23-05 re-pin explícito: "countdown label copy adapts, semantics do not").
  - **Accepts**: RST-01 scenario "Send button copy", RST-02 scenario "Existing account" (widget half), RST-04 (label re-pin), RST-DD-2, ERR-07 re-pinned
  - **Status**: UNBLOCKED
- [x] 12.17 **RED → GREEN** — RST-10: `test/presentation/nueva_contrasena_screen_test.dart` (create): (a) composición: EXACTAMENTE dos campos de contraseña + acción guardar; sin campo de código ni de email; (b) `abcde` → "La contraseña debe tener al menos 6 caracteres." y NINGÚN submit; (c) `password1` vs `password2` → "Las contraseñas no coinciden." y ningún submit; (d) dos 8-char coincidentes → submit invocado exactamente 1 vez. RED stub-first (pantalla stub que renderiza sólo el scaffold mínimo). GREEN: `lib/presentation/screens/login/nueva_contrasena_screen.dart` (campos + obscure toggle patrón actual, validación local, copy verbatim).
  - **Files**: `test/presentation/nueva_contrasena_screen_test.dart` (create), `lib/presentation/screens/login/nueva_contrasena_screen.dart` (create)
  - **TDD step**: RED widget assertions (4 ciclos, uno por escenario).
  - **Accepts**: RST-10 (ambos escenarios de validación + composición), design §3.2
  - **Status**: UNBLOCKED
- [x] 12.18 **RED → GREEN** — RST-11/RST-12 widget: extender `test/presentation/nueva_contrasena_screen_test.dart`: (a) submit válido con `restablecerContrasena` → `true` → mensaje "¡Contraseña actualizada correctamente!" visible y `/login` única ruta del stack (vía mecanismo existente `MyApp.navigatorKey`); (b) submit con fallo mapeado → copy en pantalla, el usuario permanece en la pantalla (campos no descartados); (c) RST-08 widget: con `isInitializing == true` + link inicial simulado, splash precede al routing (nunca home/admin prematuro). GREEN: submit wiring a `auth.restablecerContrasena(nueva)` (patrón Consumer existente; sin navegación manual — el signOut del controlador + Consumer raíz garantizan `/login`, design §3.2).
  - **Files**: `test/presentation/nueva_contrasena_screen_test.dart`, `lib/presentation/screens/login/nueva_contrasena_screen.dart`
  - **TDD step**: RED widget assertions (3 ciclos).
  - **Accepts**: RST-11 scenario "Success shows the message and lands on login" + "Failure keeps the user on the screen", RST-12 (widget half), RST-08 scenario "No premature authenticated flash"
  - **Status**: UNBLOCKED
- [x] 12.19 **RED → GREEN** — Consumer raíz + rutas: `test/auth/session_reset_widget_test.dart` (extender) + widget test del builder: (a) RED: `enModoRecuperacion == true` (con sesión presente) → el builder renderiza `NuevaContrasenaScreen` ANTES de `isInitializing`/`isAuthenticated` (RST-DP-1(a)); (b) RED: `consumirAvisoEnlaceInvalido()` → `MyApp.programarResetDePila(ruta: '/login', forzar: true)` se programa y navega aunque `canPop() == false` (caso en caliente, design §2.4); (c) guards existentes de `session_reset_widget_test.dart` siguen verdes (firma por defecto preservada). GREEN: extender `MyApp.programarResetDePila({String ruta = '/login', bool forzar = false})` (la guardia `canPop()` aplica sólo cuando `forzar == false` — no toca la firma usada por SES-02); builder en `lib/main.dart:148+`: consume de enlace inválido → reset; `enModoRecuperacion` → `NuevaContrasenaScreen`; rutas nombradas `/nueva_contrasena` y `/recuperar_contrasena`.
  - **Files**: `lib/main.dart`, `lib/domain/controllers/auth_controller.dart` (sólo si el consume-once necesita ajuste de wiring), `test/auth/session_reset_widget_test.dart`
  - **TDD step**: RED widget assertions (3 ciclos: render frío, reset forzado en caliente, guardias SES-02 intactas).
  - **Accepts**: RST-07 (navigation state), RST-08 (cold-start rendering order), RST-11 (Consumer render with session — design §7.1 row RST-11), AMD-2026-10-23-10, design §2.3/§2.4
  - **Status**: UNBLOCKED

**Batches**: `P12-e` = 12.15–12.19.

### P12-f — Manifest Android + gates estáticos + verificación final (commit: `chore(auth): intent-filter de recuperación y gates estáticos del flujo por enlace`)

- [x] 12.20 **STATIC GATE** — RST-06 (manifest): añadir a `.MainActivity` en `android/app/src/main/AndroidManifest.xml` el intent-filter VIEW + `DEFAULT` + `BROWSABLE`, data `android:scheme="huellitas"` + `android:host="password-recovery"` (XML exacto de design §5). Gate estático (XML no unit-testable): exactamente UN filter VIEW/BROWSABLE con scheme+host; MAIN/LAUNCHER (líneas 41-44) y BOOT_COMPLETED (líneas 51-56) intactos; `launchMode="singleTop"` (línea 27) intacto.
  - **Files**: `android/app/src/main/AndroidManifest.xml`
  - **TDD step**: static gate — el propio RST-06 "Manifest gate" es `[static]`; no aplica aserción runtime (tier del spec).
  - **Accepts**: RST-06 scenario "Manifest gate (static)", design §5
  - **Status**: UNBLOCKED
- [x] 12.21 **STATIC GATES (RST-01/RST-13)** — Ejecutar y registrar en `verification-log.md`: (a) `grep -rn "verifyOtp\|verificarOtpYCambiarContrasena\|OtpType\.recovery" lib/` → 0 matches (RST-13(d)); (b) `grep -rn "6 dígitos\|_otpCtrl" lib/presentation/screens/login/ lib/domain/controllers/ lib/data/services/` → 0 matches (RST-01); (c) `grep -rn "Uri.parse\|access_token\|refresh_token\|token_hash" lib/presentation/ lib/domain/ lib/data/` → 0 matches en recovery flow (RST-13(a)/(b) — sin parsing manual, sin token en UI/logs; el log `finest` del SDK queda al nivel por defecto, design §6); (d) `grep -rn "SharedPreferences\|Hive\|getStorage" lib/presentation/screens/login/ lib/domain/controllers/ lib/data/services/` → 0 matches (RST-13(b) "Password never persisted").
  - **Files**: `openspec/changes/mejoras-login/verification-log.md` (gate records)
  - **TDD step**: static gates (grep assertions del spec — tier `[static]`); `dart analyze` limpio incluido.
  - **Accepts**: RST-01 scenario "No OTP artifacts in the flow", RST-13 (a)/(b)/(d) escenarios estáticos, RST-13 "No manual token handling"
  - **Status**: UNBLOCKED
- [x] 12.22 **VERIFY + COMMIT** — Full suite `flutter test` exit 0 (baselines 12.1 intactos; retiros 12.2/12.3/12.9/12.14 registrados con sus AMD); `dart format`; `flutter analyze`; coverage spot `flutter test --coverage` sobre `lib/domain/controllers/auth_controller.dart` y `lib/data/services/auth_service.dart` ≥ 80 % (TDD-07 sigue vigente — los retiros no pueden bajarla sin tests nuevos que la sostengan). Commits por batch (DP-T4(a)): `P12-a`…`P12-f` — uno por batch.
  - **Files**: no edits expected; `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: regression + coverage gate (TDD-01, TDD-06, TDD-07, ERR-06 denylist final).
  - **Accepts**: TDD-01, TDD-06, TDD-07, RST-01…RST-13 (automatizables), AMD-2026-10-23-04…-10
  - **Status**: UNBLOCKED

**Batches**: `P12-f` = 12.20–12.22.

### P12-g — Gates LIVE (BLOCKED-PENDING: DASHBOARD — acción del usuario) · registro manual

> **Unblock criterion (exacto) para 12.24/12.25**: las TRES condiciones de 12.23 completadas y
> registradas por el usuario en `openspec/changes/mejoras-login/verification-log.md`:
> (i) Redirect URL `huellitas://password-recovery` registrado (6-b.2); (ii) entrega de correo
> confirmada funcionando en el teléfono conectado (6-b.3 — **hoy reportada rota: los correos de
> recuperación NUNCA llegan**; causa desconocida: template/SMTP/rate limit/spam); (iii) template
> "Reset Password" usando `{{ .ConfirmationURL }}` (6-b.1, ventana dual RST-DD-1). Sin (i)+(ii)
> NINGÚN gate LIVE puede pasar — el código de la app no puede garantizar la entrega.

- [ ] 12.23 **DASHBOARD CHECKLIST (usuario + orquestador — design §7.4 + items 6-b.1/2/3)** — Walkthrough guiado con el usuario (orden de rollout §8: **A → B → C**, "C nunca antes de B"; RST-DD-1 = template dual: el usuario mantiene el bloque OTP viejo junto al link durante la ventana): 
  - [ ] Auth → URL Configuration → agregar `huellitas://password-recovery` a Redirect URLs (exacto, sin slash final) — 6-b.2
  - [ ] Authentication → Email Templates → "Reset Password" → usar `{{ .ConfirmationURL }}` en el link (RST-DD-1 template dual) — 6-b.1
  - [ ] Confirmar que la entrega de correo funciona (hoy reportada rota — bloquea todos los gates LIVE) — 6-b.3
  - **Files**: `openspec/changes/mejoras-login/verification-log.md` (checklist + fecha + evidencia por ítem)
  - **TDD step**: manual acceptance precondition (design §7.2 precondición) — no automatizable; equivale a los gates manuales 11.4/11.10.
  - **Accepts**: RST-DD-1, verification items 6-b.1/6-b.2/6-b.3, design §7.4 + §8 Paso A/C
  - **Status**: `BLOCKED-PENDING: DASHBOARD` (unblock: los 3 checkboxes registrados)
- [ ] 12.24 **LIVE — E2E end-to-end (RST-06/07/08 + §7.2 items 1-4, 7)** — En el teléfono conectado: (1) solicitar enlace desde la app → abrir desde la app de correo con app CERRADA → llega a `NuevaContrasenaScreen` tras splash (arranque en frío, RST-08); (2) repetir con app en foreground/background (arranque en caliente, RST-07, sin pantalla de código); (3) restablecer contraseña → login con la contraseña NUEVA (RST-11 + RST-DP-2(a): termina en `/login` sin sesión fantasma); (4) RST-07 full: con sesión iniciada tocar link → pantalla de nueva contraseña (RST-DP-1(a)); (5) reenviar dentro del cooldown → bloqueado con "Reintentar en N s"; fuera → funciona (RST-04). Registrar cada resultado en `verification-log.md`.
  - **Files**: `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: manual live gate (spec-tier `[LIVE]`, mismo espíritu que 11.4) — no automatizable (deep link + correo + dispositivo).
  - **Accepts**: RST-06 scenario "OS routes the link to the app", RST-07 scenario "Warm link on a real device", RST-08 scenario "Cold start lands on the new-password screen", RST-11 (end-to-end), design §7.2 items 1-4, 7
  - **Status**: `BLOCKED-PENDING: DASHBOARD` (unblock: 12.23 completo)
- [ ] 12.25 **LIVE — Edge cases (RST-09 + §7.2 items 5-6, 6-b.4)** — (1) link caducado (>1h) o ya usado → "El enlace expiró o no es válido. Solicita uno nuevo." sin crash, path de retorno al send (RST-09); (2) RST-08 cross-device (opcional, 6-b.4): tocar el link en OTRO dispositivo → mismo copy de enlace inválido (limitación PKCE documentada — decisión de implicit-flow queda deferred/out); (3) capturar logs de debug durante (1)-(2) → denylist: sin `access_token`/`refresh_token`/`token_hash`/`code=` (RST-09 "No token leakage", RST-13(a)). Registrar en `verification-log.md`.
  - **Files**: `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: manual live gate `[LIVE]`/`[LIVE optional]`.
  - **Accepts**: RST-09 (Expired link + Cross-device + No token leakage — live halves), 6-b.4
  - **Status**: `BLOCKED-PENDING: DASHBOARD` (unblock: 12.23 completo; item (2) opcional)
- [ ] 12.26 **RECORD + CIERRE** — Consolidar en `verification-log.md`: §7.2 items 1-7 completados, gates estáticos 12.21, retiros sancionados 12.2/12.3/12.9/12.14 con sus AMD, y el estado de RST-DD-3 (App Links https → backlog, OUT). Confirmar que ningún artefacto tiene rutas absolutas (PATH RULE) y que Track B sigue `BLOCKED-PENDING: supabase export`. Preparado para `sdd-verify`/`sdd-review`.
  - **Files**: `openspec/changes/mejoras-login/verification-log.md`
  - **TDD step**: artifact review (no code).
  - **Accepts**: RST-06…RST-09 (live closure), RST-DD-3 (backlog record), PATH RULE
  - **Status**: `BLOCKED-PENDING: DASHBOARD` (unblock: 12.24/12.25 registrados)

**Batches**: `P12-g` = 12.23–12.26.

---

## Status summary

| Phase | Deliverable | Tasks | Status |
|---|---|---|---|
| 1 | S1 seams + test baseline (step 1) | 11 | UNBLOCKED |
| 2 | S2 auth listener (step 2) | 12 | UNBLOCKED |
| 3 | S4 error mapping + cooldown (step 3) | 12 | UNBLOCKED |
| 4 | S3 client prep (step 4) | 5 | UNBLOCKED |
| 5 | S6 baseline intake (step 6) | 4 | `BLOCKED-PENDING: supabase export` |
| 6 | verify/ scripts + RED run (step 7) | 9 | `BLOCKED-PENDING: supabase export` |
| 7 | S3 trigger migration (step 8) | 3 | `BLOCKED-PENDING: supabase export` |
| 8 | S5 RLS/trigger + DES-DP-3 (steps 5+9) | 5 | 8.1–8.2 UNBLOCKED (pending DP-T2); 8.3–8.5 blocked |
| 9 | Cutover + policy drop (steps 10–11) | 2 | `BLOCKED-PENDING: supabase export` |
| 10 | Verification / drills / cleanup | 5 | 10.1–10.2 unblocked; rest blocked/mixed |
| 11 | Hotfix live-test batch (BUG-1/BUG-2/NEW + overflow) | 11 | UNBLOCKED (11.4/11.10 live parts need user's phone) |
| 12 | S7 recuperación por enlace (deep link `huellitas://`) | 26 | 12.1–12.22 UNBLOCKED; 12.23–12.26 `BLOCKED-PENDING: DASHBOARD` |
| — | **Total** | **105** | |

**Status totals updated 2026-10-23**: +26 tasks (Fase 12, S7). Track B status (Phases 5–9 + 10.3–10.5): **UNCHANGED — still `BLOCKED-PENDING: supabase export`.**

**Recommended execution order**: Phases 1→2→3 *(complete — commits `81db615`, `d396ea0`, `20d0afc`)* → **Phase 11 (hotfix — finish 11.4/11.7–11.10; independent of Phase 4)** → **Phase 12 (S7 recuperación por enlace — 12.1→12.22 Track A inmediato; 12.23 es acción del usuario en el Dashboard y desbloquea 12.24–12.26; independiente de Phase 4; rollout A→B→C, "C nunca antes de B" por RST-DD-1)** → Phase 4 → (8.1–8.2, rollout step 5, si DP-T2 option (a) elegida) → *pause Track A* → Phases 5 → 6 → 7 → 8.3–8.5 → 9 → 10 as the export and Dashboard access arrive, interleaving 10.1–10.2 as soon as Track A code is final. *(Note: al ejecutar Phase 5, la tarea 5.4 debe aplicar AMD-2026-10-23-09 — ver inconsistencia #5.)*

## INCONSISTENCIES FLAGGED (Fase 12 — reportadas, NO corregidas en spec/design)

> Detected 2026-10-23 by `sdd-tasks` while authoring Phase 12. Reported per protocol ("flag, don't
> silently fix specs"). Items 1 y 2 requieren decisión; 3-6 son informativas con workaround acotado.

| # | Where | Inconsistency | Handling in this file |
|---|---|---|---|
| 1 | `spec.md` RST-11 vs `design-recovery.md` §4.1 | Spec: controller `restablecerContrasena` "delegates to **`AuthService.restablecerContrasena`**"; design names the service method **`actualizarContrasenaSesionRecuperacion`**. Two different names for the same API. | Task 12.8 marked pending **DP-T5** (recommendation: spec name) |
| 2 | `design-recovery.md` §3.1 vs `spec.md` RST-01 | Design §3.1 says the send button reads "**Enviar enlace**"; spec RST-01 (binding, user-validated) mandates "**Restablecer contraseña**". | Spec + binding decision win; task 12.16 asserts the spec copy. Design §3.1 text is superseded (design-side nit, no spec change needed) |
| 3 | `design-recovery.md` §2.3 vs §2.4 | §2.3 snippet calls `programarResetDePila(forzarRuta: '/login')`; §2.4 describes the signature as `{String ruta = '/login', bool forzar = false}` — two different parameter spellings inside the same design. | Task 12.19 uses the §2.4 signature (it also preserves the existing no-arg call of SES-02); sdd-apply implements one consistent signature |
| 4 | `design-recovery.md` §7.3 rows 4-5 vs actual `test/` | Design §7.3 prescribes retiring `verificarOtpYCambiarContrasena` tests from `test/auth/auth_service_test.dart` — **verified 2026-10-23: no such tests exist** (grep → 0); and `test/auth/recovery_flow_scenarios_test.dart` does not exist (conditional row). Only the `mocks.dart:79` comment and the UI step-2 retirement are real. | Tasks 12.2/12.9 note the no-ops; 12.7's send call-through is a NEW test (RED), not an adaptation |
| 5 | `tasks.md` task 5.4 vs `spec.md` AMD-2026-10-23-09 | Task 5.4 records the snapshot item as "recovery template `{{ .Token }}` presence"; the amendment re-pins it to **`{{ .ConfirmationURL }}`**. Task 5.4 text predates the amendment. | 5.4 left untouched (Track B blocked); execution-order note instructs applying AMD-2026-10-23-09 when Phase 5 runs |
| 6 | `spec.md` RST-11 vs `design-recovery.md` §3.2 | Spec states success navigation "`pushNamedAndRemoveUntil('/login', …)` semantics, matching the existing `MyApp.navigatorKey` pattern"; design achieves the same observable end-state via `signOut` + root Consumer render ("no hace falta pop manual"). Mechanism differs, observable end-state equivalent. | Design mechanism accepted (newer authority, consistent with the flag+builder decision 1); task 12.18/12.19 test the observable end-state (`/login` única ruta) |

## DECISION POINTS (orchestrator must present — not decided here)

| ID | Decision | Options | Recommendation |
|---|---|---|---|
| **DP-T1** | RED-type exception for constructor seams (tasks 1.3/1.5/2.1): spec TDD-02/03 define the RED as compile/run failure, while `sdd-testing` requires assertion-level failures | (a) allow compile-level RED **only** for seam-introduction tasks, all behavioral REDs must fail at an assertion; (b) strict assertion-only → seams must be added as "scaffold" first, weakening the spec's red-first wording | **(a)** — spec scenario text explicitly sanctions it; document the exception in `verification-log.md` |
| **DP-T2** | Execution timing of DES-DP-3 client removals (8.1–8.2), grouped under S5 but export-independent | (a) execute immediately after Phase 4 as rollout step 5 (dead code, zero export dependency); (b) strictly blocked until the S5 SQL lands | **(a)** — removes attack/confusion surface sooner, keeps S5 group as scope bookkeeping only; needs orchestrator/user confirmation because Phase 8 is otherwise blocked |
| **DP-T3** | Spec amendment required: `TDD-05` mandates a "role-update call-through" test and `ERR-01` enumerates `updateRol` — both reference APIs DES-DP-3 removes | (a) amend `spec.md` now (retire the call-through test, drop `updateRol` from ERR-01's list); (b) keep spec as-is → task 8.1 would violate `sdd-testing` L1/L3 | **(a)** — required before 8.1 executes; without it 8.1 is a test-deletion loophole risk |
| **DP-T4** | Commit granularity for Fase 11 (protocol note 2 prescribes one commit per phase, but the phase groups three independently revertable user-validated fixes) | (a) one commit per fix-batch: `fix(auth):` after 11.4, `fix(auth):` after 11.6, `feat(auth):` after 11.9; (b) single squashed phase commit at 11.10 | **(a)** — hotfix semantics: each live-tested fix is independently revertable; (b) only if strict protocol-note-2 adherence is preferred |

*All architectural/scope decisions for Fases 1–10 are binding user-validated decisions (D1–D4, D9, DP-1a, DP-2, DP-3, DES-DP-1…4, SP-DP-1…3, confirmation OFF, AMD-2026-10-23-01…03). The only open item is **DP-T4** (commit granularity — low stakes).* — *original text: "No other decisions required: all architectural/scope decisions used here are binding user-validated decisions (D1–D4, D9, DP-1a, DP-2, DP-3, DES-DP-1…4, SP-DP-1…3, confirmation OFF)."*
