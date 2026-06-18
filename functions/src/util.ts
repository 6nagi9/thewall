import * as crypto from "node:crypto";
import { Firestore, Timestamp } from "firebase-admin/firestore";

// Server-held secret (set via `firebase functions:config` or env in prod).
// Used to derive recoverable-by-platform reviewer keys so reviews can be
// decoupled from UIDs in public data while remaining accountable to lawful
// requests. NEVER expose this.
const SERVER_SALT = process.env.WALL_SERVER_SALT || "dev-only-rotate-me";

export const DECAY_LAMBDA = 0.005; // per day
export const MIN_REVIEWS_FOR_AGGREGATE = 3;
export const GIVE_TO_GET = 5;

/** One-way keyed HMAC of a reviewer UID — stable, not reversible by clients. */
export function reviewerKey(uid: string): string {
  return crypto.createHmac("sha256", SERVER_SALT).update(uid).digest("hex");
}

/** Dedup key for a (reviewer, target) pair so one reviewer = one review. */
export function dedupKey(uid: string, targetHash: string): string {
  return crypto
    .createHmac("sha256", SERVER_SALT)
    .update(`${uid}|${targetHash}`)
    .digest("hex");
}

/** Time-decay weight for a review of age `ageDays`. */
export function decayWeight(ageDays: number): number {
  return Math.exp(-DECAY_LAMBDA * Math.max(0, ageDays));
}

/**
 * Recompute decay-weighted dimension means and tag counts from a set of
 * active reviews. Returns aggregate fields for the wall doc.
 */
export function aggregate(
  reviews: Array<{
    dimensions: Record<string, number>;
    tags: string[];
    createdAt: number; // epoch ms
  }>,
  now = Date.now()
) {
  const dimSum: Record<string, number> = {};
  const dimWeight: Record<string, number> = {};
  const tagCounts: Record<string, number> = {};

  for (const r of reviews) {
    const ageDays = (now - r.createdAt) / 86_400_000;
    const w = decayWeight(ageDays);
    for (const [k, v] of Object.entries(r.dimensions || {})) {
      dimSum[k] = (dimSum[k] || 0) + w * v;
      dimWeight[k] = (dimWeight[k] || 0) + w;
    }
    for (const t of r.tags || []) {
      tagCounts[t] = (tagCounts[t] || 0) + 1;
    }
  }

  const dimensionAverages: Record<string, number> = {};
  for (const k of Object.keys(dimSum)) {
    dimensionAverages[k] = dimWeight[k] ? dimSum[k] / dimWeight[k] : 0;
  }
  return { dimensionAverages, tagCounts, reviewCount: reviews.length };
}

/** Positive, bucketed openness signal from disclosed/received ratio. */
export function opennessLabel(disclosed: number, received: number): {
  score: number;
  label: string;
} {
  if (received === 0) return { score: 0, label: "New" };
  const ratio = disclosed / received;
  if (ratio >= 0.8) return { score: ratio, label: "Very Open" };
  if (ratio >= 0.5) return { score: ratio, label: "Open" };
  if (ratio >= 0.2) return { score: ratio, label: "Selective" };
  return { score: ratio, label: "Private" };
}

/**
 * Layer-2 server-side moderation (authoritative gate).
 *
 * Two stages, defence-in-depth:
 *   2a. Deterministic blocklist — always on, zero-latency, catches obvious
 *       slurs even if the external API is down or unconfigured.
 *   2b. OpenAI Moderation API — ML scoring across hate, harassment, violence,
 *       self-harm, and sexual content. Free endpoint, no per-call cost.
 *       Enabled when OPENAI_API_KEY is set. Fails OPEN on API error so a
 *       transient outage never blocks legitimate feedback.
 */
const BLOCKED = [
  "idiot", "stupid", "moron", "loser", "ugly", "hate you", "worthless",
  "pathetic", "disgusting", "trash", "kill", "scum", "die",
];

