// Unit tests for the pure server-side logic (aggregation, openness, growth).
// Uses the Node built-in test runner — no extra dependencies.
// Run with `npm test` (builds first, then `node --test`).
import test from "node:test";
import assert from "node:assert";

import {
  aggregate,
  opennessLabel,
  computeGrowthScore,
  decayWeight,
  isBurst,
} from "../lib/util.js";

test("decayWeight is ~1 for a fresh review and decays with age", () => {
  assert.ok(Math.abs(decayWeight(0) - 1) < 1e-9);
  assert.ok(decayWeight(100) < decayWeight(10));
  assert.ok(decayWeight(10) < decayWeight(0));
});

test("aggregate computes decay-weighted means and tag counts", () => {
  const now = Date.now();
  const r = aggregate(
    [
      { dimensions: { punctuality: 5 }, tags: ["helpful"], createdAt: now },
      { dimensions: { punctuality: 3 }, tags: ["helpful"], createdAt: now },
    ],
    now
  );
  assert.equal(r.reviewCount, 2);
  assert.ok(Math.abs(r.dimensionAverages.punctuality - 4) < 1e-6);
  assert.equal(r.tagCounts.helpful, 2);
});

test("aggregate weights recent reviews more than old ones", () => {
  const now = Date.now();
  const old = now - 400 * 86_400_000; // ~400 days old
  const r = aggregate(
    [
      { dimensions: { reliability: 1 }, tags: [], createdAt: old },
      { dimensions: { reliability: 5 }, tags: [], createdAt: now },
    ],
    now
  );
  // The fresh 5 should dominate, pulling the mean above the simple average (3).
  assert.ok(r.dimensionAverages.reliability > 3);
});

test("opennessLabel buckets the disclosed/received ratio", () => {
  assert.equal(opennessLabel(0, 0).label, "New");
  assert.equal(opennessLabel(9, 10).label, "Very Open");
  assert.equal(opennessLabel(6, 10).label, "Open");
  assert.equal(opennessLabel(3, 10).label, "Selective");
  assert.equal(opennessLabel(1, 10).label, "Private");
});

test("computeGrowthScore is bounded to [0, 100]", () => {
  assert.equal(computeGrowthScore(0, 0, 0), 0);
  assert.equal(computeGrowthScore(1000, 100, 100), 100);
  assert.equal(computeGrowthScore(0, 10, 0), 30); // reviewCount * 3
});

test("isBurst flags only high-velocity clusters", () => {
  assert.equal(isBurst(6, 6), true);
  assert.equal(isBurst(3, 3), false);
  assert.equal(isBurst(6, 3), false);
});
