# Live PvP Initiative and Interaction Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Summon entrance motion, Auto Deck, distinct skill VFX, winner-only rewards, and server-authoritative dice initiative with alternating round starters.

**Architecture:** Flutter owns presentation and deterministic deck selection. The live PvP Durable Object owns dice rolls, starter selection, combat ordering and reward eligibility; clients only render typed events and replay authoritative logs.

**Tech Stack:** Flutter/Dart, Flame, Cloudflare Workers/Durable Objects, D1, Node test runner.

**Spec:** `docs/superpowers/specs/2026-10-31-pvp-initiative-and-security-design.md`

## Global Constraints

- Do not change skill rules, HP, Summon probabilities/costs or ranked state.
- Dice and reward authority must be server-side.
- Push this completed plan to `main` only after all checks pass.

## Review Focus

- Reconnects and duplicate events must not replay dice or grant twice.
- A tied dice roll must resolve server-side and terminate.
- Player-relative indices must preserve the same starter/log order for both clients.
- Auto Deck must be deterministic with missing stats and fewer than nine cards.
- Animation lifecycle must not leak controllers or delay authoritative ready messages.

---

### Task 1: Summon entrance and Auto Deck

**Files:** Modify `idle_flutter/lib/features/summon/summon_screen.dart`, `idle_flutter/lib/game/deck_rules.dart`, `idle_flutter/lib/features/cards/deck_builder.dart`; test `idle_flutter/test/app_shell_test.dart`, `idle_flutter/test/deck_rules_test.dart`, `idle_flutter/test/deck_builder_widget_test.dart`.

**Interfaces:** Produces panel entrance animation and `DeckRules.auto(...)` selecting the strongest nine distinct owned cards.

- [x] Write failing widget/rule tests for slide entrance and deterministic strongest-card selection.
- [x] Run focused tests and verify RED.
- [x] Implement isolated entrance controller and Auto Deck action.
- [x] Run focused tests and commit.

### Task 2: Skill-specific battle effects

**Files:** Modify `idle_flutter/lib/features/pvp/live_flame_battle.dart`, `idle_flutter/lib/features/pvp/flame_attack_style.dart`, `idle_flutter/lib/features/pvp/live_pvp_arena.dart`; test `idle_flutter/test/live_pvp_arena_test.dart` and focused Flame mapping tests.

**Interfaces:** Consumes skill IDs/events and produces a distinct immutable visual profile per skill without changing combat data.

- [x] Write failing tests proving all 30 skills resolve to distinct profiles and unknown skills fall back safely.
- [x] Run focused tests and verify RED.
- [x] Implement skill-specific palettes, glyph/motion/effect parameters using existing VFX families.
- [x] Run focused tests and commit.

### Task 3: Server-authoritative dice and alternating initiative

**Files:** Modify `live-pvp/src/index.js`, `live-pvp/src/rules.js`, `live-pvp/src/skill_duel.js`, `idle_flutter/lib/services/live_pvp_socket.dart`, live match/arena UI; add dice asset; test Worker and Flutter protocol/arena tests.

**Interfaces:** Produces `dice` WebSocket event and `resolveSkillDuel(cards, random, starter)`; `hand`/`round_result` identify authoritative starter.

- [x] Write failing Worker tests for server rolls, tie resolution, starter alternation and attack order.
- [x] Write failing Dart protocol/UI tests for dice intro and relative starter mapping.
- [x] Run focused suites and verify RED.
- [x] Import the approved sprite, implement server state/protocol, typed client event and intro animation.
- [x] Run focused suites and commit.

### Task 4: Winner-only idempotent live reward

**Files:** Modify Worker finish/reward flow and Flutter completion display; add/update D1 migration only if required; test Worker/API/Flutter completion tests.

**Interfaces:** Server grants exactly 100 Shards once to `winner_uid` for a legitimately completed match; finished event exposes `reward` for the current player.

- [x] Write failing tests: winner +100, loser/draw +0, duplicate finish +0.
- [x] Run tests and verify RED.
- [x] Implement atomic server grant and player-specific finished payload.
- [x] Update Flutter to display reward only when payload is 100.
- [x] Run tests and commit.

### Task 5: Main validation and release

**Files:** Update golden only for intentional UI changes; no unrelated files.

- [x] Run `flutter analyze`, `flutter test`, Web release build and `npm test` for live PvP/functions.
- [x] Review the complete diff for protocol/security regressions.
- [ ] Push commits to `main`, wait for build workflow and verify success.
