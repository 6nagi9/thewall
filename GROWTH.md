# The Wall — Growth, Virality & Success Strategy

*Analysis date: 2026-06-12. Grounded in the shipped codebase (M0–M9 complete, 18 Cloud
Functions live in `asia-south1`, marketing site deployed). Every recommendation names the
code it touches.*

---

## 1. Concept assessment

### What The Wall is
A consent-first interpersonal feedback app: you claim **your own** wall, people who know
you rate you on structured dimensions + tags + a moderated comment, and **you** control
what becomes public. Feedback for non-members is escrowed and unlocks when they join.

### Strengths (keep & amplify)

| Strength | Why it matters |
|---|---|
| **Escrow = a legal curiosity hook** | "Someone left you feedback — join to unlock it" is the same psychological engine that made Sarahah (#1 in 30 countries) and NGL (200M+ downloads) explode — but DPDP/TRAI-clean because nothing is processed or shown until the target consents. This is the app's single best viral asset. |
| **Consent-first is a moat, not a tax** | Peeple died in the press; Sarahah was removed from both stores for bullying. "The anti-Sarahah: structured, moderated, consent-first" is a press- and parent-friendly story competitors built on anonymity can't tell. |
| **Give-to-get** | Receiving requires giving → every activated user is also a content producer and inviter. Structurally self-feeding. |
| **Healthy monetization** | Premium = insight about *yourself* (trends, cohort, coaching), never pay-to-see-others. Aligned incentives, no extortion dynamics. |
| **Production hardening already done** | App Check, Perspective moderation, real IAP verification, Crashlytics, erasure/export, anti-abuse sweeps. Rare for a pre-launch app; removes whole classes of launch risk. |

### Honest risks

1. **Cold-start emptiness** — `giveToGetThreshold = 5` + `minReviewsForAggregate = 3`
   compound: a new user can do everything right and still see nothing for days.
2. **Category guilt-by-association** — "anonymous feedback app" carries Sarahah/NGL
   bullying baggage. Positioning must lead with consent + structure, never anonymity.
3. **Tone mismatch** *(biggest strategic issue, see §3.1)* — the dimensions are
   workplace HR language; the mechanics are consumer-social. Right now it's a
   performance review wearing a Snapchat costume.
4. **Two-sided cold start** — the wall is only interesting when ≥3 people you know are
   on it. Growth must be cluster-based (friend groups, classes, teams), not
   individual-based.

---

## 2. Viral loop analysis — where the loop leaks

The core loop:

```
 A gives feedback to B (non-member)
        │ escrowed (invites/, 30-day TTL)
        ▼
 A shares invite link via native share        ← stage 1: send rate
        ▼
 B taps https://thewall.app/i/{hash}          ← stage 2: link works?
        ▼
 B installs, OTPs, consents                   ← stage 3: activation
        ▼
 B must give 5 before seeing their wall       ← stage 4: the gate
        ▼
 B gives to C, D, E… (new escrows)            ← loop closes; K-factor > 1?
```

Each leak, in priority order:

### 2.1 🔴 P0 — The invite link is dead
`give_feedback_screen.dart:277` shares `https://thewall.app/i/{hash}`;
`functions/src/index.ts:389` returns `https://thewall.app/r/{id}` for campaigns.
**The `thewall.app` domain is not configured.** Until it is, the K-factor is
structurally ~0 — every other growth idea is moot.

**Fix:** either buy `thewall.app` or reuse the live Hosting site
(`the-wall-app-260609.web.app`) now:
- Hosting routes `/i/*` and `/r/*` → a smart landing page: app-store buttons +
  **tease** ("Someone said 3 things about you on The Wall") + `og:title`/`og:image`
  so the link unfurls as a rich card in WhatsApp/iMessage.
- iOS Universal Links (`apple-app-site-association`) + Android App Links
  (`assetlinks.json`) so the link opens the app when installed, and the app routes
  the hash through onboarding so escrow attribution survives install
  (deferred deep-link via install referrer on Android; pasteboard or
  code-on-first-run fallback on iOS).

Lets 

### 2.3 🔴 P0 — The strongest loop is paywalled
Feedback campaigns ("ask anyone for feedback via a link",
`request_feedback_screen.dart`) are **premium**. But the shareable ask-link *is*
NGL's and Sarahah's entire viral product — the thing users post to WhatsApp status /
IG stories that recruits strangers-to-the-app.

**Fix:** make campaigns **free** (maybe 1 active campaign for free users, unlimited
for premium). Monetize the *results* — trends, AI summary, cohort comparison stay
premium. A growth loop should never sit behind the paywall; the insight on its
output should.

### 2.4 🟡 P1 — Invite copy doesn't sell the curiosity
Current: *"I left you some feedback on The Wall. Join to see it: {link}"*.
Decent, but generic. The escrow data already knows the tag count and dimension count
— use it:

> *"Bal said 3 things about you on The Wall 👀 — unlock them: {link}"*

- Include sender display name, count of tags/comment presence. Never the content
  (that's the unlock).
- A/B the templates via Remote Config; log `share_sheet_opened` → `invite_join`
  conversion per variant (`core/analytics.dart` is already wired).
- Same upgrade for the campaign share text in `request_feedback_screen.dart:50`.

### 2.5 🟡 P1 — No referral incentive
`onUserJoin` already credits inviters server-side, but nothing is shown or rewarded.
**Fix:** surface it — "2 people joined from your invites" + reward: **7 days of
Premium per successful invite** (capped). Premium-as-currency costs nothing
pre-scale and lets free users taste the paid features (the best premium funnel).

---

## 3. Usefulness & retention

### 3.1 🔴 P0 — Context-adaptive dimensions (the positioning fix)
**Decision (2026-06-12): context-adaptive.** Today's four dimensions
(`FeedbackDimension.all` in `lib/core/constants.dart`: Punctuality, Professionalism,
Communication, Reliability) read like an HR form. Nobody virally asks their best
friend to score their *punctuality*.

**Design:** the context tag (already exists: Work / College / Client / Community /
Other) moves to **step 1** of the give flow and selects the dimension + tag set:

| Context | Dimensions (1–5) | Sample tags |
|---|---|---|
| **Friend** | Trustworthiness · Fun to be around · Listens · Shows up | "Hype person", "Keeps secrets", "Brutally honest", "Always down" |
| **Work / Client** | (current four) | (current twelve) |
| **College** | Team player · Dependable · Ideas · Energy | "Carries group projects", "Notes dealer", "Chill under deadline" |
| **Family / Community** | Caring · Reliable · Patient · Generous | "Shows up when it matters", "Good with kids", "Fixer" |

- Personal contexts drive **virality** (emotional, shareable); professional contexts
  drive **usefulness + B2B**. One app, two engines.
- Compliance holds: all dimensions stay subjective/behavioural, no protected
  attributes (preserve the guard comment in `constants.dart`).
- Backend: `dimensionAverages` keyed per-context in aggregation
  (`util.ts recomputeAggregates`) — context segmentation was already anticipated
  ("B6" comment on `ContextTag`).
- Wall display: tabbed or merged-with-filter view in `my_wall_screen.dart`.

### 3.2 🟡 P1 — Growth-area tags (authenticity)
All 12 tags are positive. Pure praise feels nice once, then hollow — and "honest
feedback" is the brand promise. Add a small, **constructively framed** growth set
("Could be more punctual", "Hard to reach sometimes", "Interrupts when excited"),
visually distinct (rose vs sage chips), max 2 per review, never in public aggregates
unless owner discloses. Moderation stack (Perspective + blocklist) already handles
the comment risk; fixed taxonomy makes growth tags even safer than free text.
This also feeds Premium coaching prompts with real signal.

### 3.3 🟡 P1 — Notifications: 2 triggers is leaving retention on the floor
Only `submitReview` and `onUserJoin` send FCM today. Add (all in
`functions/src/index.ts`, mostly extending the existing scheduled jobs):

| Trigger | Copy sketch | Mechanism |
|---|---|---|
| Streak at risk | "Your 6-day streak ends at midnight 🔥" | extend `antiAbuseSweep`-style schedule or a new daily job reading `gamification.streak.lastActivityAt` |
| Weekly digest | "This week: 2 new feedbacks, openness ↑, you're 1 give from Pillar" | weekly scheduled fn |
| Escrow expiring (sender side) | "Your feedback for Priya expires in 5 days — nudge her?" → re-share sheet | extend escrow TTL sweep; **TRAI-safe because the nudge goes through the sender's own share sheet, never server SMS** |
| Campaign result | "3 people answered your feedback request" | in `submitReview` when review has campaign ref |
| Badge earned | "You're now a Pillar 🏆" | in badge-award path (currently silent) |

Also implement the foreground handler (currently a no-op `onMessage.listen((_) {})`
in `main.dart`) with an in-app banner.

### 3.4 🟢 P2 — Circles replace stranger-leaderboards as the Discover spine
Global top-50 lists of opted-in strangers (`discover_screen.dart`) are weak —
proximity beats rank. **Circles**: named groups (flat-share, project team, class
section, friend group) joined by link/code; inside a circle you see who's given to
whom (counts, not content), circle streaks, "appreciation week" group events.
Circles are also the B2B on-ramp: a "team circle" with admin features *is* the B2B
product. Keep leaderboards, demote them to a tab.

### 3.5 🟢 P2 — Day-1 single-player value
Before any feedback arrives: a 2-minute **self-assessment** on the same dimensions.
When real feedback lands, show *"How you see yourself vs how others see you"* — the
Johari-window gap is the single most compelling chart this app can render, it works
with N=1 received, and it makes the empty state a product instead of an apology.
(New onboarding step + a section in `analytics_screen.dart`; self-scores in
`users/{uid}`.)

---

## 4. Shareability — the missing organic loops

The app currently has **zero shareable artifacts** — nothing a proud user can post.
Every viral consumer app has one.

### 4.1 🟡 P1 — Public web wall
`walls/{phoneHash}` was correctly locked down (enumeration risk), but an **opt-in,
owner-published** web page is different: `the-wall-app-260609.web.app/w/{vanity-slug}`
showing disclosed aggregates, top tags, openness label, with `og:image` so it unfurls
beautifully on WhatsApp/LinkedIn. This is the "link in bio" artifact — every view is
an acquisition impression. Server: new `publishWall` callable writing a sanitized
public doc keyed by random slug (not phone hash); page served from `marketing/`
hosting. Off by default; one toggle in Settings next to leaderboard opt-in.

### 4.2 🟡 P1 — Shareable cards ("brag artifacts")
Generate share-sheet images (client-side `RepaintBoundary` → PNG, brand-styled) for:
- **Badge earned** ("Pillar — gave feedback to 10 people")
- **Wall Wrapped** — monthly/yearly recap: top tags, dimension deltas, streak,
  percentile. Wrapped mechanics are proven appointment-virality; the
  `recomputeAggregates` job already has all inputs.
- **Campaign card** — pretty "give me honest feedback" image + link for IG/WhatsApp
  status (vs today's plain text).

### 4.3 🟢 P2 — Time-boxed events
"**Feedback Friday**" (give 3, get a flame-streak multiplier) and an annual
"**Appreciation Week**" with a special badge. Cheap to run via Remote Config flags +
scheduled functions; creates appointment usage and a recurring press/social beat.

---

## 5. Market & monetization

### 5.1 India-first distribution (🟡 P1)
- **WhatsApp is the channel.** First-class "Share to WhatsApp" button (not just the
  generic sheet) on invites and campaign cards; status-sized (9:16) card variants.
- **Hindi at minimum** (then Hinglish copywriting — the tags especially; "Hype
  person" beats a literal translation). Flutter `intl` scaffolding now, strings later.
- DPDP compliance is already a *marketing asset* in India — say it loudly on the
  store listing ("Your data stays in India · DPDP-compliant").

### 5.2 Free/Premium rebalance (🔴 P0 decision, ships with 2.3)

| Feature | Today | Should be |
|---|---|---|
| Feedback campaigns | Premium | **Free** (1 active; unlimited = premium) — it's the growth loop |
| Trends/analytics | Premium | Premium ✓ |
| Cohort comparison | Premium | Premium ✓ |
| Coaching prompts | Premium | Premium ✓ |
| **AI wall summary** *(new)* | — | **Premium** — "What people consistently say about you", generated from disclosed feedback + tags. Highest perceived-value feature this data can power; pairs with growth tags (§3.2). |
| **AI growth plan** *(new)* | — | Premium — monthly plan from lowest dimensions + growth tags |
| Self-vs-others gap chart (§3.5) | — | Free (N=1 hook) · history premium |
| Premium badge | Premium | Premium ✓ |

AI features: one Cloud Function calling Claude (Haiku-class is plenty for
summarization) over the user's own disclosed feedback — consent-clean because it
processes only data the user already controls, disclosed in the privacy policy.

### 5.3 B2B teams (🟢 P3, the revenue ceiling-raiser)
Circles (§3.4) → "Team plan": admin console, scheduled 360 campaigns, anonymized
team-level dashboards, CSV export, per-seat pricing. Consumer app builds the habit;
teams pay for the tooling. Don't build before circles prove organic team usage.

---

## 6. Prioritized roadmap

**P0 — Fix the loop (do before any launch/marketing; ~1 week)**
1. Invite links live: hosting routes `/i/*`, `/r/*` + OG cards + universal/app links
   + deferred deep-link attribution (§2.1) — *the rest of the list is pointless
   without this*
2. Progressive reveal: 1 give = 1 unlock (§2.2)
3. Campaigns free, results premium (§2.3 + §5.2)
4. Context-adaptive dimensions & tags (§3.1)

**P1 — Multiply the loop (~1–2 weeks)**
5. Tease-rich invite copy + A/B via Remote Config (§2.4)
6. Referral → premium days, surfaced invite credits (§2.5)
7. Notification expansion + foreground handler (§3.3)
8. Public web wall (opt-in) + shareable cards incl. Wrapped (§4.1–4.2)
9. WhatsApp-first share + Hindi scaffolding (§5.1)

**P2 — Deepen retention**
10. Circles (§3.4) · 11. Self-assessment & gap chart (§3.5) · 12. Growth-area tags
(§3.2) · 13. Feedback Friday events (§4.3)

**P3 — Monetize depth**
14. AI summary + growth plan (premium) (§5.2) · 15. B2B team plan on circles (§5.3)

*(Pre-existing go-live checklist still applies: real `PERSPECTIVE_API_KEY` /
`APPLE_SHARED_SECRET`, Play publisher access, store subscription products, release
signing, Node-20 runtime bump before 2026-10-30.)*

## 7. Metrics to instrument (all via existing `core/analytics.dart`)

| Metric | Definition | Target |
|---|---|---|
| **K-factor** | invites sent/user × invite→join conversion | > 1 is escape velocity; > 0.5 is healthy paid-assist |
| Invite→join | `invite_join` / `share_sheet_opened` | ≥ 25% (curiosity hooks convert high) |
| Activation | % of joiners who give ≥1 feedback in 24h | ≥ 60% (progressive reveal should drive this) |
| First-unlock time | join → first received item visible | < 10 min |
| D1 / D7 / D30 retention | standard | 40 / 20 / 10 as consumer-social baseline |
| Escrow release rate | escrows released / created (30d) | the loop's single truest health number |
| Free→premium | conversion after AI summary ships | 2–4% |

Add events at: share-sheet open, link-landing view (web), install attribution,
gate progress, unlock moments, campaign create/answer, card shares.

---

### One-paragraph summary

The Wall's concept is sound and its compliance posture is genuinely differentiating —
but the viral engine is currently unplugged: the invite domain is dead, the
give-5 gate starves invited users of the reward that recruited them, the
strongest loop (ask-links) is paywalled, and the workplace-toned dimensions mute the
emotional energy virality needs. Fix those four (P0) and the existing
escrow/give-to-get architecture becomes exactly the legal Sarahah-class curiosity
loop it was designed to be; then layer shareable artifacts, notifications, and
circles to retain, and monetize insight (AI summaries, trends, teams) — never access.
