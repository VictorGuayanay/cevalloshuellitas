# Design: Mejoras Login — Módulo de Autenticación (Fase 1)

> Change: `mejoras-login` · Written by `sdd-design`
> Inputs: `openspec/changes/mejoras-login/proposal.md`, `openspec/changes/mejoras-login/spec.md` (45 reqs),
> `openspec/changes/mejoras-generales-huellitas/exploration.md`, `openspec/config.yaml`.
> Classification: FULL STACK · TDD: **enforced** (`sdd.tdd: true`).
> Corporate skills applied: `project-architecture`, `project-security`, `project-ui-ux`.
> All file paths in this document are **relative to the project root**.

**Binding user-validated decisions applied (not re-opened):** D1–D4, D9 · DP-1a (schema-only baseline
committed to `supabase/migrations/`) · DP-2 (user pastes reviewed SQL in the Supabase Dashboard) ·
DP-3 (mocktail) · SP-DP-1 (cooldown = configurable `static const`, 60 s default) · SP-DP-2 (remove dead
`AuthController.updateRol` in S5) · SP-DP-3 (verify scripts committed under `supabase/migrations/verify/`) ·
email confirmation **OFF** ⇒ resend-confirmation UI stays CONDITIONAL (SGN-11 / DP-4 only) ·
out of scope: SENSO, push/FCM, adoption, `google_sign_in` upgrade.

---

## Technical Approach

The change is delivered as **two independently releasable tracks** that interlock at a single cutover point:

- **Track A (Flutter, no blockers)** — introduce constructor-injection seams so the auth module becomes
  unit-testable (S1/TDD-01…07), subscribe exactly once to `onAuthStateChange` inside `AuthController` and
  drive routing reactively (S2/SES-01…07), centralize Spanish error mapping + stale-error clearing +
  resend cooldown (S4/ERR-01…07), and make signup **client-prep** ready for the server trigger:
  `signUp` sends `nombre/telefono` in `data:` and its profile INSERT becomes duplicate-tolerant
  (S3/SGN-01, SGN-07).
- **Track B (SQL, BLOCKED-PENDING-EXPORT)** — import the sanitized schema-only export as the repo baseline
  (S6/BAS-01…04), then author two behavior changes against that baseline: the `handle_new_user`
  `SECURITY DEFINER` trigger that makes signup atomic and server-assigns `usua_rol = 'usuario'`
  (S3/SGN-02…06), and the deny-by-default RLS + `usua_rol` guard-trigger set (S5/SEC-01…08). Every
  Track-B requirement is verified by a committed SQL script executed as a **red→green cycle** in the
  Dashboard SQL editor (VER-01), each migration carrying a paired rollback (SEC-07).

The **cutover invariant** that governs the whole design: *there must never be a deployed state in which
the profile-creating client INSERT is gone while the DB trigger is absent* (and vice-versa the trigger
must exist before the INSERT is removed, so orphan accounts become impossible). Section
"Migration / Rollout" encodes the exact ordering.

---

## Architecture Decisions

### Decision: Constructor-injection seams with default-singleton back-compat

**Choice**:
- `AuthController({AuthService? authService, TokenPushPort? tokenPush})` → `_authService = authService ?? AuthService()`.
- `AuthService({SupabaseClient? client})` → `_client = client ?? Supabase.instance.client`.
- Production wiring in `lib/main.dart` stays `AuthController()` — observable behavior unchanged (TDD-02/TDD-03).

**Alternatives considered**: (b) service-locator/`@visibleForTesting static` overrides — global mutable
state, order-dependent tests; (c) full interface extraction (`abstract class AuthService`) — larger diff,
the concrete class is mockable by mocktail as-is.

**Rationale**: matches the prescribed seams (proposal approach §1), keeps the existing layered
architecture (`lib/domain/controllers` depends on `lib/data/services`), and gives mocktail doubles at
exactly two boundaries — enough to unit-test every controller behavior without Supabase, Firebase or
network (TDD-04/TDD-06). Note `AuthService` currently reads the singleton in a *field initializer*; the
constructor initializer preserves the production default while guaranteeing tests never touch
`Supabase.instance` (TDD-03 scenario).

### Decision: Auth-event subscription lives in `AuthController`, sourced through `AuthService`

**Choice**:
- New getter on the service: `Stream<AuthState> get authStates => _client.auth.onAuthStateChange;`
  (single line in `lib/data/services/auth_service.dart`).
- `AuthController.initAuthListener()` subscribes **idempotently** (`if (_authSub != null) return;`),
  stores `StreamSubscription<AuthState>? _authSub`, and cancels it in `AuthController.dispose()`
  together with the cooldown timer (SES-01: exactly one subscription, cancelled on dispose).
- `lib/main.dart` cascades: `AuthController()..initAuthListener()..tryRestoreSession()`.

**Alternatives considered**: (b) subscription in `main.dart` with callbacks into the controller — puts
event logic outside the domain layer and is untestable without pumping widgets; (c) controller takes a
`SupabaseClient` directly — breaks the data/domain dependency direction.

**Rationale**: SES-01 requires the subscription in `AuthController`; sourcing the stream via an `AuthService`
getter keeps the dependency direction intact and makes the event source a **mocktail-stubbing seam**
(tests drive a plain `StreamController<AuthState>`). Verified against supabase-flutter: `GoTrueClient`
is a plain (non-final) class exposing `Stream<AuthState> get onAuthStateChange`, so
`MockSupabaseClient.auth → MockGoTrueClient` doubles work with mocktail.

**Verified API facts used** (supabase docs, `reference/dart/auth-onauthstatechange`):
- Event types: `initialSession`, `signedIn`, `signedOut`, `passwordRecovery`, `tokenRefreshed`,
  `userUpdated`, `userDeleted`, `mfaChallengeVerified`.
- **`onError` MUST be provided** — network errors (e.g. offline token refresh) are emitted as *stream
  errors* and unhandled ones crash the app.

**Event handling matrix** (implemented as one private `Future<void> _procesarEvento(AuthState state)`):

