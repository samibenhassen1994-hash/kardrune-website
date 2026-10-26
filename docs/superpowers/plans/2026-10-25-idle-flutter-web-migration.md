# Idle KardRune Flutter Web Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the complete Idle KardRune game as a production-ready Flutter Web app in `idle_flutter/` without changing the running legacy game or backend contracts.

**Architecture:** Port deterministic rules and JSON contracts first, then repository/services, then responsive feature screens and realtime PvP. Animation controllers remain local to animated widgets so state changes do not rebuild the whole application.

**Tech Stack:** Flutter/Dart, Material widgets with custom KardRune theme, `http`, Firebase Auth for Flutter Web, WebSocket, browser storage interop, Flutter test.

**Spec:** `docs/superpowers/specs/2026-10-25-idle-flutter-web-migration-design.md`

## Global Constraints

- Work only on `feature/idle-flutter-web-migration`; preserve `idle/`, main site, Playground, SEO, database, and backend behavior.
- New application lives only in `idle_flutter/`; no production deploy or merge.
- Preserve all source values, probabilities, rewards, formulas, schema keys, API paths, and WebSocket messages.
- Main screens have no page-level vertical scroll and respect safe areas at all five required mobile viewports.
- Use original assets and maintain Italian/English, accessibility, keyboard/touch/mouse operation, and PWA installability.
- Every behavior change follows RED→GREEN; commit each task independently.

## Review Focus

- A malformed or legacy local save must normalize without losing a valid owned card or inventing progress (Task 2 tests).
- A newer cloud revision and locally modified snapshot must stop automatic upload and require review (Task 3 tests).
- Reconnecting or starting a second match must cancel timers/animations and clear every prior match visual (Task 7 tests).
- 320×568 with browser text scaling must keep navigation and primary actions reachable without overflow (Tasks 4–7 widget tests).
- WebSocket messages arriving late or duplicated must not submit a second card or advance replay twice (Task 7 tests).

---

### Task 1: Flutter foundation and parity harness

**Files:** Create `idle_flutter/` Flutter project, `idle_flutter/lib/theme/`, `idle_flutter/lib/models/hero.dart`, `idle_flutter/lib/game/catalog.dart`, `idle_flutter/test/catalog_test.dart`; create `docs/IDLE_FLUTTER_AUDIT.md`.

**Interfaces:** Produces `HeroDefinition`, `KardRuneCatalog.heroes`, shared asset paths, theme tokens, and the JS→Dart feature matrix.

- [x] Write a failing catalog test asserting all nine heroes, stages, loops, powers, and asset paths from `idle/catalog.js`.
- [x] Run `flutter test test/catalog_test.dart`; expect missing catalog failures.
- [x] Scaffold Flutter Web, implement the catalog/theme, copy original game assets into `idle_flutter/assets/idle/`, and document the feature matrix.
- [x] Run catalog test and `flutter analyze`; expect zero failures/errors.
- [x] Commit `feat: scaffold Idle KardRune Flutter app`.

### Task 2: Pure rules and save migration parity

**Files:** Create `lib/game/game_rules.dart`, `combat_rules.dart`, `summon_rules.dart`, `deck_rules.dart`, `lib/models/player_save.dart`; tests `game_rules_test.dart`, `combat_rules_test.dart`, `summon_rules_test.dart`, `deck_rules_test.dart`, `player_save_test.dart`; parity fixtures under `test/fixtures/`.

**Interfaces:** Produces deterministic random-source APIs, `PlayerSave.fromJson/toJson`, `CombatState`, `SummonResult`, and nine-slot deck operations.

- [x] Write failing Dart tests with literal outputs matching all existing JS rule tests plus summon thresholds/costs, duplicate keep/replace, initial save, legacy IDs/stats, and invalid values.
- [x] Run the focused tests; expect missing symbols.
- [x] Implement minimal pure Dart rules and models using exact JS semantics and JSON names.
- [x] Generate shared fixture inputs and compare Node and Dart JSON outputs for parity.
- [x] Run focused tests and JS suites; expect all pass except the documented pre-existing legacy CRIT test defect.
- [x] Commit `feat: port Idle game rules and saves to Dart`.

### Task 3: Local/cloud persistence and authentication

**Files:** Create `lib/services/local_save_service.dart`, `firebase_auth_service.dart`, `api_client.dart`, `lib/repositories/save_repository.dart`, tests for serialization/reconciliation/API payloads.

**Interfaces:** Consumes `PlayerSave`; produces `SaveRepository.load`, `saveLocal`, `sync`, authenticated `/api/*` calls, and revision conflict states.

- [x] Write failing tests for legacy storage import, snapshot adoption/upload/download/review decisions, revision 409, account switch, retry state, and unchanged JSON compatibility.
- [x] Run focused tests; expect missing services.
- [x] Implement injected storage/auth/HTTP boundaries and exact `/api/config`, `/api/me`, `/api/save`, `/api/pvp/*` contracts.
- [x] Run focused tests and full Flutter suite.
- [x] Commit `feat: add compatible local and cloud saves`.

