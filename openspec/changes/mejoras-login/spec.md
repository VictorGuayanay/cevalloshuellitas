# Delta Spec: Login / Auth Module — mejoras-login

> Change: `mejoras-login` · Written by `sdd-spec`
> Format: sdd-spec delta format (Context / ADDED / MODIFIED / REMOVED Requirements, RFC 2119).
> No prior specs exist under `openspec/specs/` (verified) → every requirement below is new;
> the de-facto baseline is the current behavior documented in
> `openspec/changes/mejoras-generales-huellitas/exploration.md` §2.
> TDD: **enforced** (`openspec/config.yaml` → `sdd.tdd: true`). Every requirement carries at
> least one Given/When/Then scenario written to drive a red-green-refactor cycle.
> All file paths are relative to the project root.

## Amendments (2026-10-21)

> **Rationale (binding)**: user-approved removal of the FULL dead client role-change chain per
> design decision **DES-DP-3(a)** (extends **SP-DP-2**): `AuthController.updateRol`,
> `AuthService.updateUserRol`, the `signUp(rol:)` parameter + `rol == 'veterinario'` branch,
> `AuthService._crearPerfilVeterinarioSiNoExiste`, and the register-screen role dropdown.
> This amendment was applied BEFORE task 8.1 executes per **DP-T3 option (a)**, so the test
> retirement in 8.1 is spec-sanctioned and not an assertion-weakening loophole
> (sdd-testing L1/L3).
> No requirement IDs were renumbered; amended/retired text is marked in place for traceability.

| # | Requirement(s) | Amendment |
|---|---|---|
| AMD-2026-10-21-01 | TDD-05 | The "role-update call-through" baseline coverage item is **RETIRED** — the call-through no longer exists once the chain is deleted. Rest of TDD-05 (signUp metadata, signIn guard, getUserProfile propagation, recovery/OTP sequencing) unchanged. |
| AMD-2026-10-21-02 | ERR-01 | `updateRol` removed from the enumerated auth operations (the operation itself no longer exists). |
| AMD-2026-10-21-03 | SGN-03 (scenario "Legitimate path unaffected") | Re-pinned: the register UI no longer renders any role selector (dropdown deleted, task 8.2); role `'usuario'` is structurally guaranteed client-side. |
| AMD-2026-10-21-04 | MODIFIED "Role assignment at signup" (scenario "API-level attempt ignored") | Re-pinned to post-removal reality: no client API accepts a role argument; static grep gates replace the deleted-API assertion. |
| AMD-2026-10-21-05 | SEC-02 | `AuthService.updateUserRol` removed from the named client-side paths (it no longer exists); its absence is enforced by the Phase-8 static gate. `AdminService.cambiarRolUsuario` without admin claims and raw HTTP remain covered. |
| AMD-2026-10-21-06 | DECISION POINTS · SP-DP-2 | Marked **RESOLVED** — option (a) approved by user and extended to the full dead chain via DES-DP-3(a). |

## Context

The Huellitas login/auth module (Flutter + Supabase) has correctness and security defects
prioritized as P0/P0 in exploration §2.2: no `onAuthStateChange` subscription, unverified
RLS allowing potential privilege escalation via `usua_rol`, non-atomic signup producing
orphan accounts ("login loop"), incomplete error mapping leaking raw exceptions, and a
broken test baseline. The proposal groups the fix into 6 deliverables **S1–S6**:

- **Track A (no blockers)**: S1 (TDD baseline + injection seams), S2 (auth-state listener),
  S4 (error mapping + cooldown), S3 client-side prep.
- **Track B (BLOCKED-PENDING-EXPORT)**: S6 (baseline migration intake), S5 (RLS + `usua_rol`
  trigger), S3 migration part (`handle_new_user` trigger). Blocked until the user provides
  the schema-only Supabase Dashboard export (DP-1/DP-2 binding).

**Binding user-validated decisions applied here**: email confirmation is **OFF** in the live
Dashboard ⇒ resend-confirmation UI is OUT of required scope (kept only as a CONDITIONAL
scenario tied to DP-4); the atomic-signup DB trigger remains IN; mocktail for mocking
(DP-3); migrations applied by the user pasting reviewed SQL into the Supabase Dashboard
(DP-2); schema-only baseline committed once the export arrives (DP-1a).

### Requirement status legend

| Tag | Meaning |
|---|---|
| `TRACK-A` | Implementable immediately (Flutter only) |
| `TRACK-B · BLOCKED-PENDING-EXPORT` | Requirement is fully specified but implementation cannot start until the user's Supabase export is committed as baseline (S6) |
| `CONDITIONAL · DP-4` | Not required; activates only if email confirmation is re-enabled or template issues surface |

### Domains

```
S1  → test-baseline        TDD-01…TDD-07      TRACK-A
S2  → session-events       SES-01…SES-07      TRACK-A
S3  → atomic-signup        SGN-01…SGN-11      TRACK-A (client) / TRACK-B (migration)
S4  → auth-errors          ERR-01…ERR-07      TRACK-A
S5  → rbac-rls             SEC-01…SEC-08      TRACK-B · BLOCKED-PENDING-EXPORT
S6  → schema-baseline      BAS-01…BAS-05, VER-01  TRACK-B · BLOCKED-PENDING-EXPORT
```

---

## ADDED Requirements

### Domain: test-baseline (S1 — TDD foundation)

> Mirrors existing conventions: tests live under `test/`, `flutter_test` is the only current
> test dependency; mocking uses **mocktail** (DP-3 binding) — plain `Mock` subclasses, no codegen.

#### Requirement: TDD-01 — Green test suite baseline

The test suite MUST pass in full (`flutter test` exit code 0) before any behavioral change of
this change is merged. The broken default counter test MUST be replaced by a real smoke test
of the app.

##### Scenario: Red → green on the broken default test

- GIVEN the repository at its current state (`test/widget_test.dart` contains the default
  counter test that fails against the non-counter app)
- WHEN `flutter test` is executed
- THEN the run FAILS (RED baseline established) and, after S1 is implemented, ALL tests pass
  with exit code 0 (GREEN)

##### Scenario: Replacement smoke test is meaningful

- GIVEN the replaced `test/widget_test.dart`
- WHEN the test runs
- THEN it asserts real app behavior (renders without throwing under a pumped `MaterialApp` /
  provider harness) and contains no counter assertions

#### Requirement: TDD-02 — AuthController accepts an injected AuthService

`AuthController` MUST accept an optional `AuthService` via constructor injection, defaulting
to the current production behavior (`AuthService()`) when none is provided, so its business
logic can be unit-tested with a mocktail double. Production wiring in `lib/main.dart` MUST
remain unchanged in observable behavior.

##### Scenario: Red first

- GIVEN a unit test that constructs `AuthController` with a mocktail `AuthService` double
  whose `signIn` returns a stubbed `UsuarioModel`
- WHEN `login()` is invoked
- THEN no real Supabase call occurs (verified via `verify(() => mock.signIn(...))` on the
  double) — and this test FAILS to compile/run before the seam exists (RED) and passes after
  (GREEN)

##### Scenario: Default path preserved

- GIVEN `AuthController()` constructed with no arguments (as in `lib/main.dart`)
- WHEN any auth operation runs
- THEN it delegates to a real `AuthService` exactly as today (no behavior change)

#### Requirement: TDD-03 — AuthService accepts an injected SupabaseClient

`AuthService` MUST accept an optional `SupabaseClient` via constructor injection, defaulting
to `Supabase.instance.client`, so it is unit-testable without `Supabase.initialize()`.

##### Scenario: Red first

- GIVEN a unit test constructing `AuthService(client: mockClient)` where `mockClient` is a
  mocktail `SupabaseClient`
- WHEN `signIn()` is invoked with stubbed `auth.signInWithPassword(...)`
- THEN the profile query goes through the injected double (no singleton access) — RED before
  the seam, GREEN after

##### Scenario: Singleton default

- GIVEN `AuthService()` with no arguments in production code
- WHEN any method executes
- THEN it uses `Supabase.instance.client` as today

#### Requirement: TDD-04 — AuthController business logic unit tests (mocktail)

Unit tests MUST cover, at minimum: successful login, failed login (mapped error), Google
login cancel (no error shown), successful register, failed register, logout (state reset),
`tryRestoreSession` with and without an existing session, OTP recovery success/failure, and
stale-error clearing. Mocking is via **mocktail** doubles; FCM side effects MUST be isolated.

##### Scenario: Failed login maps and stores error

- GIVEN a mocked `AuthService` whose `signIn` throws `AuthException('Invalid login
  credentials')`
- WHEN `AuthController.login()` is invoked
- THEN it returns `false`, `errorMessage` equals `'Correo o contraseña incorrectos.'`, and
  `isLoading` is `false`

##### Scenario: Logout resets local state

- GIVEN an authenticated controller with `currentUser != null`
- WHEN `logout()` completes
- THEN `currentUser` is `null`, `errorMessage` is `null`, and listeners were notified

#### Requirement: TDD-05 — AuthService unit tests (mocktail)

Unit tests MUST cover, at minimum: `signUp` happy path (metadata payload asserted), `signIn`
happy path + null-user guard, `getUserProfile` propagation of not-found, ~~role-update
call-through~~ (**RETIRED by AMD-2026-10-21-01**: the call-through no longer exists once
`AuthController.updateRol` / `AuthService.updateUserRol` are removed under DES-DP-3 — task 8.1
deletes that test entirely; this is a sanctioned test retirement, not an assertion weakening),
and recovery/OTP sequencing. PostgREST builder chains are exercised through mocktail doubles
of `SupabaseClient`.

##### Scenario: signUp sends profile metadata

- GIVEN a mocked `SupabaseClient` capturing the `auth.signUp` arguments
- WHEN `signUp(nombre: 'Ana', correo: 'a@b.c', password: 'xxxxxx', telefono: '099')` runs
- THEN the call includes `data:` carrying `nombre` and `telefono` (see SGN-01) and NO
  `usuarios` insert is issued after cutover (see SGN-08)

##### Scenario: profile not found propagates a typed failure

- GIVEN the mocked builder chain throws on `.single()`
- WHEN `getUserProfile()` runs
- THEN the exception propagates to the caller (controller maps it — ERR-06)

#### Requirement: TDD-06 — Unit tests run without Firebase or network

Auth unit tests MUST be deterministic and offline: no Firebase initialization, no real
Supabase connection, no timers left pending. Any static FCM call inside auth operations
(`FcmService.instance…`) MUST be made injectable/mocked or tolerated as a no-op under test.

##### Scenario: Suite runs offline

- GIVEN `flutter test` in a clean environment (no Firebase config, no network)
- WHEN the auth test folders execute
- THEN every test passes with no pending-timer or platform-channel errors

#### Requirement: TDD-07 — Coverage threshold on touched auth code

The touched auth code (`lib/domain/controllers/auth_controller.dart`,
`lib/data/services/auth_service.dart`) MUST reach ≥ 80% line coverage measured by
`flutter test --coverage` (project-standards: minimum 80% for new/changed features).

##### Scenario: Coverage gate

- GIVEN S1–S4 implementation complete
- WHEN `flutter test --coverage` runs
- THEN lcov reports ≥ 80% line coverage for both named files, and `flutter test` exits 0

---

### Domain: session-events (S2 — global auth-state listener)

#### Requirement: SES-01 — Reactive auth-state subscription

`AuthController` MUST subscribe exactly once to `supabase.auth.onAuthStateChange` and MUST
expose resulting state changes to the UI via `notifyListeners()` (or an equivalent reactive
stream already consumed by the `Consumer<AuthController>` in `lib/main.dart`), replacing the
build-time snapshot model.

