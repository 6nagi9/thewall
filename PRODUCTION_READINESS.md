# The Wall — Production Readiness

*Last updated: 2026-06-13. Reflects the state after the growth build + production
hardening passes. Verification at time of writing: `flutter analyze` clean ·
19 Dart tests · 15 Node tests · debug APK builds with all native plugins.*

---

## 1. What's in place (production features)

These mirror the standard pre-launch hardening we ship on every app:

| Area | Status | Where |
|---|---|---|
| Crash reporting | ✅ Crashlytics + `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.onError` | `lib/main.dart` |
| Analytics | ✅ GA4, screen-view observer, domain events (incl. growth + feedback) | `lib/core/analytics.dart` |
| App Check | ✅ Debug providers locally, Play Integrity / App Attest in release | `lib/main.dart` |
| Friendly error UI | ✅ `AppErrorView` replaces red/grey crash box in release | `lib/shared/error_view.dart` |
| Offline handling | ✅ Connectivity banner; FCM/fonts/Firestore all degrade gracefully | `lib/shared/connectivity_banner.dart` |
| Bundled fonts | ✅ Brand fonts shipped as assets — no `fonts.gstatic.com` dependency | `assets/fonts/`, `lib/core/theme.dart` |
| Onboarding | ✅ Walkthrough carousel + DPDP consent + age gate | `lib/features/onboarding/` |
| Push notifications | ✅ FCM hardened (token re-synced on sign-in; env failures non-fatal); 5 triggers + foreground banner | `lib/main.dart`, `functions/src/index.ts` |
| Deep links | ✅ `/i /r /c` routes + pending-link replay; App Links / Universal Links | `lib/router.dart`, `marketing/.well-known/` |
| Legal | ✅ Privacy Policy + Terms in-app and on marketing site | `lib/features/legal/` |
| Data rights (DPDP) | ✅ Export, erasure, consent/audit log, grievance officer | `lib/features/settings/` |
| **In-app feedback to team** | ✅ **NEW** — suggestion/bug/praise/other → `submitAppFeedback` CF | `lib/features/feedback_to_us/` |
| **In-app store review** | ✅ **NEW** — throttled native prompt + "Rate The Wall" row | `lib/core/app_review.dart` |
| **Maintenance / force-update gate** | ✅ **NEW** — Remote Config kill-switch + min-build gate | `lib/core/app_gate.dart` |
| Remote Config | ✅ Invite A/B copy, event flags, safeguards; safe defaults, fails open | `lib/core/remote_config.dart` |
| Tests | ✅ 19 Dart (phone hash, taxonomy, moderation) + 15 Node (aggregation, growth helpers) | `test/`, `functions/test/` |

### In-app feedback & "Rate us" — entry points (this pass)
The "tell us what you think" channel is intentionally easy to reach:
- **My Wall header** — a prominent campaign/feedback icon button next to the brand
  mark on the home tab (`_HeaderIconButton` in `my_wall_screen.dart`).
- **Settings → Help & feedback** — "Send feedback or suggest a feature",
  "Rate The Wall", and "Share The Wall".
- The store-review sheet is also auto-offered (throttled) after positive moments:
  laying a brick, and sending praise. Caps: ≥60 days apart, ≤3 times ever, only
  after ≥3 positive moments (Apple/Google guideline-compliant).

Server: `submitAppFeedback` writes to `appFeedback` (Functions-only rule + a
`uid+createdAt` index for its per-user rate limit of 5/hour). Each report carries
app version + platform for triage.

---

## 2. Required before public launch (deploy-time — cannot be done from code)

These are operational steps for whoever runs the release:

### 2.1 Deploy backend
```bash
cd functions && npm run build
firebase deploy --only functions,firestore:rules,firestore:indexes,hosting
```
This ships `submitAppFeedback`, the `appFeedback` rule + index, the maintenance
gate config consumers, and the hosting landing pages.

### 2.2 Secrets (Google Secret Manager)
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY     # AI summary (else feature no-ops)
firebase functions:secrets:set PERSPECTIVE_API_KEY   # ML moderation (else blocklist-only)
firebase functions:secrets:set APPLE_SHARED_SECRET   # iOS IAP receipt validation
# WALL_SERVER_SALT already set.
```
All are placeholder-aware: the code falls back safely until a real value is set.

### 2.3 Store + signing
- **Android release signing** — replace the debug keystore with a real upload key;
  put its SHA-256 in `marketing/.well-known/assetlinks.json` (currently the
  **debug** fingerprint) so App Links verify on release builds.
- **iOS** — set the real Team ID in
  `marketing/.well-known/apple-app-site-association` (`TEAMID` placeholder) and add
  the Associated Domains entitlement.
- **IAP products** — create `wall_premium_monthly` / `wall_premium_yearly` as real
  subscriptions in App Store Connect + Play Console; grant the Functions service
  account Android Publisher access.

### 2.4 Runtime
- Bump Cloud Functions runtime off **nodejs20** (decommissions 2026-10-30) to
  nodejs22 in `firebase.json` once validated.
- Point `K.webBase` / links at `thewall.app` if/when the domain is configured
  (currently the live `*.web.app` — fully functional).
- Set a real **grievance officer** mailbox (currently `grievance@thewall.app`).

### 2.5 Remote Config (set in console, defaults are safe)
- `min_supported_build` — keep `0` until you need to force an update.
- `maintenance_mode` — `false`; flip to `true` for an outage (whole app shows the
  maintenance screen with `maintenance_message`).
- Invite/campaign A/B templates as desired.

---

## 3. Recommended soon after launch (not blockers)
- Triage UI / export for the `appFeedback` collection (currently console-only).
- Wire the remaining growth analytics events into their call sites where not yet
  logged (helpers exist in `analytics.dart`).
- Localized strings: l10n scaffolding (en + hi) exists; migrate user-facing copy
  into ARB incrementally.
- B2B team plan (deferred by design until Circles shows organic team usage).

---

## 4. Known-safe degradations (by design)
- No network → fonts render (bundled), app loads, push silently disabled,
  AI/moderation fall back, Remote Config uses defaults, gate fails open.
- Missing secrets → the dependent feature no-ops rather than erroring.
- Emulator without Google Play services → FCM `SERVICE_NOT_AVAILABLE` is caught
  and logged; everything else works.
