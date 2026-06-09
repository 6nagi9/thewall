import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { setGlobalOptions } from "firebase-functions/v2";

import {
  aggregate,
  awardBadgeIfNeeded,
  computeGrowthScore,
  dedupKey,
  moderateText,
  opennessLabel,
  reviewerKey,
  updateStreak,
  GIVE_TO_GET,
  MIN_REVIEWS_FOR_AGGREGATE,
} from "./util";

initializeApp();
const db = getFirestore();

// Data residency: Mumbai region (DPDP Rules 2025 transfer limits).
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

function requireAuth(auth: { uid: string } | undefined): string {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
  return auth.uid;
}

// ─── submitReview ─────────────────────────────────────────────────────────────

/**
 * Core integrity pipeline:
 * validate → block-check → Layer-2 moderate → server-hash reviewer →
 * dedup → escrow-or-apply → recompute aggregate → credit give-to-get → badges.
 */
export const submitReview = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const {
    targetPhoneHash,
    dimensions,
    tags = [],
    comment = null,
    anonymous = false,
    contextTag = null,
  } = req.data || {};

  if (!targetPhoneHash || typeof targetPhoneHash !== "string") {
    throw new HttpsError("invalid-argument", "targetPhoneHash required.");
  }
  for (const v of Object.values(dimensions || {})) {
    if (typeof v !== "number" || (v as number) < 1 || (v as number) > 5) {
      throw new HttpsError("invalid-argument", "Ratings must be 1-5.");
    }
  }

  // Block check.
  const reviewerHash = (await db.collection("users").doc(uid).get()).get("phoneHash");
  const blockId = `${targetPhoneHash}_${reviewerHash}`;
  if ((await db.collection("blocks").doc(blockId).get()).exists) {
    throw new HttpsError("permission-denied", "You can't review this person.");
  }

  // Layer-2 moderation.
  const mod = await moderateText(comment);
  if (!mod.ok) return { ok: false, reason: mod.reason };

  const rKey = reviewerKey(uid);
  const dKey = dedupKey(uid, targetPhoneHash);
  const authorName = anonymous
    ? null
    : (await db.collection("users").doc(uid).get()).get("displayName") || null;

  const targetUserSnap = await db
    .collection("users")
    .where("phoneHash", "==", targetPhoneHash)
    .limit(1)
    .get();
  const targetJoined = !targetUserSnap.empty;

  const reviewPayload = {
    targetPhoneHash,
    dimensions: dimensions || {},
    tags,
    comment,
    authorName,
    contextTag,
    reviewerKeyHmac: rKey,
    namedOrAnon: anonymous ? "anon" : "named",
    status: "active",
    createdAt: FieldValue.serverTimestamp(),
  };

  const dedupRef = db.collection("reviewDedup").doc(dKey);
  const alreadyReviewed = (await dedupRef.get()).exists;

  if (!targetJoined) {
    // Escrow: hold until the target joins + consents.
    await db.collection("invites").doc(dKey).set({
      ...reviewPayload,
      expiresAt: Timestamp.fromMillis(Date.now() + 30 * 86_400_000),
    });
    await dedupRef.set({ targetPhoneHash, createdAt: FieldValue.serverTimestamp() });
    return { ok: true, escrowed: true };
  }

  // Target joined: write review + push inbox.
  const targetUid = targetUserSnap.docs[0].id;
  await db.collection("reviews").doc(dKey).set(reviewPayload);
  await db
    .collection("users")
    .doc(targetUid)
    .collection("inbox")
    .doc(dKey)
    .set({
      dimensions: dimensions || {},
      tags,
      comment,
      authorName,
      contextTag,
      status: "active",
      disclosed: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  await dedupRef.set({ targetPhoneHash, createdAt: FieldValue.serverTimestamp() });
  await recomputeWall(targetPhoneHash);

  // Credit give-to-get only for a new distinct contact (Path A).
  if (!alreadyReviewed) {
    await db
      .collection("users")
      .doc(uid)
      .set({ giveToGetCount: FieldValue.increment(1) }, { merge: true });
    await bumpContribution(uid);
    await updateStreak(db, uid);

    // Badge awards for reviewer.
    const userSnap = await db.collection("users").doc(uid).get();
    const newCount = (userSnap.get("giveToGetCount") as number) || 1;
    if (newCount === 1) await awardBadgeIfNeeded(db, uid, "first_feedback");
    if (newCount >= 5) await awardBadgeIfNeeded(db, uid, "giver_5");
    if (newCount >= 10) await awardBadgeIfNeeded(db, uid, "giver_10");
  }

  return { ok: true, escrowed: false };
});