##### Scenario: Single subscription lifecycle

- GIVEN an `AuthController` instance created in a test with an injectable auth-event source
- WHEN the controller is initialized and later disposed
- THEN exactly one subscription was registered, and it is cancelled on dispose (no leaks,
  no duplicate subscriptions from repeated notifications)

##### Scenario: Red first

- GIVEN no listener implementation
- WHEN the test drives a simulated `signedOut` event after login
- THEN the test FAILS (controller state did not change) until SES-02/SES-03 logic lands

#### Requirement: SES-02 — Remote session loss routes to login without restart

When a `signedOut` event arrives from the server (expiry, revocation, remote sign-out) the
app MUST clear `currentUser`, stop rendering authenticated screens, and present the login
screen — with no app restart.

##### Scenario: Session revoked while using the app

- GIVEN the user is on `HomeScreen` with an active session
- WHEN Supabase emits `signedOut` (e.g., session revoked elsewhere)
- THEN `AuthController.currentUser` becomes `null` and the root `Consumer<AuthController>`
  renders `LoginScreen` on the same run

##### Scenario: Query failures no longer strand a dead session

- GIVEN a session that has expired while the app is open
- WHEN the token refresh fails and `signedOut` is emitted
- THEN the user is routed to login instead of remaining on `HomeScreen`/`AdminScreen` with a
  dead session (previous behavior: stale screen until restart)

#### Requirement: SES-03 — Signed-in event loads profile and routes by role

When a `signedIn` event arrives, the controller MUST load the user's `usuarios` profile and
the root widget MUST route `administrador` → `AdminScreen`, otherwise → `HomeScreen`.

##### Scenario: Role-based routing after event

- GIVEN the session-less app receives `signedIn` for a user whose profile has
  `usua_rol = 'administrador'`
- WHEN the event is processed and listeners notify
- THEN `AdminScreen` is rendered; GIVEN a profile with `usua_rol = 'usuario'`, THEN
  `HomeScreen` is rendered

##### Scenario: Signed-in event for a user whose profile row is missing

- GIVEN `signedIn` fires but the `usuarios` lookup returns no row
- WHEN the event is processed
- THEN the app does not crash or loop silently: it surfaces a recoverable state (login
  screen or mapped error message) — the orphan case must remain detectable after cutover
  (see SGN-06)

#### Requirement: SES-04 — Token refresh is silent

`tokenRefreshed` events MUST NOT trigger navigation changes, splash display, or profile
re-fetch storms; they only keep the session alive.

##### Scenario: No navigation churn on refresh

- GIVEN an authenticated user on `HomeScreen`
- WHEN `tokenRefreshed` is emitted several times
- THEN the rendered screen is unchanged, `isInitializing` stays `false`, and the profile is
  fetched at most once per refresh event

#### Requirement: SES-05 — User-updated event refreshes local profile

`userUpdated` events MUST refresh `currentUser` from the profile source so edits made from
another device/session appear without re-login.

##### Scenario: Profile changed elsewhere

- GIVEN an authenticated session
- WHEN Supabase emits `userUpdated` (profile/name changed on another device)
- THEN `currentUser` reflects the updated profile after the event is processed and the UI
  rebuilt

#### Requirement: SES-06 — Password-recovery session is routed correctly

After OTP recovery creates a session, the app MUST reflect the authenticated state
immediately (navigate to the authenticated area or the password-reset step as appropriate)
instead of desyncing back to `LoginScreen` with an existing session (exploration P1-9).

##### Scenario: Recovery OTP succeeds

- GIVEN the user verified the 6-digit OTP (`verifyOTP(type: recovery)`) and a session exists
- WHEN the `passwordRecovery`/`signedIn` event is processed
- THEN the app no longer shows a logged-out `LoginScreen` while a session is active; the
  user completes the flow without manually logging in again

##### Scenario: Recovery event without a session

- GIVEN `passwordRecovery` fires with a null/expired session
- WHEN processed
- THEN the app stays on (or returns to) the login screen with a mapped message and does not
  crash

#### Requirement: SES-07 — Cold-start initial session does not fight session restore

The listener's `initialSession` MUST NOT conflict with the existing
`tryRestoreSession()`/splash flow (`isInitializing`); startup MUST perform exactly one
profile load path and the splash MUST dismiss normally.

##### Scenario: Warm start with stored session

- GIVEN the app cold-starts with a persisted session
- WHEN initialization completes
- THEN `isInitializing` transitions `true → false` once, the profile is loaded exactly once
  (no double FCM token save storm), and the correct screen (login/home/admin) renders

---

### Domain: atomic-signup (S3 — profile creation)

#### Requirement: SGN-01 — signUp transmits profile metadata (client prep) · TRACK-A

`AuthService.signUp` MUST pass `nombre` and `telefono` (and NOT `rol`) via the `data:`
metadata argument of `supabase.auth.signUp`, so the server-side trigger (SGN-02) can build
the profile from `raw_user_meta_data`.

##### Scenario: Metadata payload

- GIVEN a mocked `SupabaseClient` capturing `auth.signUp` args
- WHEN `signUp(nombre: 'Ana Torres', correo: 'ana@x.com', password: '…', telefono: '0991')`
  runs
- THEN `data` contains `nombre = 'Ana Torres'` and `telefono = '0991'`, and contains no role
  field

#### Requirement: SGN-02 — Database trigger creates the profile atomically · TRACK-B · BLOCKED-PENDING-EXPORT

A `SECURITY DEFINER` trigger on `auth.users` AFTER INSERT (the official Supabase
`handle_new_user` pattern) MUST create the corresponding `usuarios` row from
`NEW.raw_user_meta_data` within the same transaction as the auth-user insert, making signup
atomic: either both the account and the profile exist, or neither does.

##### Scenario: Email signup creates profile server-side

- GIVEN the trigger migration is applied to the live project (per DP-2)
- WHEN a new user signs up with `data: {nombre, telefono}`
- THEN exactly one `usuarios` row exists for the new `auth.users.id` with `usua_nombre`,
  `usua_telefono` populated — with NO client-side INSERT involved

##### Scenario: Migration verified red-then-green

- GIVEN the verification script for SGN-02 executed BEFORE the migration is applied
- WHEN the script attempts a synthetic `auth.users`-equivalent insert assertion
- THEN it reports FAIL (no trigger → no profile row); AFTER applying the migration the SAME
  script reports PASS (see VER-01)

##### Scenario: Trigger failure blocks signup (documented blast radius)

- GIVEN a hypothetical trigger exception during signup
- WHEN the transaction rolls back
- THEN no `auth.users` row and no `usuarios` row persist (atomic), and this failure mode is
  explicitly accepted in the migration review with a documented `DROP TRIGGER` rollback
  (Supabase docs caution: a failing trigger blocks signups)

#### Requirement: SGN-03 — Signup role can never be client-controlled · TRACK-B · BLOCKED-PENDING-EXPORT (SECURITY)

The trigger MUST assign `usua_rol = 'usuario'` for every new signup regardless of any
client-supplied metadata; `rol` MUST NOT be readable from `raw_user_meta_data` for role
assignment. Self-promotion to `administrador`/`veterinario` at signup MUST be impossible.

##### Scenario: Malicious metadata

- GIVEN an attacker calls `supabase.auth.signUp(..., data: {'rol': 'administrador',
  'usua_rol': 'administrador'})`
- WHEN the account is created
- THEN the resulting `usuarios.usua_rol` is `'usuario'`

##### Scenario: Legitimate path unaffected · amended 2026-10-21 (AMD-2026-10-21-03)

- GIVEN the app's register flow after the DES-DP-3 chain removal (the register screen renders
  NO role selector — the single-option rol dropdown is deleted in task 8.2, so no client UI
  can offer a role choice at all)
- WHEN a normal signup completes
- THEN the profile role is `'usuario'`, matching today's intended behavior

#### Requirement: SGN-04 — Trigger is idempotent against pre-existing profiles · TRACK-B · BLOCKED-PENDING-EXPORT

The trigger MUST tolerate a `usuarios` row that already exists for the new auth user
(during the two-phase deploy when the client INSERT still runs, and for Google first-time
flows) without failing signup.

##### Scenario: Client INSERT runs first (transition window)

- GIVEN the client still executes its profile INSERT (phase (a) of the deploy ordering)
- WHEN the auth account is created and the trigger fires after the client row was already
  inserted
- THEN signup succeeds (duplicate handled as a no-op) and exactly one profile row exists

##### Scenario: Google first-time sign-in

- GIVEN a first-time Google login where `AuthService.signInWithGoogle` checks for an
  existing profile
- WHEN no profile exists and the trigger creates it
- THEN the flow reads back the existing profile instead of failing on duplicate insert

#### Requirement: SGN-05 — Missing metadata must not break profile creation · TRACK-B · BLOCKED-PENDING-EXPORT

The trigger MUST create a profile with safe defaults when `raw_user_meta_data` lacks
`nombre`/`telefono` (e.g., OAuth providers supplying only an email), deriving a usable
`usua_nombre` fallback (e.g., from the email local part) rather than raising a not-null
violation.

##### Scenario: OAuth signup with no nombre

- GIVEN an auth user inserted with `raw_user_meta_data` containing only the provider's basic
  fields
- WHEN the trigger runs
- THEN a `usuarios` row is created with a non-empty `usua_nombre` fallback, null telefono,
  rol `'usuario'`, and signup succeeds

#### Requirement: SGN-06 — Signup cannot produce an orphan account · TRACK-B · BLOCKED-PENDING-EXPORT (SECURITY/CORRECTNESS)

After cutover there MUST be no code path that leaves an `auth.users` account without a
`usuarios` profile (the current "login loop": `getUserProfile().single()` throws forever).
Server-side atomicity (SGN-02) is the guarantee; the client MUST surface a mapped, actionable
error if a profile lookup still fails (ERR-06).

##### Scenario: Orphan loop is impossible

- GIVEN the trigger is live and the client INSERT removed (SGN-08)
- WHEN signup succeeds
- THEN an immediate `signIn` + `getUserProfile` succeeds without error

##### Scenario: Residual orphan is detected, not looped

- GIVEN an orphan account created BEFORE this fix (pre-existing production data)
- WHEN that user logs in and the profile lookup fails
- THEN the app shows a mapped Spanish error (not `'Error inesperado: …'`) and never enters
  an infinite silent loop — repair path documented in the change notes (manual SQL or
  re-trigger of profile creation is an acceptable operational remedy, out of app scope)

#### Requirement: SGN-07 — Client profile INSERT is duplicate-tolerant during transition · TRACK-A

Until the trigger is verified live, the client-side profile INSERTs (email signup and
Google first-time) MUST be idempotent: a duplicate-key response from the server MUST NOT
surface as a registration failure.

##### Scenario: Duplicate insert during phase (a)

- GIVEN the trigger already live but the client INSERT still present
- WHEN signup causes the profile to already exist
- THEN `register()`/`signInWithGoogle()` return success (duplicate swallowed) and the user
  proceeds to the home screen

#### Requirement: SGN-08 — Client profile INSERTs removed after cutover · TRACK-B · BLOCKED-PENDING-EXPORT

Once the trigger is verified against the baseline, the `usuarios` INSERT statements in
`AuthService.signUp` and `AuthService.signInWithGoogle` MUST be removed; the end state MUST
be grep-verifiable (no client-side `from('usuarios').insert(` in auth flows).

