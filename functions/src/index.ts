import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { setGlobalOptions } from "firebase-functions/v2";
import { defineSecret, defineString } from "firebase-functions/params";
import { GoogleAuth } from "google-auth-library";
import Anthropic from "@anthropic-ai/sdk";

import {
  aggregate,
  awardBadgeIfNeeded,
  circleCode,
  computeGrowthScore,
  contributionPoints,
  dedupKey,
  extendPremiumUntil,
  inviteTease,
  isPremiumNow,
  moderateText,
  opennessLabel,
  randomSlug,
  reviewerKey,
  updateStreak,
  validateReviewTaxonomy,
  GIVE_TO_GET,
  MIN_REVIEWS_FOR_AGGREGATE,
} from "./util";

// Secrets (set via `firebase functions:secrets:set <NAME>`).
const wallServerSalt = defineSecret("WALL_SERVER_SALT");
const perspectiveKey = defineSecret("PERSPECTIVE_API_KEY"); // optional moderation
const appleSharedSecret = defineSecret("APPLE_SHARED_SECRET"); // iOS IAP
const anthropicKey = defineSecret("ANTHROPIC_API_KEY"); // AI wall summary (premium)

// Android package name for Play receipt verification (non-secret config).
const androidPackage = defineString("ANDROID_PACKAGE", {
  default: "com.thewall.wall",
});

// Public web base for invite / campaign / circle / wall links. Served by
// Firebase Hosting; swap for a custom domain (thewall.app) once configured.
const WEB_BASE = "https://the-wall-app-260609.web.app";

initializeApp();
const db = getFirestore();

// Data residency: Mumbai region (DPDP Rules 2025 transfer limits).
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

function requireAuth(auth: { uid: string } | undefined): string {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Sign in required.");
  return auth.uid;
}

/**
 * Fire-and-forget FCM push. Missing token / APNS config = silent skip; a
 * notification must never block the flow that triggered it.
 */
async function sendPush(
  uid: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  try {
    const fcmToken = (await db.collection("users").doc(uid).get()).get("fcmToken");
    if (!fcmToken) return;
    await getMessaging().send({
      token: fcmToken as string,
      notification: { title, body },
      data,
    });
  } catch (err) {
    console.debug("FCM send skipped:", err);
  }
}

