# Proposal: Mejoras Login — Módulo de Autenticación (Fase 1)

> Change: `mejoras-login` · Created by `sdd-propose`
> Prior analysis: `openspec/changes/mejoras-generales-huellitas/exploration.md` (13 prioritized auth issues, DB map, decision points D1–D9)
> Classification: FULL STACK (Flutter UI + Supabase Postgres/RLS/triggers)
> TDD: **enforced** (`openspec/config.yaml` → `sdd.tdd: true`)
> `rules.proposal.max_scope_items` is **not configured** (commented out in config) → scope grouped into 6 reviewable deliverables.

---

## Intent

The login/auth module of Huellitas has correctness and security defects that block a
trustworthy release:

1. **Privilege escalation risk** — `usuarios.usua_rol` can be written from the anon-authenticated
   client (`AuthService.updateUserRol`, `AdminService.cambiarRolUsuario`) and RLS policies are
   **not in the repository**, so we cannot verify that self-promotion to `administrador` is blocked.
2. **Orphan-account "login loop"** — signup is 2 non-atomic calls (Auth account, then `usuarios`
   INSERT). If the INSERT fails, the account exists without a profile and the user can never log in
   (`getUserProfile().single()` throws) with no self-service repair.
3. **Stale session UI** — no `onAuthStateChange` subscription anywhere (verified by grep); an
   expired/revoked session keeps rendering `HomeScreen`/`AdminScreen` until app restart.
4. **No email-confirmation resend path** — with confirmations enabled, a user who misses the email
   is dead-ended ("Debes confirmar tu correo") with no resend action.
5. **Raw error leaks** — `_mapAuthError` covers only 4 messages; rate-limit/network/OAuth errors
   surface as `'Error inesperado: …'`, and `_errorMessage` is never cleared at operation start.
6. **Zero tests** — `test/widget_test.dart` is the broken default counter test; TDD is mandated by
   config, so a test baseline must land *before* implementation.

This change fixes the login/auth module only (phase 1 of the phased plan validated in D1).

## Scope

Scope is bound by the user-validated decisions **D1, D2, D3, D4, D7, D8, D9** (binding — not re-opened).

### In Scope

| # | Deliverable | Decision | Blocked? |
|---|---|---|---|
| S1 | **TDD test baseline**: replace broken `test/widget_test.dart` + unit tests for `AuthController`/`AuthService` with mocked Supabase (introduce injection seams first) | D9 | No |
| S2 | **Global auth-state listener** (`onAuthStateChange`: `signedIn / signedOut / tokenRefreshed / userUpdated / passwordRecovery`) in `AuthController` → reactive routing, session-expiry handling, post-recovery navigation fix | D1 | No |
| S3 | **Atomic signup via DB trigger** (`handle_new_user` on `auth.users` INSERT reading `raw_user_meta_data`) + client sends `nombre/telefono` as signUp `data:` and drops its own profile INSERT (email + Google flows); **resend-confirmation UI** after signup | D3 | **Migration part: BLOCKED-PENDING D2 export**; client prep proceeds |
| S4 | **Error mapping + stale-error cleanup**: clear `_errorMessage` at operation start; map rate-limit (`over_email_send_rate_limit`, attempt lockout), network, OAuth errors to Spanish; recovery-flow cooldown/resend timer | D1, exploration P0-4/P1-5/6/7 | No |
| S5 | **RLS + `usua_rol` enforcement migrations**: block client writes to `usua_rol` except admin/service-role path; policy-guard admin queries; `usua_rol` guard trigger | D4 | **BLOCKED-PENDING D2 export** |
| S6 | **Baseline migration intake**: import the user's Supabase export as schema reference into `supabase/migrations/` (schema-only, see DP-1) so S3/S5 SQL can be authored and diffed against reality | D2 | **BLOCKED-PENDING user export** |

Sequencing rule (D2): **S1 → S2 → S4 proceed immediately. S3 client-side prep and S6/S5/S3-migration are
hard-blocked on the export.** The task breakdown must mark blocked tasks explicitly with
`BLOCKED-PENDING: supabase export` so reviews can verify they were not silently skipped.

### Out of Scope

- **SENSO module changes** (destinacion `hogar`, territorial fields, admin census) — later phase (D1).
- **Push / FCM legacy→HTTP v1 migration** of Edge Functions — later phase (D1, exploration D5).
- **Adoption module** (build or delete) — deferred (D7).
- **`google_sign_in` upgrade** — stays `^6.2.1` (D8).
- Schema-as-code tooling beyond the auth baseline (`supabase/config.toml`, seed, `db diff` workflow) — later phase.
- Non-auth UX hygiene: splash min-delay (P2-11), logout cleanup symmetry (P1-10), mega-screen split (P2-13), Google photo persistence (P1-8 partial — only the cancel-detection/error path is touched here if needed by S4).
- Dead-code cleanup unrelated to auth (`send-push-notification`, `obtenerMascotasParaAdopcion`, `cargarTodasLasMascotas`).