##### Scenario: Grep gate

- GIVEN cutover complete
- WHEN searching `lib/data/services/auth_service.dart` for profile INSERT calls in the
  signup/Google flows
- THEN no matches remain (the profile-creation responsibility is server-side only)

#### Requirement: SGN-09 — Registration lands the user in the authenticated app · TRACK-A

With email confirmation OFF (binding decision), a successful `register()` MUST leave the
user authenticated and routed to the role-appropriate screen, with the profile row
available; it MUST NOT bounce the user back to `LoginScreen`.

##### Scenario: Successful registration

- GIVEN a valid registration form submission
- WHEN `AuthController.register()` succeeds
- THEN the app renders `HomeScreen` (rol `usuario`) with `isAuthenticated == true`, without
  requiring a manual re-login

#### Requirement: SGN-10 — Two-phase deploy ordering is observable · TRACK-A/TRACK-B

The change MUST be delivered in the documented order: (1) client tolerates duplicates
(SGN-07), (2) trigger applied and verified (SGN-02, VER-01), (3) client INSERT removed
(SGN-08). Each phase MUST be independently releasable as a Conventional Commit
(`feat(auth):` / `chore(db):`).

##### Scenario: Out-of-order protection

- GIVEN the trigger is NOT yet applied (Track B blocked)
- WHEN the Track A client changes are shipped
- THEN signup behavior is unchanged from today (client INSERT still creates the profile)
  and no error is introduced by SGN-01 metadata

#### Requirement: SGN-11 — Resend-confirmation UI · CONDITIONAL · DP-4 (NOT required)

A "reemail confirmation" action MUST exist ONLY IF email confirmation is re-enabled in the
Dashboard or a template issue (DP-4) makes it necessary. With confirmations OFF (current
validated state) this requirement is inactive and MUST NOT block verification. If activated:
`supabase.auth.resend(type: OtpType.signup, email: …)` with a cooldown shared with ERR-07.

##### Scenario: Inactive (default)

- GIVEN email confirmation is OFF in the live Dashboard
- WHEN the change is verified
- THEN the absence of a resend-confirmation control is accepted as compliant

##### Scenario: Activated after re-enabling confirmation

- GIVEN confirmation re-enabled and a user signs up without a session
- WHEN signup reports "confirma tu correo"
- THEN a resend action is reachable from that state, calls `resend(type: signup)`, is
  cooldown-limited, and surfaces rate-limit errors via ERR-02

---

### Domain: auth-errors (S4 — error mapping + banner cooldown)

#### Requirement: ERR-01 — Stale error cleared at operation start

Every auth operation (`login`, `loginWithGoogle`, `register`, `recuperarContrasena`,
`verificarOtpYCambiarContrasena`, `logout`, `updateProfile`,
`cambiarContrasena`) MUST clear the previous `errorMessage` when the operation STARTS, so a
prior failure can never linger over a new attempt.

> **AMD-2026-10-21-02**: `updateRol` was removed from this enumeration — the operation itself
> no longer exists once DES-DP-3 lands (task 8.1). The requirement applies to every remaining
> auth operation; any newly added auth operation MUST join this enumeration.

##### Scenario: Error does not survive a new attempt

- GIVEN a failed login left `errorMessage = 'Correo o contraseña incorrectos.'`
- WHEN the user edits the form and submits again (any outcome)
- THEN at the moment the new operation begins `errorMessage` is `null` (banner cleared);
  after the attempt it is either `null` (success) or the NEW mapped message

##### Scenario: Google cancel leaves no residue

- GIVEN a previous login error is displayed
- WHEN the user taps "Google" and cancels the account picker
- THEN no error banner is shown (cancel stays silent, existing behavior preserved)

#### Requirement: ERR-02 — Email rate-limit errors mapped to Spanish

The message containing `over_email_send_rate_limit` MUST map to a Spanish message telling
the user to wait before requesting another email; the raw English text MUST NOT reach the
UI.

##### Scenario: Rate-limited recovery email

- GIVEN `resetPasswordForEmail` throws `AuthException` with message containing
  `over_email_send_rate_limit`
- WHEN `recuperarContrasena` handles it
- THEN `errorMessage` is a Spanish message referencing a waiting period (no occurrence of
  `over_email_send_rate_limit` or `rate limit` in the UI text)

#### Requirement: ERR-03 — Attempt-lockout errors mapped to Spanish

Messages matching the attempt-lockout pattern (`For security purposes, you have N attempt`)
MUST map to a Spanish message including the remaining attempts when present.

##### Scenario: Lockout warning with count

- GIVEN an AuthException message `For security purposes, you have 3 attempts left before
  being locked`
- WHEN the mapping runs
- THEN the UI shows a Spanish message conveying the remaining attempts, with no raw English
  sentence

#### Requirement: ERR-04 — Network failures mapped to Spanish

Connectivity failures (socket/HTTP client exceptions) during any auth operation MUST map to
a Spanish "check your connection and retry" message; internal exception text, hostnames, and
stack details MUST NOT be shown.

##### Scenario: Login with no connectivity

- GIVEN the device is offline
- WHEN `login()` fails with a socket-level exception
- THEN `errorMessage` equals a Spanish connectivity message and contains no technical
  exception string

#### Requirement: ERR-05 — OAuth/Google failures mapped to Spanish

Google flow failures (no ID token, Supabase id-token rejection, account-picker errors) MUST
map to actionable Spanish messages; the user-cancel path MUST remain silent (no error).

##### Scenario: Missing ID token

- GIVEN `googleAuth.idToken` is null
- WHEN `signInWithGoogle` fails
- THEN the UI shows a Spanish message about the Web Client ID configuration, not the raw
  exception chain

##### Scenario: Supabase rejects the Google token

- GIVEN `signInWithIdToken` throws an `AuthException`
- WHEN handled by the controller
- THEN a mapped Spanish message is shown (never `Error inesperado: …`)

#### Requirement: ERR-06 — No raw exception text ever reaches the UI

The catch-all fallbacks (`'Error inesperado: $e'`, `'Error al crear la cuenta: $e'`,
`e.toString()` passthroughs) MUST be replaced by fixed Spanish generic messages; error text
MUST NOT contain exception class names, stack traces, SQL, or internal identifiers
(project-security: "no sensitive data in errors", "no stack traces to users").

##### Scenario: Unknown failure fallback