/** Award a badge and notify the user when it's new. */
async function awardBadgeWithPush(uid: string, badgeId: string): Promise<void> {
  const awarded = await awardBadgeIfNeeded(db, uid, badgeId);
  if (awarded) {
    await sendPush(uid, "Badge earned 🏆", "You earned a new badge on Known.", {
      type: "badge_earned",
      badgeId,
    });
  }
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
    growthTags = [],
    comment = null,
    anonymous = false,
    contextTag = null,
    campaignId = null,
  } = req.data || {};

  if (!targetPhoneHash || typeof targetPhoneHash !== "string") {
    throw new HttpsError("invalid-argument", "targetPhoneHash required.");
  }
  for (const v of Object.values(dimensions || {})) {
    if (typeof v !== "number" || (v as number) < 1 || (v as number) > 5) {
      throw new HttpsError("invalid-argument", "Ratings must be 1-5.");
    }
  }
  const tax = validateReviewTaxonomy(dimensions || {}, tags, growthTags);
  if (!tax.ok) throw new HttpsError("invalid-argument", tax.reason || "Invalid review.");

  // Block check.
  const reviewerSnap = await db.collection("users").doc(uid).get();
  const reviewerHash = reviewerSnap.get("phoneHash");
  const blockId = `${targetPhoneHash}_${reviewerHash}`;
  if ((await db.collection("blocks").doc(blockId).get()).exists) {
    throw new HttpsError("permission-denied", "You can't review this person.");
  }

  // Layer-2 moderation.
  const mod = await moderateText(comment);
  if (!mod.ok) return { ok: false, reason: mod.reason };

  const rKey = reviewerKey(uid);
  const dKey = dedupKey(uid, targetPhoneHash);
  const authorName = anonymous ? null : reviewerSnap.get("displayName") || null;

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
    growthTags,
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
    // Escrow: hold until the target joins + consents. `reviewerUid` stays in
    // this Function-only collection (rules deny all client access) and powers
    // referral credit + expiry nudges; it is never exposed to clients.
    await db.collection("invites").doc(dKey).set({
      ...reviewPayload,
      reviewerUid: uid,
      expiresAt: Timestamp.fromMillis(Date.now() + 30 * 86_400_000),
    });
    await dedupRef.set({ targetPhoneHash, createdAt: FieldValue.serverTimestamp() });
    // Tease copy for the share sheet — counts only, never content.
    const tease = inviteTease(authorName, (tags as string[]).length, !!comment);
    return {
      ok: true,
      escrowed: true,
      shareText: `${tease} — unlock it: ${WEB_BASE}/i/${targetPhoneHash}`,
    };
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
      growthTags,
      comment,
      authorName,
      contextTag,
      status: "active",
      disclosed: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  await dedupRef.set({ targetPhoneHash, createdAt: FieldValue.serverTimestamp() });
  await recomputeWall(targetPhoneHash);

  await sendPush(
    targetUid,
    "New feedback on Known",
    `${authorName || "Someone"} gave you feedback.`,
    { type: "new_feedback" }
  );

  // Campaign response accounting (B1) + owner notification.
  if (campaignId && typeof campaignId === "string") {
    const campRef = db.collection("feedbackRequests").doc(campaignId);
    const camp = await campRef.get();
    if (camp.exists && camp.get("ownerUid") === targetUid) {
      await campRef.set(
        { responseCount: FieldValue.increment(1) },
        { merge: true }
      );
      await sendPush(
        targetUid,
        "Your feedback request worked",
        "Someone answered your feedback campaign on Known.",
        { type: "campaign_response", campaignId }
      );
    }
  }

  // Credit give-to-get only for a new distinct contact (Path A).
  if (!alreadyReviewed) {
    await creditGive(uid);
  }

  return { ok: true, escrowed: false };
});

/**
 * Shared credit path for one distinct give: give-to-get progress,
 * contribution points (doubled on Feedback Friday), streak, badges, and
 * per-circle give counters.
 */
