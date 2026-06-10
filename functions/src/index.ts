import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { setGlobalOptions } from "firebase-functions/v2";
import { defineSecret, defineString } from "firebase-functions/params";
import { GoogleAuth } from "google-auth-library";

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

// Secrets (set via `firebase functions:secrets:set <NAME>`).
const wallServerSalt = defineSecret("WALL_SERVER_SALT");
const perspectiveKey = defineSecret("PERSPECTIVE_API_KEY"); // optional moderation
const appleSharedSecret = defineSecret("APPLE_SHARED_SECRET"); // iOS IAP

// Android package name for Play receipt verification (non-secret config).
const androidPackage = defineString("ANDROID_PACKAGE", {
  default: "com.thewall.wall",
});

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
export const submitReview = onCall(
  { secrets: [wallServerSalt, perspectiveKey] },
  async (req) => {
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

  // Push notification to the target (non-blocking — missing token or APNS
  // config just means silent failure, never blocks the review flow).
  try {
    const fcmToken = (await db.collection("users").doc(targetUid).get()).get("fcmToken");
    if (fcmToken) {
      await getMessaging().send({
        token: fcmToken as string,
        notification: {
          title: "New feedback on The Wall",
          body: `${authorName || "Someone"} gave you feedback.`,
        },
        data: { type: "new_feedback" },
      });
    }
  } catch (err) { console.debug("FCM send skipped:", err); }

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

  if (released > 0) {
    await recomputeWall(phoneHash);
    // Notify the new joiner that they have waiting feedback.
    try {
      const fcmToken = (await db.collection("users").doc(uid).get()).get("fcmToken");
      if (fcmToken) {
        await getMessaging().send({
          token: fcmToken as string,
          notification: {
            title: "You have feedback waiting!",
            body: `${released} piece${released > 1 ? "s" : ""} of feedback unlocked on The Wall.`,
          },
          data: { type: "feedback_released" },
        });
      }
    } catch (err) { console.debug("FCM send skipped:", err); }
  }

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
export const handleErasure = onCall({ secrets: [wallServerSalt] }, async (req) => {
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
 * Verify an IAP receipt with the store, then grant premium status.
 *
 * iOS  → Apple verifyReceipt (prod, auto-falls-back to sandbox).
 * Android → Google Play Developer API (purchases.products), authenticated with
 *           the function's service account (must be granted access in Play
 *           Console). On the emulator (FUNCTIONS_EMULATOR=true) verification is
 *           skipped so the flow is testable without store credentials.
 */
export const verifyPurchase = onCall(
  { secrets: [appleSharedSecret] },
  async (req) => {
    const uid = requireAuth(req.auth);
    const { productId, verificationData, source } = req.data || {};
    if (!productId || !verificationData) {
      throw new HttpsError(
        "invalid-argument",
        "productId and verificationData required."
      );
    }

    const onEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    let verified = onEmulator;

    if (!onEmulator) {
      if (source === "app_store") {
        verified = await verifyApple(verificationData as string);
      } else if (source === "google_play") {
        verified = await verifyGoogle(productId as string, verificationData as string);
      } else {
        throw new HttpsError("invalid-argument", "Unknown purchase source.");
      }
    }

    await db.collection("ledger").add({
      uid,
      productId,
      source: source || "unknown",
      verified,
      verificationDataPrefix: (verificationData as string).substring(0, 64),
      processedAt: FieldValue.serverTimestamp(),
    });

    if (!verified) {
      throw new HttpsError("permission-denied", "Receipt could not be verified.");
    }

    await db.collection("users").doc(uid).set(
      { premium: true, premiumSince: FieldValue.serverTimestamp() },
      { merge: true }
    );

    return { ok: true };
  }
);

/** Validate an App Store receipt; tries prod then sandbox (status 21007). */
async function verifyApple(receiptData: string): Promise<boolean> {
  const body = JSON.stringify({
    "receipt-data": receiptData,
    password: process.env.APPLE_SHARED_SECRET || "",
    "exclude-old-transactions": true,
  });
  const post = async (url: string) => {
    const r = await fetch(url, { method: "POST", body });
    return (await r.json()) as { status?: number };
  };
  try {
    let j = await post("https://buy.itunes.apple.com/verifyReceipt");
    if (j.status === 21007) {
      j = await post("https://sandbox.itunes.apple.com/verifyReceipt");
    }
    return j.status === 0;
  } catch (err) {
    console.error("Apple receipt verification failed:", err);
    return false;
  }
}

/** Validate a Google Play purchase token via the Android Publisher API. */
async function verifyGoogle(productId: string, token: string): Promise<boolean> {
  try {
    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const client = await auth.getClient();
    const pkg = androidPackage.value();
    const url =
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
      `${pkg}/purchases/products/${productId}/tokens/${token}`;
    const res = await client.request({ url });
    const data = res.data as { purchaseState?: number };
    return data.purchaseState === 0; // 0 = purchased
  } catch (err) {
    console.error("Google receipt verification failed:", err);
    return false;
  }
}

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

// ─── editReview ───────────────────────────────────────────────────────────────

/**
 * Reviewer edits feedback they previously gave (one review per reviewer→target).
 * Latest-wins with a FRESH timestamp so decay weighting treats it as recent.
 * Handles both applied reviews and still-escrowed invites.
 */
export const editReview = onCall(
  { secrets: [wallServerSalt, perspectiveKey] },
  async (req) => {
    const uid = requireAuth(req.auth);
    const {
      targetPhoneHash,
      dimensions,
      tags = [],
      comment = null,
      anonymous = false,
      contextTag = null,
    } = req.data || {};
    if (!targetPhoneHash) {
      throw new HttpsError("invalid-argument", "targetPhoneHash required.");
    }
    for (const v of Object.values(dimensions || {})) {
      if (typeof v !== "number" || v < 1 || v > 5) {
        throw new HttpsError("invalid-argument", "Ratings must be 1-5.");
      }
    }
    const mod = await moderateText(comment);
    if (!mod.ok) return { ok: false, reason: mod.reason };

    const dKey = dedupKey(uid, targetPhoneHash);
    const authorName = anonymous
      ? null
      : (await db.collection("users").doc(uid).get()).get("displayName") || null;
    const fields = {
      dimensions: dimensions || {},
      tags,
      comment,
      authorName,
      contextTag,
      namedOrAnon: anonymous ? "anon" : "named",
      createdAt: FieldValue.serverTimestamp(),
    };

    // Still escrowed (target hasn't joined): edit the invite in place.
    const inviteRef = db.collection("invites").doc(dKey);
    if ((await inviteRef.get()).exists) {
      await inviteRef.set(fields, { merge: true });
      return { ok: true, escrowed: true };
    }

    const reviewRef = db.collection("reviews").doc(dKey);
    if (!(await reviewRef.get()).exists) {
      throw new HttpsError("not-found", "No existing review to edit.");
    }
    await reviewRef.set(fields, { merge: true });

    const targetUserSnap = await db
      .collection("users")
      .where("phoneHash", "==", targetPhoneHash)
      .limit(1)
      .get();
    if (!targetUserSnap.empty) {
      const targetUid = targetUserSnap.docs[0].id;
      await db
        .collection("users")
        .doc(targetUid)
        .collection("inbox")
        .doc(dKey)
        .set(
          { dimensions: dimensions || {}, tags, comment, authorName, contextTag },
          { merge: true }
        );
      await recomputeWall(targetPhoneHash);
    }
    return { ok: true };
  }
);

// ─── deleteReview ─────────────────────────────────────────────────────────────

/** Reviewer deletes feedback they gave; removes it from the target's aggregate. */
export const deleteReview = onCall(
  { secrets: [wallServerSalt] },
  async (req) => {
    const uid = requireAuth(req.auth);
    const { targetPhoneHash } = req.data || {};
    if (!targetPhoneHash) {
      throw new HttpsError("invalid-argument", "targetPhoneHash required.");
    }
    const dKey = dedupKey(uid, targetPhoneHash);

    await db.collection("reviews").doc(dKey).delete().catch(() => {});
    await db.collection("invites").doc(dKey).delete().catch(() => {});
    await db.collection("reviewDedup").doc(dKey).delete().catch(() => {});

    const targetUserSnap = await db
      .collection("users")
      .where("phoneHash", "==", targetPhoneHash)
      .limit(1)
      .get();
    if (!targetUserSnap.empty) {
      const targetUid = targetUserSnap.docs[0].id;
      await db
        .collection("users")
        .doc(targetUid)
        .collection("inbox")
        .doc(dKey)
        .delete()
        .catch(() => {});
      await recomputeWall(targetPhoneHash);
    }

    // Give-to-get credit is revoked along with the review.
    await db
      .collection("users")
      .doc(uid)
      .set({ giveToGetCount: FieldValue.increment(-1) }, { merge: true });

    return { ok: true };
  }
);

// ─── getPublicWall ────────────────────────────────────────────────────────────

/**
 * Server-gated read of another user's public wall. Enforces the give-to-get
 * gate, block checks, and min-N gating — so walls are never directly readable
 * by clients (which would allow phone-hash enumeration).
 */
export const getPublicWall = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { phoneHash } = req.data || {};
  if (!phoneHash) throw new HttpsError("invalid-argument", "phoneHash required.");

  const caller = await db.collection("users").doc(uid).get();
  if (((caller.get("giveToGetCount") as number) || 0) < GIVE_TO_GET) {
    throw new HttpsError(
      "permission-denied",
      "Give feedback to 5 contacts to unlock walls."
    );
  }

  const myHash = caller.get("phoneHash");
  const [b1, b2] = await Promise.all([
    db.collection("blocks").doc(`${phoneHash}_${myHash}`).get(),
    db.collection("blocks").doc(`${myHash}_${phoneHash}`).get(),
  ]);
  if (b1.exists || b2.exists) {
    throw new HttpsError("permission-denied", "This wall is unavailable.");
  }

  const wall = await db.collection("walls").doc(phoneHash).get();
  if (!wall.exists) return { ok: true, wall: null };
  const w = wall.data() || {};
  if (((w.reviewCount as number) || 0) < MIN_REVIEWS_FOR_AGGREGATE) {
    return { ok: true, wall: { gated: true } };
  }
  return {
    ok: true,
    wall: {
      dimensionAverages: w.dimensionAverages || {},
      tagCounts: w.tagCounts || {},
      opennessLabel: w.opennessLabel || "New",
      disclosedComments: w.disclosedComments || [],
      reviewCount: w.reviewCount || 0,
    },
  };
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

// ─── Scheduled: phone-recycling re-verification ──────────────────────────────

/**
 * Phone-recycling defense. Indian numbers can be deactivated and reassigned
 * after ~90 days of disuse. We use last activity (gamification streak) as the
 * signal: accounts dormant beyond the threshold are flagged `needsReverify`, so
 * the client forces a fresh OTP before re-granting access — preventing a
 * recycled number from inheriting the previous owner's Wall.
 */
export const reverifyNumber = onSchedule("every 24 hours", async () => {
  const cutoff = Timestamp.fromMillis(Date.now() - 180 * 86_400_000);
  const stale = await db
    .collection("gamification")
    .where("streak.lastActivityAt", "<", cutoff)
    .limit(500)
    .get();
  await Promise.all(
    stale.docs.map((d) =>
      db.collection("users").doc(d.id).set({ needsReverify: true }, { merge: true })
    )
  );
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
