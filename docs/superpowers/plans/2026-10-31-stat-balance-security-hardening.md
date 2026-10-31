# Stat Balance and Security Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce stage-specific effective stat ranges and close competitive/economic abuse paths while preserving historical player data.

**Architecture:** Central bounds exist in JS and Dart. New grants are generated within range; raw historical values remain stored, while every trusted read/combat/deck/save boundary derives bounded effective values. Economic changes remain transactional, authenticated, ban-checked and idempotent.

**Tech Stack:** Flutter/Dart, Cloudflare Pages Functions, Workers, D1, Node tests.

**Spec:** `docs/superpowers/specs/2026-10-31-pvp-initiative-and-security-design.md`

## Global Constraints

- Work on a new branch; push it without merge or deployment.
- Preserve Firebase/D1 schema compatibility and historical raw values.
- Keep HP, skill, probabilities and costs unchanged.

## Review Focus

- Legacy out-of-range grants must remain readable but never exceed effective limits.
- `/api/save` must not raise wallet, PvP results or verified grants.
- Concurrent reward requests must produce one grant.
- Banned users must be rejected before any economic mutation.
- Stage minimums must apply to malformed/legacy low values as well as maximums.

---

### Task 1: Central effective stat ranges

**Files:** Create shared JS bounds module and Dart bounds class; modify Summon generation, save parsing, deck/PvP card construction and tests.

- [x] Write failing literal tests for all stage boundaries and generated values.
- [x] Verify RED, implement centralized clamping/generation, verify GREEN.
- [x] Commit.

### Task 2: Competitive save isolation

**Files:** Modify `/api/save` validation/normalization and tests.

- [x] Write failing tests proving forged wallet/grants/PvP fields cannot alter authoritative state.
- [x] Implement server-owned field preservation and verify tests.
- [x] Commit.

### Task 3: Reward anti-farming and idempotency

**Files:** Modify reward/history transaction flow, add migration only if an idempotency constraint is absent, and tests.

- [x] Write failing concurrent/double-claim/farming tests.
- [x] Implement atomic unique grant and abuse limits without ranked rewards.
- [x] Commit.

### Task 4: Ban enforcement on economic endpoints

**Files:** Centralize account-status guard and apply to Summon, duplicate decision, practice, reward, deck/ticket economic paths; tests.

- [x] Write failing banned-account tests for every mutating endpoint.
- [x] Implement shared guard and verify no mutation occurs.
- [x] Commit.

### Task 5: Full verification and branch push

- [ ] Run Flutter analyze/tests/build, Functions tests, Worker tests and migration checks.
- [ ] Perform whole-branch security review and fix Critical/Important findings through RED→GREEN.
- [ ] Push the new branch only; do not merge or deploy.