export async function moderateText(text?: string | null): Promise<{
  ok: boolean;
  reason?: string;
}> {
  if (!text) return { ok: true };

  // 2a — deterministic blocklist.
  const lower = text.toLowerCase();
  for (const term of BLOCKED) {
    if (lower.includes(term)) {
      return { ok: false, reason: "Comment failed moderation." };
    }
  }

  // 2b — OpenAI Moderation API. The "REPLACE_ME" sentinel means the secret
  // exists for deploy but no real key is configured yet — stay blocklist-only.
  const key = process.env.OPENAI_API_KEY;
  if (!key || key === "REPLACE_ME") return { ok: true };
  try {
    const res = await fetch("https://api.openai.com/v1/moderations", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${key}`,
      },
      body: JSON.stringify({ input: text }),
    });
    if (!res.ok) return { ok: true }; // fail open
    const data = (await res.json()) as {
      results?: Array<{
        flagged?: boolean;
        categories?: Record<string, boolean>;
        category_scores?: Record<string, number>;
      }>;
    };
    const result = data.results?.[0];
    if (!result) return { ok: true };
    if (result.flagged) {
      return { ok: false, reason: "Comment failed moderation." };
    }
    return { ok: true };
  } catch {
    return { ok: true }; // fail open — blocklist already applied
  }
}

/** Basic Sybil/velocity check: too many reviews of a target in a short window. */
export function isBurst(recentCount: number, windowReviews: number): boolean {
  return windowReviews > 5 && recentCount > 5;
}

// ─── Context-adaptive taxonomy (server mirror of lib/core/constants.dart) ─────
//
// COMPLIANCE: every dimension/tag is subjective, behavioural, and framed as
// opinion. No protected attributes (caste, religion, health, sexuality,
// politics, race). Growth tags are constructively framed and capped at 2 per
// review; they never enter public aggregates (owner-visible inbox only,
// unless the owner discloses the whole item).

export const CONTEXT_DIMENSIONS: Record<string, string[]> = {
  Friend: ["trustworthiness", "fun", "listening", "shows_up"],
  Work: ["punctuality", "professionalism", "communication", "reliability"],
  Client: ["punctuality", "professionalism", "communication", "reliability"],
  College: ["team_player", "dependable", "ideas", "energy"],
  Family: ["caring", "dependable_fam", "patience", "generosity"],
  Community: ["caring", "dependable_fam", "patience", "generosity"],
  Other: ["punctuality", "professionalism", "communication", "reliability"],
};

export const ALLOWED_DIMENSION_KEYS = new Set(
  Object.values(CONTEXT_DIMENSIONS).flat()
);

export const ALLOWED_TAGS = new Set([
  // Work / professional
  "Great listener", "Solution-oriented", "Collaborative", "Well prepared",
  "Follows through", "Calm under pressure", "Detail-oriented",
  "Big-picture thinker", "Generous with time", "Direct", "Patient", "Motivating",
  // Friend
  "Hype person", "Keeps secrets", "Brutally honest", "Always down",
  "Great company", "Remembers the little things", "Shows up in a crisis",
  "Makes you laugh",
  // College
  "Carries group projects", "Notes dealer", "Chill under deadline",
  "Idea machine", "Study buddy", "Lab partner of dreams",
  // Family / community
  "Shows up when it matters", "Good with kids", "Fixer",
  "Holds everyone together", "Quietly generous", "Wise counsel",
]);

export const ALLOWED_GROWTH_TAGS = new Set([
  "Could be more punctual", "Hard to reach sometimes",
  "Interrupts when excited", "Could listen more", "Spreads too thin",
  "Could follow through more", "Takes on too much", "Could be more patient",
  "Cancels plans sometimes", "Could share more openly",
]);

export const MAX_GROWTH_TAGS = 2;

/** Validate a submitted review payload against the taxonomy. */
export function validateReviewTaxonomy(
  dimensions: Record<string, unknown>,
  tags: unknown[],
  growthTags: unknown[]
): { ok: boolean; reason?: string } {
  for (const k of Object.keys(dimensions || {})) {
    if (!ALLOWED_DIMENSION_KEYS.has(k)) {
      return { ok: false, reason: `Unknown dimension: ${k}` };
    }
  }
  for (const t of tags || []) {
    if (typeof t !== "string" || !ALLOWED_TAGS.has(t)) {
      return { ok: false, reason: "Unknown tag." };
    }
  }
  if ((growthTags || []).length > MAX_GROWTH_TAGS) {
    return { ok: false, reason: `At most ${MAX_GROWTH_TAGS} growth tags.` };
  }
  for (const t of growthTags || []) {
    if (typeof t !== "string" || !ALLOWED_GROWTH_TAGS.has(t)) {
      return { ok: false, reason: "Unknown growth tag." };
    }
  }
  return { ok: true };
}

// ─── Growth-loop helpers ──────────────────────────────────────────────────────

/** URL-safe random slug for public wall pages (not derived from phone hash). */
export function randomSlug(length = 10): string {
  const alphabet = "abcdefghijkmnpqrstuvwxyz23456789"; // no l/o/0/1 lookalikes
  const bytes = crypto.randomBytes(length);
  let s = "";
  for (let i = 0; i < length; i++) s += alphabet[bytes[i] % alphabet.length];
  return s;
}

/** Human-friendly 6-char circle join code. */
export function circleCode(): string {
  const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
  const bytes = crypto.randomBytes(6);
  let s = "";
  for (let i = 0; i < 6; i++) s += alphabet[bytes[i] % alphabet.length];
  return s;
}

/** Effective premium check: lifetime flag OR a referral-granted window. */
export function isPremiumNow(
  premium: unknown,
  premiumUntilMs: number | null | undefined,
  nowMs = Date.now()
): boolean {
  if (premium === true) return true;
  return typeof premiumUntilMs === "number" && premiumUntilMs > nowMs;
}

/**
 * Referral reward: extend premiumUntil by `days`, never beyond `capDays`
 * in the future. Extensions stack from the current expiry (or now).
 */
export function extendPremiumUntil(
  currentUntilMs: number | null | undefined,
  nowMs: number,
  days = 7,
  capDays = 90
): number {
  const base = Math.max(currentUntilMs ?? 0, nowMs);
  const extended = base + days * 86_400_000;
  const cap = nowMs + capDays * 86_400_000;
  return Math.min(extended, cap);
}

/** Feedback Friday: contribution points double on Fridays (Asia/Kolkata). */
export function isFridayInIndia(nowMs = Date.now()): boolean {
  // IST is UTC+5:30, no DST.
  const ist = new Date(nowMs + 5.5 * 3_600_000);
  return ist.getUTCDay() === 5;
}

/** Contribution points for one give (Feedback Friday doubles them). */
export function contributionPoints(nowMs = Date.now()): number {
  return isFridayInIndia(nowMs) ? 20 : 10;
}

/**
 * Tease-rich invite copy. Counts what was left (tags + comment + dimensions)
 * without ever revealing content — the unlock is the hook.
 */
export function inviteTease(
  authorName: string | null,
  tagCount: number,
  hasComment: boolean
): string {
  const who = authorName || "Someone";
  const n = tagCount + (hasComment ? 1 : 0);
  if (n >= 2) return `${who} said ${n} things about you on Known 👀`;
  return `${who} left you feedback on Known 👀`;
}

// ─── Gamification helpers ─────────────────────────────────────────────────────

/**
 * Award a badge to the user if they haven't already earned it.
 * Reads the gamification doc once, appends, writes once (idempotent).
 * Returns true when the badge was newly awarded (so callers can notify).
 */
export async function awardBadgeIfNeeded(
  db: Firestore,
  uid: string,
  badgeId: string
): Promise<boolean> {
  const gamRef = db.collection("gamification").doc(uid);
  const snap = await gamRef.get();
  const d = snap.data() || {};
  const badges = (d.badges || []) as Array<{ id: string }>;
  if (badges.some((b) => b.id === badgeId)) return false; // already awarded
  await gamRef.set(
    { badges: [...badges, { id: badgeId, awardedAt: Timestamp.now() }] },
    { merge: true }
  );
  return true;
}

/**
 * Maintain a rolling daily streak. Call on any significant user activity.
 * If today is a new day (+1 from yesterday → increment; gap → reset to 1).
 * Awards streak_7 and streak_30 badges when thresholds are crossed.
 */
export async function updateStreak(db: Firestore, uid: string): Promise<void> {
  const gamRef = db.collection("gamification").doc(uid);
  const snap = await gamRef.get();
  const d = snap.data() || {};
  const streak = d.streak as
    | { current?: number; longest?: number; lastActivityAt?: Timestamp }
    | undefined;
  const now = Date.now();
  const lastMs = streak?.lastActivityAt?.toMillis() ?? 0;
  const diffDays = Math.floor((now - lastMs) / 86_400_000);

  if (diffDays === 0) return; // already touched today

  const prev = streak?.current ?? 0;
  const newCurrent = diffDays === 1 ? prev + 1 : 1;
  const newLongest = Math.max(streak?.longest ?? 0, newCurrent);

  await gamRef.set(
    {
      streak: {
        current: newCurrent,
        longest: newLongest,
        lastActivityAt: Timestamp.now(),
      },
    },
    { merge: true }
  );

  if (newCurrent >= 30) await awardBadgeIfNeeded(db, uid, "streak_30");
  else if (newCurrent >= 7) await awardBadgeIfNeeded(db, uid, "streak_7");
}

/**
 * Composite growth score capped at 100.
 * Reviews received (×3) + feedback given (×3) + streak days (×2).
 */
export function computeGrowthScore(
  contributionPoints: number,
  reviewCount: number,
  streakCurrent: number
): number {
  return Math.min(
    100,
    Math.round(reviewCount * 3 + (contributionPoints / 10) * 3 + streakCurrent * 2)
  );
}
