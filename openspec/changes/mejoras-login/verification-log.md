# Verification Log — mejoras-login

## 2026-10-24 — P12-a: Baseline + Sanctioned OTP Test Retirements

### Post-Retirement Test Run (GREEN Verification)
All 24 tests pass after retirements (down from 26 baseline):
- `test/auth/recovery_cooldown_test.dart`: 4 tests (ERR-07 cooldown scenarios)
- `test/presentation/recovery_cooldown_ui_test.dart`: 1 test (banner liveRegion + cooldown countdown + touch target — step-2 OTP scenario removed)
- `test/auth/auth_session_events_test.dart`: 6 tests (SES-01 through SES-07, minus SES-06 group)
- `test/auth/auth_controller_test.dart`: 9 tests (baseline behavior + ERR-01 + ERR-05/AMD-2026-10-23-02 + ERR-06)
- `test/auth/auth_service_test.dart`: 4 tests (service-level tests)

**Result**: Full suite GREEN — sanctioned retirements verified, no regressions introduced.

---

### Task 12.1 — Baseline Test Run (GREEN)
All baseline tests passed against unmodified code (26 tests):
- `test/auth/recovery_cooldown_test.dart`: 4 tests (ERR-07 cooldown scenarios)
- `test/presentation/recovery_cooldown_ui_test.dart`: 1 test (banner liveRegion + cooldown countdown + touch target)
- `test/auth/auth_session_events_test.dart`: 8 tests (SES-01 through SES-07)
- `test/auth/auth_controller_test.dart`: 9 tests (baseline behavior + ERR-01 + ERR-05/AMD-2026-10-23-02 + ERR-06)
- `test/auth/auth_service_test.dart`: 4 tests (service-level tests)

**Result**: Full suite GREEN — baseline established for Phase 12 regression guards.

---

### Task 12.2 — Retirement AMD-2026-10-23-04 (SES-06 group)
**Amendment**: AMD-2026-10-23-04 (spec.md) — Migration to RST-07/RST-08/RST-09 per design-recovery.md §7.3

**Retired tests** (deleted wholesale, no assertion weakening):
1. `test/auth/auth_session_events_test.dart` — Group "SES-06 — recuperación de contraseña":
   - Test: "passwordRecovery con sesión activa carga el perfil" (lines 350–376)
   - Test: "passwordRecovery sin sesión deja mensaje recuperable" (lines 381–397)
   - **Rationale**: OTP-based premise contradicts new `passwordRecovery` branch design (design §2.2 matrix: sets `enModoRecuperacion = true`, NO profile load). Replacement RED cycles arrive in 12.10 (RST-07) and 12.13 (RST-09).

2. `test/auth/mocks.dart` — Comment update (line 79):
   - Removed `verifyOTP` mention from `buildAuthUser` doc comment
   - **Rationale**: OTP flow retired (RST-13(d)); no `verifyOTP` stubs remain in test suite.

**Suite status after retirement**: GREEN (verified below).

---

### Task 12.3 — Retirement AMD-2026-10-23-05/-06 (OTP step-2 UI)
**Amendment**: AMD-2026-10-23-05 (re-pins ERR-07 copy only), AMD-2026-10-23-06 (service/controller OTP method retirements)

**Retired test scenario** (deleted):
- `test/presentation/recovery_cooldown_ui_test.dart` — "WHEN avanza al paso 2 (código OTP + nueva contraseña)" (lines 151–162)
  - Steps: tap 'Enviar código' → advance to step 2 → assert resend link touch target ≥ 44px
  - **Rationale**: Step-2 OTP UI ceases to exist per RST-01/RST-13(d) (single-screen link-based recovery). Cooldown countdown + banner semantics assertions preserved (re-pinned in 12.16).

**Suite status after retirement**: GREEN (verified below).

---
 
### Post-Retirement Test Run (GREEN Verification)
All 24 tests pass after retirements (down from 26 baseline):
- `test/auth/recovery_cooldown_test.dart`: 4 tests (ERR-07 cooldown scenarios)
- `test/presentation/recovery_cooldown_ui_test.dart`: 1 test (banner liveRegion + cooldown countdown + touch target — step-2 OTP scenario removed)
- `test/auth/auth_session_events_test.dart`: 6 tests (SES-01 through SES-07, minus SES-06 group)
- `test/auth/auth_controller_test.dart`: 9 tests (baseline behavior + ERR-01 + ERR-05/AMD-2026-10-23-02 + ERR-06)
- `test/auth/auth_service_test.dart`: 4 tests (service-level tests)
 
**Result**: Full suite GREEN — sanctioned retirements verified, no regressions introduced.
 
---
 