## Approach

**TDD-first (D9).** Order of work:

1. **Baseline RED/GREEN**: add constructor-injection seams (`AuthController({AuthService?})`,
   `AuthService({SupabaseClient?})` defaulting to current singletons) → write unit tests with a
   mocked/faked auth layer (see DP-3) → fix/replace `test/widget_test.dart` so the suite is green.
2. **Flutter-only fixes (Track A, no blockers)**: auth-state listener + reactive routing (S2),
   error mapping + stale-error cleanup + resend cooldown (S4), resend-confirmation UI (S4/S3 UI part),
   `signUp`/`signInWithGoogle` refactor to send `data:` metadata (S3 client prep).
3. **DB track (Track B, BLOCKED-PENDING export)**: intake export (S6) → author migrations in
   `supabase/migrations/`: `handle_new_user` trigger (S3), `usua_rol` guard trigger + RLS policies
   (S5), each with a paired rollback SQL. Apply to the live project per DP-2.
4. **Deploy ordering (critical)**: trigger must be live **before** the client stops inserting the
   profile row. Ship in two steps: (a) deploy trigger + keep client INSERT as idempotent no-op
   (catch duplicate), (b) remove client INSERT once verified.

Verified APIs used (do not re-verify): `supabase.auth.resend(type: OtpType.signup, email: …)`
(official docs; `OtpType.email` asserts), `onAuthStateChange` event names, `signUp(…, data: …)` →
`raw_user_meta_data`, and the `handle_new_user` AFTER INSERT trigger pattern (official Supabase
"managing user data" guide — including its caution that **a failing trigger blocks signups**).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/domain/controllers/auth_controller.dart` | Modified | Auth-state subscription, error mapping expansion, `_errorMessage` reset, injection seam |
| `lib/data/services/auth_service.dart` | Modified | signUp `data:` metadata; drop client profile INSERT (after trigger live); `resend()`; injection seam |
| `lib/presentation/screens/login/login_screen.dart` | Modified | Resend-confirmation UI, recovery cooldown/rate-limit feedback, listener-driven navigation |
| `lib/presentation/screens/login/register_screen.dart` | Modified | Post-signup "confirma tu correo" state + resend action |
| `lib/main.dart` | Modified | Wire auth listener → `Consumer<AuthController>` routing (`'/login'`, `'/home'`, `'/admin'`) |
| `supabase/migrations/*.sql` | New | Baseline intake (S6), `handle_new_user` trigger (S3), `usua_rol` guard + RLS (S5) + rollback SQL — **blocked** |
| `test/widget_test.dart` | Replaced | Broken counter test → real smoke test |
| `test/auth/*` | New | Unit tests: auth controller/service with mocked Supabase (S1) |
| `pubspec.yaml` | Modified | Test-dependency addition (pending DP-3) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Unknown current RLS → migrations may conflict with live policies | High (until export) | S6/S5 hard-blocked on export; author from actual exported SQL, never from inference |
| Failing `handle_new_user` trigger **blocks all signups** (Supabase docs caution) | Medium | Keep trigger minimal & defensive (`security definer`, no business logic); manual SQL review; test against export/staging before live; rollback SQL = `DROP TRIGGER` |
| Live production DB blast radius (no `config.toml`, no local repro) | Medium | Every migration ships with paired rollback SQL; apply via DP-2 chosen channel; no data-destructive statements |
| Two-phase deploy (trigger vs client INSERT) mis-ordered → duplicate-insert errors or orphans | Medium | Deploy ordering encoded in approach step 4; client keeps idempotent fallback until verified |
| Recovery flow may be silently broken if email template lacks `{{ .Token }}` | Medium | Verification item (user action); if broken → decision DP-4 |
| TDD friction: hard singletons (`Supabase.instance.client`) with no seams | High | Injection seams are the first code change (S1 precedes S2–S4) |
| Broken `test/widget_test.dart` keeps CI red until replaced | High (now) | S1 is the first deliverable |

## Rollback Plan

- **Flutter**: changes land as conventional commits per deliverable (`feat(auth):`, `test(auth):`) on
  `feature/*` branches → `git revert` of the specific commit range; app keeps working on old
  code paths because S2/S4 are additive and S3 client change is staged behind the trigger.
- **Database**: each migration file in `supabase/migrations/` has a paired rollback statement
  (`DROP TRIGGER …`, `DROP POLICY …`, `CREATE OR REPLACE` back to previous definition) documented
  in the change folder and applied through the same channel as the migration (DP-2).
- **Trigger rollback is safe**: dropping `on_auth_user_created` returns signup to the current
  (client INSERT) flow; re-adding it is idempotent if guarded with `IF NOT EXISTS`/exception handling.

## Dependencies

- **BLOCKING**: user export of schema + RLS + Auth settings from Supabase Dashboard (D2) — required
  before S6, S5, and the S3 migration can start. *Not yet provided.*
- User verification of Supabase Auth settings: email confirmation ON/OFF, Recovery template
  `{{ .Token }}`, OTP expiry/rate limits (see Open Questions).
- Decision resolutions: DP-1, DP-2, DP-3 below (DP-4 only if the recovery template check fails).

## Open Questions (require user action/verification — cannot be answered from the repo)

1. Provide the **Supabase export** (schema, RLS policies, triggers, Auth settings) — unblocks S6/S5/S3-migration.
2. Is **email confirmation** currently enabled? (Dashboard → Auth → Providers → Email.)
3. Does the **Recovery email template** contain `{{ .Token }}`? (The 6-digit OTP UI silently depends on it.)
4. Confirm no other team member is simultaneously editing auth files (merge risk during phased delivery).

## DECISION POINTS (require user validation — orchestrator must present)

| ID | Decision | Options | Tradeoffs | Recommendation |
|---|---|---|---|---|
| **DP-1** | How to store the D2 export | (a) commit **schema-only** SQL as `supabase/migrations/0001_baseline_*.sql`; (b) keep export untracked (local reference), commit only new delta migrations | (a) true schema-as-code, diffable, but export must be sanitized (no data/PII) and baseline must match live exactly; (b) zero risk of leaking data, but no reproducible baseline in repo | **(a)** schema-only, after sanitization — aligns with exploration P1-7 direction; user confirms export hygiene |
| **DP-2** | Where/how migrations are applied to the live project | (a) user pastes reviewed SQL in Supabase Dashboard SQL editor; (b) `supabase link` + CLI `db push` (needs `config.toml`, unvalidated on this Windows env) | (a) simplest, human-reviewed, but manual and unauditable; (b) auditable/versioned, but touches a live project and CLI workflow is unverified here | **(a) for this change** (smallest blast radius), revisit CLI in the schema-as-code phase |
| **DP-3** | Test mocking strategy for S1 | (a) `mocktail` (no codegen); (b) `mockito` + build_runner codegen; (c) hand-rolled fakes only, zero new deps | (a) ergonomic, one small dev-dep, no codegen; (b) codegen overhead for a small suite; (c) honors "minimize dependency count" but faking Supabase's Postgrest builder chains is painful for `AuthService` tests | **(a) mocktail** for Supabase/AuthService seams + plain fakes for controller-level tests |
| **DP-4** | Recovery flow if template lacks `{{ .Token }}` *(contingent on Open Question 3)* | (a) customize email template to include `{{ .Token }}` (keep 6-digit UI); (b) rework UI to link-based recovery (`emailRedirectTo` + `passwordRecovery` event) | (a) zero code change, dashboard-only fix, keeps current UX; (b) robust regardless of template, but bigger UI rework | **(a)** first (cheap, verified-by-user), (b) as fallback |

## Success Criteria

- [ ] `flutter test` fully green (replaces today's failing `test/widget_test.dart`).
- [ ] Unit tests cover auth business logic (login/register/Google/recovery/error-mapping/listener)
      with mocked Supabase — targeting ≥80% coverage on touched auth code (project-standards).
- [ ] Signup is atomic: profile row created by DB trigger; no client-side `usuarios` INSERT remains
      in email or Google flows after cutover (grep-verifiable); orphan login-loop impossible.
- [ ] Resend-confirmation action exists and is reachable from the "email not confirmed" state.
- [ ] Session expiry/revocation is handled reactively via `onAuthStateChange` (no restart required).
- [ ] No raw English/auth exception text reaches the UI; rate-limit and network errors mapped;
      stale banner cleared at operation start.
- [ ] `usua_rol` cannot be written by a non-admin authenticated client (RLS + trigger), verified
      against the imported baseline; rollback SQL documented for every DB migration.
- [ ] Every blocked task is explicitly marked `BLOCKED-PENDING: supabase export` (or completed
      once the export arrives) — no silent skips in the task list.