// ─── onUserJoin ───────────────────────────────────────────────────────────────

/**
 * Release escrowed feedback for this phone hash and credit any inviters
 * (Path B give-to-get). Awards wall_claimed badge.
 */
export const onUserJoin = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { phoneHash } = req.data || {};
  if (!phoneHash) throw new HttpsError("invalid-argument", "phoneHash required.");

  const now = Date.now();
  const invites = await db
    .collection("invites")
    .where("targetPhoneHash", "==", phoneHash)
    .get();

  let released = 0;
  for (const doc of invites.docs) {
    const d = doc.data();
    const expiresAt = (d.expiresAt as Timestamp | undefined)?.toMillis() ?? 0;
    if (expiresAt && expiresAt < now) {
      await doc.ref.delete();
      continue;
    }
    await db.collection("users").doc(uid).collection("inbox").doc(doc.id).set({
      dimensions: d.dimensions || {},
      tags: d.tags || [],
      comment: d.comment ?? null,
      authorName: d.authorName ?? null,
      contextTag: d.contextTag ?? null,
      status: "active",
      disclosed: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    await db.collection("reviews").doc(doc.id).set({
      ...d,
      createdAt: FieldValue.serverTimestamp(),
    });
    await doc.ref.delete();
    released++;
  }

  if (released > 0) await recomputeWall(phoneHash);

  await updateStreak(db, uid);
  await awardBadgeIfNeeded(db, uid, "wall_claimed");

  return { released };
});

// ─── setDisclosure ────────────────────────────────────────────────────────────

/** Owner discloses/hides a feedback item; recomputes openness + public wall. */
export const setDisclosure = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { feedbackId, disclosed } = req.data || {};
  const inboxRef = db
    .collection("users")
    .doc(uid)
    .collection("inbox")
    .doc(feedbackId);
  if (!(await inboxRef.get()).exists) {
    throw new HttpsError("not-found", "Feedback not found.");
  }
  await inboxRef.set({ disclosed: !!disclosed }, { merge: true });
  const phoneHash = (await db.collection("users").doc(uid).get()).get("phoneHash");
  await recomputeWall(phoneHash);
  await updateStreak(db, uid);
  return { ok: true };
});

// ─── requestDataAccess ────────────────────────────────────────────────────────

/** DPDP §11 — always-free access path (bypasses the give-to-get soft gate). */
export const requestDataAccess = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  await db
    .collection("users")
    .doc(uid)
    .set({ dataAccessGrantedAt: FieldValue.serverTimestamp() }, { merge: true });
  return { ok: true };
});

// ─── fileDispute ──────────────────────────────────────────────────────────────

/** File a dispute — hide from aggregate immediately, queue for moderation. */
export const fileDispute = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { feedbackId, reason } = req.data || {};
  const inboxRef = db.collection("users").doc(uid).collection("inbox").doc(feedbackId);
  await inboxRef.set({ status: "under_review", disclosed: false }, { merge: true });
  await db.collection("reviews").doc(feedbackId).set(
    { status: "under_review" },
    { merge: true }
  );
  await db.collection("disputes").add({
    feedbackId,
    byUid: uid,
    reason: reason || "unspecified",
    state: "open",
    createdAt: FieldValue.serverTimestamp(),
  });
  const phoneHash = (await db.collection("users").doc(uid).get()).get("phoneHash");
  await recomputeWall(phoneHash);
  return { ok: true };
});

// ─── blockUser ────────────────────────────────────────────────────────────────

export const blockUser = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { otherPhoneHash } = req.data || {};
  const myHash = (await db.collection("users").doc(uid).get()).get("phoneHash");
  await db.collection("blocks").doc(`${myHash}_${otherPhoneHash}`).set({
    createdAt: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});

// ─── reportContent ────────────────────────────────────────────────────────────

export const reportContent = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { feedbackId, reason } = req.data || {};
  await db.collection("reports").add({
    feedbackId,
    byUid: uid,
    reason: reason || "unspecified",
    state: "open",
    createdAt: FieldValue.serverTimestamp(),
  });
  return { ok: true };
});

// ─── handleErasure ────────────────────────────────────────────────────────────

/**
 * DPDP erasure — delete the user, their wall, feedback about them.
 * Keep outgoing reviews (those are the targets' data) but sever the identity link.
 */
