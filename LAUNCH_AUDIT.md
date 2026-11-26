# Known: launch-readiness audit (2026-11-24)

Step 1 of the launch playbook: is the product complete against its requirements?

## Requirements baseline

- `requirements.md` is the **original** "The Wall" concept (look up and rate anyone
  by phone number, SMS-invite them, pay per profile unlock). README records why it
  was replaced: unlawful under DPDP Act 2023 and TRAI rules.
- The **current** product is the consent-first redesign ("Known"): claim your own
  wall, invite feedback, control what is public. Its spec was meant to live in
  `SRS.md`, `COMPLIANCE.md` and `AGENT_PROMPT.md`, and the detailed plan in
  `~/.claude/plans/i-want-to-develop-eager-pnueli.md`. **None of these exist any
  more.** The effective spec today is README + PLAN.md milestones +
  PRODUCTION_READINESS.md.

## Verified working

- `flutter analyze` clean; 19 Dart tests pass; 15 Cloud Functions tests pass.
- All 24 Cloud Functions deployed (asia-south1), web landing live at
  https://the-wall-app-260609.web.app ("Known — Honest feedback, on your terms").
- Consent-first core is implemented: phone OTP, 18+ gate, DPDP consent, claim wall,
  structured feedback (sliders + tags + moderated comment), on-device contact
  hashing, native-share invites, escrow released on join, owner disclosure and
  transparency meter, min-3 aggregate gating, time-decay weighting (λ = 0.005/day),
  disputes, block/report, data export and erasure, gamification, circles, premium
  (in_app_purchase), AI summary (premium-only, cached 7 days), OpenAI moderation,
  push, deep links, legal pages, in-app feedback, maintenance gate.
- Secrets set: WALL_SERVER_SALT, OPENAI_API_KEY, ANTHROPIC_API_KEY, PERSPECTIVE_API_KEY.
- App copy is consistently branded "Known".

## Gaps against the requirements (by design or to decide)

| Item | Spec | App | Call |
|---|---|---|---|
| Pay-per-view unlock of someone's wall | original spec | not built | Dropped by the consent-first redesign; premium is self-insight |
| Truecaller one-tap login | optional | not built | Fine to skip for v1 |
| Comment length | 250 chars | 200 | Decide (either is fine) |
| B2B Teams | plan | deferred | v2 |
| SRS / compliance docs | referenced | missing | Rewrite before launch (store review and DPDP grievance need them) |

## Release blockers

1. **Identity mismatch.** Brand is Known, but bundle/package IDs are
   `com.thewall.wall`, the web base is the `*.web.app` URL, and the grievance
   mailbox is `grievance@thewall.app` (domain not owned). Package IDs are permanent
   once published, so decide name + domain + IDs first. Owned candidate:
   idoitell.com.
2. **iOS team** is `F64MH4983D`; it must be `4Q33B3AAAU` (as Bellboa had to fix).
3. **Android release build signs with the debug key.**
4. **App links:** AASA has `TEAMID` placeholder; assetlinks.json has the debug
   fingerprint; Associated Domains needs the real domain.
5. **iOS purchase verification:** `APPLE_SHARED_SECRET` is a placeholder (and Apple's
   verifyReceipt endpoint is deprecated; prefer the App Store Server API with the
   team key). Premium products `wall_premium_monthly/yearly` don't exist in the stores.
6. **Cloud Functions run on Node 20, retired 2026-10-30**: upgrade to Node 22
   before any further deploy.
7. **No store pipeline** (fastlane/CI), no store listing, screenshots or privacy
   labels. Crashlytics + Analytics mean "data collected" declarations, not
   "Data Not Collected".
8. PRODUCTION_READINESS.md is stale (still says "The Wall", Perspective API).

## Cost review (free-tier-forever rule)

| Job | Schedule | Problem | Fix |
|---|---|---|---|
| recomputeAggregates | every 24 h | Reads **every wall and all its reviews** daily: a full scan that grows forever | Recompute only walls with new/expiring activity, or apply decay at read time |
| reverifyNumber | every 24 h | Re-flags the same first 500 dormant users every day (wasted writes) and never reaches user 501 | Filter `needsReverify != true`, paginate |
| weeklyDigest | weekly | Only ever considers the first 500 users; one inbox query per user | Query recent inbox activity instead of all users |
| antiAbuseSweep | every 6 h | Incremental (6 h window): OK | — |
| escrowSweep, streakReminder | daily | Bounded (limit 500), OK at launch scale | Paginate later |
| generateAiSummary | on demand | Premium-only, cached 7 days, `claude-opus-4-8` with 1,500 max tokens | Consider a cheaper model; cost is per premium user |

Firebase project `the-wall-app-260609` needs the Blaze plan for Functions; at launch
traffic everything above stays in the free quotas once the full scans are fixed.

## Proposed order to finish

1. Identity: name, domain, permanent app IDs (research + owner decision).
2. Rewrite the consent-first SRS + COMPLIANCE docs from the code.
3. Fix the three scheduled-job problems; move Functions to Node 22; deploy.
4. Release signing, iOS team, app-link files, App Store Server API verification.
5. Store pipeline (port Bellboa's fastlane + workflow), listing, privacy labels,
   IAP products, then submit.

## Progress 2026-11-24 (commit e13855a)

Done and deployed: the three scheduled-job cost fixes; Functions on Node 22 (all
30); dormant-number re-verification wired end to end (new `clearReverify`); iOS
team 4Q33B3AAAU; Android release signing (upload key in
~/Documents/app-stores-pipeline-files/known).

## Growth: the consent-first viral loop (decided with the owner)

No processing of non-members' data and no server SMS (DPDP/TRAI and store
policy). Growth comes from users sharing their *own* link, NGL/Sarahah-style:

1. **Answer on the web, no install.** Today `respond.html` has no form: a
   responder must install the app and verify an OTP before answering, which kills
   the loop. Build a web response form for campaign links (`/r/{id}`): sliders +
   tags + moderated comment, rate-limited and App Check/reCAPTCHA-protected,
   counted as "web responses" (lower weight in anti-abuse, min-N gating unchanged).
2. **The hook after answering:** "Now see what people think of you" → get your own
   link (app install or web sign-up).
3. **Story/WhatsApp share cards** of the owner's results (image + link) so the
   wall itself is the ad.
4. Referral premium days already exist (`premiumUntil`); surface them at share time.

## Still open

- Identity: name/domain/permanent IDs (owner decision; research next).
- SRS + COMPLIANCE docs rewrite.
- Web response form + share cards (above).
- APPLE_SHARED_SECRET / App Store Server API, IAP products, store pipeline, listing.
- Repo `6nagi9/thewall` is **public**; make it private before launch.

## Store status (2026-11-26)

- Play app 4976290357971301512; production **draft** release 1.0.0 (3). Listing, graphics,
  subscriptions (`wall_premium_monthly` ₹149, `wall_premium_yearly` ₹999) live.
- App content: all declarations done except Sign in details (owner types the review
  login), then Target audience (18+) and the final Data safety Save.
- Store assets: `flutter test tool/screenshots/store_test.dart && python3 -I tool/make_store_assets.py`.
- Scripts (outside the repo, `~/Documents/app-stores-pipeline-files/`): `play_release.sh`,
  `play_listing.py`, `play_subs.py` (use the play-deploy service account by impersonation).
- Android purchase verification: invite the functions service account
  `102675326351-compute@developer.gserviceaccount.com` in Play Console with financial
  permissions (owner).
- iOS: bundle ID registered; App Store record not created yet (owner signs in to App Store
  Connect); APNs key needed in Firebase for push.
