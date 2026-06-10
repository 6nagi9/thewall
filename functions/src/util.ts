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
 *   2b. Google Perspective API — ML toxicity/threat/identity-attack scoring,
 *       enabled when PERSPECTIVE_API_KEY is set. Fails OPEN on API error
 *       (the blocklist has already run), so a transient outage never blocks
 *       legitimate feedback.
 *
 * The key is read from the environment at call time so it works with Cloud
 * Functions v2 bound secrets.
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

  // 2b — Perspective API (optional; configured via secret). The "REPLACE_ME"
  // sentinel means the secret exists for deploy but no real key is set yet, so
  // we stay blocklist-only without making a doomed API call.
  const key = process.env.PERSPECTIVE_API_KEY;
  if (!key || key === "REPLACE_ME") return { ok: true };
  try {
    const res = await fetch(
      `https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze?key=${key}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          comment: { text },
          languages: ["en"],
          requestedAttributes: {
            TOXICITY: {},
            SEVERE_TOXICITY: {},
            INSULT: {},
            THREAT: {},
            IDENTITY_ATTACK: {},
          },
        }),
      }
    );
    if (!res.ok) return { ok: true }; // fail open
    const data = (await res.json()) as {
      attributeScores?: Record<string, { summaryScore?: { value?: number } }>;
    };
    const s = data.attributeScores || {};
    const score = (k: string) => s[k]?.summaryScore?.value ?? 0;
    const toxic = Math.max(score("SEVERE_TOXICITY"), score("TOXICITY"));
    if (toxic >= 0.8 || score("THREAT") >= 0.8 || score("IDENTITY_ATTACK") >= 0.7) {
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

// ─── Gamification helpers ─────────────────────────────────────────────────────

/**
 * Award a badge to the user if they haven't already earned it.
 * Reads the gamification doc once, appends, writes once (idempotent).
 */
export async function awardBadgeIfNeeded(
  db: Firestore,
  uid: string,
  badgeId: string
): Promise<void> {
  const gamRef = db.collection("gamification").doc(uid);
  const snap = await gamRef.get();
  const d = snap.data() || {};
  const badges = (d.badges || []) as Array<{ id: string }>;
  if (badges.some((b) => b.id === badgeId)) return; // already awarded
  await gamRef.set(
    { badges: [...badges, { id: badgeId, awardedAt: Timestamp.now() }] },
    { merge: true }
  );
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