export const handleErasure = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const userSnap = await db.collection("users").doc(uid).get();
  const phoneHash = userSnap.get("phoneHash");

  const inbox = await db.collection("users").doc(uid).collection("inbox").get();
  const batch = db.batch();
  inbox.docs.forEach((d) => batch.delete(d.ref));
  batch.delete(db.collection("walls").doc(phoneHash));
  batch.delete(db.collection("gamification").doc(uid));
  batch.delete(db.collection("users").doc(uid));
  await batch.commit();

  const about = await db
    .collection("reviews")
    .where("targetPhoneHash", "==", phoneHash)
    .get();
  await Promise.all(about.docs.map((d) => d.ref.delete()));

  const byKey = reviewerKey(uid);
  const byUser = await db
    .collection("reviews")
    .where("reviewerKeyHmac", "==", byKey)
    .get();
  await Promise.all(
    byUser.docs.map((d) =>
      d.ref.set({ reviewerKeyHmac: "erased", authorName: null }, { merge: true })
    )
  );

  return { ok: true };
});

// ─── requestFeedback (B1 — campaigns) ────────────────────────────────────────

/** Create a targeted feedback campaign and return a shareable link. */
export const requestFeedback = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { message, focusDimensions = [] } = req.data || {};

  const ref = db.collection("feedbackRequests").doc();
  await ref.set({
    ownerUid: uid,
    message: message || null,
    focusDimensions,
    responseCount: 0,
    createdAt: FieldValue.serverTimestamp(),
  });

  await updateStreak(db, uid);
  await awardBadgeIfNeeded(db, uid, "campaign_launched");

  return { ok: true, link: `https://thewall.app/r/${ref.id}` };
});

// ─── verifyPurchase ───────────────────────────────────────────────────────────

/**
 * Verify an IAP receipt and grant premium status.
 * TODO: replace with real App Store / Google Play receipt verification
 *       using stored service-account credentials before going live.
 */
export const verifyPurchase = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { productId, verificationData, source } = req.data || {};
  if (!productId || !verificationData) {
    throw new HttpsError("invalid-argument", "productId and verificationData required.");
  }

  await db.collection("ledger").add({
    uid,
    productId,
    source: source || "unknown",
    verificationDataPrefix: (verificationData as string).substring(0, 64),
    processedAt: FieldValue.serverTimestamp(),
  });

  await db.collection("users").doc(uid).set(
    { premium: true, premiumSince: FieldValue.serverTimestamp() },
    { merge: true }
  );

  return { ok: true };
});

// ─── generateDataExport ───────────────────────────────────────────────────────

/** DPDP §11 data export — returns the caller's full personal data as JSON. */
export const generateDataExport = onCall(async (req) => {
  const uid = requireAuth(req.auth);

  const [userSnap, inboxSnap, gamSnap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("users").doc(uid).collection("inbox").limit(200).get(),
    db.collection("gamification").doc(uid).get(),
  ]);

  const u = userSnap.data() || {};
  const exportData = {
    exportedAt: new Date().toISOString(),
    user: {
      uid,
      displayName: u.displayName,
      phoneHash: u.phoneHash,
      consentAt: (u.consentAt as Timestamp | undefined)?.toDate().toISOString(),
      ageConfirmed: u.ageConfirmed,
      premium: u.premium ?? false,
      giveToGetCount: u.giveToGetCount ?? 0,
    },
    receivedFeedback: inboxSnap.docs.map((d) => {
      const fd = d.data();
      return {
        id: d.id,
        dimensions: fd.dimensions,
        tags: fd.tags,
        comment: fd.comment ?? null,
        authorName: fd.authorName ?? null,
        contextTag: fd.contextTag ?? null,
        status: fd.status,
        disclosed: fd.disclosed,
        createdAt: (fd.createdAt as Timestamp | undefined)?.toDate().toISOString(),
      };
    }),
    gamification: gamSnap.exists
      ? {
          contributionPoints: gamSnap.get("contributionPoints") ?? 0,
          growthScore: gamSnap.get("growthScore") ?? 0,
          opennessScore: gamSnap.get("opennessScore") ?? 0,
          badges: gamSnap.get("badges") ?? [],
          streak: gamSnap.get("streak") ?? {},
        }
      : null,
  };

  return { ok: true, json: JSON.stringify(exportData, null, 2) };
});

// ─── setLeaderboardOptIn ──────────────────────────────────────────────────────

export const setLeaderboardOptIn = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { optIn } = req.data || {};
  await db.collection("gamification").doc(uid).set(
    { leaderboardOptIn: !!optIn },
    { merge: true }
  );
  return { ok: true };
});

// ─── Scheduled: recompute aggregates nightly ─────────────────────────────────

export const recomputeAggregates = onSchedule("every 24 hours", async () => {
  const walls = await db.collection("walls").get();
  for (const w of walls.docs) {
    await recomputeWall(w.id);
  }
});

