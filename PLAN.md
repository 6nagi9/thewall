# The Wall — Project Plan

> Full plan: `/Users/eil-its/.claude/plans/i-want-to-develop-eager-pnueli.md`

## Status: Planning complete, awaiting implementation approval

## Quick reference — decisions locked

| Topic | Decision |
|---|---|
| Compliance | Consent-first redesign (DPDP Act 2023 / TRAI compliant) |
| Core framing | Self-reflection-first: claim your own wall, invite feedback |
| Viral mechanic | Native share/SMS via device composer (`share_plus`); escrowed feedback |
| Owner control | See all feedback; choose what's public; transparency meter |
| Monetization | Free core + Premium self-insight + B2B Teams |
| Gamification | Badges, streaks, contribution/growth/transparency leaderboards |
| State mgmt | Riverpod |
| Backend | Firebase (Auth, Firestore, Functions, App Check, Emulator Suite) |

## Milestones

- [ ] **M0** — Corrected docs: `SRS.md`, `AGENT_PROMPT.md`, `COMPLIANCE.md`
- [ ] **M1** — Flutter scaffold + dark theme + Riverpod + go_router + Firebase emulator wiring (runs on simulator)
- [ ] **M2** — Phone OTP auth + DPDP consent onboarding + claim own wall
- [ ] **M3** — My Wall screen + give-feedback flow + owner disclosure controls + transparency meter ← first runnable vertical slice
- [ ] **M4** — Contacts hashing (on-device) + compliant invite + escrow + release-on-join
- [ ] **M5** — Aggregation + anti-abuse Cloud Functions (decay, min-N, Sybil, App Check)
- [ ] **M6** — Gamification (badges, streaks, leaderboards)
- [ ] **M7** — Monetization (`in_app_purchase`, verifyPurchase, premium gating, B2B stub)
- [ ] **M8** — DPDP rights ops (export, erasure, grievance, retention TTLs)

## User dependencies before cloud deploy
1. `firebase login` (Google account)
2. `flutterfire configure` (selects/creates Firebase project)
3. Choice of moderation provider at M3 (Perspective API / OpenAI / Firebase ML)

## Key compliance notes
- "DEDP" in original brief = **DPDP Act 2023** (India's Digital Personal Data Protection Act)
- No server SMS blast — all invites via device native share composer only
- No wall/aggregate for any person who hasn't joined + consented
- Contacts hashed on-device; server only reveals which hashes have active walls
- Min-N gating (≥3–5 reviews) before any aggregate surfaces
