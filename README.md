# The Wall

A consent-first interpersonal feedback & reputation app. You **claim your own
wall**, invite people to give *you* structured feedback, and control exactly
what you disclose publicly. Built to be legally shippable in India — DPDP Act
2023, TRAI TCCCPR, and App Store / Play UGC compliant.

> **Why consent-first?** The original concept (rate non-consenting people from a
> phone number, then SMS-blast them) is unlawful under DPDP and TRAI. The Wall
> redesigns the viral loop so no data about a person is processed until they
> join and consent. See `COMPLIANCE.md` / `SRS.md` for the full mapping.

---

## Stack

- **Flutter** (Riverpod, go_router, fl_chart) — `lib/`
- **Firebase**: Auth (Phone OTP), Firestore, Cloud Functions (TypeScript),
  Cloud Messaging, App Check, Crashlytics, Analytics
- **Region**: `asia-south1` (Mumbai) for DPDP data residency
- **Project**: `the-wall-app-260609`

```
lib/
  core/        theme, prefs, analytics, phone_hash, moderation, badges
  data/        models, repositories (all writes go through Cloud Functions)
  features/    auth, onboarding (walkthrough + consent), my_wall, feedback,
               discover, gamification, premium, settings, legal
  shared/      error_view, connectivity_banner
functions/src/ index.ts (callables + scheduled), util.ts (pure logic)
firestore.rules  firestore.indexes.json
```

## Running locally

```bash
flutter pub get

# Against the Firebase Emulator Suite (no cloud creds needed):
firebase emulators:start
flutter run --dart-define=USE_EMULATOR=true

# Against the live project:
flutter run
```

### Tests

```bash
flutter test               # Dart: phone hashing, client moderation
cd functions && npm test   # Node: aggregation, openness, growth score
```

## Cloud Functions

18 functions in `asia-south1`. Highlights:

| Function | Purpose |
|---|---|
| `submitReview` | Validate → block-check → moderate → escrow-or-apply → recompute |
| `editReview` / `deleteReview` | Reviewer edits/removes their own feedback (latest-wins) |
| `onUserJoin` | Release escrowed feedback on join, credit inviters |
| `setDisclosure` | Owner discloses/hides feedback; recomputes openness |
| `getPublicWall` | Server-gated view of another wall (give-to-get + blocks) |
| `requestDataAccess` / `generateDataExport` / `handleErasure` | DPDP rights |
| `verifyPurchase` | Real Apple/Google receipt verification → premium |
| `requestFeedback` | B1 feedback campaigns |
| `fileDispute` / `reportContent` / `blockUser` | Safety & moderation |
| `recomputeAggregates` / `antiAbuseSweep` / `reverifyNumber` | Scheduled |

Deploy:

```bash
cd functions && npm run build
firebase deploy --only functions,firestore:rules,firestore:indexes
```

## Secrets & config (before go-live)

Set in Google Secret Manager (`firebase functions:secrets:set <NAME>`):

| Secret | Used by | Notes |
|---|---|---|
| `WALL_SERVER_SALT` | reviewer-key HMAC, dedup | **set** (random 32 bytes) |
| `PERSPECTIVE_API_KEY` | comment moderation | placeholder `REPLACE_ME`; set a real [Perspective API](https://perspectiveapi.com) key to enable ML moderation (falls back to blocklist until then) |
| `APPLE_SHARED_SECRET` | iOS IAP verification | placeholder `REPLACE_ME`; set your App Store Connect shared secret |

`functions/.env` holds non-secret config (`ANDROID_PACKAGE`). For Android IAP
verification, grant the functions service account access in the Play Console
(Android Publisher API).

## Security notes

- Clients never write `walls`/`reviews` directly — only via callable Functions.
- `walls/{phoneHash}` is **not** world-readable (phone hashes are low-entropy and
  would be enumerable); only the owner reads their own wall, and public viewing
  goes through `getPublicWall`.
- `gamification` is readable only for users who opted into leaderboards.
- App Check is activated (debug provider locally, attestation in release).
- "Anonymous" feedback is anonymous to users only; a recoverable reviewer-key
  mapping is retained for lawful requests (IT Act safe-harbour).

## Compliance posture (DPDP / TRAI / store)

Explicit withdrawable consent · 18+ gate · contacts hashed on-device · no wall
for a non-member · real erasure · min-N aggregate gating · TRAI-safe invites
(native share, never server SMS) · grievance officer · `asia-south1` residency.