// ─── Scheduled: Sybil / burst anomaly sweep ──────────────────────────────────

export const antiAbuseSweep = onSchedule("every 6 hours", async () => {
  const since = Timestamp.fromMillis(Date.now() - 6 * 3600_000);
  const recent = await db
    .collection("reviews")
    .where("createdAt", ">=", since)
    .get();
  const perTarget: Record<string, number> = {};
  recent.docs.forEach((d) => {
    const t = d.get("targetPhoneHash");
    perTarget[t] = (perTarget[t] || 0) + 1;
  });
  for (const [target, count] of Object.entries(perTarget)) {
    if (count > 5) {
      const burst = await db
        .collection("reviews")
        .where("targetPhoneHash", "==", target)
        .where("createdAt", ">=", since)
        .get();
      await Promise.all(
        burst.docs.map((d) =>
          d.ref.set({ status: "under_review" }, { merge: true })
        )
      );
      await recomputeWall(target);
    }
  }
});

// ─── Helpers ──────────────────────────────────────────────────────────────────

/**
 * Recompute a wall's aggregate from active reviews, update openness + growth
 * score in gamification, award review-count and openness badges.
 */
async function recomputeWall(phoneHash: string): Promise<void> {
  const reviewsSnap = await db
    .collection("reviews")
    .where("targetPhoneHash", "==", phoneHash)
    .where("status", "==", "active")
    .get();

  const reviews = reviewsSnap.docs.map((d) => {
    const c = d.get("createdAt") as Timestamp | undefined;
    return {
      dimensions: d.get("dimensions") || {},
      tags: d.get("tags") || [],
      createdAt: c ? c.toMillis() : Date.now(),
    };
  });

  const agg = aggregate(reviews);

  const ownerSnap = await db
    .collection("users")
    .where("phoneHash", "==", phoneHash)
    .limit(1)
    .get();

  let disclosedComments: Array<Record<string, unknown>> = [];
  let openness = { score: 0, label: "New" };

  if (!ownerSnap.empty) {
    const ownerUid = ownerSnap.docs[0].id;
    const inbox = await db
      .collection("users")
      .doc(ownerUid)
      .collection("inbox")
      .get();

    const received = inbox.size;
    const disclosed = inbox.docs.filter((d) => d.get("disclosed") === true);
    openness = opennessLabel(disclosed.length, received);

    if (agg.reviewCount >= MIN_REVIEWS_FOR_AGGREGATE) {
      disclosedComments = disclosed
        .filter((d) => d.get("comment"))
        .map((d) => ({
          text: d.get("comment"),
          authorName: d.get("authorName") ?? null,
          contextTag: d.get("contextTag") ?? null,
        }));
    }

    // Growth score — read gamification once.
    const gamSnap = await db.collection("gamification").doc(ownerUid).get();
    const gd = gamSnap.data() || {};
    const streakCurrent = (gd.streak?.current as number) || 0;
    const contributionPoints = (gd.contributionPoints as number) || 0;
    const growthScore = computeGrowthScore(
      contributionPoints,
      agg.reviewCount,
      streakCurrent
    );

    // Compute badges to award (read badges once from the snap we already have).
    const existingBadges = (gd.badges || []) as Array<{ id: string }>;
    const newBadges: Array<{ id: string; awardedAt: Timestamp }> = [];
    const award = (id: string) => {
      if (!existingBadges.some((b) => b.id === id)) {
        newBadges.push({ id, awardedAt: Timestamp.now() });
      }
    };
    if (agg.reviewCount >= 1) award("first_review");
    if (agg.reviewCount >= 5) award("five_reviews");
    if (openness.label === "Very Open") award("open_book");

    await db.collection("gamification").doc(ownerUid).set(
      {
        displayName: ownerSnap.docs[0].get("displayName") || "Member",
        opennessScore: Number(openness.score.toFixed(3)),
        growthScore,
        ...(newBadges.length > 0
          ? { badges: [...existingBadges, ...newBadges] }
          : {}),
      },
      { merge: true }
    );
  }

  await db.collection("walls").doc(phoneHash).set(
    {
      ...agg,
      opennessScore: Number(openness.score.toFixed(3)),
      opennessLabel: openness.label,
      disclosedComments,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/** Award contribution points for giving thoughtful feedback. */
async function bumpContribution(uid: string): Promise<void> {
  const snap = await db.collection("users").doc(uid).get();
  await db.collection("gamification").doc(uid).set(
    {
      displayName: snap.get("displayName") || "Member",
      contributionPoints: FieldValue.increment(10),
    },
    { merge: true }
  );
}

export { GIVE_TO_GET };
