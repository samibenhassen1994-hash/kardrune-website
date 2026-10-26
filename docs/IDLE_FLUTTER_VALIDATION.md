# Idle KardRune Flutter Web — validation evidence

Evidence is recorded against branch `feature/idle-flutter-web-migration`; no deployment or merge is part of validation.

> Status: the post-review Firebase/D1, cloud deck, live matchmaking/WebSocket arena, and match-aware PWA update integrations are implemented and pass the automated release checks. A final whole-branch review is still required before opening the PR.

## Automated coverage

- Dart parity fixtures execute the original JavaScript inputs and compare normalized outputs.
- Persistence tests cover legacy local-storage import, reconciliation decisions, revision conflicts, account switches, retry backoff, first-account backup, Profile authentication actions, and explicit cloud conflict choices.
- Widget tests cover 320×568 through 430×932 layouts, feature navigation, summon decisions, rewards, Deck Builder drag/tap behavior, and realtime arena lifecycle.
- PvP tests cover the unchanged Worker protocol, forced `/connect` socket path, cloud deck endpoints, ticket acquisition, automatic arena routing, one-play lock, physical deal, timer, authoritative replay, critical/hit feedback, two-second result, disconnect, late-event cancellation, and second-match reset.
- Web release tests cover PWA identity, `/idle/` base injection, install scope, zoom lock, browser-to-Flutter update signaling, `SKIP_WAITING`, and match-aware update deferral.

Final automated run on 2026-10-26: `flutter test` 61/61 passed; `flutter analyze` reported no issues; `flutter build web --release --base-href /idle/` completed and produced `build/web`; live-PvP Worker rules 4/4 passed; legacy rules 26/27 passed with only the baseline CRIT fixture below.

## Visual evidence

The deterministic Flutter candidate is `idle_flutter/test/goldens/tournament_390x844.png`. It was refreshed only after the new live-match control intentionally changed the Tournament screen, then rechecked with the golden test. Earlier local browser smoke captures were inspected at 390×844 for both `idle/#tournament` and the `/idle/`-based Flutter release: navigation remained reachable, no overflow occurred, original card assets loaded, and browser logs contained no warnings/errors. The legacy screen contains richer promotional copy than the migrated training view; this remains visible in the comparison and is not concealed as a test success.

## Manual release gates

The automated suite does not substitute for a preview-environment check with real credentials and network services. Before cutover, verify Google and email authentication, first-device backup and account switching against Firebase/D1, two simultaneous authenticated accounts through a complete realtime match, update arrival during a live round, install/update behavior on a physical iPhone, and the documented legacy/Flutter visual comparison. No production deployment was performed during this validation.

## Known baseline

The untouched legacy `idle/tests/combat-rules.test.js` suite contains one pre-existing invalid CRIT fixture: a roll of `0.5` is expected to pass a 25% threshold. The implementation and Dart parity preserve the actual JavaScript rule; all other legacy rule cases pass.
