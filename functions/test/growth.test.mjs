// Tests for the growth-loop server helpers (taxonomy validation, referral
// premium math, Feedback Friday, invite tease, slug/code generators).
import test from "node:test";
import assert from "node:assert";

import {
  validateReviewTaxonomy,
  extendPremiumUntil,
  isPremiumNow,
  contributionPoints,
  isFridayInIndia,
  inviteTease,
  randomSlug,
  circleCode,
} from "../lib/util.js";

test("validateReviewTaxonomy accepts known dimensions/tags", () => {
  const r = validateReviewTaxonomy(
    { trustworthiness: 4, fun: 5 },
    ["Hype person"],
    ["Could listen more"]
  );
  assert.equal(r.ok, true);
});

test("validateReviewTaxonomy rejects unknown dimension", () => {
  const r = validateReviewTaxonomy({ vibes: 5 }, [], []);
  assert.equal(r.ok, false);
});

test("validateReviewTaxonomy rejects unknown tag", () => {
  const r = validateReviewTaxonomy({ fun: 5 }, ["Smells nice"], []);
  assert.equal(r.ok, false);
});

test("validateReviewTaxonomy caps growth tags at 2", () => {
  const r = validateReviewTaxonomy({ fun: 5 }, [], [
    "Could listen more",
    "Spreads too thin",
    "Takes on too much",
  ]);
  assert.equal(r.ok, false);
});

test("extendPremiumUntil stacks from current expiry and caps at 90d", () => {
  const now = 1_000_000_000_000;
  // No current expiry → now + 7 days.
  const a = extendPremiumUntil(undefined, now);
  assert.equal(a, now + 7 * 86_400_000);
  // Stacks from a future expiry.
  const future = now + 10 * 86_400_000;
  const b = extendPremiumUntil(future, now);
  assert.equal(b, future + 7 * 86_400_000);
  // Capped 90 days out.
  const farFuture = now + 100 * 86_400_000;
  const c = extendPremiumUntil(farFuture, now);
  assert.equal(c, now + 90 * 86_400_000);
});

test("isPremiumNow honours lifetime flag and referral window", () => {
  const now = 1_000_000_000_000;
  assert.equal(isPremiumNow(true, null, now), true);
  assert.equal(isPremiumNow(false, now + 1000, now), true);
  assert.equal(isPremiumNow(false, now - 1000, now), false);
  assert.equal(isPremiumNow(false, null, now), false);
});

test("Feedback Friday doubles contribution points", () => {
  // 2026-06-12 is a Friday (IST). 12:00 UTC is well within Friday IST.
  const friday = Date.parse("2026-06-12T12:00:00Z");
  assert.equal(isFridayInIndia(friday), true);
  assert.equal(contributionPoints(friday), 20);
  const monday = Date.parse("2026-06-15T12:00:00Z");
  assert.equal(isFridayInIndia(monday), false);
  assert.equal(contributionPoints(monday), 10);
});

test("inviteTease counts without leaking content", () => {
  assert.match(inviteTease("Bal", 3, false), /Bal said 3 things/);
  assert.match(inviteTease(null, 0, false), /Someone left you feedback/);
  // tags + comment both count.
  assert.match(inviteTease("Amy", 1, true), /Amy said 2 things/);
});

test("randomSlug and circleCode have expected shapes", () => {
  assert.match(randomSlug(), /^[a-z0-9]{10}$/);
  assert.match(circleCode(), /^[A-Z0-9]{6}$/);
  // Reasonably unique.
  assert.notEqual(randomSlug(), randomSlug());
});