### Task 12.9 — Retirement AMD-2026-10-23-06/-08 (Service OTP method)
**Amendment**: AMD-2026-10-23-06 (ERR-01 enumeration), AMD-2026-10-23-08 (TDD-05 coverage swap)
 
**Retired code** (static gate verified):
- `lib/data/services/auth_service.dart` — Method `verificarOtpYCambiarContrasena` (lines 305–323)
  - **Rationale**: OTP-based recovery flow replaced by link-based recovery (RST-13(d)). No caller remains (login_screen.dart retired in 12.16).
  - **Static gate**: `grep -n "verificarOtpYCambiarContrasena\|verifyOtp\|OtpType" lib/data/services/` → 0 matches.
  - **Suite status**: GREEN (no test existed for this method — verified 2026-10-23).
 
---
 
### Task 12.14 — Retirement AMD-2026-10-23-06 (Controller OTP method)
**Amendment**: AMD-2026-10-23-06 (ERR-01 enumeration updated, `restablecerContrasena` added)
 
**Retired code** (static gate verified):
- `lib/domain/controllers/auth_controller.dart` — Method `verificarOtpYCambiarContrasena` (previously lines 489–514)
  - **Rationale**: OTP-based recovery flow replaced by link-based recovery (RST-13(d)). New `restablecerContrasena` method implements the link-based flow (RST-11).
  - **ERR-01 re-pin**: Enumeration now reads: `login`, `loginWithGoogle`, `register`, `recuperarContrasena`, `restablecerContrasena`, `logout`, `updateProfile`, `cambiarContrasena` (removed `verificarOtpYCambiarContrasena`, added `restablecerContrasena`).
  - **Static gate**: `grep -n "verificarOtpYCambiarContrasena\|verifyOtp" lib/domain/ test/` → 0 matches.
  - **Suite status**: GREEN (56 auth tests pass).
  
---

### Task 12.20 — RST-06 Manifest Gate (Static)

**Change**: Added intent-filter for `huellitas://password-recovery` to `android/app/src/main/AndroidManifest.xml` inside `.MainActivity`.

**Verification**:
- Exactly 1 VIEW/BROWSABLE filter with `android:scheme="huellitas"` + `android:host="password-recovery"` ✓
- MAIN/LAUNCHER filter (lines 41-44) intact ✓
- BOOT_COMPLETED filter (lines 51-56) intact ✓
- `launchMode="singleTop"` (line 27) intact ✓
- `flutter analyze` clean (no new issues) ✓

**Result**: Static gate PASS — RST-06 scenario "Manifest gate (static)" satisfied.

---

### Task 12.21 — Static Gates RST-01 / RST-13 (grep assertions)

All grep gates executed and verified 0 matches in recovery flow:

| Gate | Pattern | Scope | Matches | Status |
|------|---------|-------|---------|--------|
| RST-13(d) | `verifyOtp\|verificarOtpYCambiarContrasena\|OtpType\.recovery` | `lib/` | 0 | ✓ PASS |
| RST-01 | `6 dígitos\|_otpCtrl` | login screens, controllers, services | 0 | ✓ PASS |
| RST-13(a)/(b) | `Uri.parse\|access_token\|refresh_token\|token_hash` | presentation, domain, data | 0 in recovery flow* | ✓ PASS |
| RST-13(b) | `SharedPreferences\|Hive\|getStorage` | login screens, controllers, services | 0 | ✓ PASS |

*Note: 2 `Uri.parse` matches found in unrelated screens (`mapa_veterinarios_screen.dart`, `servicios_screen.dart`) — not in recovery flow.

**`dart analyze`**: 63 pre-existing issues (0 NEW) — baseline maintained.

**Result**: All static gates PASS — RST-01 "No OTP artifacts", RST-13 "No manual token handling" satisfied.

---

### Task 12.22 — Final Verification + Batch Commit

**Regression suite**: `flutter test` → 72 tests PASS (exit 0), no pending timers, no platform-channel errors.

**Formatting**: `dart format --set-exit-if-changed .` → clean (2 files reformatted, re-verified green).

**Static analysis**: `flutter analyze` → 63 issues (0 NEW vs baseline).

**Coverage** (`flutter test --coverage`):
- `lib/domain/controllers/auth_controller.dart`: 154/206 lines = **74.8%** (below 80% TDD-07 threshold)
- `lib/data/services/auth_service.dart`: 17/98 lines = **17.3%** (below 80% TDD-07 threshold)

**Coverage deviation**: Pre-existing gap from Phase 10.1 (unblocked Track A). Phase 12 changes (OTP retirements, new link-based flow) did not degrade coverage further — removed methods were deprecated stubs with no test coverage. TDD-07 remains open for Phase 10.1 resolution.

**Result**: Format/Analyze/Test gates PASS. Coverage noted as tracked deviation (TDD-07 pending Phase 10.1).

---