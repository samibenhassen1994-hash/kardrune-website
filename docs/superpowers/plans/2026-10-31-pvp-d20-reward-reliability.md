# PvP D20 and Reward Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate D20 rendering stalls/disappearance on mobile Web and guarantee recoverable, exactly-once winner rewards.

**Architecture:** Flutter renders pre-split 256×256 WebP frames instead of decoding and painting large atlases during the initiative overlay. Reward claims remain idempotent in D1, while the client recovers eligible unclaimed wins after 404, revision conflicts, reconnects or app restarts.

**Tech Stack:** Flutter Web/PWA, Cloudflare Pages Functions, D1, Cloudflare Durable Objects, Node test runner.

**Spec:** User request dated 2026-10-31 in this thread.

## Global Constraints

- Server-authoritative D20 result and match rules remain unchanged.
- Do not modify `/api/save`, stats, skills or existing security protections.
- Do not repeat D1 migrations or delete progress.
- Merge and deploy only after analyzer, tests and release build pass.

## Review Focus

- A slow image decode must show a stable placeholder/frame, never a blank die.
- The final result frame must remain visible until the server result text appears.
- A reward claim made before history persistence must recover after 404.
- A 409 revision conflict must reload the cloud revision before retrying.
- A lost `finished` event or app restart must recover an eligible unclaimed win exactly once.

---

### Task 1: Deterministic D20 frame renderer

**Files:** Create optimized assets and `dice_frame_assets.dart`; modify `live_pvp_arena.dart`; test `live_pvp_arena_test.dart` and frame mapping tests.

- [x] Write failing tests for split-frame mapping, visible fallback and static final result.
- [x] Verify RED.
- [x] Generate optimized 256×256 WebP spin frames and one final image per result; replace atlas painter with gapless frame playback.
- [x] Run focused tests and commit.

### Task 2: Recoverable exactly-once PvP reward

**Files:** Modify `functions/api/pvp/reward.js`, Flutter reward claim/recovery service and app wiring; add Node/Dart tests.

- [x] Write failing tests for pending-win discovery, 404 retry, 409 reload and restart recovery.
- [x] Verify RED.
- [x] Add authenticated pending reward discovery and idempotent client recovery using existing claim PK/rate limits.
- [x] Run focused tests and commit.

### Task 3: Validation and release

- [ ] Run Flutter analyze/test/build and Worker/Functions suites.
- [ ] Review complete diff and verify no migration or match-rule changes.
- [ ] Merge to `main`, verify Pages, and deploy Worker only if Worker source changed.
