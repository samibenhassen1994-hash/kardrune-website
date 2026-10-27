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

Visual fidelity pass — Tournament/Home (2026-10-26): rebuilt Flutter header/logo, radial background, serif hierarchy, Rune Circuit banner, framed practice arena, original card art, gold/dark actions, and fixed four-tab navigation from the rendered legacy reference. Browser before/original/after captures are under `idle_flutter/test/visual/`; exact Flutter viewport coverage passes at 320×568, 375×667, 390×844, 393×852, and 430×932 with no overflow. Next visual screen: Cards/Collection; animation preference and remaining screens still pending.

Visual fidelity pass — Cards/Summon/Profile (2026-10-26): Cards now mirrors the original loadout, nine-slot preview, collection progress, filters, framed asset grid and styled Deck Builder; Summon mirrors the Dren featured portal and two original summon choices; Profile uses the original framed avatar/profile hierarchy. Added device-local `idle-motion-preference-v1` with Automatic/Full/Reduced choices, independent from save JSON, and propagated reduced-motion state to Deck Builder and PvP visual transitions without skipping combat/result timing. Focused responsive, cloud, deck and arena tests pass; Arena visual comparison remains the next UI checkpoint.

Visual fidelity pass — PvP arena (2026-10-26): restored the original vertical composition (live header and round, rival zone/hand above, Rune Clash center, used pile left, deck remaining right, player hand below) while keeping physical deal, drag/tap, authoritative replay, HP/critical effects and two-second results. Added deterministic 390×844 golden coverage for Tournament, Cards, Summon, Profile and PvP arena.

Post-visual automated verification (2026-10-26): Flutter 69/69 passed, `flutter analyze` no issues, and release build with `--base-href /idle/` succeeded. No changes exist under legacy `idle/`, backend, database, or game-rule files in this visual pass. Real Safari/iPhone, real Firebase/D1 credentials, and a two-account deployed-preview match remain manual release checks and were not claimed.

Cards and PvP completion pass (2026-10-26): Collection card art now has an opaque mouse/touch hit target; owned taps immediately select and persist the active champion, while locked taps open a non-playable preview. Cards display persisted ATK/CRIT plus stage-derived HP, duplicate replacement refreshes/persists the same values, and selected saved ATK/stage is covered through the practice result. The two-row grid now sizes to its available viewport at 320×568 through 430×932 without being hidden by navigation. Flutter analyze is clean; Flutter 73/73 and Worker rules 4/4 pass. Worker inspection confirms ticket replay protection, D1-owned deck/stat validation, server hand validation, 30-second timeout selection, server-side duel resolution, one-ready set semantics, disconnect/reconnect handling, and server-authored round/finish events. A real two-account match remains unverified without deployed credentials/runtime and is not claimed.

Final PvP review qualification (2026-10-27): realtime match execution is server-side, but the D1 demo save feeding ownership/ATK/CRIT remains client-authored within validated ranges and `/api/save` explicitly returns `competitive:false`; ranked rewards must remain disabled. The existing Worker 100-hit guard can return a round winner while both low-ATK fighters still have HP (reproduced with stage-1 ATK 1 versus stage-3 ATK 2). Removing the guard alone would create replay logs up to roughly 860 hits and exceed the current client replay/ready timing, so the production Worker was deliberately left unchanged; fix this only as a coordinated Worker protocol plus bounded authoritative replay change. Remaining manual release checks: deployed preview with two real authenticated accounts, real Firebase/D1 reconciliation, WebSocket timeout/reconnect, service-worker update lifecycle, and physical iPhone/Safari portrait testing.

Card stat badge pass (2026-10-27): Collection/details and realtime PvP cards now render the saved ATK in a red circular badge, saved CRIT in a purple badge, and stage-derived HP in a blue circular badge over the top of the original card art, matching the supplied visual reference. Locked previews expose only deterministic HP and em dashes for unavailable ATK/CRIT. Widget interaction, compact arena layout, responsive viewports and refreshed Collection/Arena goldens pass; Flutter 73/73 and analyze are clean.

