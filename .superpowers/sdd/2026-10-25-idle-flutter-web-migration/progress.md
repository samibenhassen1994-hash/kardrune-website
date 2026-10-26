# SDD ledger — plan: docs/superpowers/plans/2026-10-25-idle-flutter-web-migration.md

Pre-flight: Tasks 2–8 consume catalog/theme from Task 1; Tasks 3–7 consume rules/models from Task 2; Tasks 4–7 consume persistence from Task 3; Tasks 6–7 share the typed PvP protocol. Interfaces are consistent with the design spec.

Task 1: complete (tests: `flutter test` → 2/2 passed; `flutter analyze` → no issues)

Task 2: Ruling: `idle/tests/combat-rules.test.js` has a pre-existing invalid critical fixture whose first CRIT roll is 0.5 against 25%, so it expects a critical where the legacy implementation correctly returns false — preserved `idle/` unchanged as required; Dart parity uses literal valid rolls and shared JS fixtures — cost if wrong: the legacy-only test remains red until separately corrected.

Task 2: complete (tests: shared JS parity 5/5, `flutter test` 13/13, live-pvp Node tests 4/4, `flutter analyze` no issues; legacy Node suite 26/27 with the documented pre-existing CRIT fixture failure)

Task 3: complete (tests: `flutter test` 23/23; `flutter analyze` no issues; local legacy key preserved; Firebase/HTTP adapters and revision conflict rules verified)

Task 4: complete (Flutter tests 33/33 including training reward, duplicate resolution, language navigation and viewports 320×568, 375×667, 390×844, 393×852, 430×932; golden `tournament_390x844.png`; `flutter analyze` no issues)

Task 5: complete (Deck Builder tests 3/3; full Flutter suite 37/37; `flutter analyze` no issues; nine non-virtualized slots, immediate drag, highlight, invalid-drop return, tap alternative and Cards integration verified)

Task 6: complete (protocol tests 4/4; Worker rules 4/4; `flutter analyze` no issues; unchanged `play`/`ready`/`pong`, ticket URI, typed inbound events and duplicate-play lock verified)

Task 7: complete (`flutter test` 47/47; `flutter analyze` no issues; physical three-card deal, tap/drag lock, countdown, authoritative HP/log replay, attack/critical effects, two-second result, disconnect handling, cancellation token and second-match reset verified)

Task 8: complete (`flutter test` 49/49; `flutter analyze` no issues; release build succeeded with `/idle/`; PWA worker has isolated `idle-kardrune-v1` cache; Worker rules 4/4; legacy 26/27 with documented CRIT fixture; local 390×844 legacy/Flutter browser smoke completed with clean Flutter logs; no deploy)

Whole-branch review gate: NOT READY FOR PR. Critical finding was that the launched shell did not construct persistence/auth/PvP services. Post-review work now wires automatic Web localStorage through conditional imports, exact `GameRules` practice results/statistics, summon ATK/CRIT/pulls and duplicate replacement, persistent deck drafts, plus a one-replay-per-hand guard. Remaining before PR: Firebase Profile/auth + D1 save reconciliation, cloud deck/matchmaking/WebSocket arena routing, and browser service-worker update signaling through `AppUpdateGate`. Do not push/open PR until these are implemented, tested, and re-reviewed.

Task A runtime integration: complete in working branch (Firebase config remains server-provided; Profile exposes Google/email/register/logout; authenticated `/api/me` and `/api/save` reconciliation protects account switches and 409 conflicts; first backup and explicit upload/load are covered by controller tests). Next: Task B cloud deck and live arena routing.

Task B runtime integration: complete in working branch (`/api/pvp/deck` load/save, live ticket, forced `/connect` Worker path, typed socket stream, automatic arena opening on `hand`, server-authoritative replay, one `ready`, disconnect/close/reset, local two-match-safe arena state; app integration test covers Tournament→arena).

Task C runtime integration: complete in working branch (dedicated `idle-kardrune-v1` worker announces waiting updates, Flutter displays a manual UPDATE action, `AppUpdateGate` defers application while arena state is active, controller change reloads once, `/idle/` relative scope retained).

Final automated verification (2026-10-26): Flutter 61/61 passed; analyze no issues; release build with `--base-href /idle/` succeeded; live-PvP Worker rules 4/4 passed; untouched legacy rules 26/27 with only the documented invalid CRIT fixture. Golden refreshed for the intentional Tournament live-match control. Remaining release gates are a fresh whole-branch review and manual preview tests with real Firebase/D1, two accounts, realtime WebSocket, service-worker lifecycle, and physical iPhone.