async function creditGive(uid: string): Promise<void> {
  await db
    .collection("users")
    .doc(uid)
    .set({ giveToGetCount: FieldValue.increment(1) }, { merge: true });
  await bumpContribution(uid);
  await updateStreak(db, uid);

  const userSnap = await db.collection("users").doc(uid).get();
  const newCount = (userSnap.get("giveToGetCount") as number) || 1;
  if (newCount === 1) await awardBadgeWithPush(uid, "first_feedback");
  if (newCount >= 5) await awardBadgeWithPush(uid, "giver_5");
  if (newCount >= 10) await awardBadgeWithPush(uid, "giver_10");

  // Circle give counters (social proximity > global rank).
  const circleIds = (userSnap.get("circleIds") as string[] | undefined) ?? [];
  await Promise.all(
    circleIds.slice(0, 10).map((cid) =>
      db
        .collection("circles")
        .doc(cid)
        .collection("members")
        .doc(uid)
        .set({ given: FieldValue.increment(1) }, { merge: true })
        .catch(() => {})
    )
  );
}

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
  const inviterUids = new Set<string>();
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
      growthTags: d.growthTags || [],
      comment: d.comment ?? null,
      authorName: d.authorName ?? null,
      contextTag: d.contextTag ?? null,
      status: "active",
      disclosed: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    // Strip the Function-only reviewerUid before the review becomes a
    // long-lived record (reviewerKeyHmac remains the lawful-request link).
    const { reviewerUid, expiresAt: _exp, ...reviewFields } = d;
    await db.collection("reviews").doc(doc.id).set({
      ...reviewFields,
      createdAt: FieldValue.serverTimestamp(),
    });
    await doc.ref.delete();
    released++;
    if (typeof reviewerUid === "string") inviterUids.add(reviewerUid);
  }

  if (released > 0) {
    await recomputeWall(phoneHash);
    // Notify the new joiner that they have waiting feedback.
    await sendPush(
      uid,
      "You have feedback waiting!",
      `${released} piece${released > 1 ? "s" : ""} of feedback unlocked on Known.`,
      { type: "feedback_released" }
    );
  }

  // Referral rewards (Path B): each inviter whose escrow released gets
  // give-to-get credit, an invite-join counter bump, and 7 days of Premium
  // (stacking, capped at 90 days out).
  for (const inviterUid of inviterUids) {
    if (inviterUid === uid) continue;
    try {
      const invSnap = await db.collection("users").doc(inviterUid).get();
      if (!invSnap.exists) continue;
      const currentUntil = (invSnap.get("premiumUntil") as Timestamp | undefined)
        ?.toMillis();
      const newUntil = extendPremiumUntil(currentUntil, now);
      await db.collection("users").doc(inviterUid).set(
        {
          giveToGetCount: FieldValue.increment(1),
          inviteJoins: FieldValue.increment(1),
          premiumUntil: Timestamp.fromMillis(newUntil),
        },
        { merge: true }
      );
      await sendPush(
        inviterUid,
        "Your invite worked 🎉",
        "Someone you invited joined Known — you earned 7 days of Premium.",
        { type: "invite_joined" }
      );
    } catch (err) {
      console.debug("Inviter credit skipped:", err);
    }
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

// ─── submitAppFeedback (in-app feedback / suggestions to the team) ────────────

/**
 * User-to-team feedback: suggestions, bug reports, praise. Distinct from the
 * peer-feedback core. Stored in `appFeedback` for the team to triage; the
 * client attaches app version + platform so reports are actionable.
 */
export const submitAppFeedback = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const {
    category = "suggestion",
    message,
    contact = null,
    appVersion = null,
    platform = null,
  } = req.data || {};

  const text = typeof message === "string" ? message.trim() : "";
  if (text.length < 3) {
    throw new HttpsError("invalid-argument", "Please add a little more detail.");
  }
  if (text.length > 2000) {
    throw new HttpsError("invalid-argument", "Message is too long.");
  }
  const allowed = ["suggestion", "bug", "praise", "other"];
  const cat = allowed.includes(category) ? category : "other";

  // Lightweight per-user rate limit: max 5 submissions per rolling hour.
  const since = Timestamp.fromMillis(Date.now() - 3600_000);
  const recent = await db
    .collection("appFeedback")
    .where("uid", "==", uid)
    .where("createdAt", ">=", since)
    .count()
    .get();
  if ((recent.data().count || 0) >= 5) {
    throw new HttpsError(
      "resource-exhausted",
      "Thanks! You've sent a lot just now — try again in a bit."
    );
  }

  await db.collection("appFeedback").add({
    uid,
    category: cat,
    message: text.substring(0, 2000),
    contact: typeof contact === "string" ? contact.substring(0, 120) : null,
    appVersion: typeof appVersion === "string" ? appVersion.substring(0, 40) : null,
    platform: typeof platform === "string" ? platform.substring(0, 20) : null,
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

/**
 * Create a feedback campaign and return a shareable link.
 *
 * GROWTH NOTE: campaigns are the strongest viral loop (the NGL-style
 * "ask anyone" link) so they are FREE — one active campaign for free users,
 * unlimited for Premium. Premium monetizes the *insight on the results*
 * (trends, AI summary, cohort), never the loop itself.
 */
export const requestFeedback = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { message, focusDimensions = [] } = req.data || {};

  const userSnap = await db.collection("users").doc(uid).get();
  const premium = isPremiumNow(
    userSnap.get("premium"),
    (userSnap.get("premiumUntil") as Timestamp | undefined)?.toMillis()
  );

  if (!premium) {
    const active = await db
      .collection("feedbackRequests")
      .where("ownerUid", "==", uid)
      .where("status", "==", "active")
      .limit(1)
      .get();
    if (!active.empty) {
      throw new HttpsError(
        "resource-exhausted",
        "Free plan allows one active campaign — close it or go Premium for unlimited."
      );
    }
  }

  const ref = db.collection("feedbackRequests").doc();
  await ref.set({
    ownerUid: uid,
    // Lets a responder who opens the link compose feedback for the owner
    // without exchanging phone numbers. Campaign docs are readable only by
    // signed-in members (rules), and walls remain unreadable by hash.
    ownerPhoneHash: userSnap.get("phoneHash") || null,
    ownerName: userSnap.get("displayName") || null,
    message: message || null,
    focusDimensions,
    responseCount: 0,
    status: "active",
    createdAt: FieldValue.serverTimestamp(),
  });

  await updateStreak(db, uid);
  await awardBadgeWithPush(uid, "campaign_launched");

  return { ok: true, link: `${WEB_BASE}/r/${ref.id}` };
});

/** Close a campaign (frees the free-tier slot). */
export const closeCampaign = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { campaignId } = req.data || {};
  if (!campaignId) throw new HttpsError("invalid-argument", "campaignId required.");
  const ref = db.collection("feedbackRequests").doc(campaignId);
  const snap = await ref.get();
  if (!snap.exists || snap.get("ownerUid") !== uid) {
    throw new HttpsError("not-found", "Campaign not found.");
  }
  await ref.set({ status: "closed" }, { merge: true });
  return { ok: true };
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
      growthTags = [],
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
    const tax = validateReviewTaxonomy(dimensions || {}, tags, growthTags);
    if (!tax.ok) throw new HttpsError("invalid-argument", tax.reason || "Invalid review.");
    const mod = await moderateText(comment);
    if (!mod.ok) return { ok: false, reason: mod.reason };

    const dKey = dedupKey(uid, targetPhoneHash);
    const authorName = anonymous
      ? null
      : (await db.collection("users").doc(uid).get()).get("displayName") || null;
    const fields = {
      dimensions: dimensions || {},
      tags,
      growthTags,
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
          {
            dimensions: dimensions || {},
            tags,
            growthTags,
            comment,
            authorName,
            contextTag,
          },
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

// ─── setWallPublish (public web wall, opt-in) ────────────────────────────────

/**
 * Publish / unpublish a shareable web wall at WEB_BASE/w/{slug}.
 *
 * Privacy: the slug is random (never derived from the phone hash), the page
 * shows only owner-disclosed aggregates, and publishing is strictly opt-in.
 * Unpublishing deletes the public doc immediately.
 */
export const setWallPublish = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { publish } = req.data || {};
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  const phoneHash = userSnap.get("phoneHash");
  if (!phoneHash) throw new HttpsError("failed-precondition", "Claim your wall first.");

  const existingSlug = userSnap.get("publicSlug") as string | undefined;

  if (!publish) {
    if (existingSlug) {
      await db.collection("publicWalls").doc(existingSlug).delete().catch(() => {});
      await userRef.set({ publicSlug: FieldValue.delete() }, { merge: true });
    }
    return { ok: true, slug: null };
  }

  const slug = existingSlug || randomSlug();
  await db.collection("publicWalls").doc(slug).set(
    {
      ownerUid: uid,
      phoneHash, // server-side pointer for recompute mirroring; never rendered
      displayName: userSnap.get("displayName") || "A Wall member",
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  await userRef.set({ publicSlug: slug }, { merge: true });
  await recomputeWall(phoneHash); // mirrors current aggregate into the page
  return { ok: true, slug, link: `${WEB_BASE}/w/${slug}` };
});

// ─── Circles (proximity beats global rank) ───────────────────────────────────

const MAX_CIRCLES_PER_USER = 10;

/** Create a circle and join it; returns the share code + link. */
export const createCircle = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const name = String(req.data?.name || "").trim();
  if (name.length < 2 || name.length > 40) {
    throw new HttpsError("invalid-argument", "Circle name must be 2-40 characters.");
  }
  const mod = await moderateText(name);
  if (!mod.ok) throw new HttpsError("invalid-argument", "Name failed moderation.");

  const userSnap = await db.collection("users").doc(uid).get();
  const circleIds = (userSnap.get("circleIds") as string[] | undefined) ?? [];
  if (circleIds.length >= MAX_CIRCLES_PER_USER) {
    throw new HttpsError("resource-exhausted", "You're already in 10 circles.");
  }

  const code = circleCode();
  const ref = db.collection("circles").doc();
  await ref.set({
    name,
    code,
    createdBy: uid,
    memberCount: 1,
    createdAt: FieldValue.serverTimestamp(),
  });
  await ref.collection("members").doc(uid).set({
    displayName: userSnap.get("displayName") || "Member",
    given: 0,
    joinedAt: FieldValue.serverTimestamp(),
  });
  await db.collection("users").doc(uid).set(
    { circleIds: FieldValue.arrayUnion(ref.id) },
    { merge: true }
  );
  return { ok: true, circleId: ref.id, code, link: `${WEB_BASE}/c/${code}` };
});