| Event | Action | Forced navigation |
|---|---|---|
| `initialSession` | If `isInitializing == true` → **ignore** (`tryRestoreSession()` owns startup — SES-07, and GoTrue's `BehaviorSubject` replays the last event to new subscribers). Else if session ≠ null and `currentUser == null` → load profile. | none (root `Consumer` routes) |
| `signedIn` | Load profile for `session.user.id`; profile missing → clear `currentUser` + mapped error (SES-03 orphan detectable, no crash/loop). | none — login/register screens keep their explicit `pushReplacementNamed` |
| `signedOut` | If `_cerrandoSesion` flag set by `logout()` → silent clear; else → clear state + session message `'Tu sesión ha expirado. Inicia sesión de nuevo.'` (SES-02). | post-frame `pushNamedAndRemoveUntil('/login', …)` **only if** `navigatorKey.currentState.canPop()` |
| `tokenRefreshed` | **No-op** (SES-04: no navigation, no splash, no profile re-fetch). | none |
| `userUpdated` | Re-fetch profile into `currentUser` (SES-05). | none |
| `passwordRecovery` | If session ≠ null → load profile; else keep login + mapped message (SES-06). **Never force-navigates** — the recovery screen drives its own flow, avoiding a race with the in-flight `updateUser(password)` call. | none |
| `userDeleted`, `mfaChallengeVerified` | `debugPrint` only — no MFA/account-deletion flows exist in the app (out of scope). | none |
| stream `onError` | `debugPrint` only — **does not mutate state** (a transient offline must not fake a logout; definitive failure arrives as `signedOut`). | none |

**Rationale for forced-navigation scope**: the root `home:` `Consumer<AuthController>` in `lib/main.dart`
already re-renders `SplashScreen`/`AdminScreen`/`HomeScreen`/`LoginScreen` from state; what it *cannot*
do is unwind a pushed navigation stack. Resetting the stack on `signedOut` (the only state where the
deep screens are guaranteed-wrong) fixes the "dead session keeps rendering until restart" defect with
minimal interference with the flows that navigate explicitly (login, register, recovery).

### Decision: Error mapping extracted to a pure, security-testable mapper

**Choice**: new file `lib/core/auth_error_mapper.dart` mirroring the `AppColors` pattern:

```dart
class AuthErrorMapper {
  AuthErrorMapper._();
  /// Devuelve null cuando NO debe mostrarse error (p. ej. cancelación de Google).
  static String? map(Object error) { … }
}
```

`AuthController` drops `_mapAuthError` and all `'Error inesperado: $e'` / `e.toString()` passthroughs;
every operation calls `errorMessage = AuthErrorMapper.map(e)` (ERR-06). Lookup order:

1. `AuthException` + allowlisted substrings → existing 4 Spanish messages verbatim (spec quotes them) +
   `over_email_send_rate_limit` → espera (ERR-02) + `For security purposes, you have N attempt(s)` →
   regex-extract `N` → `'Quedan N intentos antes de bloquear la cuenta.'` (ERR-03).
2. Google cancel marker (`'cancelado'`) → `null` (silent, ERR-01/ERR-05).
3. `SocketException` / `TimeoutException` / `http` `ClientException` → connectivity message (ERR-04).
4. `PostgrestException` code `PGRST116` (`.single()` no rows) → profile-not-found message (SES-03/SGN-06
   residual orphan: mapped + actionable, never a silent loop).
5. Fallback → fixed `'Ocurrió un error. Intenta de nuevo.'` (ERR-06). Raw text, exception class names,
   SQL and stack details never reach the UI.

**Alternatives considered**: keep the private `_mapAuthError` in the controller — cannot be unit-tested
as a table-driven security lint (ERR-06 scenario) without dragging the whole controller in; a lookup
*data file* — overkill for ~10 entries.

**Rationale**: ERR-06 explicitly requires a unit-testable allowlist/denylist assertion over a table of
raw messages; a pure function in `lib/core/` (shared utilities layer, existing pattern) is the smallest
seam that satisfies it.

### Decision: Cooldown as controller-owned, decrement-based state (SP-DP-1)

**Choice**: in `AuthController`:

```dart
static const Duration cooldownReenvio = Duration(seconds: 60); // SP-DP-1: único punto de configuración
Duration get cooldownRestante;                 // decae 1 s por tick
bool get puedeReenviarCodigo;                  // cooldownRestante == Duration.zero
void iniciarCooldownReenvio();                 // llamado tras éxito Y ante rate-limit server (ERR-07)
```

Backed by a single `Timer? _cooldownTimer` (`Timer.periodic`, 1 s) that decrements the remaining
duration and calls `notifyListeners()`; cancelled in `dispose()` (no pending-timer leaks, ERR-07
scenario 3).

**Alternatives considered**: (a) wall-clock `DateTime.now()` comparison — needs an injected clock seam to
be deterministic under test; (c) deriving the countdown inside the widget — untestable by unit tests and
lost on navigation.

**Rationale**: decrement-state + `Timer.periodic` is fully drivable with `fakeAsync` (transitive dep of
`flutter_test`): `async.elapse(30s)` → expect 30 s left and disabled; `async.elapse(31s)` → enabled —
exactly the ERR-07 fake-clock scenario, no new dependency, no real timers in tests.

### Decision: FCM side effects isolated behind a narrow port (TDD-06)

**Choice (pending DES-DP-1)**: define `TokenPushPort` (`Future<void> guardarToken(String userId)`,
`Future<void> limpiarToken(String userId)`) with an adapter that delegates to `FcmService.instance`;
`AuthController` injects it (`tokenPush ?? FcmTokenPushAdapter()`). See DECISION POINTS DES-DP-1.

**Why a seam is unavoidable**: `FcmService.instance.guardarToken(...)` is called in `login`,
`loginWithGoogle`, `register` and `tryRestoreSession`, and `limpiarToken` in `logout`
(`lib/domain/controllers/auth_controller.dart`). `FcmService` builds `FirebaseMessaging.instance` in a
field initializer, so merely touching the singleton in an offline test throws (Firebase is never
initialized) — currently caught only by the generic `catch`, which would misreport a *login failure*.

### Decision: Client profile INSERT becomes narrowly duplicate-tolerant (SGN-07)

**Choice**: keep the `from('usuarios').insert(...)` calls for the transition window, wrapped so that **only**
`PostgrestException.code == '23505'` (unique_violation — SQLSTATE, confirmed in Supabase's error-code
docs) is swallowed; every other error (notably `42501` RLS) still surfaces as a mapped message.

**Alternatives considered**: `upsert(ignoreDuplicates: true)` — one round-trip but masks *all* conflicts
and depends on `ignoreDuplicates` support in the pinned postgrest version (unverified here); "SELECT
first, INSERT if missing" — racy and already what the Google flow does (its read stays, its INSERT goes).

**Rationale**: the trigger fires on the `auth.users` INSERT, i.e. *before* the client INSERT — so in
phase (a) the client's write is always the duplicate. Swallowing exactly `23505` keeps SGN-07 honest
without hiding genuine RLS/permission regressions during cutover.

### Decision: Root routing stays a `Consumer<AuthController>` (no Navigator refactor)

**Choice**: `lib/main.dart` keeps its `home: Consumer<AuthController>` splash→routing chain; only two
additions: the post-frame `signedOut` stack reset (section above) and no other structural change.
`SplashScreen` (GIF, no text) and `isInitializing` semantics are untouched.

**Alternatives considered**: `NavigatorObserver`/`Router` rewrite — out of scope, high regression risk,
violates R5 (minimal diffs) against an app whose navigation is `pushNamed`-based.

**Rationale**: mirrors the existing pattern (skill rule: follow the codebase's pattern unless the change
addresses it); SES-07 requires startup to perform exactly one profile load, which the
`initialSession`-during-`isInitializing` guard achieves without touching the splash flow.

---

## DB Design

> **Everything in this section is TRACK-B · BLOCKED-PENDING-EXPORT.** No construct may be authored from
> the inferred map in `exploration.md` §3.1 (BAS-01); every table/column/policy/trigger name must trace
> to the exported SQL.

### Baseline migration layout (S6 / DP-1a)

```
supabase/migrations/
├── add_fcm_token.sql                          (existing — untouched)
├── 20261021000001_baseline_schema.sql         schema-only, sanitized (BAS-02/03), commit "chore(db):"
├── 20261021000002_handle_new_user.sql         trigger + paired rollback in header (SGN-02/03/04/05)
├── 20261021000003_usuarios_rls_usua_rol.sql   RLS set + guard trigger + transitional INSERT policy (SEC-01…08)
├── 20261021000004_drop_usuarios_insert_policy.sql  post-cutover policy removal (SEC-05 final)
└── verify/
    ├── 00_smoke.sql                           harness preflight — ALWAYS run first
    ├── 01_sgn02_handle_new_user.sql
    ├── 02_sgn03_sgn05_signup_rol_metadata.sql
    ├── 03_sec01_rls_audit.sql
    ├── 04_sec02_sec03_role_writes.sql
    ├── 05_sec04_admin_paths.sql
    ├── 06_sec05_sec06_usuarios_policies.sql
    └── 07_sec08_solicitudes_rol.sql
```

- Naming follows the Supabase CLI convention `<UTC timestamp>_<slug>.sql` so a future `supabase db push`
  workflow (schema-as-code phase) can adopt the files as-is; application today is **paste-in-Dashboard**
  (DP-2), so ordering by filename is advisory only.
- Baseline hygiene gate before commit: grep for `INSERT INTO`, `COPY `, `eyJ` (JWTs), real emails/PII →
  none allowed (BAS-02). Auth-settings snapshot recorded at
  `openspec/changes/mejoras-login/auth-settings-snapshot.md` (BAS-04: confirmation = OFF, OTP expiry,
  rate limits, `{{ .Token }}` presence).
- Every migration header carries: purpose, requirement IDs, **exact rollback statement(s)**, and rollback
  prerequisites (SEC-07). All statements non-destructive (no `DROP TABLE`/`DELETE`/`TRUNCATE`).

### `handle_new_user` trigger (SGN-02…SGN-06)

```sql
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nombre    text;
  v_telefono  text;
begin
  v_nombre := nullif(trim(coalesce(NEW.raw_user_meta_data->>'nombre', '')), '');
  if v_nombre is null then                       -- SGN-05: fallback OAuth sin metadata
    v_nombre := split_part(coalesce(NEW.email, 'usuario'), '@', 1);
  end if;
  v_telefono := nullif(trim(coalesce(NEW.raw_user_meta_data->>'telefono', '')), '');

  insert into public.usuarios (usua_id, usua_nombre, usua_correo, usua_telefono, usua_rol)
  values (NEW.id, v_nombre, NEW.email, v_telefono, 'usuario')   -- SGN-03: rol SIEMPRE literal
  on conflict (usua_id) do nothing;              -- SGN-04: idempotente
  return NEW;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
```

Design points and their requirement mapping:

- **`SECURITY DEFINER` + `set search_path = ''`** (official Supabase "managing user data" pattern):
  runs with the function owner's rights (the role that ran the migration — `postgres` via Dashboard),
  so profile creation succeeds even though RLS on `usuarios` denies direct INSERTs, and a fully-qualified
  `public.usuarios` reference is mandatory (empty search_path).
- **Atomicity / failure handling (SGN-02)**: there is deliberately **no** `EXCEPTION` handler — any real
  failure (FK/not-null/unexpected state) propagates and rolls back the whole signup transaction: either
  both `auth.users` and `usuarios` rows exist or neither does. This adopts the documented blast radius
  (Supabase docs: a failing trigger blocks signups), mitigated by (i) defensive defaults above
  (SGN-05), (ii) manual review, (iii) apply-after-verify ordering, (iv) rollback = `DROP TRIGGER`.
- **Role always `'usuario'` (SGN-03)**: `raw_user_meta_data->>'rol'` / `->>'usua_rol'` are never read;
  a client sending `data: {'rol':'administrador'}` still gets `'usuario'`. Self-promotion at signup is
  structurally impossible.
- **Idempotency (SGN-04)**: `on conflict (usua_id) do nothing` tolerates a pre-existing row (transition
  window where the client INSERT ran first is impossible by ordering, but admin-seeded/re-created users
  are not) without failing signup; the `drop trigger if exists` + `create or replace function` pairing
  makes the migration safe to re-paste (SEC-07).
- **Post-cutover writes**: the trigger also fires for Google first-time sign-ins and Admin-API/invite
  signups, so *every* `auth.users` insert gets a profile (SGN-06: orphan loop impossible).
- **Rollback** (header): `drop trigger if exists on_auth_user_created on auth.users; drop function if exists public.handle_new_user();`
  — **prerequisite: the client-side INSERT must already be restored (git revert of SGN-08) or new signups
  orphan.** Enforced by ordering in the Rollout section.

### `usua_rol` guard trigger (SEC-03, defense-in-depth backstop)

```sql
create or replace function public.restringir_cambio_usua_rol()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  v_claims  jsonb;
  v_role    text;
  v_admin   boolean;
begin
  if NEW.usua_rol not in ('usuario','veterinario','administrador') then
    raise exception 'usua_rol inválido: %', NEW.usua_rol;      -- allowlist SIEMPRE (SEC-03)
  end if;
  if NEW.usua_rol is not distinct from OLD.usua_rol then
    return NEW;                                                 -- solo aplica a cambios de rol
  end if;

  v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  if v_claims is null then
    return NEW;                    -- sesión directa sin JWT (Dashboard SQL editor como postgres)
  end if;
  v_role := v_claims->>'role';
  if v_role = 'service_role' then
    return NEW;                    -- Edge Functions / server-side (SEC-03 "service role allowed")
  end if;
  if v_role = 'authenticated' then
    select exists (select 1 from public.usuarios u
                   where u.usua_id = (v_claims->>'sub')::uuid
                     and u.usua_rol = 'administrador')
      into v_admin;
    if v_admin then return NEW; end if;                          -- admin autenticado (SEC-04)
  end if;
  raise exception 'Cambio de rol no autorizado';                 -- SEC-02: todo lo demás
end;
$$;

create trigger tr_restringir_usua_rol
before update of usua_rol on public.usuarios
for each row when (old.usua_rol is distinct from new.usua_rol)
execute function public.restringir_cambio_usua_rol();
```

- **Value allowlist first, actor check second** → an invalid value (`'superadmin'`) is rejected *regardless
  of privileges* (SEC-03 scenario 2).
- **`SECURITY DEFINER`** so the admin lookup does not depend on the `usuarios` SELECT policy state
  (works even when policies are misconfigured — the "policy dropped" scenario of SEC-03).
- **`WHEN old.usua_rol is distinct from new.usua_rol`** → zero overhead on normal profile updates
  (name/GPS/FCM-token writes never invoke it).
- **Fail-closed**: malformed claims JSON raises → UPDATE rolls back (PostgREST never sends malformed
  claims; only a hardening property).
- **Assumption (documented)**: PostgREST always sets `request.jwt.claims` (even for `anon`), so
  "claims absent" ⇒ direct non-JWT session ⇒ allowed (Dashboard/`postgres` path, SEC-03 scenario 1).
- **Rollback**: `drop trigger if exists tr_restringir_usua_rol on public.usuarios; drop function if exists public.restringir_cambio_usua_rol;`

### RLS policy set for `usuarios` (SEC-01, SEC-02, SEC-05, SEC-06)

```sql
alter table public.usuarios enable row level security;
drop policy if exists "usuarios_select_authenticated" on public.usuarios;   -- etc. (idempotent re-paste)
create policy "usuarios_select_authenticated" on public.usuarios
  for select to authenticated using (true);                     -- ver DES-DP-4
create policy "usuarios_update_propio_o_admin" on public.usuarios
  for update to authenticated
  using ((select auth.uid()) = usua_id or (select public.es_admin()))
  with check ((select auth.uid()) = usua_id or (select public.es_admin()));
-- FASE TRANSITORIA (se elimina en la migración …0004 tras SGN-08):
create policy "usuarios_insert_transitorio" on public.usuarios
  for insert to authenticated with check ((select auth.uid()) = usua_id and usua_rol = 'usuario');
-- Sin política SELECT para anon, sin INSERT para anon, sin DELETE para nadie → denegar por defecto.
```

Helper used by policies (also `SECURITY DEFINER`, avoids depending on the SELECT policy):

```sql
create or replace function public.es_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.usuarios u
                 where u.usua_id = (select auth.uid()) and u.usua_rol = 'administrador');
$$;
```

Policy-by-requirement rationale:

| Requirement | Mechanism |
|---|---|
| SEC-01 deny-by-default | `enable row level security`; explicit policies only for what the app needs; **no** `TO anon` policy anywhere on `usuarios`; audit query over `pg_class.relrowsecurity`/`pg_policies` |
| SEC-02 non-admin cannot change roles | row policies gate *who reaches* the row (other users: 0 rows); the guard trigger gates the *value/column* for own-row attempts — RLS alone cannot express "this column must not change", which is exactly why the trigger exists |
| SEC-04 admin path keeps working | `es_admin()` predicate lets an authenticated `administrador` UPDATE any row; trigger then authorizes the role value |
| SEC-05 no client INSERT post-cutover | transitional INSERT policy is **dropped** in migration `…0004` after SGN-08 lands; profile creation then exists only via the `SECURITY DEFINER` trigger |
| SEC-06 own-profile edits | `usua_id = auth.uid()` USING/WITH CHECK; non-role fields only — a role write is stopped by the guard trigger even on own row |
| FCM/profile/photo/Realtime writes | all client writes are own-row updates → covered by `usuarios_update_propio_o_admin` |

**Ordering of enforcement (defense in depth)**: table/column `GRANT`s (Supabase defaults grant to
`anon`/`authenticated`, so privileges are *not* the gate here) → **RLS row policies** (which rows a
session may read/update) → **BEFORE UPDATE trigger** (which values/columns/actors, independent of policy
drift). Note column-level grants were considered and **rejected**: SEC-04 requires the admin's direct
`update usuarios set usua_rol=…` over PostgREST to succeed, so `usua_rol` must stay grantable to
`authenticated`, leaving the trigger as the column-level control.

### Other tables touched by S5

`SEC-01`'s scenario demands `relrowsecurity = true` for **every** table in the baseline, and
`SEC-04`/`SEC-08` pin the behavior of `solicitudes_rol` (user INSERTs own request; admin SELECT/UPDATE)
and `veterinarios` (admin INSERT on promotion). These tables are touched **only as far as the baseline
requires**: port existing policies verbatim from the export where they exist; where a table currently has
RLS disabled, enabling it requires authoring behavior-preserving policies (see DES-DP-2 — enabling RLS
on `mascotas`/`noticias` also affects **Realtime `postgres_changes`**, which enforce RLS for the
subscriber's JWT; a read-parity check is mandatory before applying). Minimum non-negotiables:

- `solicitudes_rol`: `INSERT … WITH CHECK (auth.uid() = usua_id and srol_estado = 'pendiente')`,
  SELECT own-row for users + SELECT/UPDATE for admin (SEC-08 + SEC-04).
- `veterinarios`: SELECT for authenticated (Servicios/mapa join), INSERT for authenticated admin
  (`AdminService.cambiarRolUsuario`), no anon.

### Verification-script protocol (VER-01 + SP-DP-3)

**Simulation assumption (documented in every script header):** inside the Dashboard SQL editor the
session runs as `postgres`, which *owns* the tables and therefore **bypasses RLS**. Policies are only
exercised when the session role is a non-owner. Each scenario therefore runs:

```sql
begin;
set local role authenticated;
set local request.jwt.claims =
  '{"sub":"<uuid-prueba>","role":"authenticated","email":"prueba@test.local"}';
-- auth.uid() lee exactamente este GUC → las políticas se comportan como en producción
do $$ begin … assert … end $$;
rollback;   -- los datos de prueba NUNCA se confirman
```

Verified standard pattern (Supabase community/docs: `SET LOCAL role` + `SET LOCAL request.jwt.claims`
to simulate PostgREST contexts; `auth.uid()` derives from those claims).

**Protocol per script (strict order):**

1. **Smoke-check first (`00_smoke.sql`, and a compact copy at the top of each script):**
   - `set local role authenticated` succeeds and `current_user = 'authenticated'`;
   - with fake claims set, `auth.uid()` returns the fake `sub` (proves the claims simulation reaches
     policy helpers);
   - catalog reads work (`pg_class`/`pg_policies` for the SEC-01 audit);
   - probe: can the editor role insert a synthetic row into `auth.users` (needed by `01`/`02`)? If not,
     raise `HARNESS-UNSUPPORTED: …` — a distinct outcome so an **environmental** red is never misread
     as a requirement failure; fallback = manual end-to-end signup with a test account (documented in
     the script header).
2. **Scenario blocks**: each assertion group is its own `DO` block with inner
   `begin … exception when raise_exception then … end` capture writing `PASS/FAIL` rows into a temp
   table, so one failing assertion does not abort the others; every scenario runs inside
   `begin … rollback` so no test data persists (no PII, re-runnable).
3. **Summary block**: `DO $$ … if fallos > 0 then raise exception 'VERIFICACIÓN FALLIDA: %', fallos; end $$;`
   → hard RED. Green = notices `PASS` + clean exit.
4. **Red-green cycle (the DB equivalent of TDD):** commit scripts → run against pre-migration baseline →
   **record RED** in `openspec/changes/mejoras-login/verification-log.md` → apply migration (paste #N) →
   run → **GREEN** → rollback drill (SEC-07): execute the documented rollback → re-run → **RED again**,
   proving the migration (not the script) provided the behavior.
5. Rollbacks and results are always applied/recorded through the DP-2 channel (Dashboard paste).

Script ↔ requirement mapping: `01`→SGN-02 (+rollback-blast-radius note), `02`→SGN-03/SGN-04/SGN-05,
`03`→SEC-01, `04`→SEC-02/SEC-03 (self-promotion RED→GREEN, promote-other, admin allowed, service-role
allowed, invalid value rejected, policy-dropped backstop), `05`→SEC-04 (+ approval flow), `06`→SEC-05/
SEC-06, `07`→SEC-08.

---

## UI/UX Design (project-ui-ux applied)

> No `.agents/PROJECT_CONTEXT.md` exists → UI map derived from the code itself: **Flutter mobile,
> Material 3, Provider, GoogleFonts Poppins, design tokens in `lib/core/app_colors.dart`
> (`AppColors`), existing atoms `CustomTextField`, existing error-banner `Container` inside
> `Consumer<AuthController>` in `login_screen.dart` / `register_screen.dart`.** Target screens are
> mobile-only (`xs`/`sm`); no new breakpoints or layout wrappers are introduced (R2: none needed).

### Session-state handling (splash → routing)

```
Cold start ─► AuthController()..initAuthListener()..tryRestoreSession()
                 │  isInitializing=true ─► SplashScreen (unchanged, min 1200 ms)
                 │  initialSession event ─► IGNORED while isInitializing (SES-07, 1 profile load)
                 ▼
   isInitializing=false ─► Consumer<AuthController>:
        no session      ─► LoginScreen
        rol='administrador' ─► AdminScreen
        else            ─► HomeScreen
                 ▲
   onAuthStateChange events (matrix §Architecture) mutate state → notifyListeners() → same Consumer re-renders
   signedOut + stack deep ─► post-frame pushNamedAndRemoveUntil('/login') (fixes stale screens without restart)
```

- Login/register keep their explicit `pushReplacementNamed('/home'|'/admin')` on success — no double
  navigation (the forced reset only runs when `canPop()` and only on `signedOut`).
- `logout()` sets `_cerrandoSesion = true` before `signOut()` so the resulting `signedOut` event clears
  state **silently** (no "sesión expirada" banner after a voluntary logout).

### Error banner behavior

- **Clear-on-start (ERR-01)**: every controller operation sets `_errorMessage = null` at entry (inside
  the existing `_setLoading(true)` path). The banner in `login_screen.dart`/`register_screen.dart`
  already renders from `Consumer<AuthController>` → it disappears the moment the user retries, no widget
  changes needed beyond color-token migration.
- **Recovery "Enviar código" affordance (ERR-07)**: `_botonPrincipal` in
  `_RecuperarContrasenaScreenState` becomes
  `onPressed: auth.isLoading || !auth.puedeReenviarCodigo ? null : onTap` and its label shows
  `'Reenviar en ${auth.cooldownRestante.inSeconds} s'` while cooling down, `'Enviar código'` otherwise.
  Server rate-limit (`over_email_send_rate_limit`, ERR-02) also starts the cooldown, so the disabled
  state and the mapped banner appear together.
- **Session-expired banner**: only on remote `signedOut` (see matrix) — Spanish, mapped, no raw text.

### Visual states, tokens, accessibility (R1/R3/R4/R10)

| Concern | Design |
|---|---|
| Tokens (R1) | Banner & cooldown UI migrate **touched** colors to `AppColors.red` / `AppColors.redDark` / `AppColors.redBg` / `AppColors.tealDark` (existing hex values in untouched regions stay — R5 minimal diffs; full token migration is out of scope) |
| Contrast (R4) | Banner text uses `AppColors.redDark` on `AppColors.redBg`; verify ≥ 4.5:1 (Poppins 12 px = normal text) during implementation — **do not assume** current `#E53935`/`#FFEBEE` passes |
| Screen readers | Banner wrapped in `Semantics(liveRegion: true, …)` so a new error is announced (login + register); countdown state announced only on enabled↔disabled transitions (never per-second) |
| Touch targets (R4) | '¿No recibiste el código? Enviar de nuevo' link gets vertical padding to ≥ 44 px height; primary buttons are already 52–58 px |
| States (R3) | Disabled: existing `disabledBackgroundColor` alpha 0.5 ✓; Loading: existing `CircularProgressIndicator` ✓; Error: banner ✓; Focus: existing `focusedBorder` ✓ |
| Copy | All new strings Spanish, Poppins, tone consistent with existing copy (e.g. `'Tu sesión ha expirado. Inicia sesión de nuevo.'`, `'Reenviar en N s'`, `'Ocurrió un error. Intenta de nuevo.'`) |
| Register role UI | The single-option rol dropdown (`register_screen.dart`) is removed together with the `rol:` argument — the form no longer presents (or transmits) a role choice (MODIFIED role requirement) |

---

## Security Design (project-security applied)

### Threat model — login/auth module

| # | Threat | Vector (today) | Control layer | Verified by |
|---|---|---|---|---|
| T1 | **Self-promotion to `administrador`** | Raw PostgREST `update usuarios set usua_rol=…` as `authenticated` (`AuthService.updateUserRol`, `AdminService.cambiarRolUsuario` callable with any JWT); `signUp(rol:)`; `data:{rol}` metadata | Client (removes casual paths) → RLS row policy (`es_admin()` gate) → **guard trigger** (actor + allowlist) | `04_…` RED→GREEN (SEC-02/03) |
| T2 | **Fabricated/duplicate profiles** | Client `insert into usuarios` with arbitrary `usua_id`/`usua_rol`; anon key probing | RLS: no INSERT policy post-cutover (SEC-05); profile exists only via `SECURITY DEFINER` trigger | `06_…` (SEC-05) |
| T3 | **Anon (no session) access** | Anon key + no JWT hitting PostgREST | Deny-by-default: no `TO anon` policies; audit `relrowsecurity` on every baseline table (SEC-01) | `03_…` (SEC-01) |
| T4 | **Orphan accounts ("login loop")** | 2-call non-atomic signup; any INSERT failure ⇒ account without profile; `.single()` throws forever | Server atomicity: trigger in the `auth.users` transaction (SGN-06); client maps `PGRST116` to actionable Spanish (ERR-06/SGN-06) — residual pre-existing orphans repaired operationally (manual SQL, documented in change notes, out of app scope) | `01_…`/`02_…` + `TDD-04` |
| T5 | **Invalid role values** | Any actor writing `'superadmin'` | Trigger allowlist runs **before** the actor check | `04_…` (SEC-03) |
| T6 | **Escalation via leaked service-role key** | Key in client/bundle | Key never ships in the app (anon only, `lib/supabase_config.dart`); `service_role` exists only server-side (Edge Functions) — out of app scope, noted | code review |
| T7 | **Info leak via errors** | `'Error inesperado: $e'`, `e.toString()` reaching UI | `AuthErrorMapper` allowlist + denylist unit-test (ERR-06) | `auth_error_mapper_test.dart` |
| T8 | **Email/OTP hammering** | No cooldown on "Enviar código" | Client 60 s cooldown (SP-DP-1) + server rate-limit mapped and *also* starts cooldown (ERR-07) | `recovery_cooldown_test.dart` |
| T9 | **Privilege path closure regression** | Hardening accidentally blocks vet-request/approval | Explicit keep-working requirements (SEC-04/08) with green verification + manual admin smoke | `05_…`/`07_…` |

**Defense-in-depth ordering (stated principle):** *client → RLS → trigger.* The client layer only
removes casual/accidental paths and dead code (it is **never** a security control — the anon key is
public and every client check is bypassable with curl). RLS is the authoritative gate for *which rows*
a session may touch. The trigger is the last line: it enforces *column/value/actor invariants
regardless of policy drift* (SEC-03's drop-a-policy scenario) and it is where signup integrity lives
(`handle_new_user`, `SECURITY DEFINER`, in the same transaction as `auth.users`). Compromise of any one
layer leaves at least one other intact.

---

## Data Flow

**Login (Track A, unchanged shape):**

```
LoginScreen ─► AuthController.login() ──clear _errorMessage──► AuthService.signIn()
      ▲                │                                        │ auth.signInWithPassword
      │                │ on AuthException/Object                │ .from('usuarios').select().eq().single()
      │                ▼                                        ▼
   banner ◄── AuthErrorMapper.map() ◄──────────────────── UsuarioModel (o PostgrestException PGRST116)
      │                │ success
      │                ▼
      │        TokenPushPort.guardarToken(uid) (best-effort) ─► notifyListeners()
      └──────── pushReplacementNamed('/home'|'/admin')   +  signedIn event (idempotent, profile ya cargada)
```

**Signup after cutover (Track B + client):**

```
RegisterScreen ─► AuthController.register() ─► AuthService.signUp(data:{nombre, telefono})
      │                                                     │
      │                                                     ▼
      │                                          Supabase Auth (auth.users INSERT)
      │                                                     │ misma transacción
      │                                                     ▼
      │                                    TRIGGER on_auth_user_created (SECURITY DEFINER)
      │                                    insert public.usuarios … usua_rol='usuario'
      │                                    (on conflict do nothing / fallbacks metadata)
      ▼
 signedIn event ─► AuthController carga perfil ─► Consumer renderiza HomeScreen (SGN-09)
 (ya NO existe INSERT del cliente — SGN-08; sin inserts parciales — SGN-06)
```

**Role-change attempt (post S5):**

```
cualquier cliente ─► PostgREST UPDATE usuarios.usua_rol
        ① RLS  : ¿fila visible/editable para el actor?  (propio ó es_admin)  ── no ──► 0 filas / denegado
        ② TRIGGER tr_restringir_usua_rol:
             valor en allowlist? ── no ──► EXCEPTION (rollback)
             sin cambio de rol?  ── sí ──► permite (sin overhead)
             claims ausentes (Dashboard) ó service_role ó actor=administrador? ── sí ──► permite
             └─ no ──► EXCEPTION 'Cambio de rol no autorizado'
```

**DB verification loop (VER-01):**

```
commit verify/*.sql ─► Dashboard: 00_smoke ─┬─ HARNESS-UNSUPPORTED ─► fallback manual + escalar
                                            └─ OK ─► 01..07 = RED ─► registrar en verification-log.md
       ─► pegar migración N ─► 00 + 0N = GREEN ─► pegar rollback ─► RED (drill SEC-07)
```

---

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/domain/controllers/auth_controller.dart` | Modify | Seams (`authService`, `tokenPush`); `initAuthListener()`/`dispose()`; event matrix; `_errorMessage` clear-on-start in every op; cooldown (`cooldownReenvio` const, timer, getters); `_cerrandoSesion` flag; `_mapAuthError` → `AuthErrorMapper`; direct `Supabase.instance` call in `cambiarContrasena` moved to the service; remove `updateRol` (SP-DP-2) |
| `lib/data/services/auth_service.dart` | Modify | `AuthService({SupabaseClient? client})`; `Stream<AuthState> get authStates`; `signUp` sends `data:{nombre, telefono}` (SGN-01), drops `rol` param (MODIFIED); client INSERT 23505-tolerant during transition (SGN-07) → removed at cutover (SGN-08); new `actualizarPassword(...)`; remove `updateUserRol`/`_crearPerfilVeterinarioSiNoExiste` if DES-DP-3(a) |
| `lib/data/services/fcm_service.dart` | Modify (if DES-DP-1(a)) | Implements `TokenPushPort` (or untouched — see decision) |
| `lib/core/auth_error_mapper.dart` | Create | Pure `static String? map(Object error)` allowlist/denylist mapper (ERR-02…06) |
| `lib/core/token_push_port.dart` | Create (if DES-DP-1(a)) | `TokenPushPort` interface + `FcmTokenPushAdapter` default |
| `lib/main.dart` | Modify | `AuthController()..initAuthListener()..tryRestoreSession()`; post-frame `signedOut` stack reset in the existing `Consumer` |
| `lib/presentation/screens/login/login_screen.dart` | Modify | Banner → `AppColors` tokens + `Semantics(liveRegion)`; cooldown-disabled "Enviar código" + countdown label; resend link touch target ≥ 44 px |
| `lib/presentation/screens/login/register_screen.dart` | Modify | Remove `rol:` arg + single-option dropdown; banner tokens + semantics |
| `test/widget_test.dart` | Replace | Real smoke test (provider harness, no counter, no Firebase/Supabase) — TDD-01 |
| `test/auth/mocks.dart` | Create | `MockAuthService`, `MockSupabaseClient`, `MockGoTrueClient`, Postgrest-builder `then`-stub helpers, `FakeTokenPushPort`, `AuthResponse`/`UsuarioModel` builders |
| `test/auth/auth_controller_test.dart` | Create | TDD-04 behaviors (login/register/Google-cancel/logout/errors) |
| `test/auth/auth_session_events_test.dart` | Create | SES-01…07 via stubbed `authStates` stream |
| `test/auth/auth_service_test.dart` | Create | TDD-05 (signUp payload, signIn, getUserProfile propagation, role call-through, OTP sequencing) |
| `test/auth/auth_error_mapper_test.dart` | Create | ERR-02…06 table-driven allow/deny lint |
| `test/auth/recovery_cooldown_test.dart` | Create | ERR-07 with `fakeAsync` (0/30/61 s + no pending timers) |
| `pubspec.yaml` | Modify | dev_dependencies: `mocktail: ^1.0.5` (current pub.dev stable; DP-3) |
| `supabase/migrations/20261021000001_baseline_schema.sql` | Create | Sanitized schema-only baseline (BLOCKED-PENDING-EXPORT) |
| `supabase/migrations/20261021000002_handle_new_user.sql` | Create | Trigger + rollback header (BLOCKED) |
| `supabase/migrations/20261021000003_usuarios_rls_usua_rol.sql` | Create | RLS set + guard trigger + `es_admin()` + transitional INSERT policy + rollback (BLOCKED) |
| `supabase/migrations/20261021000004_drop_usuarios_insert_policy.sql` | Create | Post-cutover policy drop + rollback (BLOCKED) |
| `supabase/migrations/verify/00_smoke.sql` … `07_*.sql` | Create | VER-01 protocol scripts (BLOCKED; committed per SP-DP-3) |
| `openspec/changes/mejoras-login/auth-settings-snapshot.md` | Create | BAS-04 settings snapshot |
| `openspec/changes/mejoras-login/verification-log.md` | Create | RED/GREEN/rollback-drill results per script |

No file is deleted; no changes outside auth + `supabase/migrations` + `test/`.

---

## Interfaces / Contracts

```dart
// Contratos nuevos (resumen — los detalles viven en los archivos arriba)
class AuthController extends ChangeNotifier {
  AuthController({AuthService? authService, TokenPushPort? tokenPush});
  static const Duration cooldownReenvio = Duration(seconds: 60);   // SP-DP-1
  void initAuthListener();                                          // idempotente (SES-01)
  @override void dispose();                                         // cancela sub + timer
  Duration get cooldownRestante;
  bool get puedeReenviarCodigo;
  void iniciarCooldownReenvio();
  // registro sin rol (MODIFIED): Future<bool> register({nombre, correo, password, telefono});
}

class AuthService {
  AuthService({SupabaseClient? client});                 // default Supabase.instance.client
  Stream<AuthState> get authStates;                      // onAuthStateChange (seam de eventos)
  Future<void> actualizarPassword(String nueva);          // antes en el controlador (singleton directo)
  // signUp(data: {nombre, telefono}) — sin campo rol; INSERT solo durante la fase transitoria
}

class AuthErrorMapper { AuthErrorMapper._(); static String? map(Object error); }

abstract class TokenPushPort {                           // DES-DP-1 (opción recomendada)
  Future<void> guardarToken(String userId);
  Future<void> limpiarToken(String userId);
}
```

```sql
-- Resumen de objetos nuevos (firmas definitivas se completan contra el baseline)
create function public.handle_new_user() … security definer set search_path = '';      -- + trigger on_auth_user_created
create function public.restringir_cambio_usua_rol() … security definer set search_path = '';  -- + tr_restringir_usua_rol
create function public.es_admin() returns boolean … security definer set search_path = '';
alter table public.usuarios enable row level security;
-- policies: usuarios_select_authenticated | usuarios_update_propio_o_admin | usuarios_insert_transitorio (temporal)
-- + conjunto mínimo equivalente para solicitudes_rol / veterinarios derivado del baseline
```

---

## Migration / Rollout — two-phase deploy with cutover

**Phase A — Track A (Flutter; no blockers; each step = 1 Conventional Commit, independently releasable):**

1. `test(auth):` seams + replacement smoke test (S1/TDD-01…07) — RED first, suite green.
2. `feat(auth):` `onAuthStateChange` listener + reactive routing/stack reset (S2/SES-01…07).
3. `feat(auth):` error mapper + clear-on-start + cooldown (S4/ERR-01…07).
4. `feat(auth):` signUp `data:` metadata + duplicate-tolerant client INSERT (SGN-01, SGN-07) +
   register `rol` removal (MODIFIED client side). *Pre-trigger this is inert: metadata is ignored and
   no duplicate can occur yet (SGN-10 out-of-order scenario).*
5. (pending DES-DP-3(a)) `refactor(auth):` remove dead role-change surface.

**Phase B — Track B (SQL; BLOCKED-PENDING-EXPORT; every step = paste in Dashboard + recorded result):**

6. `chore(db):` sanitized baseline commit (S6/BAS-01…03) → spot-check vs live (BAS-03).
7. `test(db):` commit `verify/*.sql` → run `00_smoke` → run 01…07 → **record RED** (VER-01).
8. Paste migration `…0002_handle_new_user` → re-run `00`+`01`+`02` → **GREEN**; manual test signup on a
   throwaway account (profile exists, rol = `usuario`, no client INSERT involved). *Client INSERT still
   present → gets `23505` → swallowed (step 4).*
9. Paste migration `…0003_usuarios_rls_usua_rol` → re-run `00`, `03`…`07` → **GREEN** + manual smoke:
   admin changes a role, approves a vet request, user edits own profile, user files a vet request
   (SEC-04/SEC-08 least-functionality gate).
10. **Client cutover** `refactor(auth):` remove both profile INSERTs (SGN-08) → grep gate:
    no `from('usuarios').insert(` in the signup/Google flows.
11. Paste migration `…0004_drop_usuarios_insert_policy` → re-run `06` → **GREEN** (SEC-05 final).

**Cutover invariants (encoded above):** 8 strictly before 10; 11 strictly after 10; 4 must ship before 8
(otherwise the transition window would surface duplicates). Each phase is its own commit/paste, so each
is independently reviewable and revertible.

**Rollback:**

- **Track A**: `git revert` of the specific commit range — S2/S4 are additive; S3-client reverts to the
  plain INSERT (works pre- and post-trigger thanks to idempotent trigger).
- **Track B**: exact statements in each migration header, applied in **reverse order** (11-RB
  re-creates the transitional INSERT policy *only if* 10 is being reverted; 10-RB = git revert of
  SGN-08; 9-RB = `drop policy`/`drop trigger tr_restringir_usua_rol`/`drop function`es; 8-RB =
  `drop trigger on_auth_user_created` + `drop function handle_new_user`).
- **Hard rollback constraint**: never execute 8-RB while 10 is deployed (trigger gone + INSERT gone ⇒
  orphan accounts return). 8-RB's header states this prerequisite; after any rollback the verify
  scripts must be re-run and must show **RED** (SEC-07 rollback drill).
- Rollback safety net: trigger re-creation is idempotent (`drop trigger if exists` + `create or
  replace function`), no data statements are ever involved (SEC-07 destructive-gate checklist).

---

## Testing Strategy (TDD enforced — RED → GREEN → REFACTOR per behavior)

| Layer | What to Test | Approach |
|---|---|---|
| Unit — controller | TDD-04 list: login ok/fail(mapped), Google cancel silent, register ok/fail, logout state reset, `tryRestoreSession` ± session, OTP recovery ok/fail, stale-error clearing, FCM port invoked | `MockAuthService` + `FakeTokenPushPort`; **RED first**: test fails to compile/behave before the seam exists |
| Unit — session events | SES-01…07: single subscription + cancelled on dispose, signedOut clears+routes, signedIn loads/routes by role, missing profile ⇒ recoverable state, tokenRefreshed silent, userUpdated refresh, passwordRecovery, initialSession-vs-splash | stub `authStates` with a `StreamController<AuthState>` (no real Supabase) |
| Unit — service | TDD-05: signUp payload `data:{nombre,telefono}` + (post-cutover) `verifyNever(client.from('usuarios'))`, signIn happy/null-guard, `.single()` not-found propagation, role call-through, OTP sequencing | `MockSupabaseClient`/`MockGoTrueClient`; builder chains via `then`-stub helpers (below) |
| Unit — mapper | ERR-02…06 table of raw messages → Spanish allowlist; denylist assert (`Exception|SocketException|Postgrest|Error inesperado|attempt\(|rate limit|over_email_send`) never appears | pure function, plain `test()` |
| Unit — cooldown | ERR-07: 0 s/30 s/61 s states, server-driven start, no pending timers | `fakeAsync` driving `Timer.periodic`; `dispose()` asserted |
| Widget — smoke | TDD-01: replaced `test/widget_test.dart` renders a `MaterialApp` + provider harness (mocked `AuthController`) with no throw; no counter assertions | `flutter_test` only — avoids Firebase/Supabase/GoogleFonts-network entirely |
| Database | VER-01 red→green→rollback-red for every Track-B requirement | `supabase/migrations/verify/*.sql` in Dashboard (DP-2), results → `verification-log.md` |
| Static gates | SGN-08 grep (no client profile INSERT); coverage ≥ 80 % on `auth_controller.dart` + `auth_service.dart` | code search; `flutter test --coverage` + lcov (TDD-07) |

**Mocktail seams & the Postgrest-builder caveat (verified, not assumed):** `PostgrestBuilder<T,S>
implements Future<T>` (confirmed in postgrest-dart source) — so a mocktail double of a builder chain
(`from→select→eq→single`) can only be awaited if `then` is stubbed. `test/auth/mocks.dart` provides one
helper that stubs `when(() => b.then<Map<String,dynamic>>(any(), onError: any(named:'onError')))`
(with the required `registerFallbackValue` for the callback type in `setUpAll`) returning
`Future.value`/`Future.error` — happy path and `PGRST116` propagation both covered. **S1 spike (RED
step):** if await-on-mock proves unworkable, fallback = extract the two Postgrest call sites behind
`@visibleForTesting` methods on `AuthService` and stub those (documented deviation, no production
behavior change). `GoTrueClient`/`SupabaseClient` are plain non-final classes → mocktail-compatible
(verified in package sources); `AuthResponse`/`User`/`Session` are value objects — construct them, and
fall back to mocktail doubles of them if a constructor is not usable.

**Offline / static-side-effect determinism (TDD-06):** no `Supabase.initialize()` in any test (client is
injected); no Firebase (`TokenPushPort` fake — `FcmService.instance` is never touched, its
`FirebaseMessaging.instance` field initializer never runs); Google platform channel never invoked
(Google behavior tested at controller level through a service exception); all timers under `fakeAsync`
or cancelled in `dispose()`; suite runs with no network and no pending timers/platform-channel errors.

**SQL verification as the DB red-green cycle:** identical discipline — assertion scripts exist and fail
*before* the migration (RED), pass *after* (GREEN), fail again *after rollback* (proves causality);
script defects are distinguished from requirement gaps by the smoke-check-first protocol.

---

## Open Questions

- [ ] **S1 spike**: confirm await-on-mocktail-builder via the `then`-stub helper (fallback seam documented
      above) — technical, resolves during first RED cycle; does not need user input.
- [ ] Can the Dashboard/`postgres` session create a trigger on `auth.users` and (for verify scripts)
      insert a synthetic `auth.users` row on this project? → answered by `00_smoke.sql`; fallback =
      manual end-to-end signup test. (Official Supabase docs prescribe exactly this trigger, so
      expectation is yes — but it stays an unverified assumption until the smoke check runs.)
- [ ] Baseline discrepancies (esp. `usua_fecha_registro` default, `solicitudes_rol`/`veterinarios`
      current policies) resolved at S6 spot-check (BAS-03) before S5 authoring.
- [ ] Open Verification Items 1–3 of `spec.md` unchanged (export; `{{ .Token }}` template; no
      concurrent edits to auth files).

## DECISION POINTS (require user validation — orchestrator must present)

| ID | Decision | Options | Tradeoffs | Recommendation |
|---|---|---|---|---|
| **DES-DP-1** | How to isolate FCM side effects for TDD-06 | (a) narrow `TokenPushPort` interface + adapter over `FcmService.instance`; (b) inject concrete `FcmService` (needs constructor/`FirebaseMessaging` laziness refactor); (c) no seam — wrap the static calls in swallow-all `try/catch` ("tolerated as no-op", spec-permitted) | (a) explicit, testable (can assert token save/clear), one small file; (b) touches a working singleton service, heavier diff; (c) smallest diff but silently swallows *all* FCM errors at controller level and cannot assert the token lifecycle | **(a)** — cleanest seam at the existing controller boundary; FCM stays best-effort as today |
| **DES-DP-2** | Breadth of `enable row level security` (SEC-01 scenario says *every* baseline table) | (a) enable + author behavior-preserving policies for **all** tables in the baseline; (b) enable only auth-adjacent tables (`usuarios`, `solicitudes_rol`, `veterinarios`) and record the full inventory, amending SEC-01's scenario | (a) satisfies SEC-01 as written; largest blast radius — RLS on `mascotas`/`noticias` also gates **Realtime `postgres_changes`**, so read-parity checks are mandatory; (b) much smaller risk, but SEC-01 scenario fails verification and the spec must be amended | **(a)** with per-table parity verification from the export (policies ported verbatim where they exist) — pick (b) only if the user prefers a spec amendment over the wider migration |
| **DES-DP-3** | Scope of client-side role-model cleanup beyond SP-DP-2 | (a) remove the whole dead chain: `AuthController.updateRol` (validated), `AuthService.updateUserRol`, `signUp(rol:)` param + vet-branch, `_crearPerfilVeterinarioSiNoExiste`, register dropdown; (b) only `AuthController.updateRol` as SP-DP-2 literally states | (a) fully grep-verifiable, removes every client path that writes `usua_rol` (T1 shrinks to DB controls), consistent with MODIFIED "client must not transmit a role"; slightly larger diff; (b) leaves zero-caller methods that would always fail post-S5 | **(a)** — SP-DP-2's spirit (remove dead/confusing surface) extended to the now-dead callees; confirm scope OK |
| **DES-DP-4** | Read visibility of `usuarios` for authenticated users (privacy posture) | (a) `SELECT … TO authenticated USING (true)` — preserve current app behavior (admin list, lost-pet owner contact, vet directory, news bylines); (b) strict own-row reads + views/RPC for the cross-user screens | (a) zero app rework, matches today's de-facto posture, but any signed-in user can read any profile (cédula/GPS/phone); (b) materially better privacy, but touches many screens → scope growth beyond this change | **(a)** for this change (least-functionality preserved from current behavior), log (b) as backlog from the exploration's privacy note |

*Already resolved / binding (not re-opened): D1–D4, D9, DP-1a, DP-2, DP-3, SP-DP-1, SP-DP-2, SP-DP-3;
email confirmation OFF ⇒ SGN-11 stays CONDITIONAL (DP-4 only).*

---

## Traceability (design section ↔ spec)

| Spec domains / requirements | Design section |
|---|---|
| TDD-01…07 | Architecture Decisions (seams) · Testing Strategy |
| SES-01…07 | Decision: auth-event subscription + event matrix · UI/UX session-state |
| SGN-01, SGN-07, SGN-09, SGN-10 (client) | Decision: duplicate-tolerant INSERT · Data Flow (signup) · Rollout phase A4/B10 |
| SGN-02…SGN-06, SGN-08 (DB/cutover) | DB Design `handle_new_user` · Rollout 8/10 · Threat T4 |
| SGN-11 (CONDITIONAL) | intentionally not designed here (activates only via DP-4) |
| ERR-01…ERR-07 | Decision: error mapper · Decision: cooldown · UI/UX error banner · Tests |
| SEC-01…SEC-08 | DB Design RLS + guard trigger · Threat model · verify `03`–`07` |
| BAS-01…BAS-04, VER-01 | DB Design baseline layout · Verification-script protocol |
| MODIFIED (session/role/error) | Event matrix · `handle_new_user` + register UI change · error mapper |
| REMOVED (client INSERTs, raw leakage) | Rollout cutover 10/11 + rollback constraint · error mapper |

*End of design — ready for `sdd-tasks` (Track-A tasks unblocked; Track-B tasks must carry
`BLOCKED-PENDING: supabase export`).*