### Task 4: Responsive shell, Tournament, Cards, Summon, Profile

**Files:** Create feature folders and common responsive widgets; create viewport/widget tests and golden candidates.

**Interfaces:** Consumes catalog, rules, repository; produces four navigable, safe-area-aware feature screens and app controller.

- [x] Write failing widget tests for navigation/state, all five viewport sizes, bounded collection paging, training rewards, summon/duplicate flows, profile/avatar/name/language, semantics, and no overflow exceptions.
- [x] Run focused widget tests; expect missing screens.
- [x] Implement centered desktop game container, fixed mobile shell, bottom navigation, original asset cards, dialogs, and feature state.
- [x] Run widget tests and capture a candidate screenshot at 390×844.
- [x] Commit `feat: migrate core Idle screens to Flutter`.

### Task 5: Nine-slot deck builder and drag/drop

**Files:** Create `features/cards/deck_builder.dart`, `widgets/card_drag_avatar.dart`, `animations/snap_back.dart`; tests for drag/tap/keyboard behavior.

**Interfaces:** Consumes deck rules and save repository; produces 1–9-card local draft and authenticated deck save.

- [x] Write failing tests for insert, invalid drop snap-back, target highlight, immediate pointer drag, tap alternative, transparent proportional feedback, and save callback.
- [x] Run focused tests; expect missing deck builder.
- [x] Implement pointer-based Flutter drag with animated target state, automatic snap-back and nine visible slots.
- [x] Run focused tests plus full suite.
- [x] Commit `feat: add Flutter nine-slot deck builder`.

### Task 6: Asynchronous PvP and live transport

**Files:** Create `services/live_pvp_socket.dart`, `repositories/pvp_repository.dart`, `features/pvp/pvp_controller.dart`; protocol/transport tests.

**Interfaces:** Produces typed representations for every existing server event and sends only `play`, `ready`, `pong`.

- [x] Write failing tests for ticket URI, protocol decoding, heartbeat response, match reset, and one play per round.
- [x] Run focused tests; expect missing transport/controller.
- [x] Implement existing HTTP/WebSocket contracts with injected socket adapters and typed server events.
- [x] Run focused tests and Worker Node tests.
- [x] Commit `feat: connect Flutter to existing PvP services`.

### Task 7: Dedicated realtime arena and animations

**Files:** Create `features/pvp/live_pvp_arena.dart`, arena widgets, `animations/card_deal.dart`, `combat_replay.dart`, `battle_effects.dart`; widget/controller tests.

**Interfaces:** Consumes typed server events; produces full-screen arena, draw/select/replay/result sequences, and `ready` after replay.

- [x] Write failing tests for three-card physical deal, 30-second deadline display, drag/tap/automatic lock, attack sequence, critical treatment, two-second popup, adaptive replay timing, disconnect result, and complete two-match reset.
- [x] Run focused tests; expect missing arena.
- [x] Implement layered `Stack` arena with isolated controllers/custom painters, safe-area layout, server-authoritative HP/log replay, and cancellation tokens.
- [x] Run focused tests across all viewports and full suite.
- [x] Commit `feat: build animated Flutter realtime PvP arena`.

### Task 8: PWA, performance, validation, and release documentation

**Files:** Modify Flutter web manifest/bootstrap/build config; create deployment/runbook docs and comparison screenshots; add end-to-end smoke tests where supported.

**Interfaces:** Produces a `/idle/`-base build artifact and documented preview/cutover/rollback process; does not deploy.

- [x] Write failing checks for base href, manifest/icon metadata, service-worker namespace, lazy asset loading, focus/semantics, and production API paths.
- [x] Implement PWA/update deferral during matches, build scripts, Cloudflare preview instructions, cache separation, and safe replacement plan.
- [x] Run `flutter analyze`, `flutter test`, `flutter build web --release --base-href /idle/`, existing Node tests, and available browser/mobile smoke checks; record exact evidence and manual gaps.
- [x] Compare Flutter and legacy screenshots; fix only demonstrated regressions through RED→GREEN tests.
- [x] Commit `chore: validate Flutter Web release candidate`.
- [ ] Perform whole-branch review, push the feature branch, and open a PR without merging or deploying.

### Post-review integration gate

- [x] Wire legacy local save loading/writes, exact practice rewards/statistics, summon stats/duplicate replacement, and local deck draft into the launched app.
- [x] Reject duplicate `round_result` replay/`ready` advancement.
- [x] Wire Firebase sign-in and D1 save reconciliation into Profile and the launched app.
- [ ] Wire deck cloud save, matchmaking, WebSocket controller, and `LivePvpArena` into Tournament.
- [ ] Connect browser service-worker update notification to the match-aware update gate.
- [ ] Repeat whole-branch review; only then push and create the PR.