/** Join a circle by its 6-char code. */
export const joinCircle = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const code = String(req.data?.code || "").trim().toUpperCase();
  if (code.length !== 6) throw new HttpsError("invalid-argument", "Invalid code.");

  const found = await db.collection("circles").where("code", "==", code).limit(1).get();
  if (found.empty) throw new HttpsError("not-found", "No circle with that code.");
  const circle = found.docs[0];

  const userSnap = await db.collection("users").doc(uid).get();
  const circleIds = (userSnap.get("circleIds") as string[] | undefined) ?? [];
  if (circleIds.includes(circle.id)) {
    return { ok: true, circleId: circle.id, alreadyMember: true };
  }
  if (circleIds.length >= MAX_CIRCLES_PER_USER) {
    throw new HttpsError("resource-exhausted", "You're already in 10 circles.");
  }

  await circle.ref.collection("members").doc(uid).set({
    displayName: userSnap.get("displayName") || "Member",
    given: 0,
    joinedAt: FieldValue.serverTimestamp(),
  });
  await circle.ref.set({ memberCount: FieldValue.increment(1) }, { merge: true });
  await db.collection("users").doc(uid).set(
    { circleIds: FieldValue.arrayUnion(circle.id) },
    { merge: true }
  );
  await updateStreak(db, uid);
  return { ok: true, circleId: circle.id, name: circle.get("name") };
});