- GIVEN an unmapped exception thrown by any auth operation
- WHEN the catch-all runs
- THEN `errorMessage` is a fixed generic Spanish string (e.g., 'Ocurrió un error. Intenta
  de nuevo.') and contains none of: `Exception`, `SocketException`, `PostgrestException`,
  raw English server text, or interpolated `$e`

##### Scenario: Security lint on the mapping (unit test)

- GIVEN a table of representative raw failure messages (including SQL errors and Auth
  internals)
- WHEN each is passed through the error pipeline
- THEN the resulting UI message matches an allowlisted Spanish pattern (asserted in tests,
  TDD-04)

#### Requirement: ERR-07 — Recovery resend cooldown

The password-recovery "Enviar código" action MUST be rate-limited client-side with a
cooldown of 60 seconds (aligning with Supabase's default email send interval): during
cooldown the action is disabled and a countdown is displayed; a server rate-limit response
(ERR-02) MUST also start the cooldown.

##### Scenario: Cooldown countdown (unit test, fake clock)

- GIVEN `recuperarContrasena` just succeeded
- WHEN tests advance the clock 0s → 30s → 61s
- THEN the resend action is disabled with remaining time shown at 0s and 30s, and enabled
  again at 61s

##### Scenario: Server-driven cooldown

- GIVEN the user re-requests a code and the server responds `over_email_send_rate_limit`
- WHEN the error is mapped (ERR-02)
- THEN the cooldown timer starts as well (UI cannot be spammed in a tight loop)

##### Scenario: No pending timers leak

- GIVEN a test that starts a cooldown and finishes
- WHEN the test body ends
- THEN `flutter test` reports no pending timer (cooldown uses a cancelable/disposed-safe
  mechanism)

---

## MODIFIED Requirements

### Requirement: Session detection — build-time snapshot → event-driven state

**Previous**: The app decides routing from a snapshot (`currentSession != null`,
`currentUser`) taken at build time; there is no `onAuthStateChange` subscription anywhere
(verified by grep), so expiry/revocation only becomes visible after app restart, and a
post-recovery session desyncs the navigation stack (exploration P0-1, P1-9).

**New**: The system MUST derive the visible auth state reactively from Supabase auth events
(SES-01…SES-07), keeping `isAuthenticated`, `currentUser`, and routing synchronized with the
server for the whole app lifetime.

#### Scenario: Revocation without restart

- GIVEN a user actively using `AdminScreen`
- WHEN their session is revoked server-side
- THEN within the same run the app returns to `LoginScreen` with cleared `currentUser`

#### Scenario: Recovery desync eliminated

- GIVEN a recovery OTP verified while `LoginScreen` sits in the nav stack
- WHEN the auth event is processed
- THEN the app shows the authenticated/reset-password state instead of a logged-out screen
  with a live session

### Requirement: Role assignment at signup — client-supplied → server-assigned

**Previous**: `AuthService.signUp(rol: …)` accepted any rol and persisted the client value
into `usuarios.usua_rol` (UI limited it to `usuario`, the API did not) — an unauthenticated
input influencing authorization data.

**New**: The role of a newly created profile MUST be assigned exclusively server-side as
`'usuario'` (SGN-03); the client MUST NOT transmit or persist a role at signup time.
Strengthened by DES-DP-3 (AMD-2026-10-21-04): the `signUp(rol:)` parameter and the
register-screen role dropdown are removed outright, so no client API even accepts a role.

#### Scenario: API-level attempt ignored · amended 2026-10-21 (AMD-2026-10-21-04)

- GIVEN the DES-DP-3 client chain removal (no `signUp(rol:)` parameter, no register-screen
  rol dropdown — grep gate `grep "rol:" lib/presentation/screens/login/register_screen.dart`
  → 0 matches, task 8.2)
- WHEN a hostile/modified client attempts to smuggle a role via `supabase.auth.signUp`
  `data: {'rol': 'administrador'}` metadata (the only remaining client channel)
- THEN the account and profile are created with stored `usua_rol = 'usuario'` (SGN-03
  server-side guarantee is the sole authority)

### Requirement: Auth error surfacing — partial mapping with raw fallback → complete mapping, leak-free

**Previous**: `_mapAuthError` covered 4 messages; rate-limit, lockout, network and OAuth
errors fell through to `'Error inesperado: $e'` / `e.toString()`, and `_errorMessage` was
never cleared at operation start (exploration P0-6, P1-7).

**New**: The system MUST map every expected auth failure class to a specific Spanish message
(ERR-02…ERR-05), fall back to a fixed generic Spanish message for anything unknown
(ERR-06), and clear stale errors at the start of every operation (ERR-01).

#### Scenario: Rate-limit at login

- GIVEN a rate-limit AuthException during a login attempt
- WHEN handled
- THEN the banner shows the specific Spanish rate-limit message (not generic, not raw)

#### Scenario: Success after failure leaves clean UI

- GIVEN a previous failed attempt showed an error
- WHEN a subsequent attempt succeeds
- THEN no error banner is visible after completion

---

## REMOVED Requirements

### Requirement: Client-side `usuarios` INSERT in email signup

**Reason**: Non-atomic two-step signup creates orphan accounts and the "login loop"
(exploration P0-3). Replaced by the server-side trigger (SGN-02) which makes profile
creation atomic with account creation.

**Migration**: Two-phase cutover — SGN-07 (client INSERT becomes duplicate-tolerant,
TRACK-A) → SGN-02 trigger applied and verified (TRACK-B, blocked on export) → SGN-08
(client INSERT removed, grep-verifiable). Until SGN-08 lands, the INSERT remains as a
temporary idempotent fallback.

#### Scenario: End state

- GIVEN cutover complete
- WHEN `AuthService.signUp` runs for a new email user
- THEN no `from('usuarios').insert(...)` executes in the email flow, and the profile row
  exists anyway (created by the trigger)

### Requirement: Client-side first-time profile INSERT in Google sign-in

**Reason**: Same orphan risk and duplicate risk against the new trigger (exploration P0-3,
P1-8 adjacent).

**Migration**: Same cutover as above (SGN-07 → SGN-02 → SGN-08); the "profile exists?"
check may remain as a read, the INSERT must go.

#### Scenario: End state

- GIVEN a first-time Google sign-in after cutover
- WHEN `signInWithGoogle` completes
- THEN the profile exists (trigger-created) and no client INSERT ran

### Requirement: Raw exception leakage to the UI

**Reason**: `'Error inesperado: $e'`, `'Error al crear la cuenta: $e'` and
`e.toString()`-passthrough expose internal exception text (English, possibly SQL/internal
identifiers) to users — violates project-security error-handling rules and is unreadable
for Spanish-speaking users.

**Migration**: Replaced by ERR-01…ERR-06; unit tests assert an allowlisted message pattern.

#### Scenario: No regression

- GIVEN any auth operation under test
- WHEN it fails
- THEN the surfaced message never matches `/<Exception|SocketException|Postgrest|Error
  inesperado|attempt\(/i` style raw patterns

---

## Security Requirements (cross-cutting — security-sensitive auth change)

> Applies project-security: RBAC, least privilege, defense in depth, no sensitive data in
> errors, security test coverage for auth/authz logic. All requirements below are
> **TRACK-B · BLOCKED-PENDING-EXPORT** because RLS/triggers cannot be authored safely
> without the real baseline (exploration §3.5: policies are not in the repo).

#### Requirement: SEC-01 — RLS enabled with explicit policies (deny by default)

Row Level Security MUST be enabled on `usuarios` (and recorded for every table in the
baseline) with explicit policies; any table without an explicit policy MUST deny anon and
authenticated access by default.

##### Scenario: RLS audit query

- GIVEN the baseline imported (BAS-01) and the S5 migration applied
- WHEN executing the verification query over `pg_class`/`pg_policies` for `public` tables
- THEN every table has `relrowsecurity = true`, and policy definitions for `usuarios` are
  documented in the migration file

##### Scenario: Unauthenticated read/write denied

- GIVEN a client with only the anon key (no session)
- WHEN it attempts `select/insert/update` on `usuarios` via PostgREST
- THEN all attempts are rejected by RLS (empty result for reads, permission error for
  writes)

#### Requirement: SEC-02 — Non-admin clients cannot modify `usua_rol`

No authenticated non-admin client (anon key + valid user JWT) MUST be able to change
`usua_rol` for any row — neither its own nor another user's — through PostgREST, RPC, or
any client-side path (`AdminService.cambiarRolUsuario` when called without admin claims,
raw HTTP).

> **AMD-2026-10-21-05**: `AuthService.updateUserRol` was removed from the named client-side
> paths — the method no longer exists once DES-DP-3 lands (task 8.1, grep gate
> `grep -n "updateRol\|updateUserRol" lib/ test/` → 0 matches). The client-side
> non-enforcement surface is gone by construction; this requirement remains binding against
> any *future* reintroduction of such a path and against `AdminService.cambiarRolUsuario`
> called without admin claims.

##### Scenario: Self-promotion attempt (RED/GREEN)

- GIVEN a verification script run BEFORE the S5 migration (baseline may be permissive)
- WHEN an authenticated non-admin JWT executes
  `update usuarios set usua_rol='administrador' where usua_id = <own uid>`
- THEN the script reports current behavior; AFTER applying the migration the SAME script
  asserts the update affects 0 rows or raises a permission/trigger error (VER-01)

##### Scenario: Promoting another user

- GIVEN the same non-admin JWT
- WHEN it attempts to set `usua_rol = 'veterinario'` on a different user's row
- THEN the write is rejected (0 rows / error), preserving the `solicitudes_rol` approval
  workflow as the only user-driven path (SEC-08)

#### Requirement: SEC-03 — Database-level backstop trigger on `usua_rol` (defense in depth)

Independent of RLS policy drift, a trigger on `usuarios` (BEFORE UPDATE when
`OLD.usua_rol IS DISTINCT FROM NEW.usua_rol`) MUST reject role changes unless the actor is
an authenticated admin, the service role, or a direct non-JWT session (Dashboard SQL editor
as `postgres`). It MUST also constrain the new value to the allowed role set
(`usuario|veterinario|administrador`).

##### Scenario: Defense in depth if a policy is dropped

- GIVEN RLS on `usuarios` temporarily misconfigured (simulated in the verification script by
  bypassing policy context as the table owner)
- WHEN a non-admin JWT attempts a role change
- THEN the trigger raises an error and the UPDATE rolls back

##### Scenario: Invalid role value rejected

- GIVEN any actor attempting `usua_rol = 'superadmin'`
- WHEN the UPDATE runs
- THEN it is rejected regardless of actor privileges (value allowlist)

##### Scenario: Service role allowed

- GIVEN the service-role context (e.g., an Edge Function or Dashboard)
- WHEN a role change executes
- THEN it succeeds (no operational breakage)

#### Requirement: SEC-04 — Legitimate role-change paths keep working (least functionality)

The admin panel flows MUST continue to function after S5: direct role change from
`admin_usuarios_tab` (`cambiarRolUsuario`) and vet-request approval
(`aprobarSolicitudYCambiarRol`) executed by an authenticated `administrador`.

##### Scenario: Admin changes a role

- GIVEN an authenticated admin JWT
- WHEN `update usuarios set usua_rol='veterinario' where usua_id = <target>`
- THEN exactly 1 row is updated and the trigger allows it

##### Scenario: Approval flow end-to-end

- GIVEN a user with a `pendiente` `solicitudes_rol` row and an admin approving it
- WHEN the approval flow runs from the app
- THEN the role becomes `veterinario`, the solicitud state updates, and the `veterinarios`
  row creation path is unaffected

#### Requirement: SEC-05 — No anon write path to `usuarios` after cutover

After SGN-08 cutover, no policy MUST permit anon (or authenticated) INSERT into `usuarios`;
profile creation exists only via the `SECURITY DEFINER` trigger path.

##### Scenario: Direct profile insert denied

- GIVEN post-cutover state
- WHEN an authenticated non-admin client attempts to insert a `usuarios` row for an
  arbitrary `usua_id`
- THEN the insert is rejected (RLS and/or trigger), preventing fabricated profiles

#### Requirement: SEC-06 — Users may edit only their own profile, non-role fields

Authenticated users MUST remain able to update their own `usuarios` row (nombre, teléfono,
cédula, GPS, productor flags, foto) and MUST NOT be able to update other users' rows; role
fields are excluded from client updates (enforced by column-level grants and/or the SEC-03
trigger).

##### Scenario: Own profile edit works

- GIVEN an authenticated user
- WHEN it updates `usua_nombre` on its own row
- THEN exactly 1 row is affected and the change persists

##### Scenario: Other-user edit denied

- GIVEN the same user
- WHEN it attempts to update any field on another user's row
- THEN 0 rows are affected / permission error

#### Requirement: SEC-07 — Every database migration ships a paired rollback, non-destructive

Each file added under `supabase/migrations/` MUST contain only non-destructive statements
(no DROP TABLE/DELETE/TRUNCATE of data) and MUST document the exact rollback statement
(`DROP TRIGGER…`, `DROP POLICY…`, `CREATE OR REPLACE` back to previous definition) in the
file header comment; rollbacks MUST be applicable through the same channel as the migration
(DP-2: Dashboard SQL editor paste).

##### Scenario: Rollback drill

- GIVEN the S3 or S5 migration applied to the live project
- WHEN its documented rollback statement is executed via the Dashboard SQL editor
- THEN the previous behavior is restored (trigger/policy gone, data intact) and the
  verification script reports the pre-migration state

##### Scenario: Destructive-statement gate

- GIVEN any SQL file proposed for this change
- WHEN reviewed against the checklist
- THEN it contains no data-destructive statement and no hardcoded secrets/PII (also applies
  to the sanitized baseline, BAS-02)

#### Requirement: SEC-08 — Role-request workflow remains available to plain users

A plain authenticated user MUST still be able to INSERT its own `solicitudes_rol` request
(veterinario approval workflow) — the hardening MUST NOT close the legitimate privilege
path, only its unauthorized shortcut.

##### Scenario: Vet request succeeds for `usuario`

- GIVEN an authenticated user with rol `usuario`
- WHEN it submits a role request
- THEN the row is created with state `pendiente`; the role itself remains unchanged until
  admin approval (SEC-04)

---

### Domain: schema-baseline (S6 — migration intake)

> All requirements TRACK-B · BLOCKED-PENDING-EXPORT until the user provides the Dashboard
> export (Open Question 1 of the proposal). DP-1a binding: schema-only baseline is committed
> to `supabase/migrations/`.

#### Requirement: BAS-01 — Export received as schema reference

The user-provided Supabase export (schema DDL, RLS policies, triggers, indexes, views,
Auth settings summary) MUST be received and stored as the reference input for authoring the
S3/S5 migrations. No S5/S3-migration SQL may be authored from inference (exploration §3
caveat).

##### Scenario: Authoring input check

- GIVEN an S3 or S5 migration ready for review
- WHEN checking its provenance
- THEN every construct (table/column/policy/trigger name) traces to the exported SQL, not
  to the inferred map in exploration §3.1

#### Requirement: BAS-02 — Baseline is schema-only and sanitized

The committed baseline MUST contain schema definitions only: no row data, no PII, no
service-role/anon keys, no storage object data, no email addresses of real users.

##### Scenario: Hygiene gate

- GIVEN the exported SQL to be committed
- WHEN reviewed (or grepped) for `INSERT INTO`, `COPY `, API keys (`eyJ…`), and personal
  data
- THEN none are present; only DDL/policy/trigger definitions remain

#### Requirement: BAS-03 — Baseline committed under `supabase/migrations/`

The sanitized schema-only baseline MUST be committed as a single clearly named baseline
migration file under `supabase/migrations/` (Conventional Commit `chore(db):`), making the
repo schema diffable and satisfying DP-1a.

##### Scenario: Baseline in repo

- GIVEN the sanitized export
- WHEN committed
- THEN `supabase/migrations/` contains the baseline file alongside the existing
  `add_fcm_token.sql`, and `git status` shows no untracked export artifacts left behind

##### Scenario: Baseline matches live

- GIVEN the committed baseline
- WHEN spot-checked against the live Dashboard schema (tables/columns/policies listed)
- THEN no discrepancy is recorded; any discrepancy is corrected BEFORE S5 authoring

#### Requirement: BAS-04 — Auth/RLS settings captured for downstream decisions

The intake MUST record the live Auth settings relevant to this change (email confirmation
state — currently OFF per user validation, OTP expiry, rate limits, recovery template
contains `{{ .Token }}` status) in the change folder so S3/SGN-11/DP-4 stay verifiable.

##### Scenario: Settings snapshot exists

- GIVEN intake complete
- WHEN reading the change folder
- THEN the auth-settings snapshot exists and confirms confirmation = OFF (or flags
  DP-4/SGN-11 activation if that changed)

#### Requirement: VER-01 — SQL verification protocol for every Track-B requirement

Every TRACK-B behavioral requirement (SGN-02…SGN-06, SEC-01…SEC-06) MUST have a committed
SQL verification script under `supabase/migrations/verify/` using `DO` blocks with
`RAISE EXCEPTION` assertions and simulated JWT contexts (set role/claims in a transaction),
executed as a red-green cycle: the script FAILS before its migration and PASSES after it.
Scripts are run manually via the Dashboard SQL editor (DP-2) and their results recorded in
the change folder during verification.

##### Scenario: Red before migration

- GIVEN the verification script for SEC-02 executed against the pre-migration baseline
- WHEN it asserts that a non-admin role update is rejected
- THEN it raises `FAIL: …` (requirement not yet met)

##### Scenario: Green after migration

- GIVEN the same script executed after applying the S5 migration
- WHEN the assertions run (anon denied, non-admin blocked, admin allowed, service role
  allowed, invalid value rejected)
- THEN all assertions pass with no `RAISE EXCEPTION`

##### Scenario: Rollback returns to red

- GIVEN the rollback statement (SEC-07) executed after a green run
- WHEN the script is re-run
- THEN it fails again, confirming the migration (not a script defect) provided the behavior

---

## Traceability

| Proposal deliverable | Requirement IDs | Track | Status |
|---|---|---|---|
| S1 — TDD baseline + seams | TDD-01…TDD-07 | A | Ready |
| S2 — `onAuthStateChange` listener | SES-01…SES-07 | A | Ready |
| S3 — atomic signup (client prep) | SGN-01, SGN-07, SGN-09, SGN-10 | A | Ready |
| S3 — atomic signup (migration) | SGN-02, SGN-03, SGN-04, SGN-05, SGN-06, SGN-08 | B | BLOCKED-PENDING-EXPORT |
| S3 — resend-confirmation UI | SGN-11 | — | CONDITIONAL · DP-4 (out of required scope) |
| S4 — error mapping + cooldown | ERR-01…ERR-07 (+ MODIFIED error surfacing) | A | Ready |
| S5 — RLS + `usua_rol` enforcement | SEC-01…SEC-08 | B | BLOCKED-PENDING-EXPORT |
| S6 — baseline migration intake | BAS-01…BAS-04, VER-01 | B | BLOCKED-PENDING-EXPORT |
| Session detection model | MODIFIED: Session detection | A | Ready |
| Signup role model | MODIFIED: Role assignment at signup | B | BLOCKED-PENDING-EXPORT |
| Dead client role-chain removal (SP-DP-2 + DES-DP-3(a)) | TDD-05, ERR-01, SEC-02, MODIFIED: Role assignment at signup — amended 2026-10-21 | A | Ready (spec amended before task 8.1 — DP-T3) |
| Legacy behaviors removed | REMOVED: email-signup INSERT, Google INSERT, raw exception leakage | A→B | Phased (see Migration notes) |

### Success-criteria amendments (vs proposal)

- Proposal success criterion *"Resend-confirmation action exists…"* is **demoted to
  conditional (SGN-11)** per the binding decision that email confirmation is OFF.
- All other proposal success criteria map 1:1 to TDD-01/07, SGN-06/08, SES-02, ERR-01/06,
  SEC-02/03 + VER-01, and the BLOCKED-PENDING tagging visible in the traceability table.

### Test artifact map (TDD red-green)

| Layer | Artifact | Tooling |
|---|---|---|
| Unit (controller/service) | `test/auth/*` | `flutter_test` + **mocktail** (DP-3), fake async for cooldowns |
| Smoke | `test/widget_test.dart` (replaced) | `flutter_test` |
| Database | `supabase/migrations/verify/*.sql` | Dashboard SQL editor (DP-2), DO-block assertions |
| Static gate | grep for client profile INSERT (SGN-08) | code search in verification |

---

## Open Verification Items (user action — cannot be answered from the repo)

1. Supabase export (schema + RLS + triggers + Auth settings) — unblocks every TRACK-B
   requirement.
2. Confirm the Recovery email template contains `{{ .Token }}`; if not, DP-4 decides and
   SGN-11/ERR-07 scope may grow.
3. Confirm no concurrent edits to auth files while Track A lands (merge risk).

## DECISION POINTS (orchestrator must present)

| ID | Decision | Options | Tradeoffs | Recommendation |
|---|---|---|---|---|
| **SP-DP-1** | Cooldown duration for recovery resend (ERR-07 fixed at 60s here) | (a) 60s fixed constant; (b) configurable constant with 60s default; (c) 60s + server-driven extension | (a) simplest, matches Supabase default email interval; (b) flexible, slightly more surface; (c) most robust, needs timer state for server responses | **(b)** one `static const` (lint: never hardcode elsewhere), behavior identical to (a) |
| **SP-DP-2** | Fate of `AuthController.updateRol` (dead code — zero callers; would be blocked by SEC-02/03 anyway) | (a) remove it in S5 alongside the DB hardening; (b) keep it, rely on DB rejection | (a) removes an attack/confusion surface, small diff; (b) zero Flutter risk, but a client API that always fails remains | **RESOLVED — user-validated option (a)**, extended to the whole dead chain by DES-DP-3(a); reflected in AMD-2026-10-21-01…06 |
| **SP-DP-3** | Verification-script location convention | (a) `supabase/migrations/verify/*.sql` committed; (b) scripts kept only in the change folder (not shipped) | (a) reusable regression asset, reviewable; (b) keeps `migrations/` minimal but scripts can be lost after archive | **(a)** — trivial directory, high audit value |

*Already resolved / binding (not re-opened): DP-1a, DP-2, DP-3, D1–D4, D9, **SP-DP-2 +
DES-DP-3(a) (full dead role-chain removal, spec amended 2026-10-21 per DP-T3)**; confirmation
OFF ⇒ SGN-11 conditional.*

---

## Amendments (2026-10-23) — Hotfix de prueba en vivo (BUG-1 / BUG-2 / botón Google en registro)

> **Rationale (binding)**: user-validated decisions from a completed live diagnosis (Track A
> Phases 1–3 already landed — commits `81db615`, `d396ea0`, `20d0afc`):
> **BUG 1** — Google sign-in failures are wrapped in `lib/data/services/auth_service.dart`
> (stage prefixes `'Error al abrir Google:'`, `'Error obteniendo autenticación de Google:'`,
> `'Error autenticando en Supabase con Google:'`); none of the prefixes match the
> `AuthErrorMapper` allowlist, so every Google failure — including `PlatformException` codes
> `sign_in_failed` / `sign_in_required` and details carrying `ApiException: 10` /
> `ApiException: 12500` — degrades to the generic fallback. `AuthController.loginWithGoogle()`'
> s generic catch is the only auth catch without `debugPrint`, leaving no diagnostic trail.
> Resolution = **code fix**: mapper branches with actionable Spanish copy + log
> instrumentation, tested live on a connected phone.
> **BUG 2** — `errorMessage` is shared controller state cleared only at operation start
> (ERR-01); navigation to `lib/presentation/screens/login/register_screen.dart` never clears
> it, so a stale login banner persists on the register screen (which already renders the
> banner via `Consumer<AuthController>`). Resolution = **clear banner on register entry**
> through the screen's existing `initState` (single choke point).
> **NEW** — the register screen has no Google button; `_GoogleButton`/`_GoogleLogoPainter`
> are private widgets in `lib/presentation/screens/login/login_screen.dart`. Resolution =
> **shared widget extraction**; `signInWithGoogle` already auto-creates the `'usuario'`
> profile, so register-with-Google needs only widget extraction + handler + rol-aware
> routing (mirror of the login screen's `_handleGoogleLogin`) — `AuthController` and
> `AuthService` need NO changes for this.
> **OUT OF SCOPE for this batch**: recovery/OTP redesign (next phase).
> No requirement IDs were renumbered; ERR-01/ERR-05 are extended in place and the new
> requirement continues the SGN series (SGN-12).

| # | Requirement(s) | Amendment |
|---|---|---|
| AMD-2026-10-23-01 | ERR-01 | Adds the scenario "Error cleared when entering register screen": a stale `errorMessage` MUST be cleared when the register screen is entered (single choke point: the register screen's `initState` invoking a dedicated controller clearing method), so a prior login failure can never render its banner on the register screen. |
| AMD-2026-10-23-02 | ERR-05 | Adds Google platform/stage failure scenarios: `PlatformException` failures with codes `sign_in_failed`, `sign_in_required` and details carrying `ApiException: 10` (developer/config error) or `ApiException: 12500` (SIGN_IN_FAILED), plus the three service wrapper-prefixed stage errors, MUST map to actionable Spanish copy DISTINCT from the generic fallback; the user-cancel path (`ApiException: 12501` / `sign_in_canceled` / existing `'cancelado'` marker) MUST remain silent. A log-only diagnostic channel (`debugPrint` of the raw detail) is explicitly allowed AND required for live diagnosis — consistent with ERR-06: raw text never reaches the UI. |
| AMD-2026-10-23-03 | SGN-12 (NEW) | Introduces requirement SGN-12 — Google sign-in available from the register screen via the shared button widget (extraction from the login screen; refactor guarded by existing tests). TRACK-A; no `AuthController`/`AuthService` changes. |

### ERR-01 — added scenario (AMD-2026-10-23-01)

##### Scenario: Error cleared when entering register screen

- GIVEN a failed login left `errorMessage` populated (banner visible on the login screen)
- WHEN the user navigates to the register screen and `RegisterScreen` initializes
- THEN `errorMessage` is `null` (cleared through the single choke point on register-screen
  entry) and the stale banner does NOT render on the register screen

### ERR-05 — added scenarios (AMD-2026-10-23-02)

##### Scenario: Google platform error maps to actionable Spanish copy

- GIVEN the Google flow fails with `PlatformException` code `sign_in_failed` whose details
  carry `ApiException: 10` or `ApiException: 12500`, or with code `sign_in_required`
- WHEN the failure passes through the error pipeline
- THEN the banner shows a specific actionable Spanish message (distinct from the generic
  fallback `'Ocurrió un error. Intenta de nuevo.'`) containing no raw exception text, no
  `ApiException` token, and no numeric status code (ERR-06 denylist)

##### Scenario: Wrapper-prefixed stage errors are distinguishable

- GIVEN `signInWithGoogle` fails at a wrapped stage so the surfaced error is prefixed
  `'Error al abrir Google:'`, `'Error obteniendo autenticación de Google:'`, or
  `'Error autenticando en Supabase con Google:'`
- WHEN the mapping runs
- THEN each stage maps to actionable Spanish copy (not the generic fallback), while the raw
  wrapped text is written only to the debug log (log-only channel, ERR-06)

##### Scenario: Google cancel stays silent (re-pinned)

- GIVEN a cancel surfaces as `ApiException: 12501`, `sign_in_canceled`, or the existing
  `'cancelado'` marker
- WHEN the mapping runs
- THEN the result is `null` (no banner) — cancel silence is preserved from the original
  ERR-05/ERR-01 cancel behavior

### Requirement: SGN-12 — Google sign-in available from the register screen · TRACK-A (AMD-2026-10-23-03)

The register screen MUST expose Google sign-in through the SAME shared button widget used by
the login screen (single source definition; the private login-screen widgets are extracted
into a shared widget, never duplicated). Activating it MUST run the identical
`AuthController.loginWithGoogle()` flow — including first-time profile auto-creation with
rol `'usuario'` — and rol-aware routing; failures MUST surface through the shared error
banner with the mapped Spanish copy (ERR-05/ERR-06). This requirement MUST be satisfiable
without changes to `AuthController` or `AuthService`.

##### Scenario: Register-screen Google sign-in succeeds

- GIVEN an unauthenticated user on the register screen
- WHEN they tap the Google button and pick an account
- THEN the behavior is identical to the login-screen Google flow: `loginWithGoogle()`
  executes, the profile is auto-created if absent (rol `'usuario'`), and routing is
  rol-aware (`administrador` → admin screen, otherwise → home screen)

##### Scenario: Register-screen Google failure shows the shared banner

- GIVEN a user on the register screen
- WHEN the Google flow fails with any mapped failure (ERR-05, including the
  AMD-2026-10-23-02 branches)
- THEN the shared error banner on the register screen displays the mapped Spanish message
  (never the raw wrapper text)

##### Scenario: Cancel from register stays silent

- GIVEN a user on the register screen who cancels the Google account picker
- WHEN the cancel is processed
- THEN no error banner is shown and the user remains on the register screen

##### Scenario: Shared widget parity (refactor guard)

- GIVEN the Google button widget definition
- WHEN the login and register screens render it
- THEN both consume the SAME shared widget (no duplicated private copies — grep gate:
  `_GoogleButton|_GoogleLogoPainter` no longer DEFINED in
  `lib/presentation/screens/login/login_screen.dart`) and the existing login-screen tests
  remain green with unchanged assertions

### Traceability addendum (2026-10-23)

| Proposal deliverable | Requirement IDs | Track | Status |
|---|---|---|---|
| Hotfix live-test batch — actionable Google error copy + log instrumentation | AMD-2026-10-23-02 (ERR-05 extended) | A | Ready |
| Hotfix live-test batch — stale banner cleared on register entry | AMD-2026-10-23-01 (ERR-01 extended) | A | Ready |
| Hotfix live-test batch — register-screen Google button (shared widget) | SGN-12 (AMD-2026-10-23-03) | A | Ready |

Track B status (SGN-02…SGN-08 migration, SEC-01…SEC-08, BAS-01…BAS-04, VER-01) is
**UNCHANGED**: `BLOCKED-PENDING-EXPORT`.

---

## Amendments (2026-10-23-b) — Recuperación de contraseña basada en enlace (deep link `huellitas://`)

> **Rationale (binding)**: user-validated redesign of the password-recovery flow (new
> deliverable **S7**) after the completed live diagnosis. The current OTP flow — the private
> 2-step `_RecuperarContrasenaScreen` inside `lib/presentation/screens/login/login_screen.dart`
> (step 1 `_enviarCodigo` → `recuperarContrasena` → `resetPasswordForEmail(correo.trim())` with
> NO `redirectTo`; step 2 6-digit input → `verifyOtp(email, token, OtpType.recovery)` →
> `updateUser(UserAttributes(password:))`) — is replaced by a **link-based flow with NO 6-digit
> code anywhere**. Binding user decisions applied here:
> - Send action copy becomes **"Restablecer contraseña"** (replaces "Enviar código"); on tap
>   the user receives **ONE generic message regardless of account existence** (anti-enumeration;
>   **verified** Supabase behavior: `resetPasswordForEmail` "doesn't reveal whether an account
>   exists… when no user is associated with the address, Supabase Auth won't send an email,
>   though the method still returns without an error" — no client existence check needed).
> - The email uses the link-based template (`{{ .ConfirmationURL }}`, implicit-flow link);
>   tapping the link returns to the app via the **custom scheme**
>   `huellitas://password-recovery` passed as `redirectTo` (**verified** official Flutter
>   reference example: `io.supabase.flutter://reset-callback/` — custom schemes are the
>   sanctioned Flutter pattern; the redirect URL must also be registered in the Supabase
>   Dashboard, user action → verification item 6-b.2).
> - `supabase_flutter`'s deep-link observer (`detectSessionInUri = true`, **verified** default
>   in `FlutterAuthClientOptions`: "If true, the client will start the deep link observer and
>   obtain sessions when a valid URI is detected") exchanges the incoming URI for a session and
>   emits `passwordRecovery`; that event now **navigates** to a NEW standalone password screen
>   (no code entry), where the user sets the new password → `updateUser` persists it → success →
>   navigate to `LoginScreen`.
> - The 60 s client cooldown (**ERR-07 / SP-DP-1**) is RETAINED for the send action (verified
>   current behavior: cooldown starts on send success and on `over_email_send_rate_limit`
>   only; a network failure does NOT start it).
> - Email template editing, Redirect-URL registration, and SMTP/delivery troubleshooting are
>   **user actions in the Dashboard** — this spec defines app-side behavior + open verification
>   items only. Out of scope: Google-login issues (separate), Track B/SENSO/push, iOS (the
>   repo has NO `ios/` directory — Android-only deep-link scope).
> TDD stays enforced: every RST requirement is tiered unit / widget / static-gate / LIVE.
> OTP-specific test retirement is spec-sanctioned by these amendments (same mechanism as
> AMD-2026-10-21-01 / DP-T3 — sanctioned retirement, not an assertion weakening, sdd-testing
> L1/L3). No requirement IDs were renumbered.

| # | Requirement(s) | Amendment |
|---|---|---|
| AMD-2026-10-23-04 | SES-06 | **RETIRED** — the requirement pins the OTP model ("GIVEN the user verified the 6-digit OTP (`verifyOTP(type: recovery)`)"). Its anti-desync intent migrates to RST-07/RST-08/RST-09; the controller's `passwordRecovery` handling evolves from "never navigates" to "navigates to the new-password screen" (the link flow has no in-flight `updateUser` race). |
| AMD-2026-10-23-05 | ERR-07 | **RE-PINNED (copy adaptation)** — cooldown behavior unchanged (60 s static const, server-driven start on `over_email_send_rate_limit`, no pending timers); the rate-limited action is renamed "Enviar código" → **"Restablecer contraseña"** (it sends the recovery EMAIL/LINK, not a code); countdown label copy adapts, semantics do not. |
| AMD-2026-10-23-06 | ERR-01 | `verificarOtpYCambiarContrasena` is **removed** from the enumerated auth operations and **replaced** by the new password-update operation (working name `restablecerContrasena`, RST-11); `recuperarContrasena` remains. ERR-01's standing rule ("any newly added auth operation MUST join this enumeration") binds RST-11. |
| AMD-2026-10-23-07 | TDD-04 | The mandated coverage item "OTP recovery success/failure" is **replaced** by "recovery send success/failure + new-password submission success/failure (link flow: RST-03/RST-05/RST-11/RST-12)". |
| AMD-2026-10-23-08 | TDD-05 | The mandated "recovery/OTP sequencing" item is **replaced** by "`enviarRecuperacionContrasena` call-through (asserting the `redirectTo` argument — RST-03) and `restablecerContrasena` call-through to `auth.updateUser(UserAttributes(password:))` — RST-11". |
| AMD-2026-10-23-09 | BAS-04 | The auth-settings snapshot MUST record the recovery-template marker **`{{ .ConfirmationURL }}`** (link flow) instead of `{{ .Token }}`; a template still targeting `{{ .Token }}`/OTP flags a template mismatch (verification item 6-b.1). |
| AMD-2026-10-23-10 | MODIFIED "Session detection" — scenario "Recovery desync eliminated" | **Re-pinned**: the OTP premise ("a recovery OTP verified while `LoginScreen` sits in the nav stack") becomes "a recovery LINK processed while `LoginScreen` sits in the nav stack", and the THEN becomes: the new-password screen (RST-07) is shown instead of a logged-out screen with a live session. |

### SES-06 — RETIRED (AMD-2026-10-23-04)

**Reason**: the requirement and both its scenarios are pinned to the OTP model (6-digit
`verifyOTP(type: recovery)`), which the user-validated redesign removes entirely.

**Migration**: RST-07 (warm link → new-password screen), RST-08 (cold start → new-password
screen), RST-09 (invalid/expired link); the original invariant "never render a logged-out
`LoginScreen` while the recovery session is live" is carried over as a scenario of RST-07.

**Test retirement sanction**: tests covering `verificarOtpYCambiarContrasena` sequencing and
the OTP-step UI (incl. the ERR-01 operation-start cleanup list entry for that operation and
the 6-digit validation widget assertions) are RETIRED by these amendments when the OTP APIs
and step-2 UI are removed under the RST-13 grep gate. This is spec-sanctioned retirement
(same discipline as AMD-2026-10-21-01), not an assertion weakening; the RST test suite
replaces them and TDD-07's ≥ 80 % coverage gate still applies.

### ERR-07 — re-pinned (AMD-2026-10-23-05)

#### Requirement: ERR-07 — Recovery send cooldown (re-pinned 2026-10-23-b)

The password-recovery **"Restablecer contraseña"** action (send of the recovery link email —
renamed from "Enviar código" by AMD-2026-10-23-05; behavior otherwise unchanged) MUST be
rate-limited client-side with a cooldown of 60 seconds (aligning with Supabase's default email
send interval): during cooldown the action is disabled and a countdown is displayed; a server
rate-limit response (ERR-02) MUST also start the cooldown. A network failure (ERR-04) MUST
NOT start the cooldown (verified current behavior — the user must be able to retry immediately
after a connectivity error).

##### Scenario: Cooldown countdown (unit test, fake clock)

- GIVEN `recuperarContrasena` just succeeded
- WHEN tests advance the clock 0s → 30s → 61s
- THEN the "Restablecer contraseña" action is disabled with remaining time shown at 0s and
  30s, and enabled again at 61s

##### Scenario: Server-driven cooldown

- GIVEN the user re-requests the recovery email and the server responds
  `over_email_send_rate_limit`
- WHEN the error is mapped (ERR-02)
- THEN the cooldown timer starts as well (UI cannot be spammed in a tight loop)

##### Scenario: Network failure does not lock the user out

- GIVEN the device is offline and the send fails with a connectivity error (ERR-04)
- WHEN the error is surfaced
- THEN the cooldown is NOT started and the action remains enabled for an immediate retry

##### Scenario: No pending timers leak

- GIVEN a test that starts a cooldown and finishes
- WHEN the test body ends
- THEN `flutter test` reports no pending timer (cooldown uses a cancelable/disposed-safe
  mechanism)

### ERR-01 — amended enumeration (AMD-2026-10-23-06)

`verificarOtpYCambiarContrasena` leaves the enumeration (the operation is removed with the OTP
flow) and the new `restablecerContrasena` (RST-11) joins it; `recuperarContrasena` (the send)
stays. ERR-01's stale-error-clearing behavior applies to both. The existing scenario "Error
does not survive a new attempt" is unaffected (it already speaks of "any auth operation").

### TDD-04 / TDD-05 — amended coverage items (AMD-2026-10-23-07 / -08)

- **TDD-04** unit coverage list: "…`tryRestoreSession` with and without an existing session,
  ~~OTP recovery success/failure~~ → **recovery send success/failure + new-password submission
  success/failure (RST-03/RST-05/RST-11/RST-12)**, and stale-error clearing…"
- **TDD-05** service coverage list: "…and ~~recovery/OTP sequencing~~ → **send call-through
  (with `redirectTo` assertion) + `updateUser` password call-through**…"

### BAS-04 — amended settings snapshot (AMD-2026-10-23-09)

The snapshot MUST record the recovery template's link marker `{{ .ConfirmationURL }}` (was:
`{{ .Token }}` presence). Confirmation = OFF remains the binding recorded state.

### MODIFIED "Session detection" — scenario "Recovery desync eliminated" (AMD-2026-10-23-10)

#### Scenario: Recovery desync eliminated (re-pinned 2026-10-23-b)

- GIVEN a recovery LINK processed (its `passwordRecovery` event fired) while `LoginScreen`
  sits in the nav stack
- WHEN the auth event is processed
- THEN the app shows the new-password screen (RST-07) instead of a logged-out screen with a
  live session

---

## ADDED Requirements (2026-10-23-b)

### Domain: password-recovery-link (S7 — link-based recovery via `huellitas://`)

> All requirements TRACK-A (Flutter-only). LIVE gates additionally require the user's
> Dashboard configuration (verification items 6-b.1/6-b.2) and a connected phone
> (6-b.3/6-b.4). Testability tier of each scenario is tagged: `[unit]` mocktail/fake-clock,
> `[widget]` flutter_test pump, `[static]` grep/manifest gate, `[LIVE]` manual on device.

#### Requirement: RST-01 — Send action: link-based copy, no code entry anywhere · TRACK-A

The recovery screen's primary action MUST be labeled **"Restablecer contraseña"** and MUST
trigger the recovery-email send (RST-03). The flow MUST NOT render any 6-digit-code input,
"código"/OTP verification step, or 6-digit-validation copy anywhere (send screen, new-password
screen, or controller-driven UI).

##### Scenario: Send button copy

- GIVEN the recovery screen (step 1)
- WHEN it renders `[widget]`
- THEN the primary action reads "Restablecer contraseña" and no widget for entering a code
  exists

##### Scenario: No OTP artifacts in the flow (static gate)

- GIVEN the recovery flow implementation complete
- WHEN grepping the recovery screens and auth layer for `6 dígitos|_otpCtrl|verificarOtp` in
  `lib/presentation/screens/login/` and `lib/domain/controllers/`, `lib/data/services/` `[static]`
- THEN there are 0 matches (companion gate to RST-13's full removal gate)

#### Requirement: RST-02 — Single generic success message (anti-enumeration invariant) · TRACK-A

On a successful send the screen MUST display exactly ONE generic message conveying that IF the
email exists a link was sent (spec-proposed copy: "Si el correo existe, recibirás un enlace
para restablecer tu contraseña. Revisa tu correo y la carpeta de spam."). The message MUST be
byte-identical for existing and unknown accounts, MUST NOT indicate whether an account exists,
and the client MUST NOT perform any account-existence check (the server already guarantees
non-disclosure — verified Supabase behavior, see Amendments rationale).

##### Scenario: Existing account

- GIVEN a registered email
- WHEN the send succeeds `[unit]`
- THEN the generic success message M is shown and the send screen stays (no step-2 transition)

##### Scenario: Unknown email — identical response

- GIVEN an unregistered email
- WHEN the send returns without error (verified server behavior: no email sent, no error) `[unit]`
- THEN the byte-identical message M is shown — no error, no extra hint, no timing-difference
  assertion in the copy

##### Scenario: No enumeration channel in the client

- GIVEN the send flow under test with a mocktail `AuthService` `[unit]`
- WHEN `recuperarContrasena` runs for any email
- THEN the only interaction with the auth layer is the send call itself
  (`verifyNever` on profile/user lookups or any existence probe around the send)

#### Requirement: RST-03 — Send targets the app via `redirectTo` deep link · TRACK-A

`AuthService.enviarRecuperacionContrasena` MUST pass `redirectTo` set to the custom-scheme URL
**`huellitas://password-recovery`** (exact string) to `resetPasswordForEmail`, so the email
link returns to the app (RST-06).

##### Scenario: Captured redirect argument

- GIVEN a mocked GoTrue client capturing `resetPasswordForEmail` arguments
- WHEN `enviarRecuperacionContrasena(' a@b.c ')` runs `[unit]`
- THEN the call includes the trimmed email `a@b.c` AND
  `redirectTo == 'huellitas://password-recovery'` (RED before the argument is added)

#### Requirement: RST-04 — Send cooldown retained (ERR-07 authority) · TRACK-A

The "Restablecer contraseña" action MUST remain cooldown-limited exactly per the re-pinned
ERR-07 (60 s; server-driven start on `over_email_send_rate_limit`; no start on network
failure; no pending timers). This requirement exists for traceability: the cooldown is a
property of the RENAMED send action, and its countdown label copy adapts while its semantics
do not.

##### Scenario: Cooldown applies to the renamed action

- GIVEN `recuperarContrasena` succeeded
- WHEN 30 s elapse (fake clock) `[unit]`
- THEN the "Restablecer contraseña" button is disabled with the countdown visible, and it is
  enabled again at 61 s (ERR-07 scenario parity; only the label copy changed)

#### Requirement: RST-05 — Send failures surface through `AuthErrorMapper` · TRACK-A

Every send failure MUST surface through `AuthErrorMapper` as actionable Spanish copy: network
failures per ERR-04, rate-limit per ERR-02, anything unknown per ERR-06. Raw English server
text MUST NOT reach the UI (ERR-06 denylist applies unchanged).

##### Scenario: Offline send

- GIVEN the device is offline
- WHEN "Restablecer contraseña" is tapped `[unit]`
- THEN `errorMessage` is the Spanish connectivity message, contains no technical string, and
  the cooldown is NOT started (retry stays possible — verified current controller behavior)

##### Scenario: Rate-limited send

- GIVEN `resetPasswordForEmail` throws `over_email_send_rate_limit`
- WHEN handled `[unit]`
- THEN the Spanish wait message shows (ERR-02) AND the cooldown starts (ERR-07
  server-driven scenario)

#### Requirement: RST-06 — Android intent-filter for `huellitas://password-recovery` · TRACK-A (static) / LIVE (end-to-end)

`android/app/src/main/AndroidManifest.xml` MUST declare, on the launcher activity, an
intent-filter with action `android.intent.action.VIEW`, categories `DEFAULT` + `BROWSABLE`,
and data `android:scheme="huellitas"` + `android:host="password-recovery"`, so the OS routes
the email link to the app. (Verified current state: the manifest has ONLY the MAIN/LAUNCHER
filter on the activity — no deep link registered today.) iOS is out of scope (no `ios/`
directory in the repo).

##### Scenario: Manifest gate (static)

- GIVEN the implemented manifest
- WHEN checking the launcher activity's intent-filters `[static]`
- THEN exactly one VIEW/BROWSABLE filter exists whose data carries scheme `huellitas` and host
  `password-recovery`, and the pre-existing MAIN/LAUNCHER and BOOT_COMPLETED filters are
  untouched

##### Scenario: OS routes the link to the app

- GIVEN the app installed and the Redirect URL registered (verification item 6-b.2)
- WHEN the user taps the recovery link in the email on the same device `[LIVE]`
- THEN the Huellitas app opens (no browser interstitial choosing another app) and RST-07 /
  RST-08 navigation completes (recorded in `openspec/changes/mejoras-login/verification-log.md`)

#### Requirement: RST-07 — Warm link → direct navigation to the new-password screen · TRACK-A (simulated) / LIVE (real link)

When the app is running (warm) and the user taps the recovery link, the incoming URI MUST be
handled by `supabase_flutter`'s deep-link session detection (`detectSessionInUri` default
true — the app MUST NOT parse the link URI manually), producing a `passwordRecovery` event;
on that event with a live session the app MUST navigate to the **new-password screen**
(RST-10), replacing the recovery-send screen in the stack (no code-entry step in between).
The retired SES-06 invariant carries over: the app MUST NOT show a logged-out `LoginScreen`
as the visible screen while the recovery session is live.

##### Scenario: Simulated warm link (unit/widget)

- GIVEN the app warm with the login (or recovery-send) screen in the stack
- WHEN a `passwordRecovery` event with a session is emitted (as the deep-link observer would
  after exchanging the URI) `[widget]`
- THEN the new-password screen is the visible route, the recovery-send screen is no longer in
  the stack (replacement semantics), and no code-input widget was ever rendered

##### Scenario: Anti-desync preserved (SES-06 migration)

- GIVEN `passwordRecovery` fires with a live session
- WHEN the event is processed
- THEN the visible screen is the new-password screen — never a logged-out `LoginScreen` with
  an authenticated recovery session `[unit]`

##### Scenario: Warm link on a real device

- GIVEN the app open (foreground or background) on the connected phone
- WHEN the user taps the recovery link in the email on that device `[LIVE]`
- THEN the app comes to the foreground on the new-password screen with no code input

#### Requirement: RST-08 — Cold start (app closed) lands on the new-password screen · TRACK-A (partial) / LIVE

When the app is NOT running and the user taps the recovery link, the OS launches the app with
the link URI; after initialization the app MUST land on the new-password screen (the same
deep-link observer processes the initial link — `app_links` initial-link path). This MUST NOT
violate SES-07 (exactly one profile-load path, splash dismisses once) and MUST NOT flash
`HomeScreen`/`AdminScreen` before the recovery destination renders.

##### Scenario: Cold start lands on the new-password screen

- GIVEN the app process is closed
- WHEN the user taps the recovery link `[LIVE]`
- THEN after splash the new-password screen is visible — not `/login`, `/home`, or `/admin`

##### Scenario: SES-07 invariants hold with a recovery initial link

- GIVEN a cold start whose initial link is the recovery deep link
- WHEN initialization completes `[unit/simulated + LIVE]`
- THEN `isInitializing` transitions exactly once, the profile is loaded at most once, and the
  splash dismisses normally (no double-load storm)

##### Scenario: No premature authenticated flash

- GIVEN the cold start with the recovery initial link
- WHEN frames render before the initial link is processed `[widget]`
- THEN no authenticated home/admin screen is ever rendered (splash precedes routing)

#### Requirement: RST-09 — Invalid or expired recovery link: actionable Spanish copy, no crash · TRACK-A

If the incoming link cannot be exchanged for a session (expired token, already-used link,
tampered URI, or a link opened on a device other than the one that requested it — PKCE code
verifier lives on the originating device, verification item 6-b.4), the app MUST NOT crash and
MUST show actionable Spanish copy (spec-proposed: "El enlace expiró o no es válido. Solicita
uno nuevo.") with a direct path back to the recovery-send screen; no raw server text, token,
or code fragment may appear in the UI or logs (RST-13).

##### Scenario: Expired link

- GIVEN a recovery link whose token expired
- WHEN the exchange fails (no session results) `[unit/widget simulated]`
- THEN the actionable Spanish message is shown, the user can restart from the send screen, and
  no crash occurs

##### Scenario: Cross-device link (documented limitation)

- GIVEN the link opened on a device without the PKCE code verifier
- WHEN the exchange fails `[LIVE optional]`
- THEN the same invalid-link handling applies (documented limitation — verification item 6-b.4;
  cross-device recovery would require an implicit-flow decision, deferred)

##### Scenario: No token leakage on failure

- GIVEN any link-processing failure
- WHEN inspecting rendered strings and captured debug logs `[unit/static]`
- THEN no `access_token`, `refresh_token`, `token_hash`, or `code=` fragment appears (denylist
  assertion; log-only channel is NOT allowed for token material — stricter than ERR-06)

#### Requirement: RST-10 — New-password screen: fields and client validation · TRACK-A

The new-password screen MUST present exactly two inputs — new password and confirmation — plus
the save action. Client validation MUST enforce a minimum of 6 characters (parity with the
current register/recovery validation) and equality between the fields, with the existing
Spanish copy ("La contraseña debe tener al menos 6 caracteres." / "Las contraseñas no
coinciden."). The screen MUST NOT render any code/OTP input or email input (the account comes
from the recovery session, not from user typing).

##### Scenario: Screen composition

- GIVEN the new-password screen
- WHEN it renders `[widget]`
- THEN exactly two password fields + a save action exist, with no code field and no email field

##### Scenario: Short password rejected

- GIVEN password field `abcde`
- WHEN save is tapped `[widget]`
- THEN "La contraseña debe tener al menos 6 caracteres." is shown and NO submit call is issued

##### Scenario: Mismatch rejected

- GIVEN `password1` vs `password2`
- WHEN save is tapped `[widget]`
- THEN "Las contraseñas no coinciden." is shown and NO submit call is issued

##### Scenario: Valid input proceeds

- GIVEN two matching 8-character passwords
- WHEN save is tapped `[widget]`
- THEN the submit operation is invoked exactly once

#### Requirement: RST-11 — Submit persists via `updateUser` and returns to login · TRACK-A

Activating the save action with valid input MUST invoke the new controller operation (working
name `restablecerContrasena`, joining the ERR-01 enumeration) which delegates to
`AuthService.restablecerContrasena` → `auth.updateUser(UserAttributes(password:))` — the ONLY
persistence path (RST-13). On success the app MUST show "¡Contraseña actualizada
correctamente!" and navigate to `LoginScreen` with the recovery screens removed from the stack
(`pushNamedAndRemoveUntil('/login', …)` semantics, matching the existing
`MyApp.navigatorKey` pattern), per the binding user decision "success → navigate to login".
The fate of the recovery session at that point is RST-DP-2 (orchestrator decision).

##### Scenario: updateUser call-through

- GIVEN a mocked auth layer capturing `updateUser` arguments
- WHEN `restablecerContrasena('nueva123')` runs `[unit]`
- THEN `updateUser` receives `UserAttributes(password: 'nueva123')` exactly once, and the
  error state was cleared at operation start (ERR-01 — operation joined the enumeration)

##### Scenario: Success shows the message and lands on login

- GIVEN a valid submission whose `updateUser` succeeds
- WHEN completion is processed `[widget]`
- THEN the success message is visible and `/login` is the only route in the stack

##### Scenario: Failure keeps the user on the screen

- GIVEN `updateUser` throws (any mapped failure, incl. expired-session per RST-12)
- WHEN handled `[unit/widget]`
- THEN mapped Spanish copy surfaces (ERR-06 denylist), the user stays on the new-password
  screen, and the entered fields are not silently discarded

#### Requirement: RST-12 — Missing or invalid session at submit handled · TRACK-A

If no valid session exists when the save action runs (link expired between open and submit,
session revoked meanwhile, local storage cleared), the submit MUST fail with actionable
Spanish copy (spec-proposed: "Tu sesión de recuperación expiró. Solicita un enlace nuevo.")
and provide the path back to the recovery-send screen — never hanging silently, never
pretending success, and never showing raw `invalid claim` / `Invalid Refresh Token` / English
server text (ERR-06 denylist).

##### Scenario: Submit without a session

- GIVEN no active session
- WHEN `restablecerContrasena` runs `[unit]`
- THEN it returns failure with the actionable Spanish copy (mapped — no raw AuthException
  text) and the UI offers to restart from the send screen

##### Scenario: Session expired while the screen was open

- GIVEN the new-password screen open past the recovery-session validity
- WHEN the user submits `[unit simulated / LIVE optional]`
- THEN the same actionable handling applies (no crash, no blank screen, no success message)

#### Requirement: RST-13 — Security invariants for the recovery flow · TRACK-A (SECURITY)

The flow MUST uphold, cross-cutting: (a) no recovery token, access/refresh token, or code
fragment rendered in any widget or written to ANY log (debug included; library URI logging of
auth links MUST NOT be additionally enabled in release builds); (b) the new password leaves
the client ONLY through `updateUser` — no logging, no local persistence, no analytics, no
state beyond the text fields; (c) the RST-02 anti-enumeration invariant (exactly one success
message regardless of existence); (d) the OTP chain is fully removed and the end state is
grep-verifiable.

##### Scenario: OTP chain removed (static gate)

- GIVEN implementation complete
- WHEN grepping `lib/` for `verifyOtp|verificarOtpYCambiarContrasena|OtpType\.recovery`
  `[static]`
- THEN 0 matches (the corresponding OTP tests are retired in the same change per
  AMD-2026-10-23-04/-06/-07/-08 — sanctioned retirement; suite stays green and ≥ TDD-07
  coverage)

##### Scenario: No manual token handling

- GIVEN the recovery flow code
- WHEN grepping the app's auth/presentation layers for manual parsing or logging of the link
  URI's auth parameters `[static]`
- THEN 0 matches — the only link handling is the library deep-link observer + the
  `passwordRecovery` event (RST-07)

##### Scenario: Password never persisted outside updateUser

- GIVEN the new-password submit flow under test `[unit/static]`
- WHEN inspecting service/controller interactions
- THEN `updateUser` is the only write path (mocktail `verify`), and a grep for
  `SharedPreferences|shared_preferences|Hive|getStorage` in the recovery flow files yields 0
  matches

##### Scenario: Anti-enumeration invariant asserted

- GIVEN the byte-identical message assertion from RST-02
- WHEN run as part of the auth unit suite `[unit]`
- THEN it passes for both existing and unknown emails (security regression guard)

### Traceability addendum (2026-10-23-b)

| Proposal deliverable | Requirement IDs | Track | Status |
|---|---|---|---|
| S7 — send: copy, generic message, `redirectTo`, cooldown, errors | RST-01…RST-05 (+ ERR-07 re-pinned, ERR-01 amended) | A | Ready |
| S7 — deep link: manifest, warm + cold navigation | RST-06…RST-08 | A | Ready (LIVE gates need Dashboard config 6-b.2 + user's phone) |
| S7 — new-password screen + submit + session handling | RST-09…RST-12 | A | Ready |
| S7 — security invariants (no token UI/log, updateUser-only, anti-enumeration, OTP removal gate) | RST-13 | A | Ready |
| Retired OTP routing requirement | SES-06 (AMD-2026-10-23-04) | — | RETIRED → RST-07…RST-09 |
| Amended coverage/enumeration/snapshot items | TDD-04, TDD-05, ERR-01, BAS-04, MODIFIED "Recovery desync eliminated" | A/B | Ready |

Track B status remains **UNCHANGED**: `BLOCKED-PENDING-EXPORT`.

### Testability tier map (TDD red-green plan input for sdd-tasks)

| Tier | Coverage | Tooling |
|---|---|---|
| Unit (controller/service, fake clock) | RST-02 (incl. no-enumeration `verifyNever`), RST-03 (`redirectTo` capture), RST-04 (cooldown parity), RST-05 (mapper branches), RST-07 (event-driven navigation state), RST-09 (invalid-link mapping), RST-11 (`updateUser` call-through + ERR-01 start-clear), RST-12 | `test/auth/*` — mocktail (DP-3), `fakeAsync` |
| Widget | RST-01 (copy + no code input), RST-02 (message M rendering), RST-07/RST-08 (route assertions), RST-10 (validation), RST-11 (success → `/login`), RST-12 (failure stays) | `test/presentation/*` — `flutter_test` |
| Static gates | RST-01/RST-13 grep gates (`6 dígitos`, `verifyOtp`, `OtpType.recovery`, `verificarOtpYCambiarContrasena`), RST-06 manifest check, RST-13 persistence grep | grep in verification + `dart analyze` |
| LIVE (manual — not automatable) | RST-06 (OS routing), RST-07 (real link, warm), RST-08 (cold start), RST-09 (cross-device optional), plus email delivery end-to-end | connected phone + live Supabase → `openspec/changes/mejoras-login/verification-log.md` |

Unit/widget tests drive RED→GREEN; static gates are grep assertions; LIVE items are manual
acceptance gates in the same spirit as tasks 11.4/11.10 (user-validated live testing).

### Open verification items (appended 2026-10-23-b — user actions, cannot be answered from the repo)

6-b.1. Recovery email template uses the link marker `{{ .ConfirmationURL }}` (link flow); if
the live template still targets the OTP/token model (`{{ .Token }}`), update it in the
Dashboard (user-managed — out of app scope; BAS-04 snapshot records the finding).
6-b.2. `huellitas://password-recovery` registered in Supabase Dashboard → Authentication →
URL Configuration → Redirect URLs (exact string as passed in `redirectTo`, RST-03).
6-b.3. **End-to-end email delivery confirmed on a connected phone** — user-reported current
failure: recovery emails NEVER arrive (cause unknown: template/SMTP provider/rate limit/spam;
pending user investigation in the Dashboard). This is a LIVE prerequisite: until delivery
works, RST-06/07/08 LIVE gates cannot pass. App-side code cannot guarantee delivery.
6-b.4. PKCE same-device limitation confirmed in live test: the recovery link must be tapped on
the SAME device that requested it (supabase_flutter defaults to `AuthFlowType.pkce`; the code
verifier lives in local storage). Cross-device opening exercises the RST-09 invalid-link path;
enabling cross-device recovery would require switching `authFlowType` to implicit (decision
deferred to the user — only if cross-device recovery is required).

### DECISION POINTS (orchestrator must present — added 2026-10-23-b)

| ID | Decision | Options | Tradeoffs | Recommendation |
|---|---|---|---|---|
| **RST-DP-1** | Recovery link tapped while a user session is already active (warm, same or other account) | (a) always navigate to the new-password screen (the link is an explicit intent; Supabase attaches/replaces the recovery session per its own semantics); (b) confirmation dialog first; (c) ignore the link when authenticated | (a) simplest, matches intent, one code path; (b) extra friction but protects a session from surprise; (c) users with a forgotten password often ARE logged in with a broken mental model — ignoring confuses | **(a)** — link intent wins; (c) strands the primary recovery use case |
| **RST-DP-2** | Fate of the recovery session after successful `updateUser` (binding decision says "success → navigate to login"; the recovery session itself is live and would otherwise desync the root `Consumer`, the P1-9 class) | (a) explicitly sign out the recovery session, THEN navigate to `/login` (clean signed-out state; login screen and auth state agree); (b) navigate to `/login` leaving the session live (mirrors today's OTP behavior, `Navigator.pop` over a live session) | (a) one extra call + a test; eliminates the desync class by construction; (b) zero behavior change but keeps the "logged-out screen with live session" inconsistency the change exists to kill | **(a)** — implements the binding "success → login" without a ghost session; supabase signs the user in cleanly after they set the new password |
| **RST-DP-3** | Exact wording of the generic success message (RST-02) and invalid-link / expired-session copy (RST-09/RST-12) | (a) adopt the spec-proposed Spanish copy as-is; (b) user provides final wording during implementation (copy-only diff, no spec change) | (a) unblocks TDD immediately with concrete strings to assert; (b) keeps wording flexible but requires a re-pin of the asserted strings | **(a)** as default; the user MAY override wording later without a spec amendment (copy-only change) |

*Binding and NOT re-opened (user-validated): button copy "Restablecer contraseña"; custom
scheme `huellitas://password-recovery`; single generic success message (anti-enumeration, no
existence check); 60 s cooldown retained for the send action; NO 6-digit code anywhere in the
flow; success → navigate to login; email template/Redirect URL/SMTP = user-side verification
items (6-b.1…6-b.4); iOS out of scope; Google-login issues and Track B out of scope.*