/** Leave a circle. */
export const leaveCircle = onCall(async (req) => {
  const uid = requireAuth(req.auth);
  const { circleId } = req.data || {};
  if (!circleId) throw new HttpsError("invalid-argument", "circleId required.");
  const ref = db.collection("circles").doc(circleId);
  await ref.collection("members").doc(uid).delete().catch(() => {});
  await ref.set({ memberCount: FieldValue.increment(-1) }, { merge: true });
  await db.collection("users").doc(uid).set(
    { circleIds: FieldValue.arrayRemove(circleId) },
    { merge: true }
  );
  return { ok: true };
});

// ─── generateAiSummary (Premium) ─────────────────────────────────────────────

/**
 * "What your wall says about you" — Claude-written summary + growth plan from
 * the caller's own feedback. Premium-gated; cached for 7 days per review count.
 *
 * Consent posture: processes only data the caller already owns (their inbox),
 * disclosed in the privacy policy. Nothing about third parties is generated.
 */
export const generateAiSummary = onCall(
  { secrets: [anthropicKey], timeoutSeconds: 120 },
  async (req) => {
    const uid = requireAuth(req.auth);
    const userSnap = await db.collection("users").doc(uid).get();
    const premium = isPremiumNow(
      userSnap.get("premium"),
      (userSnap.get("premiumUntil") as Timestamp | undefined)?.toMillis()
    );
    if (!premium) {
      throw new HttpsError("permission-denied", "AI summary is a Premium feature.");
    }

    const inbox = await db
      .collection("users")
      .doc(uid)
      .collection("inbox")
      .orderBy("createdAt", "desc")
      .limit(100)
      .get();
    const active = inbox.docs.filter((d) => d.get("status") === "active");
    if (active.length < MIN_REVIEWS_FOR_AGGREGATE) {
      throw new HttpsError(
        "failed-precondition",
        "You need at least 3 pieces of feedback for an AI summary."
      );
    }

    // Cache: reuse unless stale (>7 days) or new feedback arrived.
    const cached = userSnap.get("aiSummary") as
      | { text?: string; plan?: string; reviewCount?: number; generatedAt?: Timestamp }
      | undefined;
    const fresh =
      cached?.text &&
      cached.reviewCount === active.length &&
      (cached.generatedAt?.toMillis() ?? 0) > Date.now() - 7 * 86_400_000;
    if (fresh && req.data?.force !== true) {
      return { ok: true, summary: cached.text, plan: cached.plan, cached: true };
    }

    const key = process.env.ANTHROPIC_API_KEY;
    if (!key || key === "REPLACE_ME") {
      throw new HttpsError(
        "unavailable",
        "AI summaries aren't configured yet. Try again soon."
      );
    }

    const corpus = active
      .map((d) => {
        const dims = Object.entries(d.get("dimensions") || {})
          .map(([k, v]) => `${k}:${v}/5`)
          .join(", ");
        const tags = ((d.get("tags") || []) as string[]).join("; ");
        const growth = ((d.get("growthTags") || []) as string[]).join("; ");
        const comment = d.get("comment") || "";
        const ctx = d.get("contextTag") || "unknown context";
        return `[${ctx}] dims(${dims}) tags(${tags}) growth(${growth}) "${comment}"`;
      })
      .join("\n");

    const anthropic = new Anthropic({ apiKey: key });
    const response = await anthropic.messages.create({
      model: "claude-opus-4-8",
      max_tokens: 1500,
      output_config: {
        format: {
          type: "json_schema",
          schema: {
            type: "object",
            properties: {
              summary: {
                type: "string",
                description:
                  "2-3 warm, specific paragraphs: what people consistently say about this person, in second person.",
              },
              plan: {
                type: "string",
                description:
                  "A short growth plan: 3 concrete, kind suggestions grounded in the weakest dimensions / growth tags.",
              },
            },
            required: ["summary", "plan"],
            additionalProperties: false,
          },
        },
      },
      messages: [
        {
          role: "user",
          content:
            "You are the insight engine of Known, a consent-first feedback app. " +
            "Below is structured feedback this user received from people who know them " +
            "(dimensions are 1-5 ratings; growth tags are constructive). Write the JSON " +
            "summary and growth plan. Be specific, kind, and honest; never invent facts " +
            "not supported by the feedback; never mention reviewer identities.\n\n" +
            corpus,
        },
      ],
    });

    const textBlock = response.content.find((b) => b.type === "text");
    let summary = "";
    let plan = "";
    try {
      const parsed = JSON.parse(textBlock && "text" in textBlock ? textBlock.text : "{}");
      summary = String(parsed.summary || "");
      plan = String(parsed.plan || "");
    } catch {
      throw new HttpsError("internal", "Could not generate a summary. Try again.");
    }

    await db.collection("users").doc(uid).set(
      {
        aiSummary: {
          text: summary,
          plan,
          reviewCount: active.length,
          generatedAt: Timestamp.now(),
        },
      },
      { merge: true }
    );

    return { ok: true, summary, plan, cached: false };
  }
);

// ─── webWall (public wall web page, served via Hosting rewrite /w/**) ────────

/**
 * Server-rendered public wall page with OG tags — the shareable "link in bio"
 * artifact. Renders only owner-disclosed aggregates from publicWalls/{slug}.
 */
export const webWall = onRequest(async (req, res) => {
  const slug = req.path.split("/").filter(Boolean).pop() || "";
  const snap = slug
    ? await db.collection("publicWalls").doc(slug).get()
    : null;

  if (!snap?.exists) {
    res.status(404).send(wallPage(null));
    return;
  }
  const d = snap.data() || {};
  res.set("Cache-Control", "public, max-age=300, s-maxage=600");
  res.status(200).send(wallPage(d));
});

/** Minimal brand-matched SSR template (Clay & Ink). */
function wallPage(d: Record<string, unknown> | null): string {
  const esc = (s: unknown) =>
    String(s ?? "").replace(/[&<>"']/g, (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string)
    );
  const name = d ? esc(d.displayName) : "Known";
  const tagCounts = (d?.tagCounts as Record<string, number>) || {};
  const topTags = Object.entries(tagCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([t]) => `<span class="tag">${esc(t)}</span>`)
    .join("");
  const openness = d ? esc(d.opennessLabel || "New") : "";
  const count = d ? Number(d.reviewCount || 0) : 0;
  const title = d ? `${name} on Known` : "Wall not found";
  const desc = d
    ? `${count} people have laid bricks on ${name}'s wall · ${openness}`
    : "This wall is private or was unpublished.";
  const body = d
    ? `<h1>${name}</h1>
       <p class="sub">${count} brick${count === 1 ? "" : "s"} · openness: ${openness}</p>
       <div class="tags">${topTags}</div>
       <a class="cta" href="${WEB_BASE}">Claim your own wall →</a>`
    : `<h1>This wall is private</h1>
       <p class="sub">The owner hasn't published it — or took it down. That's how
       consent works here.</p>
       <a class="cta" href="${WEB_BASE}">What is Known? →</a>`;
  return `<!doctype html><html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${title}</title>
<meta property="og:title" content="${title}">
<meta property="og:description" content="${desc}">
<meta property="og:image" content="${WEB_BASE}/assets/icon.png">
<meta name="twitter:card" content="summary">
<style>
  body{margin:0;font-family:Georgia,serif;background:#13100D;color:#FAF5EC;
       display:flex;min-height:100vh;align-items:center;justify-content:center}
  main{max-width:520px;padding:40px;text-align:center}
  h1{font-size:2.2rem;margin:.2em 0}
  .sub{color:#B5A99B}
  .tags{margin:24px 0;display:flex;flex-wrap:wrap;gap:8px;justify-content:center}
  .tag{border:1px solid #E07A5F;color:#E07A5F;border-radius:100px;
       padding:6px 14px;font-size:.85rem}
  .cta{display:inline-block;margin-top:18px;background:#E07A5F;color:#13100D;
       padding:12px 22px;border-radius:14px;text-decoration:none;font-weight:bold}
</style></head><body><main>${body}</main></body></html>`;
}

// ─── Scheduled: recompute aggregates nightly ─────────────────────────────────

export const recomputeAggregates = onSchedule("every 24 hours", async () => {
  const walls = await db.collection("walls").get();
  for (const w of walls.docs) {
    await recomputeWall(w.id);
  }
});

// ─── Scheduled: streak-at-risk reminder (evening IST) ────────────────────────

/**
 * Users with a live streak (≥3 days) who haven't acted today get one nudge
 * before midnight. Single push per day by construction (job runs once).
 */
export const streakReminder = onSchedule(
  { schedule: "every day 19:30", timeZone: "Asia/Kolkata" },
  async () => {
    const now = Date.now();
    const gam = await db
      .collection("gamification")
      .where("streak.current", ">=", 3)
      .limit(500)
      .get();
    for (const g of gam.docs) {
      const last = (g.get("streak.lastActivityAt") as Timestamp | undefined)
        ?.toMillis() ?? 0;
      const hoursSince = (now - last) / 3_600_000;
      // Active earlier than today, but not yet today (job runs 19:30 IST).
      if (hoursSince < 20 || hoursSince > 44) continue;
      const current = (g.get("streak.current") as number) || 0;
      await sendPush(
        g.id,
        `Your ${current}-day streak ends at midnight 🔥`,
        "Give one piece of feedback to keep it alive.",
        { type: "streak_risk" }
      );
    }
  }
);

// ─── Scheduled: weekly digest (Monday morning IST) ──────────────────────────

export const weeklyDigest = onSchedule(
  { schedule: "every monday 10:00", timeZone: "Asia/Kolkata" },
  async () => {
    const weekAgo = Timestamp.fromMillis(Date.now() - 7 * 86_400_000);
    const users = await db.collection("users").limit(500).get();
    for (const u of users.docs) {
      try {
        if (!u.get("fcmToken")) continue;
        const recent = await db
          .collection("users")
          .doc(u.id)
          .collection("inbox")
          .where("createdAt", ">=", weekAgo)
          .get();
        if (recent.empty) continue;
        const n = recent.size;
        await sendPush(
          u.id,
          "Your week on Known",
          `${n} new piece${n > 1 ? "s" : ""} of feedback this week. See what changed.`,
          { type: "weekly_digest" }
        );
      } catch (err) {
        console.debug("Digest skipped for", u.id, err);
      }
    }
  }
);

// ─── Scheduled: escrow expiry sweep + sender nudges ──────────────────────────

/**
 * Daily: delete expired escrows; nudge senders whose escrow expires within
 * 5 days so they can re-share the invite (via their own share sheet — never
 * server SMS, keeping the TRAI posture intact).
 */
export const escrowSweep = onSchedule(
  { schedule: "every day 11:00", timeZone: "Asia/Kolkata" },
  async () => {
    const now = Date.now();
    const soon = Timestamp.fromMillis(now + 5 * 86_400_000);
    const expiring = await db
      .collection("invites")
      .where("expiresAt", "<=", soon)
      .limit(500)
      .get();
    for (const inv of expiring.docs) {
      const expiresAt = (inv.get("expiresAt") as Timestamp | undefined)?.toMillis() ?? 0;
      if (expiresAt <= now) {
        await inv.ref.delete();
        continue;
      }
      const reviewerUid = inv.get("reviewerUid") as string | undefined;
      const nudged = inv.get("expiryNudgedAt") as Timestamp | undefined;
      if (!reviewerUid || nudged) continue;
      const days = Math.max(1, Math.round((expiresAt - now) / 86_400_000));
      await sendPush(
        reviewerUid,
        "Your feedback is about to expire",
        `An invite you sent unlocks feedback you wrote — it expires in ${days} day${days > 1 ? "s" : ""}. Nudge them to join?`,
        { type: "escrow_expiring" }
      );
      await inv.ref.set({ expiryNudgedAt: Timestamp.now() }, { merge: true });
    }
  }
);

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

  // Mirror the sanitized aggregate into the owner's public web wall (opt-in).
  if (!ownerSnap.empty) {
    const ownerDoc = ownerSnap.docs[0];
    const slug = ownerDoc.get("publicSlug") as string | undefined;
    if (slug) {
      const meetsMinN = agg.reviewCount >= MIN_REVIEWS_FOR_AGGREGATE;
      await db.collection("publicWalls").doc(slug).set(
        {
          displayName: ownerDoc.get("displayName") || "A Wall member",
          reviewCount: agg.reviewCount,
          opennessLabel: openness.label,
          // min-N gating applies on the public page too.
          dimensionAverages: meetsMinN ? agg.dimensionAverages : {},
          tagCounts: meetsMinN ? agg.tagCounts : {},
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  }
}

/** Award contribution points for giving thoughtful feedback (2× on Feedback Friday). */
async function bumpContribution(uid: string): Promise<void> {
  const snap = await db.collection("users").doc(uid).get();
  await db.collection("gamification").doc(uid).set(
    {
      displayName: snap.get("displayName") || "Member",
      contributionPoints: FieldValue.increment(contributionPoints()),
    },
    { merge: true }
  );
}

export { GIVE_TO_GET };
